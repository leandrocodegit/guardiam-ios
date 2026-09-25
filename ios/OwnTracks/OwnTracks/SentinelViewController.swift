//
//  SentinelViewController.swift
//  OwnTracks
//
//  Tela nativa do Modo Sentinela (Monitor Acústico Passivo On-Device)
//  Segurança preventiva com privacidade total (RAM apenas) e tolerância zero a falso positivo.
//  Permite cadastrar até 3 contatos de confiança para notificação em caso de emergência.
//

import UIKit
import AVFoundation
import ContactsUI

class SentinelPaddingLabel: UILabel {
    var textInsets = UIEdgeInsets(top: 2, left: 8, bottom: 2, right: 8)
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: textInsets))
    }
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + textInsets.left + textInsets.right,
                      height: size.height + textInsets.top + textInsets.bottom)
    }
}

@objc class SentinelViewController: UIViewController {

    // MARK: - UI Components

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.showsVerticalScrollIndicator = true
        return sv
    }()

    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // Header Shield Icon
    private let shieldImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        if #available(iOS 13.0, *), let img = UIImage(systemName: "shield.lefthalf.filled") {
            iv.image = img
        } else {
            iv.image = UIImage(named: "OwnTracks-320.png")
        }
        iv.tintColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Modo Sentinela", comment: "")
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Monitoramento acústico preventivo on-device. Identifica ruídos anormais de impacto ou emergência sem gravar ou transmitir áudio.", comment: "")
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = UIColor(red: 160/255, green: 175/255, blue: 180/255, alpha: 1.0)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    // MARK: - Emergency Callout Banner (Risco Iminente)
    private let emergencyBannerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 48/255, green: 16/255, blue: 20/255, alpha: 1.0)
        view.layer.cornerRadius = 14
        view.layer.borderWidth = 1.2
        view.layer.borderColor = UIColor(red: 239/255, green: 68/255, blue: 68/255, alpha: 0.85).cgColor
        return view
    }()

    private let emergencyBannerIconView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        if #available(iOS 13.0, *), let img = UIImage(systemName: "exclamationmark.triangle.fill") {
            iv.image = img
        }
        iv.tintColor = UIColor(red: 239/255, green: 68/255, blue: 68/255, alpha: 1.0)
        return iv
    }()

    private let emergencyBannerTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("EM RISCO IMINENTE?", comment: "")
        label.font = .systemFont(ofSize: 13, weight: .black)
        label.textColor = UIColor(red: 252/255, green: 165/255, blue: 165/255, alpha: 1.0)
        return label
    }()

    private let emergencyBannerTextLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Se você estiver sofrendo perigo ou ameaça imediata, NÃO aguarde o monitoramento acústico. Acione imediatamente os serviços de emergência locais de sua região ou use o SOS de Emergência do iPhone.", comment: "")
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = UIColor(red: 229/255, green: 231/255, blue: 235/255, alpha: 1.0)
        label.numberOfLines = 0
        return label
    }()

    // Status & Switch Card
    private let statusCardView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 22/255, green: 34/255, blue: 38/255, alpha: 1.0)
        view.layer.cornerRadius = 16
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor(red: 35/255, green: 53/255, blue: 59/255, alpha: 1.0).cgColor
        return view
    }()

    private let statusDotView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 6
        view.backgroundColor = .gray
        return view
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Monitoramento Inativo", comment: "")
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .white
        return label
    }()

    private let toggleSwitch: UISwitch = {
        let sw = UISwitch()
        sw.translatesAutoresizingMaskIntoConstraints = false
        sw.onTintColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        return sw
    }()

    // Live Decibel VU Meter Card
    private let meterCardView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 22/255, green: 34/255, blue: 38/255, alpha: 1.0)
        view.layer.cornerRadius = 16
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor(red: 35/255, green: 53/255, blue: 59/255, alpha: 1.0).cgColor
        return view
    }()

    private let meterTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Nível Acústico em Tempo Real", comment: "")
        label.font = .systemFont(ofSize: 15, weight: .bold)
        label.textColor = .white
        return label
    }()

    private let dbValueLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "-- dB"
        label.font = .systemFont(ofSize: 28, weight: .heavy)
        label.textColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        return label
    }()

    private let progressTrackView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 35/255, green: 53/255, blue: 59/255, alpha: 1.0)
        view.layer.cornerRadius = 6
        view.clipsToBounds = true
        return view
    }()

    private let progressBarView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        view.layer.cornerRadius = 6
        return view
    }()
    private var progressBarWidthConstraint: NSLayoutConstraint?
    private var aiCardTopToGraceConstraint: NSLayoutConstraint?
    private var aiCardTopToMeterConstraint: NSLayoutConstraint?

    private let thresholdMarkerLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = String(format: NSLocalizedString("Limiar de Gatilho: %.0f dB", comment: ""), 75.0)
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = UIColor(red: 160/255, green: 175/255, blue: 180/255, alpha: 1.0)
        return label
    }()

    // Grace Period Countdown Alert Card (Visible when in countdown)
    private let gracePeriodCardView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 70/255, green: 20/255, blue: 25/255, alpha: 1.0)
        view.layer.cornerRadius = 16
        view.layer.borderWidth = 1.5
        view.layer.borderColor = UIColor(red: 239/255, green: 68/255, blue: 68/255, alpha: 1.0).cgColor
        view.isHidden = true
        return view
    }()

    private let graceCountdownLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "10s"
        label.font = .systemFont(ofSize: 34, weight: .black)
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        label.textColor = UIColor(red: 239/255, green: 68/255, blue: 68/255, alpha: 1.0)
        label.textAlignment = .center
        return label
    }()

    private let graceReasonContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 45/255, green: 10/255, blue: 15/255, alpha: 0.95)
        view.layer.cornerRadius = 10
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor(red: 239/255, green: 68/255, blue: 68/255, alpha: 0.8).cgColor
        return view
    }()

    private let graceReasonLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("🚨 DETECÇÃO ATIVADA", comment: "")
        label.font = .systemFont(ofSize: 13, weight: .bold)
        label.textColor = UIColor(red: 254/255, green: 202/255, blue: 202/255, alpha: 1.0)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let graceDescriptionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Alerta de emergência e localização serão enviados aos contatos se não houver cancelamento.", comment: "")
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = UIColor(red: 229/255, green: 231/255, blue: 235/255, alpha: 1.0)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let cancelGraceButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setTitle(NSLocalizedString("Falso Alarme (Cancelar)", comment: ""), for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        btn.backgroundColor = UIColor(red: 239/255, green: 68/255, blue: 68/255, alpha: 1.0)
        btn.layer.cornerRadius = 12
        return btn
    }()

    // MARK: - AI On-Device Intelligence Card
    private let aiCardView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 22/255, green: 34/255, blue: 38/255, alpha: 1.0)
        view.layer.cornerRadius = 16
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor(red: 35/255, green: 53/255, blue: 59/255, alpha: 1.0).cgColor
        return view
    }()

    private let aiIconView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        if #available(iOS 13.0, *), let img = UIImage(systemName: "sparkles") {
            iv.image = img
        }
        iv.tintColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        return iv
    }()

    private let aiTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Detecção Inteligente On-Device", comment: "")
        label.font = .systemFont(ofSize: 15, weight: .bold)
        label.textColor = .white
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }()

    private let aiBadgeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("100% no Aparelho", comment: "")
        label.font = .systemFont(ofSize: 11, weight: .bold)
        label.textColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        label.backgroundColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 0.15)
        label.layer.cornerRadius = 6
        label.layer.masksToBounds = true
        label.textAlignment = .center
        return label
    }()

    private let aiSubtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Rede neural local que analisa o espectro sonoro e fonemas em tempo real sem transmitir conversas:", comment: "")
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = UIColor(red: 160/255, green: 175/255, blue: 180/255, alpha: 1.0)
        label.numberOfLines = 0
        return label
    }()

    private let aiBadgesStackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 8
        stack.distribution = .fill
        return stack
    }()

    // MARK: - Voice Profile & Unknown Voice Card
    private let voiceCardView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 22/255, green: 34/255, blue: 38/255, alpha: 1.0)
        view.layer.cornerRadius = 16
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor(red: 35/255, green: 53/255, blue: 59/255, alpha: 1.0).cgColor
        return view
    }()

    private let voiceIconView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        if #available(iOS 13.0, *), let img = UIImage(systemName: "mic.badge.plus") ?? UIImage(systemName: "waveform.path.ecg") {
            iv.image = img
        }
        iv.tintColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        return iv
    }()

    private let voiceTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Perfil Vocal & Vozes Externas", comment: "")
        label.font = .systemFont(ofSize: 15, weight: .bold)
        label.textColor = .white
        return label
    }()

    private let voiceBadgeLabel: SentinelPaddingLabel = {
        let label = SentinelPaddingLabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Não Calibrada", comment: "")
        label.font = .systemFont(ofSize: 11, weight: .bold)
        label.textColor = UIColor(red: 245/255, green: 158/255, blue: 11/255, alpha: 1.0)
        label.backgroundColor = UIColor(red: 245/255, green: 158/255, blue: 11/255, alpha: 0.15)
        label.layer.cornerRadius = 6
        label.layer.masksToBounds = true
        label.textAlignment = .center
        return label
    }()

    private let voiceSubtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Calibre a frequência fundamental da sua voz (F0 Pitch) para identificar quando uma voz diferente ou externa estiver falando no ambiente.", comment: "")
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = UIColor(red: 160/255, green: 175/255, blue: 180/255, alpha: 1.0)
        label.numberOfLines = 0
        return label
    }()

    private let calibrateVoiceButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setTitle(NSLocalizedString("Calibrar Assinatura Vocal (4.5s)", comment: ""), for: .normal)
        btn.setTitleColor(UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0), for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
        btn.titleLabel?.adjustsFontSizeToFitWidth = true
        btn.titleLabel?.minimumScaleFactor = 0.85
        btn.backgroundColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 0.1)
        btn.layer.cornerRadius = 10
        btn.layer.borderWidth = 1
        btn.layer.borderColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 0.3).cgColor
        return btn
    }()

    private let voiceDividerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 35/255, green: 53/255, blue: 59/255, alpha: 1.0)
        return view
    }()

    private let unknownVoiceTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Alerta de Voz Externa / Desconhecida", comment: "")
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .white
        label.numberOfLines = 0
        return label
    }()

    private let unknownVoiceSubtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Dispara emergência se uma voz de outra pessoa for detectada continuadamente.", comment: "")
        label.font = .systemFont(ofSize: 11, weight: .regular)
        label.textColor = UIColor(red: 160/255, green: 175/255, blue: 180/255, alpha: 1.0)
        label.numberOfLines = 0
        return label
    }()

    private let unknownVoiceSwitch: UISwitch = {
        let sw = UISwitch()
        sw.translatesAutoresizingMaskIntoConstraints = false
        sw.onTintColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        return sw
    }()

    // MARK: - Custom Distress Keywords Card (Até 3 frases)
    private let keywordsCardView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 22/255, green: 34/255, blue: 38/255, alpha: 1.0)
        view.layer.cornerRadius = 16
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor(red: 35/255, green: 53/255, blue: 59/255, alpha: 1.0).cgColor
        return view
    }()

    private let keywordsIconView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        if #available(iOS 13.0, *), let img = UIImage(systemName: "quote.bubble.fill") {
            iv.image = img
        }
        iv.tintColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        return iv
    }()

    private let keywordsTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Frases de Alerta Personalizadas", comment: "")
        label.font = .systemFont(ofSize: 15, weight: .bold)
        label.textColor = .white
        return label
    }()

    private let keywordsBadgeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "0/10"
        label.font = .systemFont(ofSize: 12, weight: .bold)
        label.textColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        label.backgroundColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 0.15)
        label.layer.cornerRadius = 6
        label.layer.masksToBounds = true
        label.textAlignment = .center
        return label
    }()

    private let keywordsSubtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Cadastre até 10 frases ou palavras-código personalizadas que ativarão o Sentinela se ouvidas pelo celular.", comment: "")
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = UIColor(red: 160/255, green: 175/255, blue: 180/255, alpha: 1.0)
        label.numberOfLines = 0
        return label
    }()

    private let keywordsStackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 8
        stack.distribution = .fill
        return stack
    }()

    private let addKeywordButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setTitle(NSLocalizedString("+ Adicionar Frase Personalizada", comment: ""), for: .normal)
        btn.setTitleColor(UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0), for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
        btn.backgroundColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 0.1)
        btn.layer.cornerRadius = 10
        btn.layer.borderWidth = 1
        btn.layer.borderColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 0.3).cgColor
        return btn
    }()

    // MARK: - Trusted Contacts Card
    private let contactsCardView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 22/255, green: 34/255, blue: 38/255, alpha: 1.0)
        view.layer.cornerRadius = 16
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor(red: 35/255, green: 53/255, blue: 59/255, alpha: 1.0).cgColor
        return view
    }()

    private let contactsIconView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        if #available(iOS 13.0, *), let img = UIImage(systemName: "person.2.fill") {
            iv.image = img
        }
        iv.tintColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        return iv
    }()

    private let contactsTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Contatos de Confiança", comment: "")
        label.font = .systemFont(ofSize: 15, weight: .bold)
        label.textColor = .white
        return label
    }()

    private let contactsBadgeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "0/3"
        label.font = .systemFont(ofSize: 12, weight: .bold)
        label.textColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        label.backgroundColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 0.15)
        label.layer.cornerRadius = 6
        label.layer.masksToBounds = true
        label.textAlignment = .center
        return label
    }()

    private let contactsSubtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Cadastre até 3 contatos para serem notificados com suas coordenadas em caso de incidente.", comment: "")
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = UIColor(red: 160/255, green: 175/255, blue: 180/255, alpha: 1.0)
        label.numberOfLines = 0
        return label
    }()

    private let contactsStackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 8
        stack.distribution = .fill
        return stack
    }()

    private let addContactButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setTitle(NSLocalizedString("+ Adicionar Contato de Confiança", comment: ""), for: .normal)
        btn.setTitleColor(UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0), for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
        btn.backgroundColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 0.1)
        btn.layer.cornerRadius = 10
        btn.layer.borderWidth = 1
        btn.layer.borderColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 0.3).cgColor
        return btn
    }()

    // MARK: - Guidelines Card (Ambiente Silencioso & Consumo de Bateria)
    private let guidelinesCardView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 22/255, green: 34/255, blue: 38/255, alpha: 1.0)
        view.layer.cornerRadius = 16
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor(red: 35/255, green: 53/255, blue: 59/255, alpha: 1.0).cgColor
        return view
    }()

    private let guidelinesTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Orientações de Uso Consciente", comment: "")
        label.font = .systemFont(ofSize: 15, weight: .bold)
        label.textColor = .white
        return label
    }()

    private let silentIconView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        if #available(iOS 13.0, *), let img = UIImage(systemName: "moon.stars.fill") {
            iv.image = img
        }
        iv.tintColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        return iv
    }()

    private let silentTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Momento Oportuno e Silencioso", comment: "")
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = UIColor(red: 94/255, green: 234/255, blue: 212/255, alpha: 1.0)
        return label
    }()

    private let silentDescLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Ative preferencialmente ao dormir, repousar ou em locais calmos. Evite locais com muito barulho (TV alta, festas, trânsito intenso) para não gerar falsos disparos com ruídos comuns do dia a dia.", comment: "")
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = UIColor(red: 160/255, green: 175/255, blue: 180/255, alpha: 1.0)
        label.numberOfLines = 0
        return label
    }()

    private let batteryIconView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        if #available(iOS 13.0, *), let img = UIImage(systemName: "battery.75") {
            iv.image = img
        }
        iv.tintColor = UIColor(red: 250/255, green: 204/255, blue: 21/255, alpha: 1.0)
        return iv
    }()

    private let batteryTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Consumo de Bateria & Salvaguarda", comment: "")
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = UIColor(red: 253/255, green: 224/255, blue: 71/255, alpha: 1.0)
        return label
    }()

    private let batteryDescLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("A escuta contínua pelo microfone consome energia adicional. Recomendamos manter o iPhone conectado à tomada (especialmente à noite). O aplicativo pausa o monitoramento automaticamente se a bateria atingir 15% desconectada.", comment: "")
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = UIColor(red: 160/255, green: 175/255, blue: 180/255, alpha: 1.0)
        label.numberOfLines = 0
        return label
    }()

    // Threshold Slider Card
    private let sliderCardView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 22/255, green: 34/255, blue: 38/255, alpha: 1.0)
        view.layer.cornerRadius = 16
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor(red: 35/255, green: 53/255, blue: 59/255, alpha: 1.0).cgColor
        return view
    }()

    private let impactsIconView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        if #available(iOS 13.0, *), let img = UIImage(systemName: "burst.fill") ?? UIImage(systemName: "waveform") {
            iv.image = img
        }
        iv.tintColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        return iv
    }()

    private let impactsTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Detectar Impactos", comment: "")
        label.font = .systemFont(ofSize: 15, weight: .bold)
        label.textColor = .white
        return label
    }()

    private let impactsSwitch: UISwitch = {
        let sw = UISwitch()
        sw.translatesAutoresizingMaskIntoConstraints = false
        sw.onTintColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        sw.isOn = true
        return sw
    }()

    private let impactsSubtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Desative para usar em ambientes barulhentos. Ignora picos de volume e estilhaços físicos, mantendo ativas palavras de socorro e gritos.", comment: "")
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = UIColor(red: 160/255, green: 175/255, blue: 180/255, alpha: 1.0)
        label.numberOfLines = 0
        return label
    }()

    private let impactsDividerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 35/255, green: 53/255, blue: 59/255, alpha: 1.0)
        return view
    }()

    private let sliderTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Sensibilidade do Limiar (dB)", comment: "")
        label.font = .systemFont(ofSize: 15, weight: .bold)
        label.textColor = .white
        return label
    }()

    private let sliderCurrentValueLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "75 dB"
        label.font = .systemFont(ofSize: 15, weight: .bold)
        label.textColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        return label
    }()

    private let thresholdSlider: UISlider = {
        let slider = UISlider()
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.minimumValue = 60.0
        slider.maximumValue = 95.0
        slider.value = 75.0
        slider.minimumTrackTintColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        slider.maximumTrackTintColor = UIColor(red: 35/255, green: 53/255, blue: 59/255, alpha: 1.0)
        return slider
    }()

    private let repeatImpactsDividerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 35/255, green: 53/255, blue: 59/255, alpha: 1.0)
        return view
    }()

    private let repeatImpactsTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Gatilho de Impactos Repetidos (Pessoas Não-Verbais)", comment: "")
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .white
        return label
    }()

    private let repeatImpactsSubtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Em modo de espera, dispara emergência automaticamente ao detectar a quantidade selecionada de impactos, sem exigir confirmação vocal.", comment: "")
        label.font = .systemFont(ofSize: 11, weight: .regular)
        label.textColor = UIColor(red: 160/255, green: 175/255, blue: 180/255, alpha: 1.0)
        label.numberOfLines = 0
        return label
    }()

    private let repeatImpactsSegmentedControl: UISegmentedControl = {
        let sc = UISegmentedControl(items: [
            NSLocalizedString("2 Impactos", comment: ""),
            NSLocalizedString("3 (Padrão)", comment: ""),
            NSLocalizedString("4 Impactos", comment: ""),
            NSLocalizedString("5 Impactos", comment: "")
        ])
        sc.translatesAutoresizingMaskIntoConstraints = false
        sc.selectedSegmentIndex = 1
        sc.selectedSegmentTintColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        let normalAttr: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 11, weight: .medium)]
        let selectedAttr: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.black, .font: UIFont.systemFont(ofSize: 11, weight: .bold)]
        sc.setTitleTextAttributes(normalAttr, for: .normal)
        sc.setTitleTextAttributes(selectedAttr, for: .selected)
        return sc
    }()

    private let attentionWindowDividerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 35/255, green: 53/255, blue: 59/255, alpha: 1.0)
        return view
    }()

    private let attentionWindowTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Janela de Tempo em Espera", comment: "")
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .white
        return label
    }()

    private let attentionWindowSubtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Tempo limite em modo de atenção aguardando confirmação por voz ou novos impactos antes de cancelar o alerta.", comment: "")
        label.font = .systemFont(ofSize: 11, weight: .regular)
        label.textColor = UIColor(red: 160/255, green: 175/255, blue: 180/255, alpha: 1.0)
        label.numberOfLines = 0
        return label
    }()

    private let attentionWindowSegmentedControl: UISegmentedControl = {
        let sc = UISegmentedControl(items: [
            NSLocalizedString("1 min (Padrão)", comment: ""),
            NSLocalizedString("5 min", comment: ""),
            NSLocalizedString("10 min", comment: ""),
            NSLocalizedString("20 min", comment: ""),
            NSLocalizedString("30 min", comment: "")
        ])
        sc.translatesAutoresizingMaskIntoConstraints = false
        sc.selectedSegmentIndex = 0
        sc.selectedSegmentTintColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        let normalAttr: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 11, weight: .medium)]
        let selectedAttr: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.black, .font: UIFont.systemFont(ofSize: 11, weight: .bold)]
        sc.setTitleTextAttributes(normalAttr, for: .normal)
        sc.setTitleTextAttributes(selectedAttr, for: .selected)
        return sc
    }()

    // Privacy Banner Card
    private let privacyCardView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 17/255, green: 27/255, blue: 30/255, alpha: 1.0)
        view.layer.cornerRadius = 14
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor(red: 28/255, green: 44/255, blue: 49/255, alpha: 1.0).cgColor
        return view
    }()

    private let privacyIconView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        if #available(iOS 13.0, *), let img = UIImage(systemName: "lock.shield.fill") {
            iv.image = img
        }
        iv.tintColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        return iv
    }()

    private let privacyTextLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Zero Cloud Audio: Toda a análise acústica ocorre 100% na memória RAM local do aparelho. Nenhum áudio bruto é gravado em disco ou transmitido para servidores.", comment: "")
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = UIColor(red: 160/255, green: 175/255, blue: 180/255, alpha: 1.0)
        label.numberOfLines = 0
        return label
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigation()
        setupUI()
        setupActions()
        configureCallbacks()
        syncStateWithMonitor()
        refreshContactsUI()
        refreshKeywordsUI()
        refreshVoiceProfileUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        syncStateWithMonitor()
        refreshContactsUI()
        refreshKeywordsUI()
        refreshVoiceProfileUI()
    }

    deinit {
        SentinelAcousticMonitor.shared.onStateChange = nil
        SentinelAcousticMonitor.shared.onDecibelUpdate = nil
        SentinelAcousticMonitor.shared.onGracePeriodTick = nil
        SentinelAcousticMonitor.shared.onIntelligentDetection = nil
    }

    // MARK: - Setup Navigation

    private func setupNavigation() {
        title = NSLocalizedString("Modo Sentinela", comment: "")
        navigationController?.navigationBar.barTintColor = UIColor(red: 11/255, green: 18/255, blue: 20/255, alpha: 1.0)
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]

        let closeBtn = UIBarButtonItem(title: NSLocalizedString("Fechar", comment: ""), style: .done, target: self, action: #selector(closeTapped))
        closeBtn.tintColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        navigationItem.rightBarButtonItem = closeBtn
    }

    @objc private func closeTapped() {
        dismiss(animated: true, completion: nil)
    }

    // MARK: - UI Layout

    private func setupUI() {
        view.backgroundColor = UIColor(red: 11/255, green: 18/255, blue: 20/255, alpha: 1.0)

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        contentView.addSubview(shieldImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(emergencyBannerView)
        contentView.addSubview(statusCardView)
        contentView.addSubview(meterCardView)
        contentView.addSubview(gracePeriodCardView)
        contentView.addSubview(aiCardView)
        contentView.addSubview(voiceCardView)
        contentView.addSubview(keywordsCardView)
        contentView.addSubview(contactsCardView)
        contentView.addSubview(guidelinesCardView)
        contentView.addSubview(sliderCardView)
        contentView.addSubview(privacyCardView)

        // Emergency Banner Subviews
        emergencyBannerView.addSubview(emergencyBannerIconView)
        emergencyBannerView.addSubview(emergencyBannerTitleLabel)
        emergencyBannerView.addSubview(emergencyBannerTextLabel)

        // Guidelines Card Subviews
        guidelinesCardView.addSubview(guidelinesTitleLabel)
        guidelinesCardView.addSubview(silentIconView)
        guidelinesCardView.addSubview(silentTitleLabel)
        guidelinesCardView.addSubview(silentDescLabel)
        guidelinesCardView.addSubview(batteryIconView)
        guidelinesCardView.addSubview(batteryTitleLabel)
        guidelinesCardView.addSubview(batteryDescLabel)

        // Status Card Subviews
        statusCardView.addSubview(statusDotView)
        statusCardView.addSubview(statusLabel)
        statusCardView.addSubview(toggleSwitch)

        // Meter Card Subviews
        meterCardView.addSubview(meterTitleLabel)
        meterCardView.addSubview(dbValueLabel)
        meterCardView.addSubview(progressTrackView)
        progressTrackView.addSubview(progressBarView)
        meterCardView.addSubview(thresholdMarkerLabel)

        // Grace Period Card Subviews
        gracePeriodCardView.addSubview(graceCountdownLabel)
        gracePeriodCardView.addSubview(graceReasonContainerView)
        graceReasonContainerView.addSubview(graceReasonLabel)
        gracePeriodCardView.addSubview(graceDescriptionLabel)
        gracePeriodCardView.addSubview(cancelGraceButton)

        // AI Card Subviews
        aiCardView.addSubview(aiIconView)
        aiCardView.addSubview(aiTitleLabel)
        aiCardView.addSubview(aiBadgeLabel)
        aiCardView.addSubview(aiSubtitleLabel)
        aiCardView.addSubview(aiBadgesStackView)
        setupAIBadges()

        // Voice Card Subviews
        voiceCardView.addSubview(voiceIconView)
        voiceCardView.addSubview(voiceTitleLabel)
        voiceCardView.addSubview(voiceBadgeLabel)
        voiceCardView.addSubview(voiceSubtitleLabel)
        voiceCardView.addSubview(calibrateVoiceButton)
        voiceCardView.addSubview(voiceDividerView)
        voiceCardView.addSubview(unknownVoiceTitleLabel)
        voiceCardView.addSubview(unknownVoiceSubtitleLabel)
        voiceCardView.addSubview(unknownVoiceSwitch)

        // Keywords Card Subviews
        keywordsCardView.addSubview(keywordsIconView)
        keywordsCardView.addSubview(keywordsTitleLabel)
        keywordsCardView.addSubview(keywordsBadgeLabel)
        keywordsCardView.addSubview(keywordsSubtitleLabel)
        keywordsCardView.addSubview(keywordsStackView)
        keywordsCardView.addSubview(addKeywordButton)

        // Contacts Card Subviews
        contactsCardView.addSubview(contactsIconView)
        contactsCardView.addSubview(contactsTitleLabel)
        contactsCardView.addSubview(contactsBadgeLabel)
        contactsCardView.addSubview(contactsSubtitleLabel)
        contactsCardView.addSubview(contactsStackView)
        contactsCardView.addSubview(addContactButton)

        // Slider Card Subviews
        sliderCardView.addSubview(impactsIconView)
        sliderCardView.addSubview(impactsTitleLabel)
        sliderCardView.addSubview(impactsSwitch)
        sliderCardView.addSubview(impactsSubtitleLabel)
        sliderCardView.addSubview(impactsDividerView)
        sliderCardView.addSubview(sliderTitleLabel)
        sliderCardView.addSubview(sliderCurrentValueLabel)
        sliderCardView.addSubview(thresholdSlider)
        sliderCardView.addSubview(repeatImpactsDividerView)
        sliderCardView.addSubview(repeatImpactsTitleLabel)
        sliderCardView.addSubview(repeatImpactsSubtitleLabel)
        sliderCardView.addSubview(repeatImpactsSegmentedControl)
        sliderCardView.addSubview(attentionWindowDividerView)
        sliderCardView.addSubview(attentionWindowTitleLabel)
        sliderCardView.addSubview(attentionWindowSubtitleLabel)
        sliderCardView.addSubview(attentionWindowSegmentedControl)

        // Privacy Card Subviews
        privacyCardView.addSubview(privacyIconView)
        privacyCardView.addSubview(privacyTextLabel)

        // Layout Constraints
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            // Shield & Headers
            shieldImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            shieldImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            shieldImageView.widthAnchor.constraint(equalToConstant: 64),
            shieldImageView.heightAnchor.constraint(equalToConstant: 64),

            titleLabel.topAnchor.constraint(equalTo: shieldImageView.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            // Emergency Callout Banner
            emergencyBannerView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 16),
            emergencyBannerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            emergencyBannerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            emergencyBannerIconView.topAnchor.constraint(equalTo: emergencyBannerView.topAnchor, constant: 14),
            emergencyBannerIconView.leadingAnchor.constraint(equalTo: emergencyBannerView.leadingAnchor, constant: 14),
            emergencyBannerIconView.widthAnchor.constraint(equalToConstant: 20),
            emergencyBannerIconView.heightAnchor.constraint(equalToConstant: 20),

            emergencyBannerTitleLabel.centerYAnchor.constraint(equalTo: emergencyBannerIconView.centerYAnchor),
            emergencyBannerTitleLabel.leadingAnchor.constraint(equalTo: emergencyBannerIconView.trailingAnchor, constant: 8),
            emergencyBannerTitleLabel.trailingAnchor.constraint(equalTo: emergencyBannerView.trailingAnchor, constant: -14),

            emergencyBannerTextLabel.topAnchor.constraint(equalTo: emergencyBannerIconView.bottomAnchor, constant: 8),
            emergencyBannerTextLabel.leadingAnchor.constraint(equalTo: emergencyBannerView.leadingAnchor, constant: 14),
            emergencyBannerTextLabel.trailingAnchor.constraint(equalTo: emergencyBannerView.trailingAnchor, constant: -14),
            emergencyBannerTextLabel.bottomAnchor.constraint(equalTo: emergencyBannerView.bottomAnchor, constant: -14)
        ])

        NSLayoutConstraint.activate([
            // Status Card
            statusCardView.topAnchor.constraint(equalTo: emergencyBannerView.bottomAnchor, constant: 16),
            statusCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            statusCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            statusCardView.heightAnchor.constraint(equalToConstant: 68),

            statusDotView.leadingAnchor.constraint(equalTo: statusCardView.leadingAnchor, constant: 18),
            statusDotView.centerYAnchor.constraint(equalTo: statusCardView.centerYAnchor),
            statusDotView.widthAnchor.constraint(equalToConstant: 12),
            statusDotView.heightAnchor.constraint(equalToConstant: 12),

            statusLabel.leadingAnchor.constraint(equalTo: statusDotView.trailingAnchor, constant: 12),
            statusLabel.centerYAnchor.constraint(equalTo: statusCardView.centerYAnchor),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: toggleSwitch.leadingAnchor, constant: -12),

            toggleSwitch.trailingAnchor.constraint(equalTo: statusCardView.trailingAnchor, constant: -18),
            toggleSwitch.centerYAnchor.constraint(equalTo: statusCardView.centerYAnchor),

            // Meter Card
            meterCardView.topAnchor.constraint(equalTo: statusCardView.bottomAnchor, constant: 16),
            meterCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            meterCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            meterTitleLabel.topAnchor.constraint(equalTo: meterCardView.topAnchor, constant: 16),
            meterTitleLabel.leadingAnchor.constraint(equalTo: meterCardView.leadingAnchor, constant: 18),

            dbValueLabel.topAnchor.constraint(equalTo: meterTitleLabel.bottomAnchor, constant: 6),
            dbValueLabel.leadingAnchor.constraint(equalTo: meterCardView.leadingAnchor, constant: 18),

            progressTrackView.topAnchor.constraint(equalTo: dbValueLabel.bottomAnchor, constant: 14),
            progressTrackView.leadingAnchor.constraint(equalTo: meterCardView.leadingAnchor, constant: 18),
            progressTrackView.trailingAnchor.constraint(equalTo: meterCardView.trailingAnchor, constant: -18),
            progressTrackView.heightAnchor.constraint(equalToConstant: 12),

            progressBarView.topAnchor.constraint(equalTo: progressTrackView.topAnchor),
            progressBarView.leadingAnchor.constraint(equalTo: progressTrackView.leadingAnchor),
            progressBarView.bottomAnchor.constraint(equalTo: progressTrackView.bottomAnchor),

            thresholdMarkerLabel.topAnchor.constraint(equalTo: progressTrackView.bottomAnchor, constant: 10),
            thresholdMarkerLabel.leadingAnchor.constraint(equalTo: meterCardView.leadingAnchor, constant: 18),
            thresholdMarkerLabel.trailingAnchor.constraint(equalTo: meterCardView.trailingAnchor, constant: -18),
            thresholdMarkerLabel.bottomAnchor.constraint(equalTo: meterCardView.bottomAnchor, constant: -16),

            // Grace Period Countdown Alert Card
            gracePeriodCardView.topAnchor.constraint(equalTo: meterCardView.bottomAnchor, constant: 16),
            gracePeriodCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            gracePeriodCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            graceCountdownLabel.topAnchor.constraint(equalTo: gracePeriodCardView.topAnchor, constant: 18),
            graceCountdownLabel.centerXAnchor.constraint(equalTo: gracePeriodCardView.centerXAnchor),

            graceReasonContainerView.topAnchor.constraint(equalTo: graceCountdownLabel.bottomAnchor, constant: 10),
            graceReasonContainerView.leadingAnchor.constraint(equalTo: gracePeriodCardView.leadingAnchor, constant: 14),
            graceReasonContainerView.trailingAnchor.constraint(equalTo: gracePeriodCardView.trailingAnchor, constant: -14),

            graceReasonLabel.topAnchor.constraint(equalTo: graceReasonContainerView.topAnchor, constant: 8),
            graceReasonLabel.leadingAnchor.constraint(equalTo: graceReasonContainerView.leadingAnchor, constant: 10),
            graceReasonLabel.trailingAnchor.constraint(equalTo: graceReasonContainerView.trailingAnchor, constant: -10),
            graceReasonLabel.bottomAnchor.constraint(equalTo: graceReasonContainerView.bottomAnchor, constant: -8),

            graceDescriptionLabel.topAnchor.constraint(equalTo: graceReasonContainerView.bottomAnchor, constant: 10),
            graceDescriptionLabel.leadingAnchor.constraint(equalTo: gracePeriodCardView.leadingAnchor, constant: 16),
            graceDescriptionLabel.trailingAnchor.constraint(equalTo: gracePeriodCardView.trailingAnchor, constant: -16),

            cancelGraceButton.topAnchor.constraint(equalTo: graceDescriptionLabel.bottomAnchor, constant: 14),
            cancelGraceButton.leadingAnchor.constraint(equalTo: gracePeriodCardView.leadingAnchor, constant: 18),
            cancelGraceButton.trailingAnchor.constraint(equalTo: gracePeriodCardView.trailingAnchor, constant: -18),
            cancelGraceButton.heightAnchor.constraint(equalToConstant: 46),
            cancelGraceButton.bottomAnchor.constraint(equalTo: gracePeriodCardView.bottomAnchor, constant: -18)
        ])

        NSLayoutConstraint.activate([
            // AI Card (topAnchor é controlado dinamicamente por aiCardTopToGraceConstraint e aiCardTopToMeterConstraint)
            aiCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            aiCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            aiIconView.leadingAnchor.constraint(equalTo: aiCardView.leadingAnchor, constant: 16),
            aiIconView.topAnchor.constraint(equalTo: aiCardView.topAnchor, constant: 16),
            aiIconView.widthAnchor.constraint(equalToConstant: 22),
            aiIconView.heightAnchor.constraint(equalToConstant: 22),

            aiTitleLabel.leadingAnchor.constraint(equalTo: aiIconView.trailingAnchor, constant: 10),
            aiTitleLabel.topAnchor.constraint(equalTo: aiCardView.topAnchor, constant: 16),
            aiTitleLabel.trailingAnchor.constraint(equalTo: aiCardView.trailingAnchor, constant: -16),

            aiBadgeLabel.topAnchor.constraint(equalTo: aiTitleLabel.bottomAnchor, constant: 6),
            aiBadgeLabel.leadingAnchor.constraint(equalTo: aiTitleLabel.leadingAnchor),
            aiBadgeLabel.heightAnchor.constraint(equalToConstant: 22),
            aiBadgeLabel.widthAnchor.constraint(equalToConstant: 116),

            aiSubtitleLabel.topAnchor.constraint(equalTo: aiBadgeLabel.bottomAnchor, constant: 10),
            aiSubtitleLabel.leadingAnchor.constraint(equalTo: aiCardView.leadingAnchor, constant: 16),
            aiSubtitleLabel.trailingAnchor.constraint(equalTo: aiCardView.trailingAnchor, constant: -16),

            aiBadgesStackView.topAnchor.constraint(equalTo: aiSubtitleLabel.bottomAnchor, constant: 12),
            aiBadgesStackView.leadingAnchor.constraint(equalTo: aiCardView.leadingAnchor, constant: 16),
            aiBadgesStackView.trailingAnchor.constraint(equalTo: aiCardView.trailingAnchor, constant: -16),
            aiBadgesStackView.bottomAnchor.constraint(equalTo: aiCardView.bottomAnchor, constant: -16)
        ])

        NSLayoutConstraint.activate([
            // Voice Profile & Unknown Voice Card
            voiceCardView.topAnchor.constraint(equalTo: aiCardView.bottomAnchor, constant: 16),
            voiceCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            voiceCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            voiceIconView.leadingAnchor.constraint(equalTo: voiceCardView.leadingAnchor, constant: 16),
            voiceIconView.topAnchor.constraint(equalTo: voiceCardView.topAnchor, constant: 16),
            voiceIconView.widthAnchor.constraint(equalToConstant: 22),
            voiceIconView.heightAnchor.constraint(equalToConstant: 22),

            voiceTitleLabel.leadingAnchor.constraint(equalTo: voiceIconView.trailingAnchor, constant: 10),
            voiceTitleLabel.topAnchor.constraint(equalTo: voiceCardView.topAnchor, constant: 16),
            voiceTitleLabel.trailingAnchor.constraint(equalTo: voiceCardView.trailingAnchor, constant: -16),

            voiceBadgeLabel.topAnchor.constraint(equalTo: voiceTitleLabel.bottomAnchor, constant: 6),
            voiceBadgeLabel.leadingAnchor.constraint(equalTo: voiceTitleLabel.leadingAnchor),
            voiceBadgeLabel.trailingAnchor.constraint(lessThanOrEqualTo: voiceCardView.trailingAnchor, constant: -16),
            voiceBadgeLabel.heightAnchor.constraint(equalToConstant: 22),

            voiceSubtitleLabel.topAnchor.constraint(equalTo: voiceBadgeLabel.bottomAnchor, constant: 10),
            voiceSubtitleLabel.leadingAnchor.constraint(equalTo: voiceCardView.leadingAnchor, constant: 16),
            voiceSubtitleLabel.trailingAnchor.constraint(equalTo: voiceCardView.trailingAnchor, constant: -16),

            calibrateVoiceButton.topAnchor.constraint(equalTo: voiceSubtitleLabel.bottomAnchor, constant: 12),
            calibrateVoiceButton.leadingAnchor.constraint(equalTo: voiceCardView.leadingAnchor, constant: 16),
            calibrateVoiceButton.trailingAnchor.constraint(equalTo: voiceCardView.trailingAnchor, constant: -16),
            calibrateVoiceButton.heightAnchor.constraint(equalToConstant: 44),

            voiceDividerView.topAnchor.constraint(equalTo: calibrateVoiceButton.bottomAnchor, constant: 14),
            voiceDividerView.leadingAnchor.constraint(equalTo: voiceCardView.leadingAnchor, constant: 16),
            voiceDividerView.trailingAnchor.constraint(equalTo: voiceCardView.trailingAnchor, constant: -16),
            voiceDividerView.heightAnchor.constraint(equalToConstant: 1),

            unknownVoiceSwitch.topAnchor.constraint(equalTo: voiceDividerView.bottomAnchor, constant: 14),
            unknownVoiceSwitch.trailingAnchor.constraint(equalTo: voiceCardView.trailingAnchor, constant: -16),

            unknownVoiceTitleLabel.topAnchor.constraint(equalTo: voiceDividerView.bottomAnchor, constant: 14),
            unknownVoiceTitleLabel.leadingAnchor.constraint(equalTo: voiceCardView.leadingAnchor, constant: 16),
            unknownVoiceTitleLabel.trailingAnchor.constraint(equalTo: unknownVoiceSwitch.leadingAnchor, constant: -12),

            unknownVoiceSubtitleLabel.topAnchor.constraint(equalTo: unknownVoiceSwitch.bottomAnchor, constant: 12),
            unknownVoiceSubtitleLabel.leadingAnchor.constraint(equalTo: voiceCardView.leadingAnchor, constant: 16),
            unknownVoiceSubtitleLabel.trailingAnchor.constraint(equalTo: voiceCardView.trailingAnchor, constant: -16),
            unknownVoiceSubtitleLabel.bottomAnchor.constraint(equalTo: voiceCardView.bottomAnchor, constant: -16)
        ])

        NSLayoutConstraint.activate([
            // Custom Keywords Card
            keywordsCardView.topAnchor.constraint(equalTo: voiceCardView.bottomAnchor, constant: 16),
            keywordsCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            keywordsCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            keywordsIconView.leadingAnchor.constraint(equalTo: keywordsCardView.leadingAnchor, constant: 16),
            keywordsIconView.topAnchor.constraint(equalTo: keywordsCardView.topAnchor, constant: 16),
            keywordsIconView.widthAnchor.constraint(equalToConstant: 22),
            keywordsIconView.heightAnchor.constraint(equalToConstant: 22),

            keywordsTitleLabel.leadingAnchor.constraint(equalTo: keywordsIconView.trailingAnchor, constant: 10),
            keywordsTitleLabel.centerYAnchor.constraint(equalTo: keywordsIconView.centerYAnchor),
            keywordsTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: keywordsBadgeLabel.leadingAnchor, constant: -8),

            keywordsBadgeLabel.trailingAnchor.constraint(equalTo: keywordsCardView.trailingAnchor, constant: -16),
            keywordsBadgeLabel.centerYAnchor.constraint(equalTo: keywordsIconView.centerYAnchor),
            keywordsBadgeLabel.widthAnchor.constraint(equalToConstant: 36),
            keywordsBadgeLabel.heightAnchor.constraint(equalToConstant: 22),

            keywordsSubtitleLabel.topAnchor.constraint(equalTo: keywordsIconView.bottomAnchor, constant: 8),
            keywordsSubtitleLabel.leadingAnchor.constraint(equalTo: keywordsCardView.leadingAnchor, constant: 16),
            keywordsSubtitleLabel.trailingAnchor.constraint(equalTo: keywordsCardView.trailingAnchor, constant: -16),

            keywordsStackView.topAnchor.constraint(equalTo: keywordsSubtitleLabel.bottomAnchor, constant: 14),
            keywordsStackView.leadingAnchor.constraint(equalTo: keywordsCardView.leadingAnchor, constant: 16),
            keywordsStackView.trailingAnchor.constraint(equalTo: keywordsCardView.trailingAnchor, constant: -16),

            addKeywordButton.topAnchor.constraint(equalTo: keywordsStackView.bottomAnchor, constant: 12),
            addKeywordButton.leadingAnchor.constraint(equalTo: keywordsCardView.leadingAnchor, constant: 16),
            addKeywordButton.trailingAnchor.constraint(equalTo: keywordsCardView.trailingAnchor, constant: -16),
            addKeywordButton.heightAnchor.constraint(equalToConstant: 44),
            addKeywordButton.bottomAnchor.constraint(equalTo: keywordsCardView.bottomAnchor, constant: -16)
        ])

        NSLayoutConstraint.activate([
            // Contacts Card
            contactsCardView.topAnchor.constraint(equalTo: keywordsCardView.bottomAnchor, constant: 16),
            contactsCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            contactsCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            contactsIconView.leadingAnchor.constraint(equalTo: contactsCardView.leadingAnchor, constant: 16),
            contactsIconView.topAnchor.constraint(equalTo: contactsCardView.topAnchor, constant: 16),
            contactsIconView.widthAnchor.constraint(equalToConstant: 22),
            contactsIconView.heightAnchor.constraint(equalToConstant: 22),

            contactsTitleLabel.leadingAnchor.constraint(equalTo: contactsIconView.trailingAnchor, constant: 10),
            contactsTitleLabel.centerYAnchor.constraint(equalTo: contactsIconView.centerYAnchor),
            contactsTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: contactsBadgeLabel.leadingAnchor, constant: -8),

            contactsBadgeLabel.trailingAnchor.constraint(equalTo: contactsCardView.trailingAnchor, constant: -16),
            contactsBadgeLabel.centerYAnchor.constraint(equalTo: contactsIconView.centerYAnchor),
            contactsBadgeLabel.widthAnchor.constraint(equalToConstant: 36),
            contactsBadgeLabel.heightAnchor.constraint(equalToConstant: 22),

            contactsSubtitleLabel.topAnchor.constraint(equalTo: contactsIconView.bottomAnchor, constant: 8),
            contactsSubtitleLabel.leadingAnchor.constraint(equalTo: contactsCardView.leadingAnchor, constant: 16),
            contactsSubtitleLabel.trailingAnchor.constraint(equalTo: contactsCardView.trailingAnchor, constant: -16),

            contactsStackView.topAnchor.constraint(equalTo: contactsSubtitleLabel.bottomAnchor, constant: 14),
            contactsStackView.leadingAnchor.constraint(equalTo: contactsCardView.leadingAnchor, constant: 16),
            contactsStackView.trailingAnchor.constraint(equalTo: contactsCardView.trailingAnchor, constant: -16),

            addContactButton.topAnchor.constraint(equalTo: contactsStackView.bottomAnchor, constant: 12),
            addContactButton.leadingAnchor.constraint(equalTo: contactsCardView.leadingAnchor, constant: 16),
            addContactButton.trailingAnchor.constraint(equalTo: contactsCardView.trailingAnchor, constant: -16),
            addContactButton.heightAnchor.constraint(equalToConstant: 44),
            addContactButton.bottomAnchor.constraint(equalTo: contactsCardView.bottomAnchor, constant: -16)
        ])

        NSLayoutConstraint.activate([
            // Guidelines Card
            guidelinesCardView.topAnchor.constraint(equalTo: contactsCardView.bottomAnchor, constant: 16),
            guidelinesCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            guidelinesCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            guidelinesTitleLabel.topAnchor.constraint(equalTo: guidelinesCardView.topAnchor, constant: 16),
            guidelinesTitleLabel.leadingAnchor.constraint(equalTo: guidelinesCardView.leadingAnchor, constant: 16),
            guidelinesTitleLabel.trailingAnchor.constraint(equalTo: guidelinesCardView.trailingAnchor, constant: -16),

            silentIconView.topAnchor.constraint(equalTo: guidelinesTitleLabel.bottomAnchor, constant: 14),
            silentIconView.leadingAnchor.constraint(equalTo: guidelinesCardView.leadingAnchor, constant: 16),
            silentIconView.widthAnchor.constraint(equalToConstant: 20),
            silentIconView.heightAnchor.constraint(equalToConstant: 20),

            silentTitleLabel.centerYAnchor.constraint(equalTo: silentIconView.centerYAnchor),
            silentTitleLabel.leadingAnchor.constraint(equalTo: silentIconView.trailingAnchor, constant: 10),
            silentTitleLabel.trailingAnchor.constraint(equalTo: guidelinesCardView.trailingAnchor, constant: -16),

            silentDescLabel.topAnchor.constraint(equalTo: silentIconView.bottomAnchor, constant: 6),
            silentDescLabel.leadingAnchor.constraint(equalTo: guidelinesCardView.leadingAnchor, constant: 16),
            silentDescLabel.trailingAnchor.constraint(equalTo: guidelinesCardView.trailingAnchor, constant: -16),

            batteryIconView.topAnchor.constraint(equalTo: silentDescLabel.bottomAnchor, constant: 14),
            batteryIconView.leadingAnchor.constraint(equalTo: guidelinesCardView.leadingAnchor, constant: 16),
            batteryIconView.widthAnchor.constraint(equalToConstant: 20),
            batteryIconView.heightAnchor.constraint(equalToConstant: 20),

            batteryTitleLabel.centerYAnchor.constraint(equalTo: batteryIconView.centerYAnchor),
            batteryTitleLabel.leadingAnchor.constraint(equalTo: batteryIconView.trailingAnchor, constant: 10),
            batteryTitleLabel.trailingAnchor.constraint(equalTo: guidelinesCardView.trailingAnchor, constant: -16),

            batteryDescLabel.topAnchor.constraint(equalTo: batteryIconView.bottomAnchor, constant: 6),
            batteryDescLabel.leadingAnchor.constraint(equalTo: guidelinesCardView.leadingAnchor, constant: 16),
            batteryDescLabel.trailingAnchor.constraint(equalTo: guidelinesCardView.trailingAnchor, constant: -16),
            batteryDescLabel.bottomAnchor.constraint(equalTo: guidelinesCardView.bottomAnchor, constant: -16)
        ])

        NSLayoutConstraint.activate([
            // Slider Card
            sliderCardView.topAnchor.constraint(equalTo: guidelinesCardView.bottomAnchor, constant: 16),
            sliderCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            sliderCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            // Impacts Switch Row
            impactsIconView.leadingAnchor.constraint(equalTo: sliderCardView.leadingAnchor, constant: 16),
            impactsIconView.topAnchor.constraint(equalTo: sliderCardView.topAnchor, constant: 16),
            impactsIconView.widthAnchor.constraint(equalToConstant: 22),
            impactsIconView.heightAnchor.constraint(equalToConstant: 22),

            impactsTitleLabel.centerYAnchor.constraint(equalTo: impactsIconView.centerYAnchor),
            impactsTitleLabel.leadingAnchor.constraint(equalTo: impactsIconView.trailingAnchor, constant: 10),
            impactsTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: impactsSwitch.leadingAnchor, constant: -8),

            impactsSwitch.centerYAnchor.constraint(equalTo: impactsIconView.centerYAnchor),
            impactsSwitch.trailingAnchor.constraint(equalTo: sliderCardView.trailingAnchor, constant: -16),

            impactsSubtitleLabel.topAnchor.constraint(equalTo: impactsIconView.bottomAnchor, constant: 8),
            impactsSubtitleLabel.leadingAnchor.constraint(equalTo: sliderCardView.leadingAnchor, constant: 16),
            impactsSubtitleLabel.trailingAnchor.constraint(equalTo: sliderCardView.trailingAnchor, constant: -16),

            impactsDividerView.topAnchor.constraint(equalTo: impactsSubtitleLabel.bottomAnchor, constant: 14),
            impactsDividerView.leadingAnchor.constraint(equalTo: sliderCardView.leadingAnchor, constant: 16),
            impactsDividerView.trailingAnchor.constraint(equalTo: sliderCardView.trailingAnchor, constant: -16),
            impactsDividerView.heightAnchor.constraint(equalToConstant: 1),

            // Slider Section below divider
            sliderTitleLabel.topAnchor.constraint(equalTo: impactsDividerView.bottomAnchor, constant: 14),
            sliderTitleLabel.leadingAnchor.constraint(equalTo: sliderCardView.leadingAnchor, constant: 18),

            sliderCurrentValueLabel.centerYAnchor.constraint(equalTo: sliderTitleLabel.centerYAnchor),
            sliderCurrentValueLabel.trailingAnchor.constraint(equalTo: sliderCardView.trailingAnchor, constant: -18),

            thresholdSlider.topAnchor.constraint(equalTo: sliderTitleLabel.bottomAnchor, constant: 14),
            thresholdSlider.leadingAnchor.constraint(equalTo: sliderCardView.leadingAnchor, constant: 18),
            thresholdSlider.trailingAnchor.constraint(equalTo: sliderCardView.trailingAnchor, constant: -18),

            repeatImpactsDividerView.topAnchor.constraint(equalTo: thresholdSlider.bottomAnchor, constant: 14),
            repeatImpactsDividerView.leadingAnchor.constraint(equalTo: sliderCardView.leadingAnchor, constant: 16),
            repeatImpactsDividerView.trailingAnchor.constraint(equalTo: sliderCardView.trailingAnchor, constant: -16),
            repeatImpactsDividerView.heightAnchor.constraint(equalToConstant: 1),

            repeatImpactsTitleLabel.topAnchor.constraint(equalTo: repeatImpactsDividerView.bottomAnchor, constant: 14),
            repeatImpactsTitleLabel.leadingAnchor.constraint(equalTo: sliderCardView.leadingAnchor, constant: 18),
            repeatImpactsTitleLabel.trailingAnchor.constraint(equalTo: sliderCardView.trailingAnchor, constant: -18),

            repeatImpactsSubtitleLabel.topAnchor.constraint(equalTo: repeatImpactsTitleLabel.bottomAnchor, constant: 4),
            repeatImpactsSubtitleLabel.leadingAnchor.constraint(equalTo: sliderCardView.leadingAnchor, constant: 18),
            repeatImpactsSubtitleLabel.trailingAnchor.constraint(equalTo: sliderCardView.trailingAnchor, constant: -18),

            repeatImpactsSegmentedControl.topAnchor.constraint(equalTo: repeatImpactsSubtitleLabel.bottomAnchor, constant: 10),
            repeatImpactsSegmentedControl.leadingAnchor.constraint(equalTo: sliderCardView.leadingAnchor, constant: 18),
            repeatImpactsSegmentedControl.trailingAnchor.constraint(equalTo: sliderCardView.trailingAnchor, constant: -18),
            repeatImpactsSegmentedControl.heightAnchor.constraint(equalToConstant: 32),

            attentionWindowDividerView.topAnchor.constraint(equalTo: repeatImpactsSegmentedControl.bottomAnchor, constant: 14),
            attentionWindowDividerView.leadingAnchor.constraint(equalTo: sliderCardView.leadingAnchor, constant: 16),
            attentionWindowDividerView.trailingAnchor.constraint(equalTo: sliderCardView.trailingAnchor, constant: -16),
            attentionWindowDividerView.heightAnchor.constraint(equalToConstant: 1),

            attentionWindowTitleLabel.topAnchor.constraint(equalTo: attentionWindowDividerView.bottomAnchor, constant: 14),
            attentionWindowTitleLabel.leadingAnchor.constraint(equalTo: sliderCardView.leadingAnchor, constant: 18),
            attentionWindowTitleLabel.trailingAnchor.constraint(equalTo: sliderCardView.trailingAnchor, constant: -18),

            attentionWindowSubtitleLabel.topAnchor.constraint(equalTo: attentionWindowTitleLabel.bottomAnchor, constant: 4),
            attentionWindowSubtitleLabel.leadingAnchor.constraint(equalTo: sliderCardView.leadingAnchor, constant: 18),
            attentionWindowSubtitleLabel.trailingAnchor.constraint(equalTo: sliderCardView.trailingAnchor, constant: -18),

            attentionWindowSegmentedControl.topAnchor.constraint(equalTo: attentionWindowSubtitleLabel.bottomAnchor, constant: 10),
            attentionWindowSegmentedControl.leadingAnchor.constraint(equalTo: sliderCardView.leadingAnchor, constant: 18),
            attentionWindowSegmentedControl.trailingAnchor.constraint(equalTo: sliderCardView.trailingAnchor, constant: -18),
            attentionWindowSegmentedControl.heightAnchor.constraint(equalToConstant: 32),
            attentionWindowSegmentedControl.bottomAnchor.constraint(equalTo: sliderCardView.bottomAnchor, constant: -16)
        ])

        NSLayoutConstraint.activate([
            // Privacy Card
            privacyCardView.topAnchor.constraint(equalTo: sliderCardView.bottomAnchor, constant: 16),
            privacyCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            privacyCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            privacyCardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32),

            privacyIconView.leadingAnchor.constraint(equalTo: privacyCardView.leadingAnchor, constant: 14),
            privacyIconView.topAnchor.constraint(equalTo: privacyCardView.topAnchor, constant: 14),
            privacyIconView.widthAnchor.constraint(equalToConstant: 24),
            privacyIconView.heightAnchor.constraint(equalToConstant: 24),

            privacyTextLabel.leadingAnchor.constraint(equalTo: privacyIconView.trailingAnchor, constant: 12),
            privacyTextLabel.topAnchor.constraint(equalTo: privacyCardView.topAnchor, constant: 14),
            privacyTextLabel.trailingAnchor.constraint(equalTo: privacyCardView.trailingAnchor, constant: -14),
            privacyTextLabel.bottomAnchor.constraint(equalTo: privacyCardView.bottomAnchor, constant: -14)
        ])

        progressBarWidthConstraint = progressBarView.widthAnchor.constraint(equalToConstant: 0)
        progressBarWidthConstraint?.isActive = true

        aiCardTopToGraceConstraint = aiCardView.topAnchor.constraint(equalTo: gracePeriodCardView.bottomAnchor, constant: 16)
        aiCardTopToMeterConstraint = aiCardView.topAnchor.constraint(equalTo: meterCardView.bottomAnchor, constant: 16)

        let isInitialGrace = (SentinelAcousticMonitor.shared.currentState == .gracePeriod || SentinelAcousticMonitor.shared.currentState == .attentionMode || SentinelAcousticMonitor.shared.currentState == .emergencyDispatched)
        updateGracePeriodVisibility(isInitialGrace, animated: false)
    }

    private func updateGracePeriodVisibility(_ isVisible: Bool, animated: Bool = true) {
        if isVisible {
            aiCardTopToMeterConstraint?.isActive = false
            aiCardTopToGraceConstraint?.isActive = true
            gracePeriodCardView.isHidden = false
            gracePeriodCardView.isUserInteractionEnabled = true
        } else {
            aiCardTopToGraceConstraint?.isActive = false
            aiCardTopToMeterConstraint?.isActive = true
            gracePeriodCardView.isUserInteractionEnabled = false
        }

        let animateBlock = {
            self.gracePeriodCardView.alpha = isVisible ? 1.0 : 0.0
            self.view.layoutIfNeeded()
        }

        if animated && self.view.window != nil {
            UIView.animate(withDuration: 0.35, delay: 0, options: [.curveEaseInOut], animations: animateBlock) { _ in
                if !isVisible {
                    self.gracePeriodCardView.isHidden = true
                }
            }
        } else {
            self.gracePeriodCardView.isHidden = !isVisible
            self.gracePeriodCardView.alpha = isVisible ? 1.0 : 0.0
            self.view.layoutIfNeeded()
        }
    }

    // MARK: - Actions & Callbacks

    private func setupActions() {
        toggleSwitch.addTarget(self, action: #selector(toggleSwitchChanged(_:)), for: .valueChanged)
        impactsSwitch.addTarget(self, action: #selector(impactsSwitchChanged(_:)), for: .valueChanged)
        thresholdSlider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
        cancelGraceButton.addTarget(self, action: #selector(cancelGraceTapped), for: .touchUpInside)
        addContactButton.addTarget(self, action: #selector(addContactTapped), for: .touchUpInside)
        addKeywordButton.addTarget(self, action: #selector(addKeywordTapped), for: .touchUpInside)
        calibrateVoiceButton.addTarget(self, action: #selector(calibrateVoiceTapped), for: .touchUpInside)
        unknownVoiceSwitch.addTarget(self, action: #selector(unknownVoiceSwitchChanged(_:)), for: .valueChanged)
        repeatImpactsSegmentedControl.addTarget(self, action: #selector(repeatImpactsChanged(_:)), for: .valueChanged)
        attentionWindowSegmentedControl.addTarget(self, action: #selector(attentionWindowChanged(_:)), for: .valueChanged)
    }

    @objc private func repeatImpactsChanged(_ sender: UISegmentedControl) {
        let count = sender.selectedSegmentIndex + 2 // 0->2, 1->3, 2->4, 3->5
        SentinelAcousticMonitor.shared.requiredAttentionImpacts = count
    }

    @objc private func attentionWindowChanged(_ sender: UISegmentedControl) {
        let seconds: Int
        switch sender.selectedSegmentIndex {
        case 0: seconds = 60     // 1 min
        case 1: seconds = 300    // 5 min
        case 2: seconds = 600    // 10 min
        case 3: seconds = 1200   // 20 min
        case 4: seconds = 1800   // 30 min
        default: seconds = 60
        }
        SentinelAcousticMonitor.shared.attentionWindowSeconds = seconds
    }

    @objc private func calibrateVoiceTapped() {
        let modal = VoiceCalibrationModalViewController()
        modal.modalPresentationStyle = .overFullScreen
        modal.modalTransitionStyle = .crossDissolve
        modal.onComplete = { [weak self] in
            self?.refreshVoiceProfileUI()
        }
        present(modal, animated: true, completion: nil)
    }

    @objc private func unknownVoiceSwitchChanged(_ sender: UISwitch) {
        let monitor = SentinelAcousticMonitor.shared
        if sender.isOn && !monitor.isUserVoiceCalibrated {
            sender.setOn(false, animated: true)
            let alert = UIAlertController(
                title: NSLocalizedString("Voz Não Calibrada", comment: ""),
                message: NSLocalizedString("Por favor, realize a calibração da sua assinatura vocal antes de ativar o alerta de vozes externas.", comment: ""),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: NSLocalizedString("Calibrar Agora", comment: ""), style: .default, handler: { [weak self] _ in
                self?.calibrateVoiceTapped()
            }))
            alert.addAction(UIAlertAction(title: NSLocalizedString("Cancelar", comment: ""), style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
            return
        }
        monitor.triggerUnknownVoice = sender.isOn
    }

    private func refreshVoiceProfileUI() {
        let monitor = SentinelAcousticMonitor.shared
        if monitor.isUserVoiceCalibrated {
            let minP = monitor.userVoicePitchMin
            let maxP = monitor.userVoicePitchMax
            voiceBadgeLabel.text = String(format: NSLocalizedString("Calibrada (%.0f-%.0f Hz)", comment: ""), minP, maxP)
            voiceBadgeLabel.textColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
            voiceBadgeLabel.backgroundColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 0.15)
            calibrateVoiceButton.setTitle(NSLocalizedString("Recalibrar Voz (4.5s)", comment: ""), for: .normal)
            unknownVoiceSwitch.isEnabled = true
            unknownVoiceSwitch.isOn = monitor.triggerUnknownVoice
        } else {
            voiceBadgeLabel.text = NSLocalizedString("Não Calibrada", comment: "")
            voiceBadgeLabel.textColor = UIColor(red: 245/255, green: 158/255, blue: 11/255, alpha: 1.0)
            voiceBadgeLabel.backgroundColor = UIColor(red: 245/255, green: 158/255, blue: 11/255, alpha: 0.15)
            calibrateVoiceButton.setTitle(NSLocalizedString("Calibrar Assinatura Vocal (4.5s)", comment: ""), for: .normal)
            unknownVoiceSwitch.isEnabled = true
            unknownVoiceSwitch.isOn = false
        }
    }

    @objc private func toggleSwitchChanged(_ sender: UISwitch) {
        if sender.isOn {
            // Reverte o switch visualmente e abre o modal de confirmação com orientações
            sender.setOn(false, animated: false)
            showActivationConfirmationModal()
        } else {
            SentinelAcousticMonitor.stopMonitoring()
            syncStateWithMonitor()
        }
    }

    private func showActivationConfirmationModal() {
        let modal = SentinelActivationModalViewController()
        modal.onConfirm = { [weak self] in
            guard let self = self else { return }
            self.toggleSwitch.setOn(true, animated: true)
            SentinelAcousticMonitor.startMonitoring()
            self.syncStateWithMonitor()
        }
        modal.onCancel = { [weak self] in
            self?.syncStateWithMonitor()
        }
        modal.modalPresentationStyle = .overFullScreen
        modal.modalTransitionStyle = .crossDissolve
        present(modal, animated: true, completion: nil)
    }



    @objc private func impactsSwitchChanged(_ sender: UISwitch) {
        SentinelAcousticMonitor.shared.detectImpacts = sender.isOn
        updateImpactsUI(enabled: sender.isOn)
    }

    private func updateImpactsUI(enabled: Bool) {
        let alpha: CGFloat = enabled ? 1.0 : 0.4
        UIView.animate(withDuration: 0.2) {
            self.sliderTitleLabel.alpha = alpha
            self.sliderCurrentValueLabel.alpha = alpha
            self.thresholdSlider.alpha = alpha
            self.repeatImpactsTitleLabel.alpha = alpha
            self.repeatImpactsSubtitleLabel.alpha = alpha
            self.repeatImpactsSegmentedControl.alpha = alpha
            self.attentionWindowTitleLabel.alpha = alpha
            self.attentionWindowSubtitleLabel.alpha = alpha
            self.attentionWindowSegmentedControl.alpha = alpha
        }
        thresholdSlider.isEnabled = enabled
        repeatImpactsSegmentedControl.isEnabled = enabled
        attentionWindowSegmentedControl.isEnabled = enabled

        if enabled {
            thresholdMarkerLabel.text = String(format: NSLocalizedString("Limiar de Gatilho: %.0f dB", comment: ""), SentinelAcousticMonitor.shared.thresholdDB)
        } else {
            thresholdMarkerLabel.text = NSLocalizedString("Impactos Desativados (Apenas Voz & Gritos)", comment: "")
        }
    }

    @objc private func sliderValueChanged(_ sender: UISlider) {
        let rounded = round(sender.value)
        sender.value = rounded
        SentinelAcousticMonitor.shared.thresholdDB = rounded
        sliderCurrentValueLabel.text = String(format: "%.0f dB", rounded)
        if SentinelAcousticMonitor.shared.detectImpacts {
            thresholdMarkerLabel.text = String(format: NSLocalizedString("Limiar de Gatilho: %.0f dB", comment: ""), rounded)
        }
    }

    @objc private func cancelGraceTapped() {
        SentinelAcousticMonitor.cancelGracePeriod()
        syncStateWithMonitor()
    }

    private func configureCallbacks() {
        SentinelAcousticMonitor.shared.onStateChange = { [weak self] state in
            DispatchQueue.main.async {
                self?.handleStateChange(state)
            }
        }

        SentinelAcousticMonitor.shared.onDecibelUpdate = { [weak self] db in
            DispatchQueue.main.async {
                self?.updateMeter(db: db)
            }
        }

        SentinelAcousticMonitor.shared.onGracePeriodTick = { [weak self] remaining in
            DispatchQueue.main.async {
                self?.graceCountdownLabel.text = "\(remaining)s"
            }
        }

        SentinelAcousticMonitor.shared.onIntelligentDetection = { [weak self] reason in
            DispatchQueue.main.async {
                self?.graceReasonLabel.text = "🚨 \(reason)"
            }
        }
    }

    // MARK: - Contacts Management UI

    private func refreshContactsUI() {
        for view in contactsStackView.arrangedSubviews {
            contactsStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let contacts = SentinelAcousticMonitor.shared.getTrustedContacts()
        contactsBadgeLabel.text = "\(contacts.count)/3"
        addContactButton.isHidden = contacts.count >= 3

        for (index, contact) in contacts.enumerated() {
            let rowView = createContactRowView(contact: contact, index: index)
            contactsStackView.addArrangedSubview(rowView)
        }
    }

    private func createContactRowView(contact: TrustedContact, index: Int) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = UIColor(red: 28/255, green: 42/255, blue: 47/255, alpha: 1.0)
        container.layer.cornerRadius = 10
        container.layer.borderWidth = 1
        container.layer.borderColor = UIColor(red: 38/255, green: 56/255, blue: 62/255, alpha: 1.0).cgColor

        // Avatar or initials circle
        let avatarView = UIView()
        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.backgroundColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 0.2)
        avatarView.layer.cornerRadius = 18
        avatarView.clipsToBounds = true

        let avatarImageView = UIImageView()
        avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        avatarImageView.contentMode = .scaleAspectFill

        let initialsLabel = UILabel()
        initialsLabel.translatesAutoresizingMaskIntoConstraints = false
        initialsLabel.font = .systemFont(ofSize: 13, weight: .bold)
        initialsLabel.textColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        initialsLabel.textAlignment = .center

        if let data = contact.avatarData, let img = UIImage(data: data) {
            avatarImageView.image = img
            avatarImageView.isHidden = false
            initialsLabel.isHidden = true
        } else {
            let initials = contact.name.split(separator: " ").prefix(2).compactMap { $0.first }.map { String($0).uppercased() }.joined()
            initialsLabel.text = initials.isEmpty ? "C" : initials
            avatarImageView.isHidden = true
            initialsLabel.isHidden = false
        }

        avatarView.addSubview(avatarImageView)
        avatarView.addSubview(initialsLabel)

        let nameLabel = UILabel()
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.text = contact.name
        nameLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        nameLabel.textColor = .white

        let phoneLabel = UILabel()
        phoneLabel.translatesAutoresizingMaskIntoConstraints = false
        phoneLabel.text = contact.phoneNumber.isEmpty ? NSLocalizedString("Sem telefone", comment: "") : contact.phoneNumber
        phoneLabel.font = .systemFont(ofSize: 12, weight: .regular)
        phoneLabel.textColor = UIColor(red: 160/255, green: 175/255, blue: 180/255, alpha: 1.0)

        let textStack = UIStackView(arrangedSubviews: [nameLabel, phoneLabel])
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.spacing = 2

        let deleteButton = UIButton(type: .system)
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 13.0, *), let img = UIImage(systemName: "trash") {
            deleteButton.setImage(img, for: .normal)
        } else {
            deleteButton.setTitle("✕", for: .normal)
        }
        deleteButton.tintColor = UIColor(red: 239/255, green: 68/255, blue: 68/255, alpha: 0.8)
        deleteButton.tag = index
        deleteButton.addTarget(self, action: #selector(deleteContactTapped(_:)), for: .touchUpInside)

        container.addSubview(avatarView)
        container.addSubview(textStack)
        container.addSubview(deleteButton)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 54),

            avatarView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            avatarView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 36),
            avatarView.heightAnchor.constraint(equalToConstant: 36),

            avatarImageView.topAnchor.constraint(equalTo: avatarView.topAnchor),
            avatarImageView.leadingAnchor.constraint(equalTo: avatarView.leadingAnchor),
            avatarImageView.trailingAnchor.constraint(equalTo: avatarView.trailingAnchor),
            avatarImageView.bottomAnchor.constraint(equalTo: avatarView.bottomAnchor),

            initialsLabel.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            initialsLabel.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),

            textStack.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 10),
            textStack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            textStack.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -10),

            deleteButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            deleteButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            deleteButton.widthAnchor.constraint(equalToConstant: 30),
            deleteButton.heightAnchor.constraint(equalToConstant: 30)
        ])

        return container
    }

    @objc private func addContactTapped() {
        guard SentinelAcousticMonitor.shared.getTrustedContacts().count < 3 else {
            let alert = UIAlertController(title: NSLocalizedString("Limite Atingido", comment: ""),
                                          message: NSLocalizedString("Você já cadastrou o número máximo de 3 contatos de confiança.", comment: ""),
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            present(alert, animated: true)
            return
        }

        let actionSheet = UIAlertController(title: NSLocalizedString("Adicionar Contato de Confiança", comment: ""),
                                            message: NSLocalizedString("Como deseja adicionar o contato de emergência?", comment: ""),
                                            preferredStyle: .actionSheet)

        actionSheet.addAction(UIAlertAction(title: NSLocalizedString("Escolher da Agenda do iPhone", comment: ""), style: .default, handler: { [weak self] _ in
            self?.openContactPicker()
        }))

        actionSheet.addAction(UIAlertAction(title: NSLocalizedString("Digitar Nome e Telefone", comment: ""), style: .default, handler: { [weak self] _ in
            self?.openManualContactAlert()
        }))

        actionSheet.addAction(UIAlertAction(title: NSLocalizedString("Cancelar", comment: ""), style: .cancel, handler: nil))

        if let popover = actionSheet.popoverPresentationController {
            popover.sourceView = addContactButton
            popover.sourceRect = addContactButton.bounds
        }

        present(actionSheet, animated: true)
    }

    private func openContactPicker() {
        let picker = CNContactPickerViewController()
        picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
        picker.delegate = self
        present(picker, animated: true)
    }

    private func openManualContactAlert() {
        let alert = UIAlertController(title: NSLocalizedString("Novo Contato de Confiança", comment: ""),
                                      message: NSLocalizedString("Informe o nome e o número de telefone com DDD.", comment: ""),
                                      preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = NSLocalizedString("Nome do Contato", comment: "")
            tf.autocapitalizationType = .words
        }
        alert.addTextField { tf in
            tf.placeholder = NSLocalizedString("Telefone (com DDD)", comment: "")
            tf.keyboardType = .phonePad
        }

        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancelar", comment: ""), style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Adicionar", comment: ""), style: .default, handler: { [weak self] _ in
            let name = alert.textFields?[0].text ?? ""
            let phone = alert.textFields?[1].text ?? ""
            
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedName.isEmpty {
                let errAlert = UIAlertController(
                    title: NSLocalizedString("Nome Obrigatório", comment: ""),
                    message: NSLocalizedString("Por favor, informe o nome do contato.", comment: ""),
                    preferredStyle: .alert
                )
                errAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self?.present(errAlert, animated: true)
                return
            }

            let digits = phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if digits.count < 10 {
                let errAlert = UIAlertController(
                    title: NSLocalizedString("Telefone Inválido", comment: ""),
                    message: NSLocalizedString("O número de telefone deve conter o DDD (mínimo 10 dígitos com DDD). Ex: (11) 99999-9999", comment: ""),
                    preferredStyle: .alert
                )
                errAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self?.present(errAlert, animated: true)
                return
            }

            if SentinelAcousticMonitor.shared.addTrustedContact(name: trimmedName, phoneNumber: phone) {
                self?.refreshContactsUI()
            }
        }))

        present(alert, animated: true)
    }

    @objc private func deleteContactTapped(_ sender: UIButton) {
        let index = sender.tag
        SentinelAcousticMonitor.shared.removeTrustedContact(at: index)
        refreshContactsUI()
    }

    // MARK: - State Sync

    private func syncStateWithMonitor() {
        let monitor = SentinelAcousticMonitor.shared
        toggleSwitch.isOn = monitor.isMonitoring
        impactsSwitch.isOn = monitor.detectImpacts
        thresholdSlider.value = monitor.thresholdDB
        sliderCurrentValueLabel.text = String(format: "%.0f dB", monitor.thresholdDB)

        let reqImpacts = monitor.requiredAttentionImpacts
        let idx = max(0, min(3, reqImpacts - 2))
        repeatImpactsSegmentedControl.selectedSegmentIndex = idx

        let attSeconds = monitor.attentionWindowSeconds
        let attIdx: Int
        switch attSeconds {
        case 60: attIdx = 0
        case 300: attIdx = 1
        case 600: attIdx = 2
        case 1200: attIdx = 3
        case 1800: attIdx = 4
        default: attIdx = 0
        }
        attentionWindowSegmentedControl.selectedSegmentIndex = attIdx

        updateImpactsUI(enabled: monitor.detectImpacts)
        refreshVoiceProfileUI()
        handleStateChange(monitor.currentState)
    }

    private func handleStateChange(_ state: SentinelState) {
        let isGrace = (state == .gracePeriod || state == .attentionMode || state == .emergencyDispatched)
        updateGracePeriodVisibility(isGrace, animated: true)

        switch state {
        case .idle:
            statusLabel.text = NSLocalizedString("Monitoramento Inativo", comment: "")
            statusDotView.backgroundColor = .systemGray
            shieldImageView.tintColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
            toggleSwitch.isOn = false
            updateMeter(db: 0)

        case .listening:
            statusLabel.text = NSLocalizedString("Escuta Passiva Ativa", comment: "")
            statusDotView.backgroundColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
            shieldImageView.tintColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
            toggleSwitch.isOn = true

        case .attentionMode:
            let reason = SentinelAcousticMonitor.shared.lastTriggerReason
            statusLabel.text = NSLocalizedString("Atenção (Modo Silencioso)", comment: "")
            statusDotView.backgroundColor = .systemYellow
            shieldImageView.tintColor = .systemYellow
            toggleSwitch.isOn = true
            graceCountdownLabel.text = NSLocalizedString("MODO DE ATENÇÃO", comment: "")
            if !reason.isEmpty {
                graceReasonLabel.text = "⚠️ \(reason)"
            } else {
                graceReasonLabel.text = "⚠️ " + NSLocalizedString("Impacto acústico detectado em aguardo", comment: "")
            }
            graceDescriptionLabel.text = NSLocalizedString("Aguardando confirmação vocal ou novos impactos. Toque abaixo para cancelar.", comment: "")

        case .gracePeriod:
            let reason = SentinelAcousticMonitor.shared.lastTriggerReason
            statusLabel.text = NSLocalizedString("Atenção: Detecção Ativada!", comment: "")
            statusDotView.backgroundColor = UIColor(red: 239/255, green: 68/255, blue: 68/255, alpha: 1.0)
            shieldImageView.tintColor = UIColor(red: 239/255, green: 68/255, blue: 68/255, alpha: 1.0)
            toggleSwitch.isOn = true
            graceCountdownLabel.text = "\(SentinelAcousticMonitor.shared.gracePeriodRemainingSeconds)s"
            if !reason.isEmpty {
                graceReasonLabel.text = "🚨 \(reason)"
            } else {
                graceReasonLabel.text = "🚨 " + NSLocalizedString("Ruído de emergência detectado", comment: "")
            }
            graceDescriptionLabel.text = NSLocalizedString("Alerta de emergência e localização serão enviados aos contatos se não houver cancelamento.", comment: "")

        case .emergencyDispatched:
            let reason = SentinelAcousticMonitor.shared.lastTriggerReason
            statusLabel.text = NSLocalizedString("Alerta de Emergência Disparado", comment: "")
            statusDotView.backgroundColor = UIColor(red: 239/255, green: 68/255, blue: 68/255, alpha: 1.0)
            shieldImageView.tintColor = UIColor(red: 239/255, green: 68/255, blue: 68/255, alpha: 1.0)
            toggleSwitch.isOn = true
            graceCountdownLabel.text = NSLocalizedString("ENVIADO", comment: "")
            if !reason.isEmpty {
                graceReasonLabel.text = "🚨 \(reason)"
            } else {
                graceReasonLabel.text = "🚨 " + NSLocalizedString("Emergência Despachada", comment: "")
            }
            graceDescriptionLabel.text = NSLocalizedString("Alerta e localização enviados aos contatos. Toque abaixo para encerrar o alerta.", comment: "")

        case .batteryCritical:
            statusLabel.text = NSLocalizedString("Pausado: Bateria Crítica (<= 15%)", comment: "")
            statusDotView.backgroundColor = .systemOrange
            shieldImageView.tintColor = .systemOrange
            toggleSwitch.isOn = false

        case .permissionDenied:
            statusLabel.text = NSLocalizedString("Permissão de Microfone Negada", comment: "")
            statusDotView.backgroundColor = .systemRed
            toggleSwitch.isOn = false

        case .error:
            statusLabel.text = NSLocalizedString("Falha ao Iniciar Microfone", comment: "")
            statusDotView.backgroundColor = .systemRed
            toggleSwitch.isOn = false
        }
    }

    // MARK: - AI Badges Setup

    private func setupAIBadges() {
        aiBadgesStackView.addArrangedSubview(createAIRow(
            icon: "🪟",
            title: NSLocalizedString("Vidro Quebrando & Impactos", comment: ""),
            subtitle: NSLocalizedString("Classifica estilhaçamento de janelas, garrafas e quebra de portas.", comment: "")
        ))
        aiBadgesStackView.addArrangedSubview(createAIRow(
            icon: "🔊",
            title: NSLocalizedString("Gritos & Pânico Acústico", comment: ""),
            subtitle: NSLocalizedString("Classifica berros, gritos de socorro agudos e gemidos de agressão.", comment: "")
        ))
        aiBadgesStackView.addArrangedSubview(createAIRow(
            icon: "🗣️",
            title: NSLocalizedString("Frases de Socorro (PT, EN, ES)", comment: ""),
            subtitle: NSLocalizedString("\"Não me bate\", \"Socorro\", \"Me ajuda\", \"Help me\", \"No me pegues\".", comment: "")
        ))
    }

    private func createAIRow(icon: String, title: String, subtitle: String) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = UIColor(red: 28/255, green: 42/255, blue: 47/255, alpha: 1.0)
        container.layer.cornerRadius = 10
        container.layer.borderWidth = 1
        container.layer.borderColor = UIColor(red: 40/255, green: 60/255, blue: 67/255, alpha: 1.0).cgColor

        let iconLabel = UILabel()
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        iconLabel.text = icon
        iconLabel.font = .systemFont(ofSize: 18)

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 13, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 0
        titleLabel.lineBreakMode = .byWordWrapping

        let subLabel = UILabel()
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        subLabel.text = subtitle
        subLabel.font = .systemFont(ofSize: 11, weight: .regular)
        subLabel.textColor = UIColor(red: 160/255, green: 175/255, blue: 180/255, alpha: 1.0)
        subLabel.numberOfLines = 0
        subLabel.lineBreakMode = .byWordWrapping

        let vStack = UIStackView(arrangedSubviews: [titleLabel, subLabel])
        vStack.translatesAutoresizingMaskIntoConstraints = false
        vStack.axis = .vertical
        vStack.spacing = 2

        container.addSubview(iconLabel)
        container.addSubview(vStack)

        NSLayoutConstraint.activate([
            iconLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            iconLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconLabel.widthAnchor.constraint(equalToConstant: 24),

            vStack.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 10),
            vStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            vStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            vStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10)
        ])

        return container
    }

    // MARK: - Custom Keywords Management UI

    private func refreshKeywordsUI() {
        for view in keywordsStackView.arrangedSubviews {
            keywordsStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let keywords = SentinelAcousticMonitor.shared.getCustomKeywords()
        keywordsBadgeLabel.text = "\(keywords.count)/10"

        if keywords.isEmpty {
            let emptyLabel = UILabel()
            emptyLabel.text = NSLocalizedString("Nenhuma frase personalizada cadastrada ainda.", comment: "")
            emptyLabel.font = UIFont.italicSystemFont(ofSize: 12)
            emptyLabel.textColor = UIColor(red: 120/255, green: 135/255, blue: 140/255, alpha: 1.0)
            keywordsStackView.addArrangedSubview(emptyLabel)
        } else {
            for (index, keyword) in keywords.enumerated() {
                let row = createKeywordRow(keyword: keyword, index: index)
                keywordsStackView.addArrangedSubview(row)
            }
        }

        addKeywordButton.isHidden = keywords.count >= 10
    }

    private func createKeywordRow(keyword: String, index: Int) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = UIColor(red: 28/255, green: 42/255, blue: 47/255, alpha: 1.0)
        container.layer.cornerRadius = 10
        container.layer.borderWidth = 1
        container.layer.borderColor = UIColor(red: 40/255, green: 60/255, blue: 67/255, alpha: 1.0).cgColor

        let quoteIcon = UIImageView()
        quoteIcon.translatesAutoresizingMaskIntoConstraints = false
        quoteIcon.contentMode = .scaleAspectFit
        if #available(iOS 13.0, *), let img = UIImage(systemName: "quote.opening") {
            quoteIcon.image = img
        }
        quoteIcon.tintColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "\"\(keyword)\""
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .white

        let deleteBtn = UIButton(type: .system)
        deleteBtn.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 13.0, *), let img = UIImage(systemName: "trash") {
            deleteBtn.setImage(img, for: .normal)
        } else {
            deleteBtn.setTitle("✕", for: .normal)
        }
        deleteBtn.tintColor = UIColor(red: 239/255, green: 68/255, blue: 68/255, alpha: 0.8)
        deleteBtn.tag = index
        deleteBtn.addTarget(self, action: #selector(deleteKeywordTapped(_:)), for: .touchUpInside)

        container.addSubview(quoteIcon)
        container.addSubview(label)
        container.addSubview(deleteBtn)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 44),

            quoteIcon.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            quoteIcon.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            quoteIcon.widthAnchor.constraint(equalToConstant: 16),
            quoteIcon.heightAnchor.constraint(equalToConstant: 16),

            label.leadingAnchor.constraint(equalTo: quoteIcon.trailingAnchor, constant: 8),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.trailingAnchor.constraint(equalTo: deleteBtn.leadingAnchor, constant: -8),

            deleteBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            deleteBtn.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            deleteBtn.widthAnchor.constraint(equalToConstant: 30),
            deleteBtn.heightAnchor.constraint(equalToConstant: 30)
        ])

        return container
    }

    @objc private func addKeywordTapped() {
        guard SentinelAcousticMonitor.shared.getCustomKeywords().count < 3 else {
            let alert = UIAlertController(title: NSLocalizedString("Limite Atingido", comment: ""),
                                          message: NSLocalizedString("Você já cadastrou o número máximo de 3 frases personalizadas.", comment: ""),
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            present(alert, animated: true)
            return
        }

        let alert = UIAlertController(title: NSLocalizedString("Nova Frase de Alerta", comment: ""),
                                      message: NSLocalizedString("Digite uma palavra-código ou frase de emergência (ex: 'socorro amigos', 'código vermelho').", comment: ""),
                                      preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = NSLocalizedString("Ex: não me machuca, socorro", comment: "")
            tf.autocapitalizationType = .none
        }

        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancelar", comment: ""), style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Salvar", comment: ""), style: .default, handler: { [weak self] _ in
            let text = alert.textFields?[0].text ?? ""
            if SentinelAcousticMonitor.shared.addCustomKeyword(text) {
                self?.refreshKeywordsUI()
            }
        }))

        present(alert, animated: true)
    }

    @objc private func deleteKeywordTapped(_ sender: UIButton) {
        let index = sender.tag
        SentinelAcousticMonitor.shared.removeCustomKeyword(at: index)
        refreshKeywordsUI()
    }

    private func updateMeter(db: Float) {
        guard SentinelAcousticMonitor.shared.isMonitoring else {
            dbValueLabel.text = "-- dB"
            progressBarWidthConstraint?.constant = 0
            view.layoutIfNeeded()
            return
        }

        dbValueLabel.text = String(format: "%.1f dB", db)

        // Progress bar (0 dB a 100 dB)
        let totalWidth = progressTrackView.frame.width
        if totalWidth > 0 {
            let percentage = CGFloat(min(max(db, 0), 100) / 100.0)
            progressBarWidthConstraint?.constant = totalWidth * percentage

            if SentinelAcousticMonitor.shared.detectImpacts {
                if db >= SentinelAcousticMonitor.shared.thresholdDB {
                    progressBarView.backgroundColor = UIColor(red: 239/255, green: 68/255, blue: 68/255, alpha: 1.0)
                    dbValueLabel.textColor = UIColor(red: 239/255, green: 68/255, blue: 68/255, alpha: 1.0)
                } else if db >= (SentinelAcousticMonitor.shared.thresholdDB - 10.0) {
                    progressBarView.backgroundColor = UIColor.systemOrange
                    dbValueLabel.textColor = UIColor.systemOrange
                } else {
                    progressBarView.backgroundColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
                    dbValueLabel.textColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
                }
            } else {
                progressBarView.backgroundColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 0.6)
                dbValueLabel.textColor = UIColor(red: 160/255, green: 175/255, blue: 180/255, alpha: 1.0)
            }
            UIView.animate(withDuration: 0.1) {
                self.view.layoutIfNeeded()
            }
        }
    }
}

// MARK: - CNContactPickerDelegate

extension SentinelViewController: CNContactPickerDelegate {
    func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
        let fullName = [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
        let displayName = fullName.isEmpty ? (contact.organizationName.isEmpty ? NSLocalizedString("Contato", comment: "") : contact.organizationName) : fullName
        let phone = contact.phoneNumbers.first?.value.stringValue ?? ""
        let avatar = contact.thumbnailImageData

        processSelectedContact(name: displayName, phone: phone, avatar: avatar)
    }

    func contactPicker(_ picker: CNContactPickerViewController, didSelect contactProperty: CNContactProperty) {
        let contact = contactProperty.contact
        let fullName = [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
        let displayName = fullName.isEmpty ? (contact.organizationName.isEmpty ? NSLocalizedString("Contato", comment: "") : contact.organizationName) : fullName
        let phone = (contactProperty.value as? CNPhoneNumber)?.stringValue ?? contact.phoneNumbers.first?.value.stringValue ?? ""
        let avatar = contact.thumbnailImageData

        processSelectedContact(name: displayName, phone: phone, avatar: avatar)
    }

    private func processSelectedContact(name: String, phone: String, avatar: Data?) {
        let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmedPhone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()

        if digits.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                let alert = UIAlertController(
                    title: NSLocalizedString("Contato sem Telefone", comment: ""),
                    message: NSLocalizedString("O contato selecionado não possui um número de telefone cadastrado na agenda.", comment: ""),
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: NSLocalizedString("Entendi", comment: ""), style: .default, handler: nil))
                self?.present(alert, animated: true, completion: nil)
            }
            return
        }

        if digits.count < 10 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                let alert = UIAlertController(
                    title: NSLocalizedString("Contato Inválido", comment: ""),
                    message: NSLocalizedString("O número do contato selecionado não possui o DDD (código de área). O envio via WhatsApp/SMS necessita do DDD para funcionar.\n\nPor favor, edite o contato na sua agenda adicionando o DDD e tente novamente.", comment: ""),
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: NSLocalizedString("Entendi", comment: ""), style: .default, handler: nil))
                self?.present(alert, animated: true, completion: nil)
            }
            return
        }

        if SentinelAcousticMonitor.shared.addTrustedContact(name: name, phoneNumber: phone, avatarData: avatar) {
            refreshContactsUI()
        }
    }
}

// MARK: - SentinelActivationModalViewController

class SentinelActivationModalViewController: UIViewController {

    var onConfirm: (() -> Void)?
    var onCancel: (() -> Void)?

    private let backdropView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = UIColor.black.withAlphaComponent(0.72)
        return v
    }()

    private let containerView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = UIColor(red: 18/255, green: 28/255, blue: 32/255, alpha: 1.0)
        v.layer.cornerRadius = 20
        v.layer.borderWidth = 1.5
        v.layer.borderColor = UIColor(red: 45/255, green: 65/255, blue: 72/255, alpha: 1.0).cgColor
        v.layer.masksToBounds = true
        return v
    }()

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.showsVerticalScrollIndicator = true
        return sv
    }()

    private let scrollContentView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // Header
    private let shieldImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        if #available(iOS 13.0, *), let img = UIImage(systemName: "shield.lefthalf.filled") {
            iv.image = img
        }
        iv.tintColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        return iv
    }()

    private let modalTitleLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.text = NSLocalizedString("Ativar Modo Sentinela", comment: "")
        l.font = .systemFont(ofSize: 20, weight: .bold)
        l.textColor = .white
        l.textAlignment = .center
        return l
    }()

    private let modalSubtitleLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.text = NSLocalizedString("Leia com atenção antes de iniciar o monitoramento:", comment: "")
        l.font = .systemFont(ofSize: 13, weight: .regular)
        l.textColor = UIColor(red: 160/255, green: 175/255, blue: 180/255, alpha: 1.0)
        l.textAlignment = .center
        return l
    }()

    // Box 1: Risco Iminente (Destaque Máximo)
    private let emergencyBoxView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = UIColor(red: 58/255, green: 20/255, blue: 24/255, alpha: 1.0)
        v.layer.cornerRadius = 12
        v.layer.borderWidth = 1.2
        v.layer.borderColor = UIColor(red: 239/255, green: 68/255, blue: 68/255, alpha: 0.9).cgColor
        return v
    }()

    private let emergencyTitleLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.text = NSLocalizedString("🚨 ESTÁ EM RISCO IMINENTE?", comment: "")
        l.font = .systemFont(ofSize: 13, weight: .black)
        l.textColor = UIColor(red: 252/255, green: 165/255, blue: 165/255, alpha: 1.0)
        return l
    }()

    private let emergencyDescLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.text = NSLocalizedString("Se você estiver sofrendo perigo ou ameaça imediata, NÃO aguarde o monitoramento acústico. Acione imediatamente as autoridades locais ou utilize o recurso SOS de Emergência do iPhone.", comment: "")
        l.font = .systemFont(ofSize: 12, weight: .medium)
        l.textColor = .white
        l.numberOfLines = 0
        return l
    }()

    // Box 2: Momento Oportuno / Local Silencioso
    private let silentBoxView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = UIColor(red: 24/255, green: 38/255, blue: 43/255, alpha: 1.0)
        v.layer.cornerRadius = 12
        v.layer.borderWidth = 1
        v.layer.borderColor = UIColor(red: 38/255, green: 58/255, blue: 65/255, alpha: 1.0).cgColor
        return v
    }()

    private let silentTitleLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.text = NSLocalizedString("🤫 Ambiente Oportuno e Silencioso", comment: "")
        l.font = .systemFont(ofSize: 13, weight: .bold)
        l.textColor = UIColor(red: 94/255, green: 234/255, blue: 212/255, alpha: 1.0)
        return l
    }()

    private let silentDescLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.text = NSLocalizedString("Ative preferencialmente ao dormir, repousar ou em locais calmos. Ambientes barulhentos (TV alta, festas, trânsito intenso) provocam falsos disparos acústicos.", comment: "")
        l.font = .systemFont(ofSize: 12, weight: .regular)
        l.textColor = UIColor(red: 209/255, green: 213/255, blue: 219/255, alpha: 1.0)
        l.numberOfLines = 0
        return l
    }()

    // Box 3: Consumo de Bateria & Salvaguarda
    private let batteryBoxView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = UIColor(red: 24/255, green: 38/255, blue: 43/255, alpha: 1.0)
        v.layer.cornerRadius = 12
        v.layer.borderWidth = 1
        v.layer.borderColor = UIColor(red: 38/255, green: 58/255, blue: 65/255, alpha: 1.0).cgColor
        return v
    }()

    private let batteryTitleLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.text = NSLocalizedString("🔋 Consumo de Bateria & Salvaguarda", comment: "")
        l.font = .systemFont(ofSize: 13, weight: .bold)
        l.textColor = UIColor(red: 253/255, green: 224/255, blue: 71/255, alpha: 1.0)
        return l
    }()

    private let batteryDescLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.text = NSLocalizedString("A escuta contínua pelo microfone consome bateria. Recomendamos manter o aparelho no carregador. O monitoramento desliga sozinho se a bateria atingir 15% desconectada.", comment: "")
        l.font = .systemFont(ofSize: 12, weight: .regular)
        l.textColor = UIColor(red: 209/255, green: 213/255, blue: 219/255, alpha: 1.0)
        l.numberOfLines = 0
        return l
    }()

    // Buttons
    private let confirmButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setTitle(NSLocalizedString("Compreendi e Quero Ativar", comment: ""), for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 15, weight: .bold)
        b.backgroundColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        b.layer.cornerRadius = 12
        return b
    }()

    private let cancelButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setTitle(NSLocalizedString("Cancelar", comment: ""), for: .normal)
        b.setTitleColor(UIColor(red: 160/255, green: 175/255, blue: 180/255, alpha: 1.0), for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        return b
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
    }

    private func setupUI() {
        view.backgroundColor = .clear

        view.addSubview(backdropView)
        view.addSubview(containerView)

        containerView.addSubview(scrollView)
        scrollView.addSubview(scrollContentView)

        scrollContentView.addSubview(shieldImageView)
        scrollContentView.addSubview(modalTitleLabel)
        scrollContentView.addSubview(modalSubtitleLabel)
        scrollContentView.addSubview(emergencyBoxView)
        scrollContentView.addSubview(silentBoxView)
        scrollContentView.addSubview(batteryBoxView)

        // Emergency Box subviews
        emergencyBoxView.addSubview(emergencyTitleLabel)
        emergencyBoxView.addSubview(emergencyDescLabel)

        // Silent Box subviews
        silentBoxView.addSubview(silentTitleLabel)
        silentBoxView.addSubview(silentDescLabel)

        // Battery Box subviews
        batteryBoxView.addSubview(batteryTitleLabel)
        batteryBoxView.addSubview(batteryDescLabel)

        containerView.addSubview(confirmButton)
        containerView.addSubview(cancelButton)

        let widthConstraint = containerView.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -32)
        widthConstraint.priority = UILayoutPriority(999)

        NSLayoutConstraint.activate([
            // Backdrop
            backdropView.topAnchor.constraint(equalTo: view.topAnchor),
            backdropView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdropView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdropView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Container Card
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16),
            widthConstraint,
            containerView.widthAnchor.constraint(lessThanOrEqualToConstant: 440),
            containerView.heightAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.heightAnchor, constant: -40),

            // ScrollView
            scrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: confirmButton.topAnchor, constant: -10),

            // ScrollContentView
            scrollContentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            scrollContentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            scrollContentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            scrollContentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            scrollContentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            // Header Elements
            shieldImageView.topAnchor.constraint(equalTo: scrollContentView.topAnchor, constant: 18),
            shieldImageView.centerXAnchor.constraint(equalTo: scrollContentView.centerXAnchor),
            shieldImageView.widthAnchor.constraint(equalToConstant: 44),
            shieldImageView.heightAnchor.constraint(equalToConstant: 44),

            modalTitleLabel.topAnchor.constraint(equalTo: shieldImageView.bottomAnchor, constant: 8),
            modalTitleLabel.leadingAnchor.constraint(equalTo: scrollContentView.leadingAnchor, constant: 16),
            modalTitleLabel.trailingAnchor.constraint(equalTo: scrollContentView.trailingAnchor, constant: -16),

            modalSubtitleLabel.topAnchor.constraint(equalTo: modalTitleLabel.bottomAnchor, constant: 4),
            modalSubtitleLabel.leadingAnchor.constraint(equalTo: scrollContentView.leadingAnchor, constant: 16),
            modalSubtitleLabel.trailingAnchor.constraint(equalTo: scrollContentView.trailingAnchor, constant: -16),

            // Emergency Box
            emergencyBoxView.topAnchor.constraint(equalTo: modalSubtitleLabel.bottomAnchor, constant: 14),
            emergencyBoxView.leadingAnchor.constraint(equalTo: scrollContentView.leadingAnchor, constant: 16),
            emergencyBoxView.trailingAnchor.constraint(equalTo: scrollContentView.trailingAnchor, constant: -16),

            emergencyTitleLabel.topAnchor.constraint(equalTo: emergencyBoxView.topAnchor, constant: 12),
            emergencyTitleLabel.leadingAnchor.constraint(equalTo: emergencyBoxView.leadingAnchor, constant: 12),
            emergencyTitleLabel.trailingAnchor.constraint(equalTo: emergencyBoxView.trailingAnchor, constant: -12),

            emergencyDescLabel.topAnchor.constraint(equalTo: emergencyTitleLabel.bottomAnchor, constant: 6),
            emergencyDescLabel.leadingAnchor.constraint(equalTo: emergencyBoxView.leadingAnchor, constant: 12),
            emergencyDescLabel.trailingAnchor.constraint(equalTo: emergencyBoxView.trailingAnchor, constant: -12),
            emergencyDescLabel.bottomAnchor.constraint(equalTo: emergencyBoxView.bottomAnchor, constant: -12),

            // Silent Box
            silentBoxView.topAnchor.constraint(equalTo: emergencyBoxView.bottomAnchor, constant: 12),
            silentBoxView.leadingAnchor.constraint(equalTo: scrollContentView.leadingAnchor, constant: 16),
            silentBoxView.trailingAnchor.constraint(equalTo: scrollContentView.trailingAnchor, constant: -16),

            silentTitleLabel.topAnchor.constraint(equalTo: silentBoxView.topAnchor, constant: 12),
            silentTitleLabel.leadingAnchor.constraint(equalTo: silentBoxView.leadingAnchor, constant: 12),
            silentTitleLabel.trailingAnchor.constraint(equalTo: silentBoxView.trailingAnchor, constant: -12),

            silentDescLabel.topAnchor.constraint(equalTo: silentTitleLabel.bottomAnchor, constant: 4),
            silentDescLabel.leadingAnchor.constraint(equalTo: silentBoxView.leadingAnchor, constant: 12),
            silentDescLabel.trailingAnchor.constraint(equalTo: silentBoxView.trailingAnchor, constant: -12),
            silentDescLabel.bottomAnchor.constraint(equalTo: silentBoxView.bottomAnchor, constant: -12),

            // Battery Box
            batteryBoxView.topAnchor.constraint(equalTo: silentBoxView.bottomAnchor, constant: 12),
            batteryBoxView.leadingAnchor.constraint(equalTo: scrollContentView.leadingAnchor, constant: 16),
            batteryBoxView.trailingAnchor.constraint(equalTo: scrollContentView.trailingAnchor, constant: -16),
            batteryBoxView.bottomAnchor.constraint(equalTo: scrollContentView.bottomAnchor, constant: -14),

            batteryTitleLabel.topAnchor.constraint(equalTo: batteryBoxView.topAnchor, constant: 12),
            batteryTitleLabel.leadingAnchor.constraint(equalTo: batteryBoxView.leadingAnchor, constant: 12),
            batteryTitleLabel.trailingAnchor.constraint(equalTo: batteryBoxView.trailingAnchor, constant: -12),

            batteryDescLabel.topAnchor.constraint(equalTo: batteryTitleLabel.bottomAnchor, constant: 4),
            batteryDescLabel.leadingAnchor.constraint(equalTo: batteryBoxView.leadingAnchor, constant: 12),
            batteryDescLabel.trailingAnchor.constraint(equalTo: batteryBoxView.trailingAnchor, constant: -12),
            batteryDescLabel.bottomAnchor.constraint(equalTo: batteryBoxView.bottomAnchor, constant: -12),

            // Action Buttons
            confirmButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            confirmButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            confirmButton.heightAnchor.constraint(equalToConstant: 48),
            confirmButton.bottomAnchor.constraint(equalTo: cancelButton.topAnchor, constant: -4),

            cancelButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            cancelButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            cancelButton.heightAnchor.constraint(equalToConstant: 38),
            cancelButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -10)
        ])
    }

    private func setupActions() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(cancelTapped))
        backdropView.addGestureRecognizer(tap)

        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
    }

    @objc private func confirmTapped() {
        dismiss(animated: true) { [weak self] in
            self?.onConfirm?()
        }
    }

    @objc private func cancelTapped() {
        dismiss(animated: true) { [weak self] in
            self?.onCancel?()
        }
    }
}

// MARK: - Modal Controller para Calibração de Voz do Usuário

class VoiceCalibrationModalViewController: UIViewController {

    var onComplete: (() -> Void)?

    private let backdropView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        return view
    }()

    private let containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 22/255, green: 34/255, blue: 38/255, alpha: 1.0)
        view.layer.cornerRadius = 20
        view.layer.borderWidth = 1.2
        view.layer.borderColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 0.5).cgColor
        return view
    }()

    private let micIconView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        if #available(iOS 13.0, *), let img = UIImage(systemName: "mic.circle.fill") {
            iv.image = img
        }
        iv.tintColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Calibrando Sua Voz", comment: "")
        label.font = .systemFont(ofSize: 18, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Por favor, fale normalmente (ex: conte de 1 a 10 ou fale frases do dia a dia) para que o Sentinela aprenda seu tom de voz (pitch baseline).", comment: "")
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = UIColor(red: 160/255, green: 175/255, blue: 180/255, alpha: 1.0)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let progressView: UIProgressView = {
        let pv = UIProgressView(progressViewStyle: .bar)
        pv.translatesAutoresizingMaskIntoConstraints = false
        pv.progressTintColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        pv.trackTintColor = UIColor(red: 35/255, green: 53/255, blue: 59/255, alpha: 1.0)
        pv.layer.cornerRadius = 4
        pv.clipsToBounds = true
        return pv
    }()

    private let statusMessageLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Ouvindo tom de voz... 0%", comment: "")
        label.font = .systemFont(ofSize: 12, weight: .bold)
        label.textColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        label.textAlignment = .center
        return label
    }()

    private let cancelButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setTitle(NSLocalizedString("Cancelar", comment: ""), for: .normal)
        btn.setTitleColor(UIColor(red: 160/255, green: 175/255, blue: 180/255, alpha: 1.0), for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        return btn
    }()

    private var progressTimer: Timer?
    private var progressCounter: Float = 0.0

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        startCalibrationProcess()
    }

    private func setupUI() {
        view.addSubview(backdropView)
        view.addSubview(containerView)

        containerView.addSubview(micIconView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(subtitleLabel)
        containerView.addSubview(progressView)
        containerView.addSubview(statusMessageLabel)
        containerView.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            backdropView.topAnchor.constraint(equalTo: view.topAnchor),
            backdropView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdropView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdropView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),

            micIconView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            micIconView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            micIconView.widthAnchor.constraint(equalToConstant: 48),
            micIconView.heightAnchor.constraint(equalToConstant: 48),

            titleLabel.topAnchor.constraint(equalTo: micIconView.bottomAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            subtitleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),

            progressView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 20),
            progressView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            progressView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            progressView.heightAnchor.constraint(equalToConstant: 8),

            statusMessageLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 10),
            statusMessageLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            statusMessageLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),

            cancelButton.topAnchor.constraint(equalTo: statusMessageLabel.bottomAnchor, constant: 16),
            cancelButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            cancelButton.heightAnchor.constraint(equalToConstant: 38),
            cancelButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16)
        ])

        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
    }

    private func startCalibrationProcess() {
        progressCounter = 0.0
        progressView.setProgress(0.0, animated: false)

        SentinelAcousticMonitor.shared.onVoiceCalibrationComplete = { [weak self] success, message in
            guard let self = self else { return }
            self.progressTimer?.invalidate()
            self.progressTimer = nil

            if success {
                self.progressView.setProgress(1.0, animated: true)
                self.statusMessageLabel.text = "✅ " + message
                self.statusMessageLabel.textColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    self.dismiss(animated: true) {
                        self.onComplete?()
                    }
                }
            } else {
                self.statusMessageLabel.text = "⚠️ " + message
                self.statusMessageLabel.textColor = UIColor(red: 239/255, green: 68/255, blue: 68/255, alpha: 1.0)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    self.dismiss(animated: true) {
                        self.onComplete?()
                    }
                }
            }
        }

        SentinelAcousticMonitor.shared.startVoiceCalibration()

        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.progressCounter += 0.1
            let progress = min(1.0, self.progressCounter / 4.5)
            self.progressView.setProgress(progress, animated: true)
            let pct = Int(progress * 100)
            self.statusMessageLabel.text = String(format: NSLocalizedString("Ouvindo tom de voz... %d%%", comment: ""), pct)
        }
    }

    @objc private func cancelTapped() {
        progressTimer?.invalidate()
        progressTimer = nil
        SentinelAcousticMonitor.shared.onVoiceCalibrationComplete = nil
        dismiss(animated: true, completion: nil)
    }
}
