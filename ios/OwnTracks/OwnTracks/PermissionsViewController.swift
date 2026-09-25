//
//  PermissionsViewController.swift
//  OwnTracks
//
//  Tela de permissões do Bipe.me (GPS, Localização em Segundo Plano, Câmera e Notificações).
//

import UIKit
import CoreLocation
import AVFoundation
import UserNotifications

final class PermissionsViewController: UIViewController {

    // MARK: - Subviews UI

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

    private let headerImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        iv.image = UIImage(named: "OwnTracks-320.png")
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Status das Permissões", comment: "")
        label.font = .systemFont(ofSize: 22, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Confira e gerencie as permissões necessárias para o funcionamento completo do Bipe.me no seu iPhone.", comment: "")
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = UIColor(red: 142/255, green: 157/255, blue: 161/255, alpha: 1.0)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let cardsStackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 16
        stack.distribution = .fill
        return stack
    }()

    private let settingsButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(NSLocalizedString("Abrir Configurações do iOS", comment: ""), for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        button.backgroundColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0) // Teal
        button.layer.cornerRadius = 12
        button.layer.masksToBounds = true
        return button
    }()

    // MARK: - Properties

    private let locationManager = CLLocationManager()
    private var gpsCardView: PermissionCardView!
    private var backgroundLocCardView: PermissionCardView!
    private var cameraCardView: PermissionCardView!
    private var notificationCardView: PermissionCardView!
    private var micCardView: PermissionCardView!

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigation()
        registerObservers()
        refreshPermissionsStatus()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup Navigation

    private func setupNavigation() {
        title = NSLocalizedString("Permissões", comment: "")
        navigationController?.navigationBar.barTintColor = UIColor(red: 11/255, green: 18/255, blue: 20/255, alpha: 1.0)
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]

        let closeBtn = UIBarButtonItem(title: NSLocalizedString("Fechar", comment: ""), style: .done, target: self, action: #selector(closeTapped))
        closeBtn.tintColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        navigationItem.rightBarButtonItem = closeBtn
    }

    @objc private func closeTapped() {
        dismiss(animated: true, completion: nil)
    }

    // MARK: - Setup UI Layout

    private func setupUI() {
        view.backgroundColor = UIColor(red: 11/255, green: 18/255, blue: 20/255, alpha: 1.0)

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        contentView.addSubview(headerImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(cardsStackView)
        contentView.addSubview(settingsButton)

        settingsButton.addTarget(self, action: #selector(openSystemSettingsTapped), for: .touchUpInside)

        // Build Cards
        setupCards()

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

            headerImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            headerImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            headerImageView.widthAnchor.constraint(equalToConstant: 72),
            headerImageView.heightAnchor.constraint(equalToConstant: 72),

            titleLabel.topAnchor.constraint(equalTo: headerImageView.bottomAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            cardsStackView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24),
            cardsStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardsStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            settingsButton.topAnchor.constraint(equalTo: cardsStackView.bottomAnchor, constant: 28),
            settingsButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            settingsButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            settingsButton.heightAnchor.constraint(equalToConstant: 50),
            settingsButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32)
        ])
    }

    private func setupCards() {
        gpsCardView = PermissionCardView(
            systemIcon: "location.fill",
            title: NSLocalizedString("1. GPS e Localização", comment: ""),
            descriptionText: NSLocalizedString("Necessário para obter a posição exata do seu dispositivo em tempo real e habilitar os recursos de rastreamento do Bipe.me.", comment: ""),
            isOptional: false
        )
        gpsCardView.onActionTapped = { [weak self] in
            self?.handleGPSAction()
        }

        backgroundLocCardView = PermissionCardView(
            systemIcon: "arrow.triangle.2.circlepath.circle.fill",
            title: NSLocalizedString("2. Localização em Segundo Plano", comment: ""),
            descriptionText: NSLocalizedString("Permite que o aplicativo continue enviando a localização com precisão mesmo quando estiver minimizado ou com a tela bloqueada.", comment: ""),
            isOptional: false
        )
        backgroundLocCardView.onActionTapped = { [weak self] in
            self?.handleBackgroundLocationAction()
        }

        cameraCardView = PermissionCardView(
            systemIcon: "camera.fill",
            title: NSLocalizedString("3. Câmera", comment: ""),
            descriptionText: NSLocalizedString("Necessário para tirar fotos do perfil/veículo e realizar a leitura de QR codes para associação rápida.", comment: ""),
            isOptional: false
        )
        cameraCardView.onActionTapped = { [weak self] in
            self?.handleCameraAction()
        }

        notificationCardView = PermissionCardView(
            systemIcon: "bell.badge.fill",
            title: NSLocalizedString("4. Notificações Push", comment: ""),
            descriptionText: NSLocalizedString("Permite que você receba alertas de emergência, confirmações de rotinas e avisos importantes do sistema em tempo real.", comment: ""),
            isOptional: true
        )
        notificationCardView.onActionTapped = { [weak self] in
            self?.handleNotificationAction()
        }

        micCardView = PermissionCardView(
            systemIcon: "mic.fill",
            title: NSLocalizedString("5. Microfone (Modo Sentinela)", comment: ""),
            descriptionText: NSLocalizedString("Permite a análise acústica passiva on-device para detecção preventiva de emergência em casos de violência doméstica. 100% em RAM, nenhum áudio é gravado.", comment: ""),
            isOptional: true
        )
        micCardView.onActionTapped = { [weak self] in
            self?.handleMicrophoneAction()
        }

        cardsStackView.addArrangedSubview(gpsCardView)
        cardsStackView.addArrangedSubview(backgroundLocCardView)
        cardsStackView.addArrangedSubview(cameraCardView)
        cardsStackView.addArrangedSubview(notificationCardView)
        cardsStackView.addArrangedSubview(micCardView)
    }

    // MARK: - Observers

    private func registerObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func appDidBecomeActive() {
        refreshPermissionsStatus()
    }

    // MARK: - Refresh Permissions Status

    private func refreshPermissionsStatus() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // 1. GPS / Foreground Location
            let servicesEnabled = CLLocationManager.locationServicesEnabled()
            let locStatus = CLLocationManager.authorizationStatus()

            if !servicesEnabled {
                self.gpsCardView.updateStatus(granted: false, badgeText: NSLocalizedString("GPS Desativado", comment: ""), actionTitle: NSLocalizedString("Ativar nas Configurações", comment: ""))
            } else if locStatus == .authorizedWhenInUse || locStatus == .authorizedAlways {
                self.gpsCardView.updateStatus(granted: true, badgeText: NSLocalizedString("Permitido", comment: ""), actionTitle: nil)
            } else if locStatus == .notDetermined {
                self.gpsCardView.updateStatus(granted: false, badgeText: NSLocalizedString("Não Configurado", comment: ""), actionTitle: NSLocalizedString("Permitir Acesso", comment: ""))
            } else {
                self.gpsCardView.updateStatus(granted: false, badgeText: NSLocalizedString("Negado", comment: ""), actionTitle: NSLocalizedString("Abrir Configurações", comment: ""))
            }

            // 2. Background Location
            if locStatus == .authorizedAlways {
                self.backgroundLocCardView.updateStatus(granted: true, badgeText: NSLocalizedString("Permitido Sempre", comment: ""), actionTitle: nil)
            } else if locStatus == .authorizedWhenInUse {
                self.backgroundLocCardView.updateStatus(granted: false, badgeText: NSLocalizedString("Apenas em Uso", comment: ""), actionTitle: NSLocalizedString("Alterar para 'Sempre'", comment: ""))
            } else if locStatus == .notDetermined {
                self.backgroundLocCardView.updateStatus(granted: false, badgeText: NSLocalizedString("Não Configurado", comment: ""), actionTitle: NSLocalizedString("Permitir 'Sempre'", comment: ""))
            } else {
                self.backgroundLocCardView.updateStatus(granted: false, badgeText: NSLocalizedString("Negado", comment: ""), actionTitle: NSLocalizedString("Abrir Configurações", comment: ""))
            }

            // 3. Camera
            let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
            switch cameraStatus {
            case .authorized:
                self.cameraCardView.updateStatus(granted: true, badgeText: NSLocalizedString("Permitido", comment: ""), actionTitle: nil)
            case .notDetermined:
                self.cameraCardView.updateStatus(granted: false, badgeText: NSLocalizedString("Não Configurado", comment: ""), actionTitle: NSLocalizedString("Solicitar Permissão", comment: ""))
            default:
                self.cameraCardView.updateStatus(granted: false, badgeText: NSLocalizedString("Negado", comment: ""), actionTitle: NSLocalizedString("Abrir Configurações", comment: ""))
            }

            // 4. Notifications
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                DispatchQueue.main.async {
                    switch settings.authorizationStatus {
                    case .authorized, .provisional:
                        self.notificationCardView.updateStatus(granted: true, badgeText: NSLocalizedString("Ativado", comment: ""), actionTitle: nil)
                    case .notDetermined:
                        self.notificationCardView.updateStatus(granted: false, badgeText: NSLocalizedString("Opcional", comment: ""), actionTitle: NSLocalizedString("Ativar Notificações", comment: ""))
                    default:
                        self.notificationCardView.updateStatus(granted: false, badgeText: NSLocalizedString("Desativado (Opcional)", comment: ""), actionTitle: NSLocalizedString("Abrir Configurações", comment: ""))
                    }
                }
            }

            // 5. Microphone (Sentinel Mode)
            let micStatus = AVAudioSession.sharedInstance().recordPermission
            switch micStatus {
            case .granted:
                self.micCardView.updateStatus(granted: true, badgeText: NSLocalizedString("Permitido", comment: ""), actionTitle: nil)
            case .undetermined:
                self.micCardView.updateStatus(granted: false, badgeText: NSLocalizedString("Opcional", comment: ""), actionTitle: NSLocalizedString("Ativar Microfone", comment: ""))
            default:
                self.micCardView.updateStatus(granted: false, badgeText: NSLocalizedString("Desativado (Opcional)", comment: ""), actionTitle: NSLocalizedString("Abrir Configurações", comment: ""))
            }
        }
    }

    // MARK: - Permission Actions

    private func handleGPSAction() {
        let status = CLLocationManager.authorizationStatus()
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else {
            openSystemSettingsTapped()
        }
    }

    private func handleBackgroundLocationAction() {
        let status = CLLocationManager.authorizationStatus()
        if status == .notDetermined {
            locationManager.requestAlwaysAuthorization()
        } else {
            openSystemSettingsTapped()
        }
    }

    private func handleCameraAction() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { [weak self] _ in
                self?.refreshPermissionsStatus()
            }
        } else {
            openSystemSettingsTapped()
        }
    }

    private func handleMicrophoneAction() {
        let status = AVAudioSession.sharedInstance().recordPermission
        if status == .undetermined {
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] _ in
                self?.refreshPermissionsStatus()
            }
        } else {
            openSystemSettingsTapped()
        }
    }

    private func handleNotificationAction() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            if settings.authorizationStatus == .notDetermined {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
                    self?.refreshPermissionsStatus()
                }
            } else {
                DispatchQueue.main.async {
                    self?.openSystemSettingsTapped()
                }
            }
        }
    }

    @objc private func openSystemSettingsTapped() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }
}

// MARK: - Componente Card de Permissão UI

private final class PermissionCardView: UIView {

    var onActionTapped: (() -> Void)?

    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        iv.tintColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 16, weight: .bold)
        label.textColor = .white
        label.numberOfLines = 0
        return label
    }()

    private let badgeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 11, weight: .bold)
        label.textColor = .white
        label.layer.cornerRadius = 6
        label.layer.masksToBounds = true
        label.textAlignment = .center
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = UIColor(red: 160/255, green: 175/255, blue: 180/255, alpha: 1.0)
        label.numberOfLines = 0
        return label
    }()

    private let actionButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        button.setTitleColor(UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0), for: .normal)
        button.contentHorizontalAlignment = .leading
        return button
    }()

    private let bottomStackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        return stack
    }()

    init(systemIcon: String, title: String, descriptionText: String, isOptional: Bool) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor(red: 22/255, green: 34/255, blue: 38/255, alpha: 1.0)
        layer.cornerRadius = 14
        layer.borderWidth = 1
        layer.borderColor = UIColor(red: 35/255, green: 53/255, blue: 59/255, alpha: 1.0).cgColor

        if #available(iOS 13.0, *), let img = UIImage(systemName: systemIcon) {
            iconImageView.image = img
        } else {
            iconImageView.image = UIImage(named: "OwnTracks-320.png")
        }

        titleLabel.text = title
        descriptionLabel.text = descriptionText

        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(iconImageView)
        addSubview(titleLabel)
        addSubview(descriptionLabel)
        addSubview(bottomStackView)

        bottomStackView.addArrangedSubview(badgeLabel)
        bottomStackView.addArrangedSubview(actionButton)

        actionButton.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            iconImageView.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            iconImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.centerYAnchor.constraint(equalTo: iconImageView.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            descriptionLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 10),
            descriptionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            descriptionLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            bottomStackView.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 12),
            bottomStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            bottomStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            bottomStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),

            badgeLabel.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    @objc private func buttonTapped() {
        onActionTapped?()
    }

    func updateStatus(granted: Bool, badgeText: String, actionTitle: String?) {
        badgeLabel.text = "  \(badgeText)  "
        if granted {
            badgeLabel.backgroundColor = UIColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 0.25)
            badgeLabel.textColor = UIColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 1.0)
        } else {
            badgeLabel.backgroundColor = UIColor(red: 245/255, green: 158/255, blue: 11/255, alpha: 0.25)
            badgeLabel.textColor = UIColor(red: 245/255, green: 158/255, blue: 11/255, alpha: 1.0)
        }

        if let title = actionTitle, !title.isEmpty {
            actionButton.setTitle("➔ \(title)", for: .normal)
            actionButton.isHidden = false
        } else {
            actionButton.setTitle(nil, for: .normal)
            actionButton.isHidden = true
        }
    }
}
