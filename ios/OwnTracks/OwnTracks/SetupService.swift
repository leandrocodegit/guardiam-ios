//
//  SetupService.swift
//  OwnTracks
//
//  Equivalente ao SetupService.kt do Android.
//  Chama o endpoint /bipe/devices/setup com o Bearer token do Keycloak e o tokenFCM,
//  e persiste as configurações no CoreData via Settings.
//

import Foundation
import FirebaseMessaging
import CoreData
#if canImport(ActivityKit)
import ActivityKit
#endif

// MARK: - DTO de resposta

struct DeviceSetupResponseDto: Codable {
    let clientId: String
    let username: String
    let password: String
    let deviceId: String
    let tid: String?
    let icon: String?
    let color: String?
}

// MARK: - Erros

enum SetupError: LocalizedError {
    case notAuthorized
    case noToken
    case networkError(Error)
    case invalidResponse(Int)
    case emptyBody
    case decodingError(Error)
    case coreDataUnavailable

    var errorDescription: String? {
        switch self {
        case .notAuthorized:              return "Usuário não autorizado. Faça login novamente."
        case .noToken:                    return "Token de acesso indisponível."
        case .networkError(let e):        return "Sem conexão com a internet ou falha de rede: \(e.localizedDescription)"
        case .invalidResponse(let code):  return "Servidor retornou erro (HTTP \(code)). A conexão com a internet está ativa."
        case .emptyBody:                  return "Resposta vazia recebida do servidor."
        case .decodingError(let e):       return "Erro ao interpretar resposta do servidor: \(e.localizedDescription)"
        case .coreDataUnavailable:        return "Armazenamento local (CoreData) indisponível."
        }
    }
}

// MARK: - SetupService

@objc class SetupService: NSObject {

    // MARK: - Constantes
    private static let setupURL = "https://dev.simodapp.com:2087/bipe/devices/setup"

    /// Host MQTT a persistir (hardcoded, igual ao Android)
    private static let mqttHost = "broker.simodapp.com"
    private static let mqttPort = 8884

    // MARK: - Singleton
    @objc static let shared = SetupService()

    private override init() { super.init() }

    // MARK: - Verificação de setup

    @objc static let setupCompletedKey = "setupCompleted"

    @objc var isSetupCompleted: Bool {
        let moc = CoreData.sharedInstance().mainMOC
        var hasValidDeviceId = false
        
        moc.performAndWait {
            if let deviceId = Settings.string(forKey: "deviceid_preference", inMOC: moc),
               !deviceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               deviceId != "device" {
                hasValidDeviceId = true
            }
        }

        if hasValidDeviceId {
            markSetupCompleted()
            return true
        } else {
            // Se perdeu o deviceId por algum motivo, garante que a flag volte para false
            UserDefaults.standard.removeObject(forKey: SetupService.setupCompletedKey)
            return false
        }
    }

    @objc func markSetupCompleted() {
        UserDefaults.standard.set(true, forKey: SetupService.setupCompletedKey)
    }

    @objc func resetSetup() {
        UserDefaults.standard.removeObject(forKey: SetupService.setupCompletedKey)
        AuthManager.shared.logout()
    }

    // MARK: - Obtém a versão do app

    private func getAppVersion() -> Double? {
        if let versionString = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            let components = versionString.split(separator: ".")
            if components.count >= 2, let doubleVal = Double("\(components[0]).\(components[1])") {
                return doubleVal
            } else if let doubleVal = Double(versionString) {
                return doubleVal
            }
        }
        return nil
    }

    // MARK: - Obtém token FCM do Firebase

    private func fetchFCMToken(retries: Int = 3, completion: @escaping (String?) -> Void) {
        Messaging.messaging().token { token, error in
            if let error = error {
                NSLog("[SetupService] Erro ao obter token FCM (tentativas restantes: %d): %@", retries, error.localizedDescription)
                if retries > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.fetchFCMToken(retries: retries - 1, completion: completion)
                    }
                } else {
                    #if targetEnvironment(simulator)
                    NSLog("[SetupService] Fallback no simulador. Retornando token FCM mockado após falha.")
                    completion("mock-token-simulator-12345")
                    #else
                    // Retornar nil evita salvar string vazia no banco do Spring Boot
                    completion(nil)
                    #endif
                }
            } else if let token = token, !token.isEmpty {
                NSLog("[SetupService] Token FCM obtido: %@", token)
                completion(token)
            } else {
                completion(nil)
            }
        }
    }

    // MARK: - Obtém pushToStartToken de Live Activity

    private func fetchPushToStartToken(completion: @escaping (String?) -> Void) {
        #if canImport(ActivityKit)
        if #available(iOS 17.2, *) {
            if let tokenData = Activity<BipeAlertActivityAttributes>.pushToStartToken {
                let hexToken = tokenData.map { String(format: "%02x", $0) }.joined()
                NSLog("[SetupService] pushToStartToken obtido: %@", hexToken)
                completion(hexToken)
                return
            }

            var completed = false
            let timer = DispatchSource.makeTimerSource(queue: .main)
            timer.schedule(deadline: .now() + 1.5)
            timer.setEventHandler {
                if !completed {
                    completed = true
                    NSLog("[SetupService] Timeout ao aguardar pushToStartToken.")
                    completion(nil)
                }
            }
            timer.resume()

            Task {
                for await tokenData in Activity<BipeAlertActivityAttributes>.pushToStartTokenUpdates {
                    let hexToken = tokenData.map { String(format: "%02x", $0) }.joined()
                    DispatchQueue.main.async {
                        if !completed {
                            completed = true
                            timer.cancel()
                            NSLog("[SetupService] pushToStartToken (async) obtido: %@", hexToken)
                            completion(hexToken)
                        }
                    }
                    break
                }
            }
        } else {
            completion(nil)
        }
        #else
        completion(nil)
        #endif
    }

    /// Inicia o listener continuo de Push-To-Start Token que sincroniza automaticamente com o servidor backend
    @objc func startPushToStartTokenSyncListener() {
        #if canImport(ActivityKit)
        if #available(iOS 17.2, *) {
            Task {
                for await tokenData in Activity<BipeAlertActivityAttributes>.pushToStartTokenUpdates {
                    let hexToken = tokenData.map { String(format: "%02x", $0) }.joined()
                    NSLog("[SetupService] pushToStartToken (listener ativo) obtido: %@", hexToken)
                    SetupService.shared.syncPushToStartTokenWithServer(hexToken)
                }
            }
        }
        #endif
    }

    /// Força a sincronização imediata dos tokens (Push-To-Start + FCM) com o backend no momento da inicialização do app
    @objc func triggerTokenSyncImmediately() {
        fetchPushToStartToken { ptsToken in
            if let ptsToken = ptsToken, !ptsToken.isEmpty {
                NSLog("[SetupService] triggerTokenSyncImmediately sincronizando pushToStartToken: %@", ptsToken)
                SetupService.shared.syncPushToStartTokenWithServer(ptsToken)
            } else {
                NSLog("[SetupService] triggerTokenSyncImmediately: PushToStartToken ainda nao disponivel no momento.")
            }
        }
    }

    /// Sincroniza o Push-To-Start Token e o FCM Token diretamente com o dispositivo via endpoint PATCH /bipe/devices/{id}/tokens
    @objc func syncPushToStartTokenWithServer(_ pushToStartToken: String) {
        guard !pushToStartToken.contains("mock"), !pushToStartToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            NSLog("[SetupService] syncPushToStartTokenWithServer: Token mockado ou vazio ignorado.")
            return
        }
        
        let moc = CoreData.sharedInstance().mainMOC
        var deviceId: String? = nil
        moc.performAndWait {
            deviceId = Settings.string(forKey: "deviceid_preference", inMOC: moc)
        }
        
        guard let devId = deviceId, !devId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            // Fallback: se ainda não houver deviceId configurado localmente, roda o setup completo
            AuthManager.shared.getBearerToken { [weak self] bearerToken in
                guard let self = self, let bearerToken = bearerToken else { return }
                let appVersion = self.getAppVersion()
                self.fetchFCMToken { fcmToken in
                    self.callSetupAPI(
                        bearerToken: bearerToken,
                        fcmToken: fcmToken,
                        pushToStartToken: pushToStartToken,
                        version: appVersion
                    ) { _ in }
                }
            }
            return
        }
        
        self.fetchFCMToken { fcmToken in
            AuthManager.shared.getBearerToken { bearerToken in
                guard let bearerToken = bearerToken else { return }
                let urlString = "https://dev.simodapp.com:2087/bipe/devices/\(devId)/tokens"
                guard let url = URL(string: urlString) else { return }
                
                var request = URLRequest(url: url)
                request.httpMethod = "PATCH"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue(bearerToken, forHTTPHeaderField: "Authorization")
                
                var bodyDict: [String: String] = ["pushToStartToken": pushToStartToken]
                if let fcm = fcmToken, !fcm.isEmpty {
                    bodyDict["fcmToken"] = fcm
                }
                request.httpBody = try? JSONSerialization.data(withJSONObject: bodyDict, options: [])
                
                URLSession.shared.dataTask(with: request) { _, response, error in
                    if let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) {
                        NSLog("[SetupService] Tokens (PushToStart + FCM) atualizados com sucesso no endpoint especifico /bipe/devices/%@/tokens", devId)
                    } else {
                        NSLog("[SetupService] Falha ao atualizar tokens via endpoint especifico. Status: %ld", (response as? HTTPURLResponse)?.statusCode ?? 0)
                    }
                }.resume()
            }
        }
    }

    // MARK: - Fluxo principal

    /// Executa o setup do device: obtém Bearer token + tokenFCM + pushToStartToken + version, chama API, persiste configurações.
    /// - Parameters:
    ///   - context: NSManagedObjectContext para persistir via Settings
    ///   - completion: chamado na main thread com `true` em caso de sucesso ou `error` em caso de falha
    func performDeviceSetup(
        context: NSManagedObjectContext,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        if isSetupCompleted {
            NSLog("[SetupService] Setup já realizado e deviceId configurado. Ignorando chamada repetida ao endpoint /bipe/devices/setup.")
            DispatchQueue.main.async { completion(true, nil) }
            return
        }
        AuthManager.shared.getBearerToken { [weak self] bearerToken in
            guard let self = self else { return }
            guard let bearerToken = bearerToken else {
                DispatchQueue.main.async { completion(false, SetupError.noToken) }
                return
            }

            let appVersion = self.getAppVersion()

            // Busca o token FCM e o pushToStartToken antes de chamar a API
            self.fetchFCMToken { fcmToken in
                self.fetchPushToStartToken { pushToStartToken in
                    self.callSetupAPI(
                        bearerToken: bearerToken,
                        fcmToken: fcmToken,
                        pushToStartToken: pushToStartToken,
                        version: appVersion
                    ) { result in
                        switch result {
                        case .success(let dto):
                            self.persistSetup(dto: dto, context: context)
                            DispatchQueue.main.async { completion(true, nil) }
                        case .failure(let error):
                            DispatchQueue.main.async { completion(false, error) }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Chamada de rede

    private func callSetupAPI(
        bearerToken: String,
        fcmToken: String?,
        pushToStartToken: String?,
        version: Double?,
        completion: @escaping (Result<DeviceSetupResponseDto, SetupError>) -> Void
    ) {
        guard let url = URL(string: SetupService.setupURL) else {
            completion(.failure(.networkError(NSError(domain: "SetupService", code: -1))))
            return
        }

        // Monta payload
        var payloadDict: [String: Any] = ["os": "ios"]
        if let token = fcmToken {
            payloadDict["tokenFCM"] = token
        }
        if let ptsToken = pushToStartToken {
            payloadDict["pushToStartToken"] = ptsToken
        }
        if let ver = version {
            payloadDict["version"] = ver
        }
        let payloadData = (try? JSONSerialization.data(withJSONObject: payloadDict, options: [])) ?? Data()
        let payloadString = String(data: payloadData, encoding: .utf8) ?? "{\"os\":\"ios\"}"

        NSLog("[SetupService] callSetupAPI payload: %@", payloadString)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(bearerToken, forHTTPHeaderField: "Authorization")
        request.httpBody = payloadData

        let session = URLSession(configuration: .default)

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse(0)))
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(.invalidResponse(httpResponse.statusCode)))
                return
            }

            guard let data = data, !data.isEmpty else {
                completion(.failure(.emptyBody))
                return
            }

            do {
                let dto = try JSONDecoder().decode(DeviceSetupResponseDto.self, from: data)
                completion(.success(dto))
            } catch {
                completion(.failure(.decodingError(error)))
            }
        }.resume()
    }

    // MARK: - Persistência

    private func persistSetup(dto: DeviceSetupResponseDto, context: NSManagedObjectContext) {
        context.performAndWait {
            // Credenciais MQTT
            Settings.setString(dto.username as NSString, forKey: "user_preference", inMOC: context)
            Settings.setString(dto.password as NSString, forKey: "pass_preference", inMOC: context)
            Settings.setString(dto.clientId as NSString, forKey: "clientid_preference", inMOC: context)
            Settings.setString(dto.deviceId as NSString, forKey: "deviceid_preference", inMOC: context)
 
            if let tid = dto.tid {
                Settings.setString(tid as NSString, forKey: "trackerid_preference", inMOC: context)
            }

            if let icon = dto.icon {
                Settings.setString(icon as NSString, forKey: "icon", inMOC: context)
                Settings.setString(icon as NSString, forKey: "face_preference", inMOC: context)
            }

            if let color = dto.color {
                Settings.setString(color as NSString, forKey: "color", inMOC: context)
            }

            // Broker MQTT
            Settings.setString(SetupService.mqttHost as NSString, forKey: "host_preference", inMOC: context)
            Settings.setInt(Int32(SetupService.mqttPort), forKey: "port_preference", inMOC: context)

            // Tempo de envio padrão (30 segundos)
            Settings.setString("30" as NSString, forKey: "mintime_preference", inMOC: context)
            LocationManager.sharedInstance().minTime = 30.0

            // Flags TLS e autenticação
            Settings.setBool(true, forKey: "tls_preference", inMOC: context)
            Settings.setBool(true, forKey: "auth_preference", inMOC: context)
            Settings.setBool(true, forKey: "usepassword_preference", inMOC: context)

            // Modo MQTT (CONNECTION_MODE_MQTT = 0)
            Settings.setMode(ConnectionMode.CONNECTION_MODE_MQTT, inMOC: context)

            // Salva no CoreData
            if context.hasChanges {
                try? context.save()
            }
        }

        // Marca o setup como concluído no UserDefaults
        markSetupCompleted()
    }
}