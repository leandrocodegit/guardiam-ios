//
//  BipeLiveActivityManager.swift
//  OwnTracks
//
//  Gerenciador Singleton de Live Activity.
//  Garante que exista sempre no máximo UMA Live Activity ativa simultaneamente,
//  reaproveitando e atualizando a mesma atividade para qualquer notificação/evento.
//

import Foundation
import UIKit
import AVFoundation
import UserNotifications
#if canImport(ActivityKit)
import ActivityKit
#endif
import FirebaseMessaging

// MARK: - BipeAudioHelper (Gerenciamento e Reprodução de Áudio de Notificação)

@objc class BipeAudioHelper: NSObject {
    
    private static var audioPlayer: AVAudioPlayer?

    /// Sanitiza e resolve o som recebido no payload buscando EXCLUSIVAMENTE na pasta/subdiretório 'audios/'
    /// (ex: "audios/bipe_exit.mp3" ou "bipe_exit" -> "audios/bipe_exit.mp3")
    @objc(resolveSoundNameFrom:)
    static func resolveSoundName(from rawSound: String?) -> String? {
        guard let raw = rawSound?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        
        let filename = (raw as NSString).lastPathComponent
        let baseName = (filename as NSString).deletingPathExtension
        let rawExt = (filename as NSString).pathExtension
        
        let possibleExtensions = [rawExt, "mp3", "wav", "caf", "aiff"].filter { !$0.isEmpty }
        
        for ext in possibleExtensions {
            if Bundle.main.url(forResource: baseName, withExtension: ext, subdirectory: "audios") != nil {
                return "audios/\(baseName).\(ext)"
            }
        }
        
        if Bundle.main.url(forResource: "audios/\(filename)", withExtension: nil) != nil {
            return "audios/\(filename)"
        }
        
        return "audios/\(baseName).mp3"
    }

    /// Toca o som de notificação localmente da pasta 'audios/' via AVAudioPlayer
    @objc(playSoundNamed:)
    static func playSound(named rawSound: String?) {
        guard let relativePath = resolveSoundName(from: rawSound) else {
            NSLog("[BipeAudioHelper] Impossível resolver áudio para o parâmetro: %@", rawSound ?? "nil")
            return
        }
        
        let filename = (relativePath as NSString).lastPathComponent
        let baseName = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        
        guard let soundURL = Bundle.main.url(forResource: baseName, withExtension: ext, subdirectory: "audios")
                ?? Bundle.main.url(forResource: relativePath, withExtension: nil) else {
            NSLog("[BipeAudioHelper] Arquivo de áudio '%@' não encontrado na pasta 'audios/'", relativePath)
            return
        }
        
        DispatchQueue.main.async {
            do {
                if SentinelAcousticMonitor.shared.isMonitoring {
                    try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .defaultToSpeaker, .allowBluetooth])
                } else {
                    try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
                }
                try AVAudioSession.sharedInstance().setActive(true)
                
                audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
                audioPlayer?.prepareToPlay()
                audioPlayer?.play()
                NSLog("[BipeAudioHelper] Áudio '%@' da pasta 'audios/' reproduzido com sucesso!", relativePath)
            } catch {
                NSLog("[BipeAudioHelper] Erro ao reproduzir áudio '%@': %@", relativePath, error.localizedDescription)
            }
        }
    }
}

@objc class BipeLiveActivityManager: NSObject {
    
    private static let tokenEndpoint = "https://dev.simodapp.com:2087/bipe/live-activity/token"
    private static let activityEndpointPrefix = "https://dev.simodapp.com:2087/bipe/live-activity/activity/"
    private static let appGroupSuite = "group.br.guardiam.com"
    private static var lastSentTokens: [String: String] = [:]

    // MARK: - Register Push-to-Start & Token Listeners

    @objc static func registerPushToStartListener() {
        return
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            Task {
                for await activity in Activity<BipeAlertActivityAttributes>.activityUpdates {
                    NSLog("[BipeLiveActivityManager] Nova atividade detectada via activityUpdates (ID: %@)", activity.id)
                    await sanitizeDuplicateActivities(keeping: activity)
                    observeActivityToken(activity)
                }
            }
            Task { @MainActor in
                let active = Activity<BipeAlertActivityAttributes>.activities.filter { $0.activityState == .active || $0.activityState == .stale }
                if let first = active.first {
                    await sanitizeDuplicateActivities(keeping: first)
                }
                for activity in Activity<BipeAlertActivityAttributes>.activities {
                    observeActivityToken(activity)
                }
            }
        }
        if #available(iOS 17.2, *) {
            Task {
                for await tokenData in Activity<BipeAlertActivityAttributes>.pushToStartTokenUpdates {
                    let tokenHex = tokenData.map { String(format: "%02x", $0) }.joined()
                    NSLog("[BipeLiveActivityManager] Push-to-Start Token registrado/atualizado: %@", tokenHex)
                    SetupService.shared.syncPushToStartTokenWithServer(tokenHex)
                }
            }
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("FCMToken"), object: nil, queue: .main) { _ in
            NSLog("[BipeLiveActivityManager] Notificação FCMToken recebida. Re-sincronizando tokens das Live Activities...")
            if #available(iOS 16.1, *) {
                for activity in Activity<BipeAlertActivityAttributes>.activities {
                    if activity.activityState == .active || activity.activityState == .stale {
                        observeActivityToken(activity)
                    }
                }
            }
        }
        #endif
    }

    @available(iOS 16.1, *)
    private static func observeActivityToken(_ activity: Activity<BipeAlertActivityAttributes>) {
        #if canImport(ActivityKit)
        Task {
            if let pushTokenData = activity.pushToken {
                let pushTokenHex = pushTokenData.map { String(format: "%02x", $0) }.joined()
                NSLog("[BipeLiveActivityManager] Push Token inicial para Live Activity %@: %@", activity.id, pushTokenHex)
                sendLiveActivityTokenToServer(token: pushTokenHex, activityId: activity.id)
            }
            for await pushTokenData in activity.pushTokenUpdates {
                let pushTokenHex = pushTokenData.map { String(format: "%02x", $0) }.joined()
                NSLog("[BipeLiveActivityManager] Push Token recebido para Live Activity %@: %@", activity.id, pushTokenHex)
                sendLiveActivityTokenToServer(token: pushTokenHex, activityId: activity.id)
            }
        }
        Task {
            for await state in activity.activityStateUpdates {
                if state == .ended || state == .dismissed {
                    NSLog("[BipeLiveActivityManager] Live Activity %@ finalizada. Removendo token do servidor.", activity.id)
                    removeLiveActivityTokenFromServer(activityId: activity.id)
                }
            }
        }
        #endif
    }

    // MARK: - Sanitization (Garantia de Live Activity Única)

    @available(iOS 16.1, *)
    private static func sanitizeDuplicateActivities(keeping primaryActivity: Activity<BipeAlertActivityAttributes>? = nil) async {
        #if canImport(ActivityKit)
        let allActivities = Activity<BipeAlertActivityAttributes>.activities
        let visibleActivities = allActivities.filter { $0.activityState == .active || $0.activityState == .stale }
        
        guard visibleActivities.count > 1 else { return }
        
        let targetToKeep = primaryActivity ?? visibleActivities.first
        NSLog("[BipeLiveActivityManager] Encontradas %d Live Activities visíveis. Mantendo ID %@ e encerrando duplicadas...", visibleActivities.count, targetToKeep?.id ?? "")
        
        for activity in visibleActivities {
            if let keep = targetToKeep, activity.id == keep.id {
                continue
            }
            NSLog("[BipeLiveActivityManager] Encerrando Live Activity duplicada ID: %@", activity.id)
            let activityId = activity.id
            await activity.end(nil, dismissalPolicy: .immediate)
            removeLiveActivityTokenFromServer(activityId: activityId)
        }
        #endif
    }

    // MARK: - Region Helper
    
    @objc static func getCurrentRegionName() -> String {
        let insideRegions = LocationManager.sharedInstance().insideCircularRegions
        for (identifier, isInside) in insideRegions {
            if let num = isInside as? NSNumber, num.boolValue {
                let components = (identifier as? String)?.components(separatedBy: "|")
                if let regionName = components?.first, !regionName.isEmpty {
                    return regionName
                }
            }
        }
        return ""
    }

    @objc static func getCurrentRegionInsecure() -> Bool {
        guard let appDelegate = UIApplication.shared.delegate as? OwnTracksAppDelegate else {
            return false
        }
        
        let insideRegions = LocationManager.sharedInstance().insideCircularRegions
        for (identifier, isInside) in insideRegions {
            if let num = isInside as? NSNumber, num.boolValue, let strId = identifier as? String {
                if appDelegate.isRegionInsecure(strId) {
                    return true
                }
            }
        }
        return false
    }


    // MARK: - Lifecycle Management

    @objc static func startLiveActivityOnAppLaunch() {
        return
        if #available(iOS 16.1, *) {
            #if canImport(ActivityKit)
            Task { @MainActor in
                // 1. Limpa atividades finalizadas/descartadas da memória do ActivityKit
                for activity in Activity<BipeAlertActivityAttributes>.activities {
                    if activity.activityState == .ended || activity.activityState == .dismissed {
                        await activity.end(nil, dismissalPolicy: .immediate)
                        removeLiveActivityTokenFromServer(activityId: activity.id)
                    }
                }
                
                // 2. Garante que exista no máximo 1 ativa/visível
                let visibleActivities = Activity<BipeAlertActivityAttributes>.activities.filter { $0.activityState == .active || $0.activityState == .stale }
                if visibleActivities.count > 1 {
                    await sanitizeDuplicateActivities(keeping: visibleActivities.first)
                }
                
                // 3. Se nenhuma estiver visível, cria a Live Activity padrão inicial
                let remainingVisible = Activity<BipeAlertActivityAttributes>.activities.filter { $0.activityState == .active || $0.activityState == .stale }
                if remainingVisible.isEmpty {
                    NSLog("[BipeLiveActivityManager] Nenhuma Live Activity ativa. Criando Live Activity única inicial...")
                    let moc = CoreData.sharedInstance().mainMOC
                    var nickname: String = "Bipe.me"
                    moc.performAndWait {
                        if let name = Settings.string(forKey: "device_name_preference", inMOC: moc), !name.isEmpty {
                            nickname = name
                        } else if let name = Settings.string(forKey: "nickname_preference", inMOC: moc), !name.isEmpty {
                            nickname = name
                        }
                    }
                    startLiveActivity(
                        nickname: nickname,
                        address: String(localized: "Monitorando em tempo real"),
                        iconLocalPath: nil,
                        iconUrl: "logo",
                        status: "transition",
                        way: BipeLiveActivityManager.getCurrentRegionName(),
                        devices: nil,
                        event: "active",
                        activityType: "transition",
                        insecure: BipeLiveActivityManager.getCurrentRegionInsecure()
                    )
                } else {
                    if let first = remainingVisible.first {
                        NSLog("[BipeLiveActivityManager] Live Activity única já visível na tela (ID: %@). Re-sincronizando tokens...", first.id)
                        observeActivityToken(first)
                    }
                }
                
                checkPendingBipeConfirmationFromAppGroup()
            }
            #endif
        }
    }

    @objc static func updateLiveActivityForRegionChange(regionName: String, enter: Bool, insecure: Bool) {
        if #available(iOS 16.1, *) {
            #if canImport(ActivityKit)
            Task { @MainActor in
                let currentVisible = Activity<BipeAlertActivityAttributes>.activities.filter { $0.activityState == .active || $0.activityState == .stale }
                if let singleActiveActivity = currentVisible.first {
                    let st = singleActiveActivity.content.state.status.lowercased()
                    let act = singleActiveActivity.content.state.activityType?.lowercased() ?? ""
                    let ev = singleActiveActivity.content.state.event?.lowercased() ?? ""
                    
                    let isBipe = act == "bipe" || act == "bipe_alert" || st == "bipe" || st == "bipe_alert" || ev == "bipe" || ev == "bipe_alert"
                    let isEmergency = isBipe || act.contains("emergency") || st.contains("emergency") || st.contains("emergencia") || st.contains("emergência")
                    let isRoutine = !isEmergency && (act.contains("routine") || act.contains("rotina") || st.contains("routine") || st.contains("rotina") || ev.contains("routine") || ev.contains("rotina"))
                    let hasValidTarget = (singleActiveActivity.content.state.target != nil && !(singleActiveActivity.content.state.target?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true))
                    let isDistance = !isEmergency && !isRoutine && (act.contains("distance") || st.contains("distance") || hasValidTarget || ev.contains("aproxim") || ev.contains("afast"))
                    
                    if isEmergency || isDistance || isRoutine {
                        NSLog("[BipeLiveActivityManager] updateLiveActivityForRegionChange ignorado, status prioritario ativo.")
                        return
                    }
                }
                
                let moc = CoreData.sharedInstance().mainMOC
                var nickname: String = "Bipe.me"
                moc.performAndWait {
                    if let name = Settings.string(forKey: "device_name_preference", inMOC: moc), !name.isEmpty {
                        nickname = name
                    } else if let name = Settings.string(forKey: "nickname_preference", inMOC: moc), !name.isEmpty {
                        nickname = name
                    }
                }
                
                startLiveActivity(
                    nickname: nickname,
                    address: String(localized: "Monitorando em tempo real"),
                    iconLocalPath: nil,
                    iconUrl: "logo",
                    status: "transition",
                    way: regionName,
                    devices: nil,
                    event: enter ? "enter" : "exit",
                    activityType: "transition",
                    insecure: insecure
                )
            }
            #endif
        }
    }

    @objc static func checkPendingBipeConfirmationFromAppGroup() {
        if let sharedDefaults = UserDefaults(suiteName: appGroupSuite),
           let pendingExecId = sharedDefaults.string(forKey: "pending_bipe_confirm_execucao_id"),
           !pendingExecId.isEmpty {
            sharedDefaults.removeObject(forKey: "pending_bipe_confirm_execucao_id")
            sharedDefaults.synchronize()
            NSLog("[BipeLiveActivityManager] Processando confirmacao de bipe pendente via AppGroup execucaoId: %@", pendingExecId)
            sendBipeConfirmation(execucaoId: pendingExecId)
        }
    }

    // MARK: - Start / Update Live Activity

    @available(iOS 16.1, *)
    private static func startLiveActivity(
        nickname: String,
        address: String,
        iconLocalPath: String?,
        iconUrl: String?,
        status: String,
        way: String? = nil,
        devices: [String]? = nil,
        event: String? = nil,
        activityType: String? = "emergency",
        target: String? = nil,
        alvo: String? = nil,
        distancia: String? = nil,
        icon: String? = nil,
        execucaoId: String? = nil,
        insecure: Bool? = nil
    ) {
        #if canImport(ActivityKit)
        DispatchQueue.main.async {
            let state = BipeAlertActivityAttributes.ContentState(
                address: address,
                way: way,
                event: event,
                devices: devices,
                activityType: activityType,
                nickname: nickname,
                status: status,
                iconUrl: iconUrl,
                iconLocalPath: iconLocalPath,
                icon: icon ?? iconUrl,
                timestamp: Date().timeIntervalSince1970,
                target: target,
                alvo: alvo,
                distancia: distancia,
                execucaoId: execucaoId,
                insecure: insecure
            )
            let content: ActivityContent<BipeAlertActivityAttributes.ContentState>
            if #available(iOS 16.2, *) {
                content = ActivityContent(state: state, staleDate: Date.distantFuture, relevanceScore: 100.0)
            } else {
                content = ActivityContent(state: state, staleDate: Date.distantFuture)
            }
            
            Task { @MainActor in
                let visibleActivities = Activity<BipeAlertActivityAttributes>.activities.filter { $0.activityState == .active || $0.activityState == .stale }
                
                // Se houver mais de uma atividade visível, encerra as duplicadas mantendo apenas a primeira
                if visibleActivities.count > 1 {
                    await sanitizeDuplicateActivities(keeping: visibleActivities.first)
                }
                
                let currentVisible = Activity<BipeAlertActivityAttributes>.activities.filter { $0.activityState == .active || $0.activityState == .stale }
                
                if let singleActiveActivity = currentVisible.first {
                    NSLog("[BipeLiveActivityManager] Reutilizando e atualizando Live Activity existente (ID: %@)", singleActiveActivity.id)
                    await singleActiveActivity.update(content)
                    observeActivityToken(singleActiveActivity)
                    NSLog("[BipeLiveActivityManager] Live Activity %@ atualizada com sucesso!", singleActiveActivity.id)
                } else {
                    NSLog("[BipeLiveActivityManager] Nenhuma Live Activity visível. Criando nova atividade única...")
                    do {
                        let attributes = BipeAlertActivityAttributes()
                        let activity = try Activity<BipeAlertActivityAttributes>.request(
                            attributes: attributes,
                            content: content,
                            pushType: .token
                        )
                        NSLog("[BipeLiveActivityManager] Nova Live Activity iniciada com sucesso. ID: %@", activity.id)
                        observeActivityToken(activity)
                    } catch {
                        NSLog("[BipeLiveActivityManager] Erro ao iniciar Live Activity: %@ (detalhes: %@)", error.localizedDescription, String(describing: error))
                    }
                }
            }
        }
        #endif
    }

    // MARK: - End Live Activities

    @objc static func endAllLiveActivities() {
        endEmergencyLiveActivity()
    }

    @objc static func endEmergencyLiveActivity() {
        if #available(iOS 16.1, *) {
            #if canImport(ActivityKit)
            Task { @MainActor in
                for activity in Activity<BipeAlertActivityAttributes>.activities {
                    let activityId = activity.id
                    await activity.end(nil, dismissalPolicy: .immediate)
                    removeLiveActivityTokenFromServer(activityId: activityId)
                }
            }
            #endif
        }
    }

    // MARK: - Process Push Notification Payload

    @objc static func testTransitionLiveActivity() {
        if #available(iOS 16.1, *) {
            startLiveActivity(
                nickname: "Bipe.me",
                address: String(localized: "Região Monitorada"),
                iconLocalPath: nil,
                iconUrl: nil,
                status: "transition",
                way: String(localized: "Casa da Vovó"),
                devices: ["iPhone do João", "Carro da Maria"],
                event: "enter",
                activityType: "transition"
            )
        }
    }

    @objc static func processBipePushNotificationPayload(_ userInfo: NSDictionary) {
        return
        NSLog("[BipeLiveActivityManager] Recebido push payload: %@", userInfo)
        
        var dataDict: [String: Any]? = userInfo["data"] as? [String: Any]
        if dataDict == nil, let dataString = userInfo["data"] as? String, let data = dataString.data(using: .utf8) {
            dataDict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        }
        
        let type = extractValue(keys: ["type", "_type", "activityType"], userInfo: userInfo, dataDict: dataDict)
        let status = extractValue(keys: ["status", "_status"], userInfo: userInfo, dataDict: dataDict)
        let eventVal = extractValue(keys: ["event", "transition", "event_type", "eventType", "action"], userInfo: userInfo, dataDict: dataDict)
        let wayVal = extractValue(keys: ["way", "region", "wayName", "locationName"], userInfo: userInfo, dataDict: dataDict)
        let targetVal = extractValue(keys: ["target", "targetDevice", "dispositivo1"], userInfo: userInfo, dataDict: dataDict)
        let alvoVal = extractValue(keys: ["alvo", "targetAlvo", "dispositivo2"], userInfo: userInfo, dataDict: dataDict)
        let distanciaVal = extractValue(keys: ["distancia", "distance"], userInfo: userInfo, dataDict: dataDict)
        let soundVal = extractValue(keys: ["sound", "soundName", "audio"], userInfo: userInfo, dataDict: dataDict)
        let execucaoIdVal = extractValue(keys: ["execucaoId", "execucao_id", "id"], userInfo: userInfo, dataDict: dataDict)
        let insecureStr = extractValue(keys: ["insecure"], userInfo: userInfo, dataDict: dataDict)
        let insecureVal = (insecureStr != nil) ? (insecureStr?.lowercased() == "true" || insecureStr == "1") : BipeLiveActivityManager.getCurrentRegionInsecure()
        
        if let soundVal = soundVal, !soundVal.isEmpty {
            BipeAudioHelper.playSound(named: soundVal)
        }
        
        let titleVal = extractValue(keys: ["title"], userInfo: userInfo, dataDict: dataDict)?.lowercased() ?? ""
        let soundValLower = soundVal?.lowercased() ?? ""
        
        let typeLower = type?.lowercased() ?? ""
        let statusLower = status?.lowercased() ?? ""
        let eventLower = eventVal?.lowercased() ?? ""
        
        let isBipe = typeLower.contains("bipe") || statusLower.contains("bipe") || eventLower.contains("bipe") || titleVal.contains("bipe")
        let isEmergency = !isBipe && (typeLower.contains("emergency") || statusLower.contains("emergency") || statusLower.contains("emergencia") || statusLower.contains("emergência") || typeLower.contains("sentinela") || typeLower.contains("sentinel") || statusLower.contains("sentinela") || statusLower.contains("sentinel") || eventLower.contains("sentinela") || eventLower.contains("sentinel"))
        let isRoutine = !isBipe && !isEmergency && (typeLower.contains("routine") || typeLower.contains("rotina") || statusLower.contains("routine") || statusLower.contains("rotina") || eventLower.contains("routine") || eventLower.contains("rotina"))
        let isDistance = !isBipe && !isEmergency && !isRoutine && (typeLower.contains("distance") || statusLower.contains("distance") || eventLower.contains("aproxim") || eventLower.contains("afast") || statusLower.contains("aproxim") || statusLower.contains("afast") || targetVal != nil || alvoVal != nil || distanciaVal != nil)
        let isTransition = !isBipe && !isEmergency && !isDistance && !isRoutine
        
        guard isBipe || isDistance || isTransition || isEmergency || isRoutine else {
            NSLog("[BipeLiveActivityManager] Push ignorado (type: '%@', status: '%@', event: '%@'). Não corresponde a bipe, distance, transition, routine ou emergency.", typeLower, statusLower, eventLower)
            return
        }
        
        if #available(iOS 16.1, *) {
            let moc = CoreData.sharedInstance().mainMOC
            let nickname = extractValue(keys: ["nickname", "name", "userName"], userInfo: userInfo, dataDict: dataDict)
                ?? Settings.string(forKey: "device_name_preference", inMOC: moc)
                ?? Settings.string(forKey: "nickname_preference", inMOC: moc)
                ?? "Bipe.me"
            
            let address = extractValue(keys: ["address", "endereco", "locationName", "desc", "text", "location"], userInfo: userInfo, dataDict: dataDict)
                ?? "Localização atual"
            
            let appDeviceIcon = Settings.string(forKey: "icon", inMOC: moc) ?? Settings.string(forKey: "face_preference", inMOC: moc)
            let iconUrl = extractValue(keys: ["icon", "iconUrl", "image", "imageUrl", "avatar"], userInfo: userInfo, dataDict: dataDict) ?? appDeviceIcon
            
            if isBipe || isEmergency {
                let activityTypeToUse = isBipe ? "bipe" : "emergency"
                let statusToUse = isBipe ? "bipe" : "emergency"
                NSLog("[BipeLiveActivityManager] Atualizando Live Activity para BIPE/EMERGENCY (nickname: '%@', address: '%@', execucaoId: '%@')", nickname, address, execucaoIdVal ?? "")
                
                startLiveActivity(
                    nickname: nickname,
                    address: address,
                    iconLocalPath: nil,
                    iconUrl: iconUrl,
                    status: statusToUse,
                    way: nil,
                    devices: nil,
                    event: nil,
                    activityType: activityTypeToUse,
                    icon: iconUrl,
                    execucaoId: execucaoIdVal,
                    insecure: insecureVal
                )
            } else if isRoutine {
                NSLog("[BipeLiveActivityManager] Atualizando Live Activity para ROUTINE (nickname: '%@', address: '%@')", nickname, address)
                
                startLiveActivity(
                    nickname: nickname,
                    address: address,
                    iconLocalPath: nil,
                    iconUrl: iconUrl,
                    status: "routine",
                    way: nil,
                    devices: nil,
                    event: "routine",
                    activityType: "routine",
                    icon: iconUrl,
                    insecure: insecureVal
                )
            } else if isDistance {
                let eventDisplay = eventVal ?? (statusLower.contains("afast") ? "AFASTAR" : "APROXIMAR")
                NSLog("[BipeLiveActivityManager] Atualizando Live Activity para DISTANCE: target='%@', alvo='%@', distancia='%@', event='%@'", targetVal ?? "", alvoVal ?? "", distanciaVal ?? "", eventDisplay)
                
                startLiveActivity(
                    nickname: nickname,
                    address: address,
                    iconLocalPath: nil,
                    iconUrl: iconUrl,
                    status: "distance",
                    way: nil,
                    devices: nil,
                    event: eventDisplay,
                    activityType: "distance",
                    target: targetVal,
                    alvo: alvoVal,
                    distancia: distanciaVal,
                    insecure: insecureVal
                )
            } else if isTransition {
                let way = wayVal ?? extractValue(keys: ["way", "region", "wayName", "locationName", "desc"], userInfo: userInfo, dataDict: dataDict) ?? "Região Cadastrada"
                let isExitEvent = eventLower.contains("exit") || eventLower.contains("leave") || eventLower.contains("left") || eventLower.contains("saida") || eventLower.contains("saída") || eventLower.contains("saiu") || eventLower.contains("out") || statusLower.contains("exit") || statusLower.contains("leave") || statusLower.contains("left") || statusLower.contains("saida") || statusLower.contains("saída") || statusLower.contains("saiu") || statusLower.contains("out")
                let event = isExitEvent ? "exit" : "enter"
                let devicesList = extractDevicesArray(userInfo: userInfo, dataDict: dataDict)
                
                NSLog("[BipeLiveActivityManager] Atualizando Live Activity para TRANSITION (way: '%@', event: '%@', devices: %@)", way, event, devicesList)
                
                startLiveActivity(
                    nickname: nickname,
                    address: address,
                    iconLocalPath: nil,
                    iconUrl: iconUrl,
                    status: "transition",
                    way: way,
                    devices: devicesList,
                    event: event,
                    activityType: "transition",
                    icon: iconUrl,
                    insecure: insecureVal
                )
            }
        } else {
            NSLog("[BipeLiveActivityManager] Live Activities não suportadas nesta versão do iOS.")
        }
    }

    // MARK: - Data Extraction Helpers

    private static func extractValue(keys: [String], userInfo: NSDictionary, dataDict: [String: Any]?) -> String? {
        let apsDict = (userInfo["aps"] as? NSDictionary) ?? (userInfo["aps"] as? [String: Any]) as NSDictionary?
        let alertDict = (apsDict?["alert"] as? NSDictionary) ?? (apsDict?["alert"] as? [String: Any]) as NSDictionary?
        let contentState = (apsDict?["content-state"] as? NSDictionary)
            ?? (apsDict?["content-state"] as? [String: Any]) as NSDictionary?
            ?? (apsDict?["contentState"] as? NSDictionary)
            ?? (apsDict?["content_state"] as? NSDictionary)
        
        for key in keys {
            if let val = userInfo[key] {
                let str = String(describing: val).trimmingCharacters(in: .whitespacesAndNewlines)
                if !str.isEmpty && str != "<null>" && str != "nil" && str != "null" { return str }
            }
            if let dataDict = dataDict, let val = dataDict[key] {
                let str = String(describing: val).trimmingCharacters(in: .whitespacesAndNewlines)
                if !str.isEmpty && str != "<null>" && str != "nil" && str != "null" { return str }
            }
            if let contentState = contentState, let val = contentState[key] {
                let str = String(describing: val).trimmingCharacters(in: .whitespacesAndNewlines)
                if !str.isEmpty && str != "<null>" && str != "nil" && str != "null" { return str }
            }
            if let alertDict = alertDict, let val = alertDict[key] {
                let str = String(describing: val).trimmingCharacters(in: .whitespacesAndNewlines)
                if !str.isEmpty && str != "<null>" && str != "nil" && str != "null" { return str }
            }
            if let apsDict = apsDict, let val = apsDict[key] {
                let str = String(describing: val).trimmingCharacters(in: .whitespacesAndNewlines)
                if !str.isEmpty && str != "<null>" && str != "nil" && str != "null" { return str }
            }
        }
        return nil
    }

    private static func extractDevicesArray(userInfo: NSDictionary, dataDict: [String: Any]?) -> [String] {
        let apsDict = (userInfo["aps"] as? NSDictionary) ?? (userInfo["aps"] as? [String: Any]) as NSDictionary?
        let contentState = (apsDict?["content-state"] as? NSDictionary)
            ?? (apsDict?["content-state"] as? [String: Any]) as NSDictionary?
            ?? (apsDict?["contentState"] as? NSDictionary)
            ?? (apsDict?["content_state"] as? NSDictionary)
        
        var rawValue: Any? = userInfo["devices"] ?? userInfo["_devices"]
        if rawValue == nil {
            rawValue = dataDict?["devices"] ?? dataDict?["_devices"]
        }
        if rawValue == nil {
            rawValue = contentState?["devices"] ?? contentState?["_devices"]
        }
        
        guard let raw = rawValue else { return [] }
        
        if let array = raw as? [String] {
            return array
        }
        if let nestedArray = raw as? [[String]] {
            return nestedArray.flatMap { $0 }
        }
        if let nsArray = raw as? NSArray {
            var result: [String] = []
            for item in nsArray {
                if let subArray = item as? NSArray {
                    for sub in subArray {
                        result.append(String(describing: sub))
                    }
                } else if let subStringArray = item as? [String] {
                    result.append(contentsOf: subStringArray)
                } else {
                    result.append(String(describing: item))
                }
            }
            return result
        }
        if let arrayDict = raw as? [[String: Any]] {
            return arrayDict.compactMap { dict in
                dict["name"] as? String ?? dict["nickname"] as? String ?? dict["apelido"] as? String ?? dict["username"] as? String ?? dict["icon"] as? String
            }
        }
        if let str = raw as? String {
            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                if let data = trimmed.data(using: .utf8) {
                    if let parsedArray = try? JSONSerialization.jsonObject(with: data) as? [String] {
                        return parsedArray
                    }
                    if let parsedNested = try? JSONSerialization.jsonObject(with: data) as? [[String]] {
                        return parsedNested.flatMap { $0 }
                    }
                    if let parsedDicts = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                        return parsedDicts.compactMap { dict in
                            dict["name"] as? String ?? dict["nickname"] as? String ?? dict["apelido"] as? String ?? dict["username"] as? String ?? dict["icon"] as? String
                        }
                    }
                }
            }
            let cleaned = trimmed.replacingOccurrences(of: "[", with: "")
                                 .replacingOccurrences(of: "]", with: "")
                                 .replacingOccurrences(of: "\"", with: "")
                                 .replacingOccurrences(of: "'", with: "")
            return cleaned.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }
        return []
    }

    // MARK: - Server Token Sync

    private static func sendLiveActivityTokenToServer(token: String, activityId: String) {
        var bgTask: UIBackgroundTaskIdentifier = .invalid
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "SendLiveActivityToken") {
            if bgTask != .invalid {
                UIApplication.shared.endBackgroundTask(bgTask)
                bgTask = .invalid
            }
        }
        
        AuthManager.shared.getBearerToken { bearerToken in
            let finishBgTaskIfNeeded = {
                if bgTask != .invalid {
                    UIApplication.shared.endBackgroundTask(bgTask)
                    bgTask = .invalid
                }
            }
            
            guard let bearerToken = bearerToken else {
                NSLog("[BipeLiveActivityManager] Impossível registrar token: Bearer token ausente.")
                finishBgTaskIfNeeded()
                return
            }
            
            let moc = CoreData.sharedInstance().mainMOC
            var clientId: String? = nil
            var deviceId: String? = nil
            moc.performAndWait {
                clientId = Settings.string(forKey: "clientid_preference", inMOC: moc)
                deviceId = Settings.string(forKey: "deviceid_preference", inMOC: moc)
            }
            
            let fcmToken = Messaging.messaging().fcmToken ?? UserDefaults.standard.string(forKey: "fcm_token")
            let fcmTokenStr = fcmToken ?? ""
            let cacheKey = "\(token)|\(fcmTokenStr)"
            
            if lastSentTokens[activityId] == cacheKey {
                NSLog("[BipeLiveActivityManager] Token %@ com FCM %@ para Activity %@ já foi enviado recentemente. Ignorando envio duplicado.", token, fcmTokenStr, activityId)
                finishBgTaskIfNeeded()
                return
            }
            lastSentTokens[activityId] = cacheKey
            
            var payloadDict: [String: Any] = [
                "token": token,
                "activityId": activityId
            ]
            if let clientId = clientId, !clientId.isEmpty {
                payloadDict["clientId"] = clientId
            }
            if let deviceId = deviceId, !deviceId.isEmpty {
                payloadDict["deviceId"] = deviceId
            }
            if !fcmTokenStr.isEmpty {
                payloadDict["fcmToken"] = fcmTokenStr
            }
            
            let authHeader = bearerToken.hasPrefix("Bearer ") ? bearerToken : "Bearer \(bearerToken)"
            
            let group = DispatchGroup()
            
            // 1. Registra no endpoint /bipe/live-activity/token
            if let url = URL(string: tokenEndpoint) {
                group.enter()
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue(authHeader, forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try? JSONSerialization.data(withJSONObject: payloadDict)
                
                URLSession.shared.dataTask(with: request) { _, response, error in
                    defer { group.leave() }
                    if let error = error {
                        NSLog("[BipeLiveActivityManager] Erro ao enviar activityToken para servidor: %@", error.localizedDescription)
                    } else if let httpResp = response as? HTTPURLResponse {
                        NSLog("[BipeLiveActivityManager] ActivityToken enviado para /bipe/live-activity/token com sucesso. Status: %d", httpResp.statusCode)
                    }
                }.resume()
            }
            
            // 2. Atualiza no endpoint especifico do dispositivo /bipe/devices/{id}/tokens se o deviceId existir
            if let devId = deviceId, !devId.isEmpty, let patchUrl = URL(string: "https://dev.simodapp.com:2087/bipe/devices/\(devId)/tokens") {
                group.enter()
                var patchReq = URLRequest(url: patchUrl)
                patchReq.httpMethod = "PATCH"
                patchReq.setValue(authHeader, forHTTPHeaderField: "Authorization")
                patchReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let patchBody: [String: String] = ["token": token]
                patchReq.httpBody = try? JSONSerialization.data(withJSONObject: patchBody)
                
                URLSession.shared.dataTask(with: patchReq) { _, response, error in
                    defer { group.leave() }
                    if let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) {
                        NSLog("[BipeLiveActivityManager] ActivityToken sincronizado no dispositivo %@ via PATCH. Status: %d", devId, httpResp.statusCode)
                    }
                }.resume()
            }
            
            group.notify(queue: .main) {
                finishBgTaskIfNeeded()
            }
        }
    }

    private static func removeLiveActivityTokenFromServer(activityId: String) {
        var bgTask: UIBackgroundTaskIdentifier = .invalid
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "RemoveLiveActivityToken") {
            if bgTask != .invalid {
                UIApplication.shared.endBackgroundTask(bgTask)
                bgTask = .invalid
            }
        }
        
        AuthManager.shared.getBearerToken { bearerToken in
            let finishBgTaskIfNeeded = {
                if bgTask != .invalid {
                    UIApplication.shared.endBackgroundTask(bgTask)
                    bgTask = .invalid
                }
            }
            
            guard let bearerToken = bearerToken else {
                finishBgTaskIfNeeded()
                return
            }
            guard let url = URL(string: "\(activityEndpointPrefix)\(activityId)") else {
                finishBgTaskIfNeeded()
                return
            }
            
            let authHeader = bearerToken.hasPrefix("Bearer ") ? bearerToken : "Bearer \(bearerToken)"
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
            
            URLSession.shared.dataTask(with: request) { _, response, error in
                defer { finishBgTaskIfNeeded() }
                if let error = error {
                    NSLog("[BipeLiveActivityManager] Erro ao remover token do servidor: %@", error.localizedDescription)
                } else if let httpResp = response as? HTTPURLResponse {
                    NSLog("[BipeLiveActivityManager] Token da Live Activity removido do servidor. Status HTTP: %d", httpResp.statusCode)
                }
            }.resume()
        }
    }

    // MARK: - Bipe MQTT Receipt & Confirmation Flow

    @objc(sendBipeReceiptWithStatus:execucaoId:)
    static func sendBipeReceipt(status: String, execucaoId: String?) {
        sendBipeResponse(status: status, button: nil, execucaoId: execucaoId, autoResetLiveActivity: false)
    }

    @objc(sendBipeConfirmationWithExecucaoId:)
    static func sendBipeConfirmation(execucaoId: String?) {
        sendBipeResponse(status: "COMPLETED", button: "TOUCH", execucaoId: execucaoId, autoResetLiveActivity: true)
    }

    @available(iOS 16.1, *)
    static func sendBipeConfirmationAsync(execucaoId: String?) async {
        sendBipeResponse(status: "COMPLETED", button: "TOUCH", execucaoId: execucaoId, autoResetLiveActivity: true)
    }

    private static func sendBipeResponse(status: String, button: String?, execucaoId: String?, autoResetLiveActivity: Bool) {
        DispatchQueue.main.async {
            guard let appDelegate = UIApplication.shared.delegate as? OwnTracksAppDelegate else { return }
            let moc = CoreData.sharedInstance().mainMOC
            var json: [String: Any] = [
                "_type": "bipe",
                "status": status
            ]
            if let btn = button, !btn.isEmpty {
                json["button"] = btn
            }
            if let execId = execucaoId, !execId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                json["execucaoId"] = execId
            }
            
            var userName: String? = nil
            var clienteId: String? = nil
            var tid: String? = nil
            var deviceId: String? = nil
            var nickname: String? = nil
            var face: String? = nil
            var color: String? = nil
            var qosVal: Int32 = 0
            var baseTopic: String? = nil
            
            moc.performAndWait {
                userName = Settings.string(forKey: "user_preference", inMOC: moc)
                clienteId = Settings.string(forKey: "clientid_preference", inMOC: moc)
                tid = Settings.string(forKey: "trackerid_preference", inMOC: moc)
                deviceId = Settings.string(forKey: "deviceid_preference", inMOC: moc)
                nickname = Settings.string(forKey: "device_name_preference", inMOC: moc)
                if nickname == nil || nickname!.isEmpty {
                    nickname = Settings.string(forKey: "nickname_preference", inMOC: moc)
                }
                face = Settings.string(forKey: "icon", inMOC: moc)
                color = Settings.string(forKey: "color", inMOC: moc)
                qosVal = Settings.int(forKey: "qos_preference", inMOC: moc)
                baseTopic = Settings.theGeneralTopic(inMOC: moc)
            }
            
            if let userName = userName, !userName.isEmpty { json["userName"] = userName }
            if let clienteId = clienteId, !clienteId.isEmpty { json["clienteId"] = clienteId }
            if let tid = tid, !tid.isEmpty { json["tid"] = tid }
            if let deviceId = deviceId, !deviceId.isEmpty { json["deviceId"] = deviceId }
            if let nickname = nickname, !nickname.isEmpty { json["nickname"] = nickname }
            if let face = face, !face.isEmpty { json["face"] = face }
            if let color = color, !color.isEmpty { json["color"] = color }
            
            if autoResetLiveActivity, #available(iOS 16.1, *) {
                let nickToUse = nickname ?? "Bipe.me"
                let iconToUse = (face != nil && !face!.isEmpty) ? face : "logo"
                startLiveActivity(
                    nickname: nickToUse,
                    address: String(localized: "Bipe Confirmado"),
                    iconLocalPath: nil,
                    iconUrl: iconToUse,
                    status: "CONFIRMADO",
                    way: BipeLiveActivityManager.getCurrentRegionName(),
                    devices: nil,
                    event: "bipe",
                    activityType: "bipe",
                    icon: iconToUse,
                    execucaoId: nil,
                    insecure: BipeLiveActivityManager.getCurrentRegionInsecure()
                )
            }
            
            guard let payload = try? JSONSerialization.data(withJSONObject: json, options: []) else { return }
            
            if appDelegate.connection == nil {
                appDelegate.connection = Connection()
                appDelegate.connection?.delegate = appDelegate
                appDelegate.connection?.start()
            }
            appDelegate.connection?.connectToLast()
            
            let qos = MQTTQosLevel(rawValue: UInt8(qosVal)) ?? .atMostOnce
            let userStr = (userName ?? "").isEmpty ? "user" : userName!
            let devStr = (deviceId ?? "").isEmpty ? ((tid ?? "").isEmpty ? "device" : tid!) : deviceId!
            let topic = "owntracks/\(userStr)/\(devStr)/bipe"
            
            func attemptPublish(attemptsRemaining: Int) {
                let currentState = Int(appDelegate.connection?.state ?? -1)
                NSLog("[BipeLiveActivityManager] Tentativa de envio MQTT status '%@'. Estado conexao: %d, tentativas restantes: %d", status, currentState, attemptsRemaining)
                
                // state_connected tem rawValue 3
                if currentState == 3 {
                    appDelegate.connection?.send(payload, topic: topic, topicAlias: nil, qos: qos, retain: false)
                    NSLog("[BipeLiveActivityManager] MQTT bipe status '%@' enviado com sucesso (topico: '%@', execucaoId: %@)", status, topic, execucaoId ?? "nil")
                } else if attemptsRemaining > 0 {
                    appDelegate.connection?.connectToLast()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        attemptPublish(attemptsRemaining: attemptsRemaining - 1)
                    }
                } else {
                    appDelegate.connection?.send(payload, topic: topic, topicAlias: nil, qos: qos, retain: false)
                    NSLog("[BipeLiveActivityManager] MQTT bipe status '%@' enviado no fallback final com execucaoId: %@", status, execucaoId ?? "nil")
                }
            }
            
            attemptPublish(attemptsRemaining: 15)
        }
    }
}
