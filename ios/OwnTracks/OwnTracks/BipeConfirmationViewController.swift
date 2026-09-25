import UIKit
import CoreData

@objc(BipeConfirmationViewController)
public class BipeConfirmationViewController: UIViewController {
    
    @objc public var pushTitle: String = "Novo Bipe"
    @objc public var pushBody: String = "Você recebeu um alerta de Bipe"
    @objc public var execucaoId: String?
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
    }
    
    private func setupView() {
        view.backgroundColor = .clear
        
        // Blur background
        let blurEffect = UIBlurEffect(style: .dark)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = view.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(blurEffectView)
        
        let containerView = UIView()
        containerView.backgroundColor = UIColor(white: 0.15, alpha: 0.9)
        containerView.layer.cornerRadius = 24
        containerView.layer.masksToBounds = true
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        let iconImageView = UIImageView(image: UIImage(systemName: "bell.badge.fill"))
        iconImageView.tintColor = .systemRed
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(iconImageView)
        
        let titleLabel = UILabel()
        titleLabel.text = pushTitle
        titleLabel.font = UIFont.systemFont(ofSize: 26, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)
        
        let bodyLabel = UILabel()
        bodyLabel.text = pushBody
        bodyLabel.font = UIFont.systemFont(ofSize: 17, weight: .regular)
        bodyLabel.textColor = UIColor(white: 0.8, alpha: 1.0)
        bodyLabel.textAlignment = .center
        bodyLabel.numberOfLines = 0
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(bodyLabel)
        
        let confirmButton = UIButton(type: .system)
        confirmButton.setTitle("CONFIRMAR", for: .normal)
        confirmButton.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .heavy)
        confirmButton.backgroundColor = .systemRed
        confirmButton.setTitleColor(.white, for: .normal)
        confirmButton.layer.cornerRadius = 16
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        containerView.addSubview(confirmButton)
        
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("Ignorar", for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        closeButton.setTitleColor(.lightGray, for: .normal)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        containerView.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.85),
            
            iconImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 40),
            iconImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 70),
            iconImageView.heightAnchor.constraint(equalToConstant: 70),
            
            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            bodyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            bodyLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            bodyLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            confirmButton.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 40),
            confirmButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            confirmButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            confirmButton.heightAnchor.constraint(equalToConstant: 60),
            
            closeButton.topAnchor.constraint(equalTo: confirmButton.bottomAnchor, constant: 16),
            closeButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            closeButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24),
            closeButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    @objc private func confirmTapped() {
        sendMqttStatus("COMPLETED")
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func closeTapped() {
        sendMqttStatus("FORCED")
        dismiss(animated: true, completion: nil)
    }
    
    private func sendMqttStatus(_ status: String) {
        if let appDelegate = UIApplication.shared.delegate as? OwnTracksAppDelegate {
            let moc = CoreData.sharedInstance().mainMOC
            var json = [String: Any]()
            json["_type"] = "bipe"
            json["status"] = status
            json["button"] = "VOL_TICK";
            
            if let execId = execucaoId, !execId.isEmpty {
                json["execucaoId"] = execId
            }
            
            if let userName = Settings.string(forKey: "user_preference", inMOC: moc), !userName.isEmpty {
                json["userName"] = userName
            }
            if let clienteId = Settings.string(forKey: "clientid_preference", inMOC: moc), !clienteId.isEmpty {
                json["clienteId"] = clienteId
            }
            
            if let tid = Settings.string(forKey: "trackerid_preference", inMOC: moc), !tid.isEmpty {
                json["tid"] = tid
            }
            if let deviceId = Settings.string(forKey: "deviceid_preference", inMOC: moc), !deviceId.isEmpty {
                json["deviceId"] = deviceId
            }
            var nickname = Settings.string(forKey: "device_name_preference", inMOC: moc)
            if nickname == nil || nickname!.isEmpty {
                nickname = Settings.string(forKey: "nickname_preference", inMOC: moc)
            }
            if let nick = nickname, !nick.isEmpty {
                json["nickname"] = nick
            }
            if let face = Settings.string(forKey: "icon", inMOC: moc), !face.isEmpty {
                json["face"] = face
            }
            if let color = Settings.string(forKey: "color", inMOC: moc), !color.isEmpty {
                json["color"] = color
            }
            
            if let payload = try? JSONSerialization.data(withJSONObject: json, options: []) {
                if appDelegate.connection == nil {
                    appDelegate.connection = Connection()
                    appDelegate.connection?.delegate = appDelegate
                    appDelegate.connection?.start()
                }
                
                let qos = MQTTQosLevel(rawValue: UInt8(Settings.int(forKey: "qos_preference", inMOC: moc))) ?? .atMostOnce
                let userName = Settings.string(forKey: "user_preference", inMOC: moc) ?? "user"
                let deviceId = Settings.string(forKey: "deviceid_preference", inMOC: moc) ?? "device"
                let topic = "owntracks/\(userName)/\(deviceId)/bipe"
                
                appDelegate.connection?.send(payload, topic: topic, topicAlias: nil, qos: qos, retain: false)
                print("[BipeConfirmationViewController] MQTT Payload bipe status \(status) enviado para \(topic)")
            }
        }
    }
}
