//
//  SetupService.swift
//  OwnTracks / Guardiam
//
//  Serviço de Setup do dispositivo para a nova arquitetura do Guardiam.
//  Chama o endpoint POST /api/setup enviando telefone, senha e contraSenha,
//  e persiste as configurações (clientId, username, password, icon) no CoreData via Settings.
//  Utiliza clientId exclusivamente para registro MQTT (sem deviceId).
//

import Foundation
import FirebaseMessaging
import CoreData
#if canImport(ActivityKit)
import ActivityKit
#endif

// MARK: - DTO de resposta do Setup

struct SetupResponseDTO: Codable {
    let clientId: String
    let icon: String?
    let username: String
    let password: String
}

// MARK: - Erros de Setup

enum SetupError: LocalizedError {
    case notAuthorized
    case networkError(Error)
    case invalidResponse(Int, String?)
    case emptyBody
    case decodingError(Error)
    case coreDataUnavailable
    case validationError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:              return "Acesso não autorizado. Verifique os dados inseridos."
        case .networkError(let e):        return "Falha de conexão com a rede: \(e.localizedDescription)"
        case .invalidResponse(let code, let msg): return msg ?? "Servidor retornou erro (HTTP \(code))."
        case .emptyBody:                  return "Resposta vazia recebida do servidor."
        case .decodingError(let e):       return "Erro ao processar a resposta do servidor: \(e.localizedDescription)"
        case .coreDataUnavailable:        return "Armazenamento local (CoreData) indisponível."
        case .validationError(let msg):   return msg
        }
    }
}

// MARK: - SetupService

@objc class SetupService: NSObject {

    // MARK: - Constantes
    private static let setupURLPrimary = "https://dev.simodapp.com/api/setup"
    private static let setupURLFallback = "https://dev.simodapp.com:2087/api/setup"

    /// Host e Porta MQTT
    private static let mqttHost = "broker.simodapp.com"
    private static let mqttPort = 8884

    // MARK: - Singleton
    @objc static let shared = SetupService()

    private override init() { super.init() }

    // MARK: - Verificação de setup

    @objc static let setupCompletedKey = "setupCompleted"

    @objc var isSetupCompleted: Bool {
        let moc = CoreData.sharedInstance().mainMOC
        var hasValidClientId = false
        
        moc.performAndWait {
            if let clientId = Settings.string(forKey: "clientid_preference", inMOC: moc),
               !clientId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               clientId != "client" {
                hasValidClientId = true
            }
        }

        if hasValidClientId {
            markSetupCompleted()
            return true
        } else {
            UserDefaults.standard.removeObject(forKey: SetupService.setupCompletedKey)
            return false
        }
    }

    @objc func markSetupCompleted() {
        UserDefaults.standard.set(true, forKey: SetupService.setupCompletedKey)
    }

    @objc func resetSetup() {
        UserDefaults.standard.removeObject(forKey: SetupService.setupCompletedKey)
    }

    // MARK: - Push Tokens Sync

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

    @objc func triggerTokenSyncImmediately() {
        fetchPushToStartToken { ptsToken in
            if let ptsToken = ptsToken, !ptsToken.isEmpty {
                NSLog("[SetupService] triggerTokenSyncImmediately sincronizando pushToStartToken: %@", ptsToken)
                SetupService.shared.syncPushToStartTokenWithServer(ptsToken)
            }
        }
    }

    @objc func syncPushToStartTokenWithServer(_ pushToStartToken: String) {
        guard !pushToStartToken.contains("mock"), !pushToStartToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let moc = CoreData.sharedInstance().mainMOC
        var clientId: String? = nil
        moc.performAndWait {
            clientId = Settings.string(forKey: "clientid_preference", inMOC: moc)
        }
        
        guard let cId = clientId, !cId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        self.fetchFCMToken { fcmToken in
            let urlString = "https://dev.simodapp.com/api/devices/\(cId)/tokens"
            guard let url = URL(string: urlString) else { return }
            
            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            var bodyDict: [String: String] = ["pushToStartToken": pushToStartToken]
            if let fcm = fcmToken, !fcm.isEmpty {
                bodyDict["fcmToken"] = fcm
            }
            request.httpBody = try? JSONSerialization.data(withJSONObject: bodyDict, options: [])
            
            URLSession.shared.dataTask(with: request) { _, response, error in
                if let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) {
                    NSLog("[SetupService] Tokens sincronizados com sucesso para clientId: %@", cId)
                }
            }.resume()
        }
    }

    private func fetchFCMToken(completion: @escaping (String?) -> Void) {
        Messaging.messaging().token { token, error in
            if let token = token, !token.isEmpty {
                completion(token)
            } else {
                completion(nil)
            }
        }
    }

    private func fetchPushToStartToken(completion: @escaping (String?) -> Void) {
        #if canImport(ActivityKit)
        if #available(iOS 17.2, *) {
            if let tokenData = Activity<BipeAlertActivityAttributes>.pushToStartToken {
                let hexToken = tokenData.map { String(format: "%02x", $0) }.joined()
                completion(hexToken)
                return
            }
        }
        #endif
        completion(nil)
    }

    // MARK: - Execução do Setup

    /// Executa o setup do dispositivo enviando telefone, senha e contraSenha para a API do Guardiam
    @objc func performDeviceSetup(
        telefone: String,
        senha: String,
        contraSenha: String,
        context: NSManagedObjectContext,
        completion: @escaping (Bool, String?) -> Void
    ) {
        let cleanPhone = telefone.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSenha = senha.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanContra = contraSenha.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanPhone.isEmpty else {
            completion(false, "O telefone é obrigatório.")
            return
        }
        guard !cleanSenha.isEmpty else {
            completion(false, "A senha (pergunta de código) é obrigatória.")
            return
        }
        guard !cleanContra.isEmpty else {
            completion(false, "A contra-senha (resposta de emergência) é obrigatória.")
            return
        }

        callSetupAPI(telefone: cleanPhone, senha: cleanSenha, contraSenha: cleanContra) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let dto):
                self.persistSetup(dto: dto, context: context)
                DispatchQueue.main.async {
                    completion(true, nil)
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(false, error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Chamada de Rede HTTP POST /setup

    private func callSetupAPI(
        telefone: String,
        senha: String,
        contraSenha: String,
        completion: @escaping (Result<SetupResponseDTO, SetupError>) -> Void
    ) {
        let payloadDict: [String: Any] = [
            "telefone": telefone,
            "senha": senha,
            "contraSenha": contraSenha
        ]

        guard let payloadData = try? JSONSerialization.data(withJSONObject: payloadDict, options: []) else {
            completion(.failure(.validationError("Falha ao gerar o payload do setup.")))
            return
        }

        guard let primaryURL = URL(string: SetupService.setupURLPrimary) else {
            completion(.failure(.networkError(NSError(domain: "SetupService", code: -1))))
            return
        }

        var request = URLRequest(url: primaryURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = payloadData
        request.timeoutInterval = 15.0

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                // Tenta a URL fallback caso ocorra erro na primaria
                self.callFallbackSetupAPI(payloadData: payloadData, completion: completion, originalError: error)
                return
            }

            self.parseSetupResponse(data: data, response: response, completion: completion)
        }.resume()
    }

    private func callFallbackSetupAPI(
        payloadData: Data,
        completion: @escaping (Result<SetupResponseDTO, SetupError>) -> Void,
        originalError: Error
    ) {
        guard let fallbackURL = URL(string: SetupService.setupURLFallback) else {
            completion(.failure(.networkError(originalError)))
            return
        }

        var request = URLRequest(url: fallbackURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = payloadData
        request.timeoutInterval = 15.0

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }
            self.parseSetupResponse(data: data, response: response, completion: completion)
        }.resume()
    }

    private func parseSetupResponse(
        data: Data?,
        response: URLResponse?,
        completion: @escaping (Result<SetupResponseDTO, SetupError>) -> Void
    ) {
        guard let httpResponse = response as? HTTPURLResponse else {
            completion(.failure(.invalidResponse(0, nil)))
            return
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            var serverMessage: String? = nil
            if let data = data, let jsonMsg = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                serverMessage = jsonMsg["message"] as? String ?? jsonMsg["error"] as? String
            }
            completion(.failure(.invalidResponse(httpResponse.statusCode, serverMessage)))
            return
        }

        guard let data = data, !data.isEmpty else {
            completion(.failure(.emptyBody))
            return
        }

        do {
            let dto = try JSONDecoder().decode(SetupResponseDTO.self, from: data)
            completion(.success(dto))
        } catch {
            completion(.failure(.decodingError(error)))
        }
    }

    // MARK: - Persistência das Configurações do Setup

    private func persistSetup(dto: SetupResponseDTO, context: NSManagedObjectContext) {
        context.performAndWait {
            // Credenciais do Usuário e do Broker MQTT
            Settings.setString(dto.username as NSString, forKey: "user_preference", inMOC: context)
            Settings.setString(dto.password as NSString, forKey: "pass_preference", inMOC: context)
            Settings.setString(dto.clientId as NSString, forKey: "clientid_preference", inMOC: context)
            Settings.setString(dto.clientId as NSString, forKey: "deviceid_preference", inMOC: context)

            if let icon = dto.icon, !icon.isEmpty {
                Settings.setString(icon as NSString, forKey: "icon", inMOC: context)
                Settings.setString(icon as NSString, forKey: "face_preference", inMOC: context)
            }

            // Configuração do Tópico Base do MQTT usando o clientId exclusivamente
            let bipeTopic = "owntracks/\(dto.clientId)"
            Settings.setString(bipeTopic as NSString, forKey: "topic_preference", inMOC: context)

            // Broker MQTT
            Settings.setString(SetupService.mqttHost as NSString, forKey: "host_preference", inMOC: context)
            Settings.setInt(Int32(SetupService.mqttPort), forKey: "port_preference", inMOC: context)

            // Tempo de envio padrão (30 segundos)
            Settings.setString("30" as NSString, forKey: "mintime_preference", inMOC: context)
            LocationManager.sharedInstance().minTime = 30.0

            // Flags TLS e Autenticação
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