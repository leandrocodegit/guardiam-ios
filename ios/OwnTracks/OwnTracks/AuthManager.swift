//
//  AuthManager.swift
//  OwnTracks
//
//  Equivalente ao AuthManager.kt do Android.
//  Gerencia o fluxo OAuth2/OIDC com Keycloak via AppAuth-iOS.
//
//  IMPORTANTE: Adicionar o pacote AppAuth-iOS via Xcode:
//  File > Add Package Dependencies > https://github.com/openid/AppAuth-iOS ~> 2.0
//

import Foundation
import AppAuth
import SafariServices

@objc class AuthManager: NSObject {

    // MARK: - Constantes
    private static let issuerURI   = "https://auth.simodapp.com/realms/bipe.simodapp.com"
    private static let clientID    = "bipe.simodapp.com"
    private static let redirectURI = "bipe.me://auth"
    private static let scope       = "openid profile email"
    private static let accountURL  = "https://auth.simodapp.com/realms/bipe.simodapp.com/account/#/security/signing-in"

    // MARK: - Persistência
    private static let authStateKey = "OIDAuthState"

    // MARK: - Estado
    private var authState: OIDAuthState? {
        didSet { saveAuthState() }
    }

    /// Guarda a sessão em andamento durante o redirect do browser
    private var currentAuthorizationFlow: OIDExternalUserAgentSession?

    // MARK: - Singleton
    @objc static let shared = AuthManager()

    private override init() {
        super.init()
        loadAuthState()
    }

    // MARK: - Público

    /// Retorna `true` se há um token válido (ou renovável)
    @objc var isAuthorized: Bool {
        return authState?.isAuthorized == true
    }

    /// Inicia o fluxo de login OAuth via SFAuthenticationSession / ASWebAuthenticationSession.
    /// O resultado chega via completion: `(success: Bool, error: Error?) -> Void`
    func startLogin(presenting viewController: UIViewController,
                    completion: @escaping (Bool, Error?) -> Void) {

        guard let issuerURL = URL(string: AuthManager.issuerURI) else {
            completion(false, NSError(domain: "AuthManager", code: -1,
                                     userInfo: [NSLocalizedDescriptionKey: "ISSUER_URI inválida"]))
            return
        }

        OIDAuthorizationService.discoverConfiguration(forIssuer: issuerURL) { [weak self] config, error in
            guard let self = self, let config = config else {
                completion(false, error)
                return
            }

            let request = OIDAuthorizationRequest(
                configuration: config,
                clientId: AuthManager.clientID,
                clientSecret: nil,
                scopes: [OIDScopeOpenID, OIDScopeProfile, "email"],
                redirectURL: URL(string: AuthManager.redirectURI)!,
                responseType: OIDResponseTypeCode,
                additionalParameters: nil
            )

            DispatchQueue.main.async {
                guard let externalUserAgent = OIDExternalUserAgentIOS(presenting: viewController, prefersEphemeralSession: true) ?? OIDExternalUserAgentIOS(presenting: viewController) else {
                    completion(false, NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Falha ao inicializar OIDExternalUserAgentIOS"]))
                    return
                }
                self.currentAuthorizationFlow = OIDAuthorizationService.present(
                    request,
                    externalUserAgent: externalUserAgent
                ) { response, error in
                    if let response = response {
                        let authState = OIDAuthState(authorizationResponse: response)
                        self.authState = authState
                        if let tokenRequest = response.tokenExchangeRequest() {
                            OIDAuthorizationService.perform(tokenRequest) { tokenResponse, tokenError in
                                authState.update(with: tokenResponse, error: tokenError)
                                self.authState = authState
                                completion(tokenError == nil, tokenError)
                            }
                        } else {
                            completion(true, nil)
                        }
                    } else {
                        completion(false, error)
                    }
                }
            }
        }
    }

    /// Abre a página de gerenciamento de conta do Keycloak em um SFSafariViewController,
    /// permitindo o cadastro e gerenciamento completo de Passkeys (WebAuthn) com Face ID / Touch ID / iCloud Keychain.
    @objc func openAccountManagement(presenting viewController: UIViewController) {
        guard let url = URL(string: AuthManager.accountURL) else { return }
        let safariVC = SFSafariViewController(url: url)
        safariVC.dismissButtonStyle = .close
        viewController.present(safariVC, animated: true, completion: nil)
    }

    /// Processa o redirect URI vindo do iOS (chamado no AppDelegate / SceneDelegate)
    @objc func handleRedirectURL(_ url: URL) -> Bool {
        if let flow = currentAuthorizationFlow, flow.resumeExternalUserAgentFlow(with: url) {
            currentAuthorizationFlow = nil
            return true
        }
        return false
    }

    /// Retorna o Bearer token atual (com refresh automático se necessário).
    /// Chama o completion na thread que invocar, mas internamente usa background.
    func getBearerToken(completion: @escaping (String?) -> Void) {
        guard let authState = authState else {
            completion(nil)
            return
        }

        authState.performAction { accessToken, _, error in
            if let token = accessToken {
                completion("Bearer \(token)")
            } else {
                completion(nil)
            }
        }
    }

    /// Retorna o Access Token atual
    @objc func getAccessToken() -> String? {
        return authState?.lastTokenResponse?.accessToken
    }

    /// Retorna o ID Token atual
    @objc func getIdToken() -> String? {
        return authState?.lastTokenResponse?.idToken
    }

    /// Retorna o Refresh Token atual
    @objc func getRefreshToken() -> String? {
        return authState?.lastTokenResponse?.refreshToken ?? authState?.refreshToken
    }

    /// Extrai o `sub` do ID token (userId Keycloak)
    @objc func getUserId() -> String? {
        guard let idToken = authState?.lastTokenResponse?.idToken else { return nil }
        let parts = idToken.components(separatedBy: ".")
        guard parts.count == 3,
              let payloadData = Data(base64Encoded: base64Padded(parts[1])),
              let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let sub = json["sub"] as? String
        else { return nil }
        return sub
    }

    /// Inicia a sessão utilizando o Refresh Token salvo (usado na Biometria)
    func loginWithRefreshToken(refreshToken: String? = nil, completion: @escaping (Bool, Error?) -> Void) {
        let tokenToUse = refreshToken ?? BiometricAuthManager.shared.getStoredRefreshToken()
        guard let refreshTok = tokenToUse, !refreshTok.isEmpty else {
            completion(false, NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Nenhum refresh token encontrado"]))
            return
        }

        guard let issuerURL = URL(string: AuthManager.issuerURI) else {
            completion(false, NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "ISSUER_URI inválida"]))
            return
        }

        OIDAuthorizationService.discoverConfiguration(forIssuer: issuerURL) { [weak self] config, error in
            guard let self = self, let config = config else {
                completion(false, error)
                return
            }

            let tokenRequest = OIDTokenRequest(
                configuration: config,
                grantType: OIDGrantTypeRefreshToken,
                authorizationCode: nil,
                redirectURL: URL(string: AuthManager.redirectURI),
                clientID: AuthManager.clientID,
                clientSecret: nil,
                scopes: [OIDScopeOpenID, OIDScopeProfile, "email"],
                refreshToken: refreshTok,
                codeVerifier: nil,
                additionalParameters: nil
            )

            OIDAuthorizationService.perform(tokenRequest) { tokenResponse, tokenError in
                if let tokenResponse = tokenResponse {
                    if let currentAuthState = self.authState {
                        currentAuthState.update(with: tokenResponse, error: nil)
                        self.authState = currentAuthState
                    } else {
                        let dummyReq = OIDAuthorizationRequest(
                            configuration: config,
                            clientId: AuthManager.clientID,
                            clientSecret: nil,
                            scopes: [OIDScopeOpenID, OIDScopeProfile, "email"],
                            redirectURL: URL(string: AuthManager.redirectURI)!,
                            responseType: OIDResponseTypeCode,
                            additionalParameters: nil
                        )
                        let dummyResp = OIDAuthorizationResponse(request: dummyReq, parameters: [:])
                        let newAuthState = OIDAuthState(authorizationResponse: dummyResp, tokenResponse: tokenResponse)
                        self.authState = newAuthState
                    }
                    self.saveAuthState()
                    completion(true, nil)
                } else {
                    completion(false, tokenError)
                }
            }
        }
    }

    /// Faz a requisição HTTP bruta (raw) direto para o endpoint de token do Keycloak
    /// contornando o AppAuth para evitar conflitos de estado de refresh token rotation.
    @objc func refreshAccessTokenRaw(completion: @escaping (String?, Error?) -> Void) {
        let tokenToUse = getRefreshToken() ?? BiometricAuthManager.shared.getStoredRefreshToken()
        guard let refreshToken = tokenToUse, !refreshToken.isEmpty else {
            completion(nil, NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Nenhum refresh token disponível"]))
            return
        }

        guard let url = URL(string: "\(AuthManager.issuerURI)/protocol/openid-connect/token") else {
            completion(nil, NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "URL inválida"]))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "client_id": AuthManager.clientID,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ]
        
        let bodyString = bodyParams.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(nil, error)
                return
            }

            guard let data = data else {
                completion(nil, NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Sem dados na resposta"]))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    if let newAccessToken = json["access_token"] as? String {
                        if let newRefreshToken = json["refresh_token"] as? String {
                            BiometricAuthManager.shared.saveRefreshToken(newRefreshToken)
                        }
                        completion(newAccessToken, nil)
                    } else if let errorDesc = json["error_description"] as? String {
                        completion(nil, NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: errorDesc]))
                    } else {
                        completion(nil, NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Resposta inválida do Keycloak"]))
                    }
                } else {
                    completion(nil, NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Falha no parse do JSON"]))
                }
            } catch {
                completion(nil, error)
            }
        }.resume()
    }

    /// Remove todos os tokens e estado salvo
    @objc func logout() {
        authState = nil
        UserDefaults.standard.removeObject(forKey: AuthManager.authStateKey)
        BiometricAuthManager.shared.clearBiometricData()
    }

    // MARK: - Persistência interna

    private func saveAuthState() {
        guard let state = authState else {
            UserDefaults.standard.removeObject(forKey: AuthManager.authStateKey)
            return
        }
        let data = try? NSKeyedArchiver.archivedData(withRootObject: state, requiringSecureCoding: false)
        UserDefaults.standard.set(data, forKey: AuthManager.authStateKey)

        if let refreshToken = state.lastTokenResponse?.refreshToken, !refreshToken.isEmpty {
            BiometricAuthManager.shared.saveRefreshToken(refreshToken)
        }
    }

    private func loadAuthState() {
        guard let data = UserDefaults.standard.data(forKey: AuthManager.authStateKey) else { return }
        
        let classes: [AnyClass] = [
            OIDAuthState.self,
            OIDAuthorizationResponse.self,
            OIDTokenResponse.self,
            OIDServiceConfiguration.self,
            OIDAuthorizationRequest.self,
            OIDTokenRequest.self,
            NSDictionary.self,
            NSArray.self,
            NSString.self,
            NSNumber.self,
            NSDate.self,
            NSURL.self
        ]
        
        if let state = (try? NSKeyedUnarchiver.unarchivedObject(ofClasses: classes, from: data)) as? OIDAuthState {
            authState = state
        } else if let state = (try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data)) as? OIDAuthState {
            authState = state
        }
    }

    // MARK: - Helpers

    private func base64Padded(_ string: String) -> String {
        var s = string.replacingOccurrences(of: "-", with: "+")
                      .replacingOccurrences(of: "_", with: "/")
        let remainder = s.count % 4
        if remainder > 0 { s += String(repeating: "=", count: 4 - remainder) }
        return s
    }
}
