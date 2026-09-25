//
//  BipeWidgetExtensionLiveActivity.swift
//  BipeWidgetExtension
//

import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

@available(iOS 17.0, *)
struct ConfirmBipeIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Confirmar Bipe"
    static var openAppWhenRun: Bool = true
    
    @Parameter(title: "Execução ID")
    var execucaoId: String?
    
    init() {}
    init(execucaoId: String?) {
        self.execucaoId = execucaoId
    }
    
    func perform() async throws -> some IntentResult {
        if let sharedDefaults = UserDefaults(suiteName: "group.br.guardiam.com") {
            sharedDefaults.set(execucaoId ?? "", forKey: "pending_bipe_confirm_execucao_id")
            sharedDefaults.synchronize()
        }
        return .result()
    }
}

private class WidgetBundleClass {}

@available(iOS 16.1, *)
struct DeviceBadgeView: View {
    let item: String
    let themeColor: Color
    var size: CGFloat = 20.0
    
    var cleanName: String {
        let name = item.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.hasSuffix(".png") || name.hasSuffix(".svg") || name.hasSuffix(".jpg") || name.hasSuffix(".jpeg") {
            return (name as NSString).deletingPathExtension
        }
        return name
    }
    
    var uiImage: UIImage? {
        let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        if let img = UIImage(named: cleanName) ?? UIImage(named: item) ?? UIImage(named: "drawable/\(cleanName)") ?? UIImage(named: "drawable/\(item)") {
            return img
        }
        
        let ext = (item as NSString).pathExtension
        guard !ext.isEmpty else { return nil }
        
        let possibleTypes = Array(Set([ext, "png", "PNG", "jpg", "JPG", "jpeg"])).filter { !$0.isEmpty }
        let bundles = [Bundle.main, Bundle(for: WidgetBundleClass.self)]
        
        for bundle in bundles {
            for type in possibleTypes {
                // 1. Busca na raiz do bundle (Yellow Group no Xcode)
                if let path = bundle.path(forResource: cleanName, ofType: type), let img = UIImage(contentsOfFile: path) {
                    return img
                }
                if let path = bundle.path(forResource: item, ofType: type), let img = UIImage(contentsOfFile: path) {
                    return img
                }
                // 2. Busca na pasta drawable (Blue Folder Reference no Xcode)
                if let path = bundle.path(forResource: cleanName, ofType: type, inDirectory: "drawable"), let img = UIImage(contentsOfFile: path) {
                    return img
                }
                if let path = bundle.path(forResource: item, ofType: type, inDirectory: "drawable"), let img = UIImage(contentsOfFile: path) {
                    return img
                }
            }
        }
        
        return nil
    }
    
    var isImageFile: Bool {
        let n = item.lowercased()
        return n.hasSuffix(".png") || n.hasSuffix(".svg") || n.hasSuffix(".jpg") || n.hasSuffix(".jpeg") || uiImage != nil
    }
    
    var systemIcon: String {
        let n = cleanName.lowercased()
        if n.contains("car") || n.contains("carro") || n.contains("auto") { return "car.fill" }
        if n.contains("person") || n.contains("user") || n.contains("pessoa") || n.contains("logo") { return "person.fill" }
        if n.contains("iphone") || n.contains("phone") || n.contains("mobile") || n.contains("celular") { return "iphone" }
        if n.contains("bus") || n.contains("onibus") { return "bus.fill" }
        if n.contains("bicycle") || n.contains("bike") || n.contains("bicicleta") { return "bicycle" }
        if n.contains("boat") || n.contains("ship") { return "ferry.fill" }
        if n.contains("plane") || n.contains("aviao") { return "airplane" }
        if n.contains("motorcycle") || n.contains("scooter") { return "motorcycle" }
        if n.contains("truck") || n.contains("caminhao") { return "truck.box.fill" }
        if n.contains("train") || n.contains("tram") { return "tram.fill" }
        return "mappin.circle.fill"
    }
    
    var body: some View {
        HStack(spacing: 4) {
            if let img = uiImage {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            } else {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [themeColor, themeColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: size, height: size)
                    
                    Image(systemName: systemIcon)
                        .font(.system(size: size * 0.48, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(2)
    }
}

// MARK: - View para Transições de Região ("transition") - Premium UI

@available(iOS 16.1, *)
struct TransitionWidgetView: View {
    let state: BipeAlertActivityAttributes.ContentState
    
    var isExit: Bool {
        let ev = state.event?.lowercased() ?? ""
        let st = state.status.lowercased()
        return ev.contains("exit") || ev.contains("leave") || ev.contains("left") || ev.contains("saida") || ev.contains("saída") || ev.contains("saiu") || ev.contains("out") ||
               st.contains("exit") || st.contains("leave") || st.contains("left") || st.contains("saida") || st.contains("saída") || st.contains("saiu") || st.contains("out")
    }

    var isActived: Bool {
        let ev = state.event?.lowercased() ?? "" 
        return ev.contains("active") || ev.contains("ativo")
    } 
    
    var isMove: Bool {
        let ev = state.event?.lowercased() ?? ""
        let st = state.status.lowercased()
        return ev.contains("move") || ev.contains("movimento") || st.contains("move") || st.contains("movimento")
    }
    
    var themeColor: Color {
        if state.insecure == true { return .red }
        return isExit ? Color.orange : (isMove ? Color.blue : Color(red: 0.18, green: 0.80, blue: 0.44))
    }
    
    var eventTitle: String {
        if state.insecure == true {
            return isExit ? String(localized: "SAIU DE ÁREA DE RISCO") : (isActived ? String(localized: "ÁREA DE RISCO") : (isMove ? String(localized: "MOVIMENTOU EM ÁREA DE RISCO") : String(localized: "ENTROU EM ÁREA DE RISCO")))
        }
        return isExit ? String(localized: "SAIU") : (isActived ? String(localized: "ATIVO") : (isMove ? String(localized: "SE MOVEU") : String(localized: "ENTROU")))
    }
    
    var eventIcon: String {
        isExit ? "arrow.left.to.line.compact" : (isMove ? "location.fill" : "arrow.right.to.line.compact")
    }
    
    var regionName: String {
        state.way ?? state.address
    }
    
    var devicesList: [String] {
        state.devices ?? []
    }

    var isInsideRegion: Bool {
        state.way != nil && !(state.way!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) && state.way != "Bipe.me"
    }
    
    var emptyStateText: String {
        if isInsideRegion && !isExit {
            return state.insecure == true ? String(localized: "Dentro de área de risco") : String(localized: "Dentro de uma região protegida")
        }
        return String(localized: "Aguardando publicação")
    }
    
    var emptyStateIcon: String {
        if isInsideRegion && !isExit {
            return state.insecure == true ? "exclamationmark.triangle.fill" : "shield.checkerboard"
        }
        return "checkmark.shield.fill"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // MARK: 1. Header com ícone de radar, título da região e badge translúcido
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [themeColor.opacity(0.3), themeColor.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .overlay(
                            Circle()
                                .stroke(themeColor.opacity(0.4), lineWidth: 1.5)
                        )
                    
                    let triggerIcon = (state.icon != nil && !state.icon!.isEmpty) ? state.icon! : ((state.iconUrl != nil && !state.iconUrl!.isEmpty) ? state.iconUrl! : "logo")
                    DeviceBadgeView(item: triggerIcon, themeColor: themeColor, size: 34)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(regionName)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        // Live pulse dot
                        Circle()
                            .fill(themeColor)
                            .frame(width: 7, height: 7)
                            .shadow(color: themeColor, radius: 3)
                    }
                    
                    let nick = state.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
                    Text(nick.isEmpty || nick == "Bipe.me" ? String(localized: "Monitorando em tempo real") : nick)
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundColor(.secondary)
                        .tracking(0.5)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Badge translúcido
                HStack(spacing: 5) {
                    Image(systemName: eventIcon)
                        .font(.system(size: 11, weight: .bold))
                    Text(eventTitle)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(themeColor.opacity(0.18))
                )
                .overlay(
                    Capsule()
                        .stroke(themeColor.opacity(0.4), lineWidth: 1.2)
                )
                .foregroundColor(themeColor)
            }
            
            // MARK: 2. Card de Perímetro (Geofence Zone) com os dispositivos
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    HStack(spacing: 5) {
                        Text(devicesList.isEmpty ? LocalizedStringKey("PERÍMETRO ATIVO") : LocalizedStringKey("DISPOSITIVOS PRÓXIMOS"))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            .tracking(0.5)
                    }
                    
                    Spacer()
                    
                    if !devicesList.isEmpty {
                        Text("\(devicesList.count) \(devicesList.count == 1 ? String(localized: "dispositivo") : String(localized: "dispositivos"))")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(themeColor)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(themeColor.opacity(0.12)))
                    }
                }
                
                if !devicesList.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(devicesList.prefix(8), id: \.self) { devName in
                            DeviceBadgeView(item: devName, themeColor: themeColor)
                        }
                        
                        if devicesList.count > 8 {
                            ZStack {
                                Circle()
                                    .fill(themeColor.opacity(0.2))
                                    .frame(width: 28, height: 28)
                                Text("+\(devicesList.count - 8)")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(themeColor)
                            }
                        }
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: emptyStateIcon)
                            .font(.system(size: 13))
                            .foregroundColor(themeColor)
                        Text(emptyStateText)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(UIColor.tertiarySystemGroupedBackground).opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(themeColor.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    )
            )
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [themeColor.opacity(0.5), themeColor.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .activityBackgroundTint(Color(UIColor.systemBackground))
        .activitySystemActionForegroundColor(Color.primary)
    }
}

// MARK: - View para Alertas de Emergência

@available(iOS 16.1, *)
struct EmergencyWidgetView: View {
    let state: BipeAlertActivityAttributes.ContentState

    var receivedIcon: String? {
        if let icon = state.icon, !icon.isEmpty { return icon } 
        if let target = state.target, !target.isEmpty { return target }
        if let firstDev = state.devices?.first, !firstDev.isEmpty { return firstDev }
        return nil
    }

    var isProtectedRegion: Bool {
        let st = state.status.lowercased()
        let isDefault = (st == "start" || st.isEmpty)
        let hasRegion = state.way != nil && !(state.way!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        return isDefault && hasRegion
    }

    var isEmergencyState: Bool {
        let st = state.status.lowercased()
        let act = state.activityType?.lowercased() ?? ""
        return st == "emergency" || st == "emergencia" || st == "emergência" || act == "emergency"
    }

    var themeColor: Color {
        if isEmergencyState { return .red }
        if state.insecure == true { return .red }
        return isProtectedRegion ? Color(red: 0.18, green: 0.80, blue: 0.44) : .orange
    }

    var badgeText: String {
        if isEmergencyState { return String(localized: "EMERGÊNCIA") }
        if state.insecure == true { return String(localized: "CUIDADO") }
        if isProtectedRegion {
            return String(localized: "ZONA PROTEGIDA")
        }
        let st = state.status.lowercased()
        if st == "start" || st == "bipe" || st == "bipe_alert" || st.isEmpty {
            return String(localized: "ATENÇÃO")
        }
        return state.status.uppercased()
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                HStack(spacing: 8) {
                    if let iconItem = receivedIcon {
                        ZStack {
                            DeviceBadgeView(item: iconItem, themeColor: themeColor, size: 44)
                            if isEmergencyState {
                                Circle()
                                    .stroke(Color.red, lineWidth: 2)
                                    .frame(width: 48, height: 48)
                            }
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(state.nickname)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(isEmergencyState ? .white : .primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(badgeText)
                            .font(.caption2)
                            .fontWeight(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(isEmergencyState ? Color.white : themeColor))
                            .foregroundColor(isEmergencyState ? Color.red : .white)
                    }
                    
                    if isProtectedRegion, let region = state.way {
                        HStack(alignment: .center, spacing: 4) {
                            Image(systemName: "shield.checkerboard")
                                .font(.system(size: 11, weight: .bold))
                            Text(region)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(isEmergencyState ? Color.white.opacity(0.9) : themeColor)
                        .padding(.bottom, 1)
                    }
                    
                    Text(state.address)
                        .font(.subheadline)
                        .foregroundColor(isEmergencyState ? Color.white.opacity(0.9) : .secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if let proxStr = state.prox, !proxStr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        let parts = proxStr.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
                        if parts.count >= 2 {
                            let proxIcon = parts[0]
                            let proxDist = parts[1]
                            let proxNick = parts.count > 2 ? parts[2] : ""
                            
                            HStack(alignment: .center, spacing: 6) {
                                DeviceBadgeView(item: proxIcon, themeColor: .gray, size: 20)
                                Text("\(proxNick.isEmpty ? String(localized: "Mais próximo") : proxNick) a \(proxDist)")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(isEmergencyState ? Color.white : themeColor)
                            }
                            .padding(.top, 1)
                        }
                    }
                    
                    if let prev = state.previousEvent, !prev.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("\(String(localized: "Último evento:")) \(prev)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(isEmergencyState ? Color.white.opacity(0.8) : .secondary.opacity(0.8))
                            .lineLimit(1)
                    }
                }
            }
            
            let act = state.activityType?.lowercased() ?? ""
            let st = state.status.lowercased()
            let ev = state.event?.lowercased() ?? ""
            let isBipeAlert = act == "bipe" || act == "bipe_alert" || st == "bipe" || st == "bipe_alert" || ev == "bipe" || ev == "bipe_alert"
            if isBipeAlert && st != "confirmado" {
                if #available(iOS 17.0, *) {
                    Button(intent: ConfirmBipeIntent(execucaoId: state.execucaoId)) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 15, weight: .bold))
                            Text(String(localized: "CONFIRMAR BIPE"))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(LinearGradient(colors: [Color.green, Color(red: 0.15, green: 0.70, blue: 0.35)], startPoint: .leading, endPoint: .trailing))
                        )
                        .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                } else {
                    Link(destination: URL(string: "bipe://confirm?execucaoId=\(state.execucaoId ?? "")")!) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 15, weight: .bold))
                            Text(String(localized: "CONFIRMAR BIPE"))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(LinearGradient(colors: [Color.green, Color(red: 0.15, green: 0.70, blue: 0.35)], startPoint: .leading, endPoint: .trailing))
                        )
                        .foregroundColor(.white)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    isEmergencyState ?
                        AnyShapeStyle(LinearGradient(colors: [Color(red: 0.75, green: 0.08, blue: 0.08), Color(red: 0.50, green: 0.02, blue: 0.02)], startPoint: .topLeading, endPoint: .bottomTrailing)) :
                        AnyShapeStyle(Color(UIColor.secondarySystemGroupedBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(isEmergencyState ? Color.red : Color.clear, lineWidth: 1.5)
                )
        )
        .activityBackgroundTint(isEmergencyState ? Color(red: 0.18, green: 0.02, blue: 0.02) : Color(UIColor.systemBackground))
        .activitySystemActionForegroundColor(isEmergencyState ? .white : Color.primary)
    }
}

// MARK: - Separador Direcional de Distância (Ex: ›—‹ para Aproximar, ‹—› para Afastar)

struct DistanceDirectionSeparatorView: View {
    let isApproaching: Bool
    let themeColor: Color
    var fontSize: CGFloat = 11

    var body: some View {
        HStack(spacing: 2) {
            if isApproaching {
                // › — ‹ (Aproximando)
                Image(systemName: "chevron.right")
                    .font(.system(size: fontSize, weight: .bold))
                Capsule()
                    .fill(themeColor.opacity(0.7))
                    .frame(width: 5, height: 2)
                Image(systemName: "chevron.left")
                    .font(.system(size: fontSize, weight: .bold))
            } else {
                // ‹ — › (Afastando)
                Image(systemName: "chevron.left")
                    .font(.system(size: fontSize, weight: .bold))
                Capsule()
                    .fill(themeColor.opacity(0.7))
                    .frame(width: 5, height: 2)
                Image(systemName: "chevron.right")
                    .font(.system(size: fontSize, weight: .bold))
            }
        }
        .foregroundColor(themeColor)
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(themeColor.opacity(0.18))
        )
    }
}

// MARK: - View para Evento de Distância ("distance" / "APROXIMAR" / "AFASTAR") - Compact UI

@available(iOS 16.1, *)
struct DistanceWidgetView: View {
    let state: BipeAlertActivityAttributes.ContentState
    
    var isApproaching: Bool {
        let ev = state.event?.lowercased() ?? ""
        let st = state.status.lowercased()
        return ev.contains("aproxim") || st.contains("aproxim") || ev == "enter"
    }
    
    var themeColor: Color {
        isApproaching ? Color(red: 0.18, green: 0.80, blue: 0.44) : Color.orange
    }
    
    var statusTitle: String {
        isApproaching ? "SE APROXIMOU" : "SE AFASTOU"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // MARK: Header com selo de aproximar/afastar
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(themeColor.opacity(0.18))
                        .frame(width: 32, height: 32)
                        .overlay(Circle().stroke(themeColor.opacity(0.4), lineWidth: 1))
                    
                    if let firstDev = state.devices?.first, !firstDev.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        DeviceBadgeView(item: firstDev, themeColor: themeColor, size: 24)
                    } else {
                        Image(systemName: isApproaching ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(themeColor)
                    }
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(state.nickname)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(String(localized: "Alerta de Distância"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        
                    if let prev = state.previousEvent, !prev.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("\(String(localized: "Último evento:")) \(prev)")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary.opacity(0.8))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text(statusTitle)
                        .font(.system(size: 10, weight: .black, design: .rounded))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(themeColor))
                .foregroundColor(.black)
            }
            
            // MARK: Linha Compacta: Ícones [Target] / [Alvo] e Distância
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    if let target = state.target, !target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        DeviceBadgeView(item: target, themeColor: themeColor, size: 24)
                    }
                    
                    if let target = state.target, !target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       let alvo = state.alvo, !alvo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        DistanceDirectionSeparatorView(isApproaching: isApproaching, themeColor: themeColor)
                    }
                    
                    if let alvo = state.alvo, !alvo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        DeviceBadgeView(item: alvo, themeColor: themeColor, size: 24)
                    }
                }
                
                Spacer()
                
                if let dist = state.distancia, !dist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(themeColor)
                        Text(dist)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(UIColor.tertiarySystemGroupedBackground))
                    )
                }
            }
            
            if let execucaoId = state.execucaoId, !execucaoId.isEmpty {
                if #available(iOS 17.0, *) {
                    Button(intent: ConfirmBipeIntent(execucaoId: execucaoId)) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 15, weight: .bold))
                            Text(String(localized: "CONFIRMAR RECEBIMENTO"))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(LinearGradient(colors: [Color.green, Color(red: 0.15, green: 0.70, blue: 0.35)], startPoint: .leading, endPoint: .trailing))
                        )
                        .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                } else {
                    Link(destination: URL(string: "bipe://confirm?execucaoId=\(execucaoId)")!) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 15, weight: .bold))
                            Text(String(localized: "CONFIRMAR RECEBIMENTO"))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(LinearGradient(colors: [Color.green, Color(red: 0.15, green: 0.70, blue: 0.35)], startPoint: .leading, endPoint: .trailing))
                        )
                        .foregroundColor(.white)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(themeColor.opacity(0.3), lineWidth: 1.5)
                )
        )
        .activityBackgroundTint(Color(UIColor.systemBackground))
        .activitySystemActionForegroundColor(Color.primary)
    }
}

// MARK: - View para Evento de Rotina ("routine") - Compact UI

@available(iOS 16.1, *)
struct RoutineWidgetView: View {
    let state: BipeAlertActivityAttributes.ContentState
    
    var themeColor: Color {
        Color(red: 0.55, green: 0.27, blue: 0.80) // Purple theme for routine
    }
    
    var deviceIcon: String {
        if let icon = state.icon, !icon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return icon
        }
        if let iconUrl = state.iconUrl, !iconUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return iconUrl
        }
        return "logo"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // MARK: Header com ícone do device e badge ROTINA
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [themeColor.opacity(0.3), themeColor.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .overlay(
                            Circle()
                                .stroke(themeColor.opacity(0.4), lineWidth: 1.5)
                        )
                    
                    DeviceBadgeView(item: deviceIcon, themeColor: themeColor, size: 34)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.nickname)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(state.way ?? "")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        
                    if let prev = state.previousEvent, !prev.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("\(String(localized: "Último evento:")) \(prev)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary.opacity(0.8))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Badge ROTINA
                HStack(spacing: 5) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.system(size: 11, weight: .bold))
                    Text(String(localized: "ROTINA"))
                        .font(.system(size: 11, weight: .black, design: .rounded))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(themeColor.opacity(0.18))
                )
                .overlay(
                    Capsule()
                        .stroke(themeColor.opacity(0.4), lineWidth: 1.2)
                )
                .foregroundColor(themeColor)
            }
            
            // MARK: Info card
            HStack(spacing: 8) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(themeColor)
                Text(state.address)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(themeColor.opacity(0.08))
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(themeColor.opacity(0.3), lineWidth: 1.5)
                )
        )
        .activityBackgroundTint(Color(UIColor.systemBackground))
        .activitySystemActionForegroundColor(Color.primary)
    }
}

// MARK: - Live Activity Widget Principal

@available(iOS 16.1, *)
public struct BipeWidgetExtensionLiveActivity: Widget {
    public init() {}
    
    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: BipeAlertActivityAttributes.self) { context in
            let st = context.state.status.lowercased()
            let act = context.state.activityType?.lowercased() ?? ""
            let ev = context.state.event?.lowercased() ?? ""
            
            let isBipe = act == "bipe" || act == "bipe_alert" || st == "bipe" || st == "bipe_alert" || ev == "bipe" || ev == "bipe_alert"
            let isEmergency = isBipe || act.contains("emergency") || st.contains("emergency") || st.contains("emergencia") || st.contains("emergência")
            let isRoutine = !isEmergency && (act.contains("routine") || act.contains("rotina") || st.contains("routine") || st.contains("rotina") || ev.contains("routine") || ev.contains("rotina"))
            let hasValidTarget = (context.state.target != nil && !(context.state.target?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true))
            let isDistance = !isEmergency && !isRoutine && (act.contains("distance") || st.contains("distance") || hasValidTarget || ev.contains("aproxim") || ev.contains("afast"))
            let isTransition = !isEmergency && !isDistance && !isRoutine
            let isActive = ev.contains("active") || ev.contains("active")
            
            Group {
                if isEmergency {
                    EmergencyWidgetView(state: context.state)
                } else if isRoutine {
                    RoutineWidgetView(state: context.state)
                } else if isDistance {
                    DistanceWidgetView(state: context.state)
                } else {
                    TransitionWidgetView(state: context.state)
                }
            }
            .widgetURL(URL(string: "bipe://activity-history"))
        } dynamicIsland: { context in
            let st = context.state.status.lowercased()
            let act = context.state.activityType?.lowercased() ?? ""
            let ev = context.state.event?.lowercased() ?? ""
            
            let isBipe = act == "bipe" || act == "bipe_alert" || st == "bipe" || st == "bipe_alert" || ev == "bipe" || ev == "bipe_alert"
            let isEmergency = isBipe || act.contains("emergency") || st.contains("emergency") || st.contains("emergencia") || st.contains("emergência")
            let isRoutine = !isEmergency && (act.contains("routine") || act.contains("rotina") || st.contains("routine") || st.contains("rotina") || ev.contains("routine") || ev.contains("rotina"))
            let hasValidTarget = (context.state.target != nil && !(context.state.target?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true))
            let isDistance = !isEmergency && !isRoutine && (act.contains("distance") || st.contains("distance") || hasValidTarget || ev.contains("aproxim") || ev.contains("afast"))
            let isTransition = !isEmergency && !isDistance && !isRoutine
            
            let isExit = ev.contains("exit") || ev.contains("leave") || ev.contains("left") || ev.contains("saida") || ev.contains("saída") || ev.contains("saiu") || ev.contains("out") ||
                         st.contains("exit") || st.contains("leave") || st.contains("left") || st.contains("saida") || st.contains("saída") || st.contains("saiu") || st.contains("out")
            let isApproaching = ev.contains("aproxim") || st.contains("aproxim")
            let isMove = ev.contains("move") || ev.contains("movimento") || st.contains("move") || st.contains("movimento")
            
            let routineThemeColor = Color(red: 0.55, green: 0.27, blue: 0.80)
            let defaultThemeColor: Color = isRoutine ? routineThemeColor : (isEmergency ? .orange : (isDistance ? (isApproaching ? Color(red: 0.18, green: 0.80, blue: 0.44) : .orange) : (isTransition ? (isExit ? .orange : (isMove ? .blue : Color(red: 0.18, green: 0.80, blue: 0.44))) : .orange)))
            let themeColor: Color = context.state.insecure == true ? .red : defaultThemeColor
            let regionName = context.state.way ?? context.state.address
            let devicesList = context.state.devices ?? []
            let isActive = ev.contains("active") || ev.contains("active")
            
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        if isDistance {
                            HStack(spacing: 4) {
                                if let target = context.state.target, !target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    DeviceBadgeView(item: target, themeColor: themeColor)
                                }
                                if let target = context.state.target, !target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                                   let alvo = context.state.alvo, !alvo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    DistanceDirectionSeparatorView(isApproaching: isApproaching, themeColor: themeColor, fontSize: 10)
                                }
                                if let alvo = context.state.alvo, !alvo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    DeviceBadgeView(item: alvo, themeColor: themeColor)
                                }
                            }
                            let triggerIcon = (context.state.icon != nil && !context.state.icon!.isEmpty) ? context.state.icon! : ((context.state.iconUrl != nil && !context.state.iconUrl!.isEmpty) ? context.state.iconUrl! : "logo")
                            DeviceBadgeView(item: triggerIcon, themeColor: themeColor)
                            if !regionName.lowercased().contains("monitora") {
                                Text(regionName)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            } else {
                                Text(context.state.nickname)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            }
                        } else if isRoutine {
                            let routineIcon = (context.state.icon != nil && !context.state.icon!.isEmpty) ? context.state.icon! : ((context.state.iconUrl != nil && !context.state.iconUrl!.isEmpty) ? context.state.iconUrl! : "logo")
                            DeviceBadgeView(item: routineIcon, themeColor: themeColor)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(context.state.nickname)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text(context.state.address)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        } else {
                            let triggerIcon = (context.state.icon != nil && !context.state.icon!.isEmpty) ? context.state.icon! : ((context.state.iconUrl != nil && !context.state.iconUrl!.isEmpty) ? context.state.iconUrl! : "logo")
                            DeviceBadgeView(item: triggerIcon, themeColor: .orange, size: 28)
                        }
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    if isDistance {
                        Text(isApproaching ? "APROXIMOU" : "AFASTOU")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(themeColor))
                            .foregroundColor(.black)
                    } else if isTransition && !isActive {
                        HStack(spacing: 4) {
                            Image(systemName: isExit ? "arrow.left.to.line.compact" : (isMove ? "location.fill" : "arrow.right.to.line.compact"))
                                .font(.system(size: 10, weight: .bold))
                            Text(isExit ? LocalizedStringKey("SAIU") : (isMove ? LocalizedStringKey("MOVEU") : LocalizedStringKey("ENTROU")))
                                .font(.system(size: 11, weight: .black, design: .rounded))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(themeColor))
                        .foregroundColor(.black)
                    } else if isActive {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10, weight: .bold))
                            Text(String(localized: "ATIVO"))
                                .font(.system(size: 11, weight: .black, design: .rounded))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(themeColor))
                        .foregroundColor(.black)
                    } else if isRoutine {
                        HStack(spacing: 5) {
                            Image(systemName: "clock.badge.exclamationmark")
                                .font(.system(size: 10, weight: .bold))
                            Text(String(localized: "ROTINA"))
                                .font(.system(size: 11, weight: .black, design: .rounded))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(themeColor))
                        .foregroundColor(.white)
                    } else {
                        let st = context.state.status.lowercased()
                        let emergencyStatusText = (st == "start" || st == "emergency" || st == "emergencia" || st == "emergência" || st == "bipe" || st == "bipe_alert" || st.isEmpty) ? "ATENÇÃO" : context.state.status.uppercased()
                        Text(emergencyStatusText)
                            .font(.caption2)
                            .fontWeight(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.orange))
                            .foregroundColor(.white)
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    if isDistance {
                        if let dist = context.state.distancia {
                            HStack(spacing: 6) {
                                Image(systemName: "location.fill")
                                    .font(.footnote)
                                    .foregroundColor(themeColor)
                                Text("\(String(localized: "Distância:")) \(dist)")
                                    .font(.footnote)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            .padding(.top, 4)
                        }
                        
                        if let execucaoId = context.state.execucaoId, !execucaoId.isEmpty {
                            if #available(iOS 17.0, *) {
                                Button(intent: ConfirmBipeIntent(execucaoId: execucaoId)) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 13, weight: .bold))
                                        Text(String(localized: "CONFIRMAR RECEBIMENTO"))
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(LinearGradient(colors: [Color.green, Color(red: 0.15, green: 0.70, blue: 0.35)], startPoint: .leading, endPoint: .trailing)))
                                    .foregroundColor(.white)
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 4)
                            } else {
                                Link(destination: URL(string: "bipe://confirm?execucaoId=\(execucaoId)")!) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 13, weight: .bold))
                                        Text(String(localized: "CONFIRMAR RECEBIMENTO"))
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(LinearGradient(colors: [Color.green, Color(red: 0.15, green: 0.70, blue: 0.35)], startPoint: .leading, endPoint: .trailing)))
                                    .foregroundColor(.white)
                                }
                                .padding(.top, 4)
                            }
                        }
                    } else if isRoutine {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.badge.exclamationmark")
                                .font(.footnote)
                                .foregroundColor(themeColor)
                            Text(String(localized: "Rotina não atendida"))
                                .font(.footnote)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        .padding(.top, 4)
                    } else if isTransition {
                        if !devicesList.isEmpty {
                            HStack(spacing: 8) {
                                ForEach(devicesList.prefix(8), id: \.self) { dev in
                                    DeviceBadgeView(item: dev, themeColor: themeColor)
                                }
                                
                                if devicesList.count > 8 {
                                    Text("+\(devicesList.count - 8)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(themeColor)
                                }
                            }
                            .padding(.top, 4)
                        } else {
                            HStack(spacing: 6) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.footnote)
                                    .foregroundColor(themeColor)
                                Text(regionName)
                                    .font(.footnote)
                                    .foregroundColor(.white)
                            }
                            .padding(.top, 4)
                        }
                    } else {
                        VStack(spacing: 6) {
                            HStack(alignment: .center, spacing: 6) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.orange)
                                
                                Text(context.state.address)
                                    .font(.footnote)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                            }
                            
                            let isBipeAlert = context.state.status.lowercased() == "bipe" || context.state.status.lowercased() == "bipe_alert" || context.state.activityType?.lowercased() == "bipe" || context.state.activityType?.lowercased() == "bipe_alert" || context.state.event?.lowercased() == "bipe" || context.state.event?.lowercased() == "bipe_alert"
                            let isConfirmed = context.state.status.lowercased() == "confirmado"
                            if isBipeAlert && !isConfirmed {
                                if #available(iOS 17.0, *) {
                                    Button(intent: ConfirmBipeIntent(execucaoId: context.state.execucaoId)) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 13, weight: .bold))
                                            Text(String(localized: "CONFIRMAR BIPE"))
                                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 6)
                                        .background(Capsule().fill(LinearGradient(colors: [Color.green, Color(red: 0.15, green: 0.70, blue: 0.35)], startPoint: .leading, endPoint: .trailing)))
                                        .foregroundColor(.white)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    Link(destination: URL(string: "bipe://confirm?execucaoId=\(context.state.execucaoId ?? "")")!) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 13, weight: .bold))
                                            Text(String(localized: "CONFIRMAR BIPE"))
                                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 6)
                                        .background(Capsule().fill(LinearGradient(colors: [Color.green, Color(red: 0.15, green: 0.70, blue: 0.35)], startPoint: .leading, endPoint: .trailing)))
                                        .foregroundColor(.white)
                                    }
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            } compactLeading: {
                if isDistance {
                    if let firstDev = devicesList.first, !firstDev.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        DeviceBadgeView(item: firstDev, themeColor: themeColor)
                    } else {
                        Image(systemName: isApproaching ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .foregroundColor(themeColor)
                    }
                } else if isRoutine {
                    let routineIcon = (context.state.icon != nil && !context.state.icon!.isEmpty) ? context.state.icon! : ((context.state.iconUrl != nil && !context.state.iconUrl!.isEmpty) ? context.state.iconUrl! : "logo")
                    DeviceBadgeView(item: routineIcon, themeColor: themeColor)
                } else if isTransition {
                    Image(systemName: isExit ? "arrow.left.circle.fill" : (isMove ? "location.circle.fill" : "arrow.right.circle.fill"))
                        .foregroundColor(themeColor)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                }
            } compactTrailing: {
                if isDistance {
                    if let dist = context.state.distancia {
                        Text(dist)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(themeColor)
                    } else {
                        Text(isApproaching ? "APROX" : "AFAST")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(themeColor)
                    }
                } else {
                    if let firstDev = devicesList.first {
                        DeviceBadgeView(item: firstDev, themeColor: themeColor)
                    } else {
                        let triggerIcon = (context.state.icon != nil && !context.state.icon!.isEmpty) ? context.state.icon! : ((context.state.iconUrl != nil && !context.state.iconUrl!.isEmpty) ? context.state.iconUrl! : "logo")
                        DeviceBadgeView(item: triggerIcon, themeColor: themeColor, size: 20)
                    }
                }
            } minimal: {
                if isDistance {
                    if let firstDev = devicesList.first, !firstDev.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        DeviceBadgeView(item: firstDev, themeColor: themeColor)
                    } else {
                        Image(systemName: isApproaching ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .foregroundColor(themeColor)
                    }
                } else if isRoutine {
                    Image(systemName: "clock.badge.exclamationmark")
                        .foregroundColor(themeColor)
                } else if isTransition {
                    if let firstDev = devicesList.first {
                        DeviceBadgeView(item: firstDev, themeColor: themeColor)
                    } else {
                        Image(systemName: isExit ? "arrow.left.circle.fill" : (isMove ? "location.circle.fill" : "arrow.right.circle.fill"))
                            .foregroundColor(themeColor)
                    }
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                }
            }
            .keylineTint(themeColor)
            .widgetURL(URL(string: "bipe://activity-history"))
        }
    }
}

