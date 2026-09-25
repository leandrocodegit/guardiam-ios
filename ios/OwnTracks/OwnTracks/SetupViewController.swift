//
//  SetupViewController.swift
//  OwnTracks / Guardiam
//
//  Created for Guardiam - Medida Protetiva para Mulheres.
//  Tela de Setup nativa apresentada antes de abrir a tela inicial.
//  Exige o preenchimento de telefone, senha e contraSenha.
//  Retorna SetupResponseDTO (clientId, icon, username, password).
//

import UIKit
import CoreData

@objc class SetupViewController: UIViewController, UITextFieldDelegate {

    // MARK: - UI Components

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.showsVerticalScrollIndicator = false
        sv.alwaysBounceVertical = true
        return sv
    }()

    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var shieldImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        let config = UIImage.SymbolConfiguration(pointSize: 48, weight: .bold)
        if #available(iOS 13.0, *), let img = UIImage(systemName: "shield.lefthalf.filled", withConfiguration: config) {
            iv.image = img
        }
        iv.tintColor = UIColor(red: 244/255, green: 63/255, blue: 94/255, alpha: 1.0) // #F43F5E (Rose)
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private lazy var titleLabel: UILabel = {
        let l = UILabel()
        l.text = "Guardiam"
        l.font = UIFont.systemFont(ofSize: 34, weight: .bold)
        l.textColor = .white
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var subtitleLabel: UILabel = {
        let l = UILabel()
        l.text = "Configuração Inicial de Segurança"
        l.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        l.textColor = UIColor(red: 148/255, green: 163/255, blue: 184/255, alpha: 1.0)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var descriptionLabel: UILabel = {
        let l = UILabel()
        l.text = "Preencha suas credenciais para ativar o serviço de proteção no seu dispositivo."
        l.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        l.textColor = UIColor(white: 0.7, alpha: 1.0)
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // Campo 1: Telefone
    private lazy var telefoneContainer: UIView = createFieldContainer()
    private lazy var telefoneField: UITextField = {
        let tf = createTextField(placeholder: "Telefone (ex: 11999999999)")
        tf.keyboardType = .phonePad
        tf.textContentType = .telephoneNumber
        return tf
    }()

    // Campo 2: Senha
    private lazy var senhaContainer: UIView = createFieldContainer()
    private lazy var senhaField: UITextField = {
        let tf = createTextField(placeholder: "Senha")
        tf.isSecureTextEntry = true
        tf.textContentType = .password
        return tf
    }()

    // Campo 3: Contra-Senha
    private lazy var contraSenhaContainer: UIView = createFieldContainer()
    private lazy var contraSenhaField: UITextField = {
        let tf = createTextField(placeholder: "Contra-senha (Confirme a senha)")
        tf.isSecureTextEntry = true
        tf.textContentType = .password
        return tf
    }()

    // Botão Concluir Setup
    private lazy var submitButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Concluir Setup"
        config.image = UIImage(systemName: "checkmark.shield.fill")
        config.imagePlacement = .leading
        config.imagePadding = 10
        config.baseBackgroundColor = UIColor(red: 244/255, green: 63/255, blue: 94/255, alpha: 1.0) // #F43F5E
        config.baseForegroundColor = .white
        config.cornerStyle = .large
        let b = UIButton(configuration: config)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.layer.shadowColor = UIColor(red: 244/255, green: 63/255, blue: 94/255, alpha: 0.4).cgColor
        b.layer.shadowOffset = CGSize(width: 0, height: 6)
        b.layer.shadowRadius = 10
        b.layer.shadowOpacity = 0.6
        b.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)
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
        l.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        l.textColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0) // Teal
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var errorLabel: UILabel = {
        let l = UILabel()
        l.text = ""
        l.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        l.textColor = UIColor(red: 248/255, green: 113/255, blue: 113/255, alpha: 1.0) // Light Red
        l.textAlignment = .center
        l.numberOfLines = 0
        l.isHidden = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Properties

    @objc var managedObjectContext: NSManagedObjectContext?
    private var onSetupComplete: (() -> Void)?

    @objc func setCompletionHandler(_ handler: @escaping () -> Void) {
        onSetupComplete = handler
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 15/255, green: 23/255, blue: 42/255, alpha: 1.0) // #0F172A Slate Dark
        buildLayout()
        setupKeyboardDismissal()

        if SetupService.shared.isSetupCompleted {
            DispatchQueue.main.async { [weak self] in
                self?.dismissAndStart()
            }
        }
    }

    // MARK: - UI Helpers Construction

    private func createFieldContainer() -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor(red: 30/255, green: 41/255, blue: 59/255, alpha: 0.9) // #1E293B
        v.layer.cornerRadius = 14
        v.layer.borderWidth = 1
        v.layer.borderColor = UIColor(red: 51/255, green: 65/255, blue: 85/255, alpha: 0.8).cgColor
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }

    private func createTextField(placeholder: String) -> UITextField {
        let tf = UITextField()
        tf.placeholder = placeholder
        tf.textColor = .white
        tf.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        tf.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor(red: 148/255, green: 163/255, blue: 184/255, alpha: 0.7)]
        )
        tf.autocapitalizationType = .none
        tf.autocorrectionType = .no
        tf.delegate = self
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }

    private func createIconView(systemName: String) -> UIImageView {
        let iv = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        iv.image = UIImage(systemName: systemName, withConfiguration: config)
        iv.tintColor = UIColor(red: 148/255, green: 163/255, blue: 184/255, alpha: 1.0)
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }

    // MARK: - Layout Setup

    private func buildLayout() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        let phoneIcon = createIconView(systemName: "phone.fill")
        telefoneContainer.addSubview(phoneIcon)
        telefoneContainer.addSubview(telefoneField)

        let senhaIcon = createIconView(systemName: "lock.fill")
        senhaContainer.addSubview(senhaIcon)
        senhaContainer.addSubview(senhaField)

        let contraIcon = createIconView(systemName: "lock.shield.fill")
        contraSenhaContainer.addSubview(contraIcon)
        contraSenhaContainer.addSubview(contraSenhaField)

        let fieldsStack = UIStackView(arrangedSubviews: [
            telefoneContainer,
            senhaContainer,
            contraSenhaContainer
        ])
        fieldsStack.axis = .vertical
        fieldsStack.spacing = 14
        fieldsStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(shieldImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(descriptionLabel)
        contentView.addSubview(fieldsStack)
        contentView.addSubview(submitButton)
        contentView.addSubview(activityIndicator)
        contentView.addSubview(statusLabel)
        contentView.addSubview(errorLabel)

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

            shieldImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 32),
            shieldImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            shieldImageView.widthAnchor.constraint(equalToConstant: 72),
            shieldImageView.heightAnchor.constraint(equalToConstant: 72),

            titleLabel.topAnchor.constraint(equalTo: shieldImageView.bottomAnchor, constant: 12),
            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            descriptionLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 8),
            descriptionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            descriptionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),

            fieldsStack.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 28),
            fieldsStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            fieldsStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            telefoneContainer.heightAnchor.constraint(equalToConstant: 54),
            phoneIcon.leadingAnchor.constraint(equalTo: telefoneContainer.leadingAnchor, constant: 14),
            phoneIcon.centerYAnchor.constraint(equalTo: telefoneContainer.centerYAnchor),
            phoneIcon.widthAnchor.constraint(equalToConstant: 24),
            telefoneField.leadingAnchor.constraint(equalTo: phoneIcon.trailingAnchor, constant: 12),
            telefoneField.trailingAnchor.constraint(equalTo: telefoneContainer.trailingAnchor, constant: -14),
            telefoneField.centerYAnchor.constraint(equalTo: telefoneContainer.centerYAnchor),

            senhaContainer.heightAnchor.constraint(equalToConstant: 54),
            senhaIcon.leadingAnchor.constraint(equalTo: senhaContainer.leadingAnchor, constant: 14),
            senhaIcon.centerYAnchor.constraint(equalTo: senhaContainer.centerYAnchor),
            senhaIcon.widthAnchor.constraint(equalToConstant: 24),
            senhaField.leadingAnchor.constraint(equalTo: senhaIcon.trailingAnchor, constant: 12),
            senhaField.trailingAnchor.constraint(equalTo: senhaContainer.trailingAnchor, constant: -14),
            senhaField.centerYAnchor.constraint(equalTo: senhaContainer.centerYAnchor),

            contraSenhaContainer.heightAnchor.constraint(equalToConstant: 54),
            contraIcon.leadingAnchor.constraint(equalTo: contraSenhaContainer.leadingAnchor, constant: 14),
            contraIcon.centerYAnchor.constraint(equalTo: contraSenhaContainer.centerYAnchor),
            contraIcon.widthAnchor.constraint(equalToConstant: 24),
            contraSenhaField.leadingAnchor.constraint(equalTo: contraIcon.trailingAnchor, constant: 12),
            contraSenhaField.trailingAnchor.constraint(equalTo: contraSenhaContainer.trailingAnchor, constant: -14),
            contraSenhaField.centerYAnchor.constraint(equalTo: contraSenhaContainer.centerYAnchor),

            submitButton.topAnchor.constraint(equalTo: fieldsStack.bottomAnchor, constant: 28),
            submitButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            submitButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            submitButton.heightAnchor.constraint(equalToConstant: 54),

            activityIndicator.topAnchor.constraint(equalTo: submitButton.bottomAnchor, constant: 16),
            activityIndicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            statusLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 10),
            statusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),

            errorLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
            errorLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            errorLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),
            errorLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32)
        ])
    }

    private func setupKeyboardDismissal() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - Actions

    @objc private func submitTapped() {
        dismissKeyboard()
        clearError()

        guard let telefone = telefoneField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !telefone.isEmpty else {
            showError("O telefone é obrigatório.")
            return
        }

        guard let senha = senhaField.text, !senha.isEmpty else {
            showError("A senha é obrigatória.")
            return
        }

        guard let contraSenha = contraSenhaField.text, !contraSenha.isEmpty else {
            showError("A contra-senha é obrigatória.")
            return
        }

        guard senha == contraSenha else {
            showError("A senha e a contra-senha não conferem.")
            return
        }

        guard let moc = managedObjectContext ?? CoreData.sharedInstance().mainMOC else {
            showError("Armazenamento local (CoreData) indisponível.")
            return
        }

        setLoading(true, status: "Registrando dispositivo...")

        SetupService.shared.performDeviceSetup(
            telefone: telefone,
            senha: senha,
            contraSenha: contraSenha,
            context: moc
        ) { [weak self] success, errorMessage in
            guard let self = self else { return }

            if success {
                self.setLoading(false, status: "Setup concluído com sucesso!")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    self.dismissAndStart()
                }
            } else {
                self.setLoading(false, status: "")
                let msg = errorMessage ?? "Erro ao realizar o setup."
                self.showError(msg)
            }
        }
    }

    // MARK: - UI Helpers

    private func setLoading(_ loading: Bool, status: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.submitButton.isEnabled = !loading
            self.telefoneField.isEnabled = !loading
            self.senhaField.isEnabled = !loading
            self.contraSenhaField.isEnabled = !loading
            self.statusLabel.text = status
            if loading {
                self.activityIndicator.startAnimating()
            } else {
                self.activityIndicator.stopAnimating()
            }
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
            self.dismiss(animated: true) {
                self.onSetupComplete?()
            }
        }
    }

    // MARK: - UITextFieldDelegate

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == telefoneField {
            senhaField.becomeFirstResponder()
        } else if textField == senhaField {
            contraSenhaField.becomeFirstResponder()
        } else if textField == contraSenhaField {
            contraSenhaField.resignFirstResponder()
            submitTapped()
        }
        return true
    }
}
