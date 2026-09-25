//
//  LoginViewController.swift
//  OwnTracks
//
//  Tela de login apresentada modalmente antes do app iniciar o monitoramento.
//  Fluxo: Keycloak OAuth (AppAuth) → /bipe/devices/setup → app normal
//

import UIKit

class LoginViewController: UIViewController {

    // MARK: - UI

    private lazy var logoImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        let img = UIImage(named: "OwnTracks-320.png") ?? UIImage(named: "OwnTracks-320") ?? UIImage(named: "AppIcon")
        iv.image = img?.withRenderingMode(.alwaysOriginal)
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private lazy var titleLabel: UILabel = {
        let l = UILabel()
        l.text = "Bipe.me"
        l.font = UIFont.systemFont(ofSize: 42, weight: .bold)
        l.textColor = .white
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var subtitleLabel: UILabel = {
        let l = UILabel()
        l.text = "Rastreamento inteligente"
        l.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        l.textColor = UIColor(white: 0.8, alpha: 1.0)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var loginButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Entrar com Bipe.me"
        config.image = UIImage(systemName: "person.badge.key.fill")
        config.imagePlacement = .leading
        config.imagePadding = 8
        config.baseBackgroundColor = .systemBlue
        config.baseForegroundColor = .white
        config.cornerStyle = .large
        let b = UIButton(configuration: config)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)
        return b
    }()

    private lazy var biometricButton: UIButton = {
        var config = UIButton.Configuration.tinted()
        config.title = "Entrar com \(BiometricAuthManager.shared.biometricName)"
        config.image = UIImage(systemName: BiometricAuthManager.shared.biometricIconName)
        config.imagePlacement = .leading
        config.imagePadding = 8
        config.baseBackgroundColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        config.baseForegroundColor = .white
        config.cornerStyle = .large
        let b = UIButton(configuration: config)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.isHidden = true
        b.addTarget(self, action: #selector(biometricLoginTapped), for: .touchUpInside)
        return b
    }()

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let a = UIActivityIndicatorView(style: .large)
        a.color = .white
        a.hidesWhenStopped = true
        a.translatesAutoresizingMaskIntoConstraints = false
        return a
    }()

    private lazy var statusLabel: UILabel = {
        let l = UILabel()
        l.text = ""
        l.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        l.textColor = UIColor(white: 0.8, alpha: 1.0)
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var errorLabel: UILabel = {
        let l = UILabel()
        l.text = ""
        l.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        l.textColor = .systemRed
        l.textAlignment = .center
        l.numberOfLines = 0
        l.isHidden = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Dependências

    private let authManager = AuthManager.shared
    private let setupService = SetupService.shared
    private var hasPromptedBiometrics = false
    @objc var managedObjectContext: NSManagedObjectContext?

    /// Bloco chamado quando o setup for concluído.
    /// Use `setCompletionHandler(_:)` para definir a partir do Objective-C.
    private var onSetupComplete: (() -> Void)?

    /// Define o handler de conclusão a partir do Objective-C (blocks são bridged automaticamente).
    @objc func setCompletionHandler(_ handler: @escaping () -> Void) {
        onSetupComplete = handler
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "primaryBackgroundColor") ?? UIColor(red: 11.0/255.0, green: 18.0/255.0, blue: 20.0/255.0, alpha: 1.0)
        buildLayout()

        // Se o setup já tiver sido concluído e o usuário estiver autorizado, dispensa a tela de setup
        if authManager.isAuthorized && setupService.isSetupCompleted {
            DispatchQueue.main.async { [weak self] in
                self?.dismissAndStart()
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if BiometricAuthManager.shared.canLoginWithBiometrics {
            biometricButton.isHidden = false
            if !hasPromptedBiometrics && !BiometricAuthManager.shared.isAuthenticating {
                hasPromptedBiometrics = true
                biometricLoginTapped()
            }
        }
    }

    // MARK: - Layout

    private func buildLayout() {
        let stack = UIStackView(arrangedSubviews: [
            logoImageView,
            titleLabel,
            subtitleLabel
        ])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        view.addSubview(loginButton)
        view.addSubview(biometricButton)
        view.addSubview(activityIndicator)
        view.addSubview(statusLabel)
        view.addSubview(errorLabel)

        NSLayoutConstraint.activate([
            logoImageView.widthAnchor.constraint(equalToConstant: 100),
            logoImageView.heightAnchor.constraint(equalToConstant: 100),

            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -90),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            loginButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loginButton.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 40),
            loginButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            loginButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            loginButton.heightAnchor.constraint(equalToConstant: 52),

            biometricButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            biometricButton.topAnchor.constraint(equalTo: loginButton.bottomAnchor, constant: 14),
            biometricButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            biometricButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            biometricButton.heightAnchor.constraint(equalToConstant: 52),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: biometricButton.bottomAnchor, constant: 20),

            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            errorLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
            errorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            errorLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
        ])
    }

    // MARK: - Ações

    @objc private func loginTapped() {
        setLoading(true, status: NSLocalizedString("Abrindo autenticação…", comment: ""))
        clearError()

        authManager.startLogin(presenting: self) { [weak self] success, error in
            guard let self = self else { return }

            if success {
                // Aguarda 0.5s para garantir que o modal de login (SFAuthenticationSession) fechou completamente
                // antes de tentarmos apresentar o alerta de FaceID ou dispensar a tela.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if self.setupService.isSetupCompleted {
                        self.dismissAndStart()
                    } else {
                        self.setStatus(NSLocalizedString("Configurando dispositivo…", comment: ""))
                        self.performSetup(isStandardLogin: true)
                    }
                }
            } else {
                let msg = error?.localizedDescription ?? NSLocalizedString("Erro desconhecido", comment: "")
                self.showError("\(NSLocalizedString("Falha no login", comment: "")): \(msg)")
                self.setLoading(false, status: "")
            }
        }
    }

    @objc private func biometricLoginTapped() {
        guard BiometricAuthManager.shared.canLoginWithBiometrics else { return }
        setLoading(true, status: "Autenticando via \(BiometricAuthManager.shared.biometricName)…")
        clearError()

        BiometricAuthManager.shared.authenticate { [weak self] success, error in
            guard let self = self else { return }

            if success {
                self.setStatus("Renovando sessão…")
                self.authManager.loginWithRefreshToken { [weak self] authSuccess, authError in
                    guard let self = self else { return }
                    if authSuccess {
                        if self.setupService.isSetupCompleted {
                            self.dismissAndStart()
                        } else {
                            self.setStatus("Configurando dispositivo…")
                            self.performSetup(isStandardLogin: false)
                        }
                    } else {
                        let msg = authError?.localizedDescription ?? "Sessão expirada"
                        self.showError("Falha na renovação da biometria: \(msg)")
                        self.setLoading(false, status: "")
                    }
                }
            } else {
                let msg = error?.localizedDescription ?? "Cancelado"
                self.showError("Autenticação por \(BiometricAuthManager.shared.biometricName) não concluída.")
                self.setLoading(false, status: "")
            }
        }
    }

    private func performSetup(isStandardLogin: Bool = false) {
        guard let moc = managedObjectContext else {
            showError("CoreData não disponível.")
            setLoading(false, status: "")
            return
        }

        if setupService.isSetupCompleted {
            NSLog("[LoginViewController] DeviceId já configurado e setup concluído. Pulando chamada de setup.")
            if isStandardLogin && BiometricAuthManager.shared.isBiometricsAvailable && !BiometricAuthManager.shared.isBiometricsEnabled {
                self.promptEnableBiometricsIfNeeded()
            } else {
                self.dismissAndStart()
            }
            return
        }

        setupService.performDeviceSetup(context: moc) { [weak self] success, error in
            guard let self = self else { return }

            if success {
                if isStandardLogin && BiometricAuthManager.shared.isBiometricsAvailable && !BiometricAuthManager.shared.isBiometricsEnabled {
                    self.promptEnableBiometricsIfNeeded()
                } else {
                    self.dismissAndStart()
                }
            } else {
                let msg = error?.localizedDescription ?? "Erro desconhecido"
                self.showError("Falha no setup: \(msg)")
                self.setLoading(false, status: "")
            }
        }
    }

    private func promptEnableBiometricsIfNeeded() {
        let name = BiometricAuthManager.shared.biometricName
        let alert = UIAlertController(
            title: "Ativar \(name)?",
            message: "Deseja ativar o \(name) para entrar no Bipe.me de forma rápida e segura nas próximas vezes?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Ativar \(name)", style: .default) { [weak self] _ in
            BiometricAuthManager.shared.isBiometricsEnabled = true
            if let token = AuthManager.shared.getRefreshToken() {
                BiometricAuthManager.shared.saveRefreshToken(token)
            }
            self?.dismissAndStart()
        })

        alert.addAction(UIAlertAction(title: "Agora Não", style: .cancel) { [weak self] _ in
            self?.dismissAndStart()
        })

        present(alert, animated: true)
    }

    // MARK: - Helpers de UI

    private func setLoading(_ loading: Bool, status: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.loginButton.isEnabled = !loading
            self.statusLabel.text = status
            if loading {
                self.activityIndicator.startAnimating()
            } else {
                self.activityIndicator.stopAnimating()
            }
        }
    }

    private func setStatus(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            self?.statusLabel.text = text
        }
    }

    private func showError(_ msg: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.errorLabel.text = msg
            self.errorLabel.isHidden = false
        }
    }

    private func clearError() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.errorLabel.text = ""
            self.errorLabel.isHidden = true
        }
    }

    private func dismissAndStart() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // O VC se dispensa e só então chama o handler — sem precisar de referência externa
            self.dismiss(animated: true) {
                self.onSetupComplete?()
            }
        }
    }
}
