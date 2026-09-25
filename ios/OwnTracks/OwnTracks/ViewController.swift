//
//  ViewController.swift
//  OwnTracks / Guardiam - Medida Protetiva para Mulheres
//
//  Created by Christoph Krey on 19.03.26.
//  Updated for Guardiam: 100% Native Interface (Sem WebKit).
//  Acesso imediato sem login.
//

import Foundation
import UIKit
import MapKit
import AppIntents
import AudioToolbox
#if canImport(ActivityKit)
import ActivityKit
#endif

@objc class ViewController: UIViewController, MKMapViewDelegate, NSFetchedResultsControllerDelegate {
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var actionButton: UIBarButtonItem!
    @IBOutlet weak var privacyButton: UIBarButtonItem!
    @IBOutlet weak var askForMapButton: UIBarButtonItem!
    @IBOutlet weak var accuracyButton: UIBarButtonItem!
    
    var trackingButton: MKUserTrackingButton? = nil
    var modes: UISegmentedControl? = nil
    var mapMode: UISegmentedControl? = nil
    var scaleView: MKScaleView? = nil
    var offlineView: UIView? = nil
    
    var osmRenderer: MKTileOverlayRenderer? = nil
    var osmCopyright: UITextField? = nil
    var osmOverlay: MKTileOverlay? = nil
    
    var suspendAutomaticTrackingOfChangesInManagedObjectContext: Bool = false
    var warningShown: Bool = false
    var initialCenter: Bool = false
    
    var frcFriends: NSFetchedResultsController<Friend>? = nil
    var frcRegions: NSFetchedResultsController<Region>? = nil
    var frcWaypoints: NSFetchedResultsController<Waypoint>? = nil
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    // MARK: - UI Components Nativa (Guardiam - Medida Protetiva)

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

    // Header View
    private let headerContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let shieldImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .bold)
        if #available(iOS 13.0, *), let img = UIImage(systemName: "shield.lefthalf.filled", withConfiguration: config) {
            iv.image = img
        }
        iv.tintColor = UIColor(red: 244/255, green: 63/255, blue: 94/255, alpha: 1.0) // #F43F5E (Rose)
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let headerTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Guardiam"
        label.font = UIFont.systemFont(ofSize: 26, weight: .bold)
        label.textColor = .white
        return label
    }()

    private let headerSubtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Medida Protetiva & Segurança Pessoal"
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = UIColor(red: 148/255, green: 163/255, blue: 184/255, alpha: 1.0) // #94A3B8
        return label
    }()

    private let settingsButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        if #available(iOS 13.0, *), let img = UIImage(systemName: "gearshape.fill", withConfiguration: config) {
            button.setImage(img, for: .normal)
        } else {
            button.setTitle("⚙︎", for: .normal)
        }
        button.tintColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0) // #14B8A6
        button.backgroundColor = UIColor(red: 30/255, green: 41/255, blue: 59/255, alpha: 0.85) // #1E293B
        button.layer.cornerRadius = 22
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor(red: 51/255, green: 65/255, blue: 85/255, alpha: 0.8).cgColor
        return button
    }()

    // Card de Status
    private let statusCardView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 30/255, green: 41/255, blue: 59/255, alpha: 0.85)
        view.layer.cornerRadius = 16
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor(red: 51/255, green: 65/255, blue: 85/255, alpha: 0.8).cgColor
        return view
    }()

    private let statusDotView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 6
        view.backgroundColor = UIColor.systemGray
        return view
    }()

    private let statusHeaderLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "STATUS DA PROTEÇÃO"
        label.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        label.textColor = UIColor(red: 148/255, green: 163/255, blue: 184/255, alpha: 1.0)
        return label
    }()

    private let statusDescriptionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Proteção Pronta • Modo Sentinela Desativado"
        label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .white
        label.numberOfLines = 0
        return label
    }()

    private let decibelBadgeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "-- dB"
        label.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        label.textColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        label.backgroundColor = UIColor(red: 13/255, green: 148/255, blue: 136/255, alpha: 0.2)
        label.layer.cornerRadius = 10
        label.clipsToBounds = true
        label.textAlignment = .center
        label.isHidden = true
        return label
    }()

    // Botão 1: ACIONAR EMERGÊNCIA (SOS)
    private let emergencyCardView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 220/255, green: 38/255, blue: 38/255, alpha: 1.0) // Red #DC2626
        view.layer.cornerRadius = 24
        view.layer.shadowColor = UIColor(red: 239/255, green: 68/255, blue: 68/255, alpha: 0.55).cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 8)
        view.layer.shadowRadius = 14
        view.layer.shadowOpacity = 0.75
        return view
    }()

    private let emergencyButtonTouch: UIButton = {
        let btn = UIButton(type: .custom)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    private let emergencyIconView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 34, weight: .bold)
        if #available(iOS 13.0, *), let img = UIImage(systemName: "exclamationmark.shield.fill", withConfiguration: config) {
            iv.image = img
        } else if #available(iOS 13.0, *), let img = UIImage(systemName: "bell.badge.fill", withConfiguration: config) {
            iv.image = img
        }
        iv.tintColor = .white
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let emergencyTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "ACIONAR EMERGÊNCIA"
        label.font = UIFont.systemFont(ofSize: 20, weight: .heavy)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    private let emergencySubtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Envia alerta imediato de SOS com sua localização GPS em tempo real"
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = UIColor(white: 0.95, alpha: 0.9)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    // Botão 2: ATIVAR/DESATIVAR MODO SENTINELA
    private let sentinelCardView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 1.0) // Teal #10B981
        view.layer.cornerRadius = 20
        view.layer.shadowColor = UIColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 0.35).cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 6)
        view.layer.shadowRadius = 12
        view.layer.shadowOpacity = 0.5
        return view
    }()

    private let sentinelButtonTouch: UIButton = {
        let btn = UIButton(type: .custom)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    private let sentinelIconView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 26, weight: .bold)
        if #available(iOS 13.0, *), let img = UIImage(systemName: "ear.fill", withConfiguration: config) {
            iv.image = img
        } else if #available(iOS 13.0, *), let img = UIImage(systemName: "mic.fill", withConfiguration: config) {
            iv.image = img
        }
        iv.tintColor = .white
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let sentinelTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "ATIVAR MODO SENTINELA"
        label.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    private let sentinelSubtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Escuta acústica passiva on-device para palavras de socorro e ruídos de emergência"
        label.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        label.textColor = UIColor(white: 0.95, alpha: 0.85)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    // Cards Informativos
    private let infoGridStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 12
        return stack
    }()

    private let gpsCardView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 30/255, green: 41/255, blue: 59/255, alpha: 0.8)
        view.layer.cornerRadius = 14
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor(red: 51/255, green: 65/255, blue: 85/255, alpha: 0.6).cgColor
        return view
    }()

    private let contactsCardView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 30/255, green: 41/255, blue: 59/255, alpha: 0.8)
        view.layer.cornerRadius = 14
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor(red: 51/255, green: 65/255, blue: 85/255, alpha: 0.6).cgColor
        return view
    }()

    private let contactsCountLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "0 Contatos"
        label.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        label.textColor = .white
        return label
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.setNavigationBarHidden(true, animated: false)
        navigationController?.setToolbarHidden(true, animated: false)
        tabBarController?.tabBar.isHidden = true
        mapView?.removeFromSuperview()

        view.backgroundColor = UIColor(red: 15/255, green: 23/255, blue: 42/255, alpha: 1.0) // Deep Navy #0F172A

        setupNativeUI()
        setupSentinelListeners()
        updateSentinelUIState()
        
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        navigationController?.setToolbarHidden(true, animated: false)
        tabBarController?.tabBar.isHidden = true
        updateSentinelUIState()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateSentinelUIState()
    }

    @objc private func appDidEnterBackground() {
        // App background handling
    }
    
    @objc private func appWillEnterForeground() {
        updateSentinelUIState()
    }

    // MARK: - Native UI Layout Setup

    private func setupNativeUI() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])

        // 1. Header
        contentView.addSubview(headerContainerView)
        headerContainerView.addSubview(shieldImageView)
        headerContainerView.addSubview(headerTitleLabel)
        headerContainerView.addSubview(headerSubtitleLabel)
        headerContainerView.addSubview(settingsButton)

        NSLayoutConstraint.activate([
            headerContainerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            headerContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            headerContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            headerContainerView.heightAnchor.constraint(equalToConstant: 54),

            shieldImageView.leadingAnchor.constraint(equalTo: headerContainerView.leadingAnchor),
            shieldImageView.centerYAnchor.constraint(equalTo: headerContainerView.centerYAnchor),
            shieldImageView.widthAnchor.constraint(equalToConstant: 36),
            shieldImageView.heightAnchor.constraint(equalToConstant: 36),

            headerTitleLabel.leadingAnchor.constraint(equalTo: shieldImageView.trailingAnchor, constant: 10),
            headerTitleLabel.topAnchor.constraint(equalTo: headerContainerView.topAnchor, constant: 2),

            headerSubtitleLabel.leadingAnchor.constraint(equalTo: shieldImageView.trailingAnchor, constant: 10),
            headerSubtitleLabel.topAnchor.constraint(equalTo: headerTitleLabel.bottomAnchor, constant: 2),

            settingsButton.trailingAnchor.constraint(equalTo: headerContainerView.trailingAnchor),
            settingsButton.centerYAnchor.constraint(equalTo: headerContainerView.centerYAnchor),
            settingsButton.widthAnchor.constraint(equalToConstant: 44),
            settingsButton.heightAnchor.constraint(equalToConstant: 44)
        ])

        settingsButton.addTarget(self, action: #selector(openSentinelSettings), for: .touchUpInside)

        // 2. Status Card
        contentView.addSubview(statusCardView)
        statusCardView.addSubview(statusDotView)
        statusCardView.addSubview(statusHeaderLabel)
        statusCardView.addSubview(statusDescriptionLabel)
        statusCardView.addSubview(decibelBadgeLabel)

        NSLayoutConstraint.activate([
            statusCardView.topAnchor.constraint(equalTo: headerContainerView.bottomAnchor, constant: 20),
            statusCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            statusCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            statusDotView.leadingAnchor.constraint(equalTo: statusCardView.leadingAnchor, constant: 16),
            statusDotView.topAnchor.constraint(equalTo: statusCardView.topAnchor, constant: 18),
            statusDotView.widthAnchor.constraint(equalToConstant: 12),
            statusDotView.heightAnchor.constraint(equalToConstant: 12),

            statusHeaderLabel.centerYAnchor.constraint(equalTo: statusDotView.centerYAnchor),
            statusHeaderLabel.leadingAnchor.constraint(equalTo: statusDotView.trailingAnchor, constant: 8),

            decibelBadgeLabel.trailingAnchor.constraint(equalTo: statusCardView.trailingAnchor, constant: -16),
            decibelBadgeLabel.centerYAnchor.constraint(equalTo: statusDotView.centerYAnchor),
            decibelBadgeLabel.widthAnchor.constraint(equalToConstant: 58),
            decibelBadgeLabel.heightAnchor.constraint(equalToConstant: 24),

            statusDescriptionLabel.topAnchor.constraint(equalTo: statusHeaderLabel.bottomAnchor, constant: 8),
            statusDescriptionLabel.leadingAnchor.constraint(equalTo: statusCardView.leadingAnchor, constant: 16),
            statusDescriptionLabel.trailingAnchor.constraint(equalTo: statusCardView.trailingAnchor, constant: -16),
            statusDescriptionLabel.bottomAnchor.constraint(equalTo: statusCardView.bottomAnchor, constant: -16)
        ])

        // 3. Botão 1: ACIONAR EMERGÊNCIA (SOS)
        contentView.addSubview(emergencyCardView)
        emergencyCardView.addSubview(emergencyIconView)
        emergencyCardView.addSubview(emergencyTitleLabel)
        emergencyCardView.addSubview(emergencySubtitleLabel)
        emergencyCardView.addSubview(emergencyButtonTouch)

        NSLayoutConstraint.activate([
            emergencyCardView.topAnchor.constraint(equalTo: statusCardView.bottomAnchor, constant: 24),
            emergencyCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            emergencyCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            emergencyCardView.heightAnchor.constraint(equalToConstant: 140),

            emergencyIconView.topAnchor.constraint(equalTo: emergencyCardView.topAnchor, constant: 18),
            emergencyIconView.centerXAnchor.constraint(equalTo: emergencyCardView.centerXAnchor),
            emergencyIconView.widthAnchor.constraint(equalToConstant: 40),
            emergencyIconView.heightAnchor.constraint(equalToConstant: 40),

            emergencyTitleLabel.topAnchor.constraint(equalTo: emergencyIconView.bottomAnchor, constant: 8),
            emergencyTitleLabel.centerXAnchor.constraint(equalTo: emergencyCardView.centerXAnchor),

            emergencySubtitleLabel.topAnchor.constraint(equalTo: emergencyTitleLabel.bottomAnchor, constant: 4),
            emergencySubtitleLabel.leadingAnchor.constraint(equalTo: emergencyCardView.leadingAnchor, constant: 16),
            emergencySubtitleLabel.trailingAnchor.constraint(equalTo: emergencyCardView.trailingAnchor, constant: -16),

            emergencyButtonTouch.topAnchor.constraint(equalTo: emergencyCardView.topAnchor),
            emergencyButtonTouch.leadingAnchor.constraint(equalTo: emergencyCardView.leadingAnchor),
            emergencyButtonTouch.trailingAnchor.constraint(equalTo: emergencyCardView.trailingAnchor),
            emergencyButtonTouch.bottomAnchor.constraint(equalTo: emergencyCardView.bottomAnchor)
        ])

        emergencyButtonTouch.addTarget(self, action: #selector(emergencyButtonTapped), for: .touchUpInside)

        // 4. Botão 2: ATIVAR MODO SENTINELA
        contentView.addSubview(sentinelCardView)
        sentinelCardView.addSubview(sentinelIconView)
        sentinelCardView.addSubview(sentinelTitleLabel)
        sentinelCardView.addSubview(sentinelSubtitleLabel)
        sentinelCardView.addSubview(sentinelButtonTouch)

        NSLayoutConstraint.activate([
            sentinelCardView.topAnchor.constraint(equalTo: emergencyCardView.bottomAnchor, constant: 18),
            sentinelCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            sentinelCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            sentinelCardView.heightAnchor.constraint(equalToConstant: 120),

            sentinelIconView.topAnchor.constraint(equalTo: sentinelCardView.topAnchor, constant: 16),
            sentinelIconView.centerXAnchor.constraint(equalTo: sentinelCardView.centerXAnchor),
            sentinelIconView.widthAnchor.constraint(equalToConstant: 32),
            sentinelIconView.heightAnchor.constraint(equalToConstant: 32),

            sentinelTitleLabel.topAnchor.constraint(equalTo: sentinelIconView.bottomAnchor, constant: 6),
            sentinelTitleLabel.centerXAnchor.constraint(equalTo: sentinelCardView.centerXAnchor),

            sentinelSubtitleLabel.topAnchor.constraint(equalTo: sentinelTitleLabel.bottomAnchor, constant: 4),
            sentinelSubtitleLabel.leadingAnchor.constraint(equalTo: sentinelCardView.leadingAnchor, constant: 16),
            sentinelSubtitleLabel.trailingAnchor.constraint(equalTo: sentinelCardView.trailingAnchor, constant: -16),

            sentinelButtonTouch.topAnchor.constraint(equalTo: sentinelCardView.topAnchor),
            sentinelButtonTouch.leadingAnchor.constraint(equalTo: sentinelCardView.leadingAnchor),
            sentinelButtonTouch.trailingAnchor.constraint(equalTo: sentinelCardView.trailingAnchor),
            sentinelButtonTouch.bottomAnchor.constraint(equalTo: sentinelCardView.bottomAnchor)
        ])

        sentinelButtonTouch.addTarget(self, action: #selector(sentinelButtonTapped), for: .touchUpInside)

        // 5. Info Grid
        contentView.addSubview(infoGridStack)
        infoGridStack.addArrangedSubview(gpsCardView)
        infoGridStack.addArrangedSubview(contactsCardView)

        NSLayoutConstraint.activate([
            infoGridStack.topAnchor.constraint(equalTo: sentinelCardView.bottomAnchor, constant: 20),
            infoGridStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            infoGridStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            infoGridStack.heightAnchor.constraint(equalToConstant: 80),
            infoGridStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -30)
        ])

        setupGPSCardSubviews()
        setupContactsCardSubviews()
    }

    private func setupGPSCardSubviews() {
        let icon = UIImageView()
        icon.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 13.0, *), let img = UIImage(systemName: "location.fill") {
            icon.image = img
        }
        icon.tintColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        icon.contentMode = .scaleAspectFit

        let title = UILabel()
        title.translatesAutoresizingMaskIntoConstraints = false
        title.text = "GPS Ativo"
        title.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        title.textColor = .white

        let sub = UILabel()
        sub.translatesAutoresizingMaskIntoConstraints = false
        sub.text = "Rastreamento Contínuo"
        sub.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        sub.textColor = UIColor(red: 148/255, green: 163/255, blue: 184/255, alpha: 1.0)

        gpsCardView.addSubview(icon)
        gpsCardView.addSubview(title)
        gpsCardView.addSubview(sub)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: gpsCardView.leadingAnchor, constant: 14),
            icon.topAnchor.constraint(equalTo: gpsCardView.topAnchor, constant: 16),
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20),

            title.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            title.centerYAnchor.constraint(equalTo: icon.centerYAnchor),

            sub.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 4),
            sub.leadingAnchor.constraint(equalTo: gpsCardView.leadingAnchor, constant: 14),
            sub.trailingAnchor.constraint(equalTo: gpsCardView.trailingAnchor, constant: -10)
        ])
    }

    private func setupContactsCardSubviews() {
        let icon = UIImageView()
        icon.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 13.0, *), let img = UIImage(systemName: "person.2.fill") {
            icon.image = img
        }
        icon.tintColor = UIColor(red: 244/255, green: 63/255, blue: 94/255, alpha: 1.0)
        icon.contentMode = .scaleAspectFit

        let sub = UILabel()
        sub.translatesAutoresizingMaskIntoConstraints = false
        sub.text = "Contatos Notificados"
        sub.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        sub.textColor = UIColor(red: 148/255, green: 163/255, blue: 184/255, alpha: 1.0)

        contactsCardView.addSubview(icon)
        contactsCardView.addSubview(contactsCountLabel)
        contactsCardView.addSubview(sub)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: contactsCardView.leadingAnchor, constant: 14),
            icon.topAnchor.constraint(equalTo: contactsCardView.topAnchor, constant: 16),
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20),

            contactsCountLabel.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            contactsCountLabel.centerYAnchor.constraint(equalTo: icon.centerYAnchor),

            sub.topAnchor.constraint(equalTo: contactsCountLabel.bottomAnchor, constant: 4),
            sub.leadingAnchor.constraint(equalTo: contactsCardView.leadingAnchor, constant: 14),
            sub.trailingAnchor.constraint(equalTo: contactsCardView.trailingAnchor, constant: -10)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(openSentinelSettings))
        contactsCardView.addGestureRecognizer(tap)
        contactsCardView.isUserInteractionEnabled = true
    }

    // MARK: - Sentinel Listeners & UI State Updates

    private func setupSentinelListeners() {
        SentinelAcousticMonitor.shared.onStateChange = { [weak self] _ in
            self?.updateSentinelUIState()
        }

        SentinelAcousticMonitor.shared.onDecibelUpdate = { [weak self] db in
            DispatchQueue.main.async {
                self?.decibelBadgeLabel.text = String(format: "%.0f dB", db)
            }
        }
    }

    private func updateSentinelUIState() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let isMonitoring = SentinelAcousticMonitor.shared.isMonitoring
            let state = SentinelAcousticMonitor.shared.currentState
            
            if isMonitoring {
                self.statusDotView.backgroundColor = UIColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 1.0)
                switch state {
                case .gracePeriod:
                    self.statusDescriptionLabel.text = "Modo Sentinela: Período de Graça (Iniciando...)"
                case .attentionMode:
                    self.statusDescriptionLabel.text = "Modo Sentinela: Atenção Elevada (Analisando Ruídos)"
                case .emergencyDispatched:
                    self.statusDescriptionLabel.text = "Modo Sentinela: Emergência Disparada!"
                default:
                    self.statusDescriptionLabel.text = "Modo Sentinela: Monitorando Ruídos e Frases de Socorro"
                }
                
                self.sentinelTitleLabel.text = "DESATIVAR MODO SENTINELA"
                self.sentinelCardView.backgroundColor = UIColor(red: 217/255, green: 119/255, blue: 6/255, alpha: 1.0) // Amber #D97706
                self.sentinelCardView.layer.shadowColor = UIColor(red: 217/255, green: 119/255, blue: 6/255, alpha: 0.4).cgColor
                self.decibelBadgeLabel.isHidden = false
            } else {
                self.statusDotView.backgroundColor = .systemGray
                self.statusDescriptionLabel.text = "Proteção Pronta • Modo Sentinela Desativado"
                self.sentinelTitleLabel.text = "ATIVAR MODO SENTINELA"
                self.sentinelCardView.backgroundColor = UIColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 1.0) // Teal #10B981
                self.sentinelCardView.layer.shadowColor = UIColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 0.35).cgColor
                self.decibelBadgeLabel.isHidden = true
                self.decibelBadgeLabel.text = "-- dB"
            }
            
            let contactsCount = SentinelAcousticMonitor.shared.getTrustedContacts().count
            self.contactsCountLabel.text = "\(contactsCount) Contato\(contactsCount == 1 ? "" : "s")"
        }
    }

    // MARK: - Actions

    @objc private func openSentinelSettings() {
        let sentinelVC = SentinelViewController()
        let navController = UINavigationController(rootViewController: sentinelVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true, completion: nil)
    }

    @objc private func emergencyButtonTapped() {
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()

        let alert = UIAlertController(title: "ACIONAR EMERGÊNCIA",
                                      message: "Tem certeza de que deseja enviar o alerta imediato de emergência com sua localização em tempo real?",
                                      preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Sim, Enviar Alerta Agora!", style: .destructive, handler: { _ in
            BipeEmergencyHelper.sendEmergencyAlert { [weak self] success in
                DispatchQueue.main.async {
                    let successAlert = UIAlertController(title: "Alerta Enviado!",
                                                          message: "Seu alerta de emergência e sua localização em tempo real foram transmitidos com sucesso.",
                                                          preferredStyle: .alert)
                    successAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    self?.present(successAlert, animated: true, completion: nil)
                }
            }
        }))
        
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    @objc private func sentinelButtonTapped() {
        if SentinelAcousticMonitor.shared.isMonitoring {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            SentinelAcousticMonitor.stopMonitoring()
        } else {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            SentinelAcousticMonitor.startMonitoring()
        }
        updateSentinelUIState()
    }
    
    @objc func dismissModalViewController() {
        dismiss(animated: true, completion: nil)
    }

    @objc func setCenter(annotation: Any) {
        if let ann = annotation as? MKAnnotation {
            mapView?.setCenter(ann.coordinate, animated: true)
        }
    }
}

// MARK: - BipeEmergencyHelper (Suporte ao Botão de Ação, Atalhos e SOS)

@objc class BipeEmergencyHelper: NSObject {
    
    @objc static func sendEmergencyAlert() {
        sendEmergencyAlert(type: "sentinela", completion: nil)
    }

    @objc static func sendEmergencyAlert(completion: ((Bool) -> Void)?) {
        sendEmergencyAlert(type: "sentinela", completion: completion)
    }

    @objc static func sendEmergencyAlert(type: String, completion: ((Bool) -> Void)?) {
        DispatchQueue.main.async {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
            
            guard let delegate = UIApplication.shared.delegate as? OwnTracksAppDelegate else {
                NSLog("[BipeEmergencyHelper] Erro: OwnTracksAppDelegate não disponível")
                completion?(false)
                return
            }
            
            let moc = CoreData.sharedInstance().mainMOC
            let userName = Settings.string(forKey: "user_preference", inMOC: moc) ?? "user"
            let deviceId = Settings.string(forKey: "deviceid_preference", inMOC: moc) ?? "device"
            let bipeTopic = "owntracks/\(userName)/\(deviceId)/bipe"
            
            let nickname = Settings.string(forKey: "device_name_preference", inMOC: moc) ?? ""
            let face = Settings.string(forKey: "icon", inMOC: moc) ?? ""
            let color = Settings.string(forKey: "color", inMOC: moc) ?? ""
            
            var payload: [String: Any] = [
                "_type": type,
                "type": type,
                "status": "EMERGENCY",
                "deviceId": deviceId,
                "nickname": nickname,
                "tst": Int64(Date().timeIntervalSince1970)
            ]
            if !face.isEmpty { payload["face"] = face }
            if !color.isEmpty { payload["color"] = color }
            
            let trustedContacts = SentinelAcousticMonitor.shared.getTrustedContacts()
            if !trustedContacts.isEmpty {
                payload["trustedContacts"] = trustedContacts.map { [
                    "name": $0.name,
                    "phone": $0.phoneNumber
                ] }
            }
            
            let triggerReason = SentinelAcousticMonitor.shared.lastTriggerReason
            if !triggerReason.isEmpty {
                payload["triggerReason"] = triggerReason
            }
            
            if delegate.connection == nil {
                delegate.connection = Connection()
                delegate.connection?.delegate = delegate
                delegate.connection?.start()
            }
            delegate.connection?.connectToLast()
            
            if let data = try? JSONSerialization.data(withJSONObject: payload, options: []) {
                let qos = MQTTQosLevel(rawValue: UInt8(Settings.int(forKey: "qos_preference", inMOC: moc))) ?? .exactlyOnce
                delegate.connection?.send(data, topic: bipeTopic, topicAlias: nil, qos: qos, retain: false)
                NSLog("[BipeEmergencyHelper] Alerta de emergência (%@) enviado via MQTT para o tópico: %@", type, bipeTopic)
                
                BipeAudioHelper.playSound(named: "bipe_enter")
                
                if #available(iOS 16.1, *) {
                    BipeLiveActivityManager.processBipePushNotificationPayload([
                        "type": type,
                        "status": "EMERGENCY",
                        "activityType": "emergency",
                        "nickname": nickname.isEmpty ? "Guardiam" : nickname,
                        "address": triggerReason.isEmpty ? NSLocalizedString("Alerta de Emergência Acionado", comment: "") : triggerReason
                    ] as NSDictionary)
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    let successGen = UINotificationFeedbackGenerator()
                    successGen.notificationOccurred(.success)
                }
                completion?(true)
            } else {
                NSLog("[BipeEmergencyHelper] Erro ao serializar o payload JSON de emergência")
                completion?(false)
            }
        }
    }
}

// MARK: - BipeHapticsHelper (Vibração Prolongada)

@objc class BipeHapticsHelper: NSObject {
    @objc static func playAttentionVibration() {
        playAttentionVibration(durationSeconds: 6.0)
    }

    @objc static func playAttentionVibration(durationSeconds: Double = 6.0) {
        DispatchQueue.main.async {
            if #available(iOS 13.0, *) {
                let generator = UINotificationFeedbackGenerator()
                generator.prepare()
                
                var elapsed = 0.0
                let interval = 0.35
                
                Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
                    generator.notificationOccurred(.warning)
                    elapsed += interval
                    if elapsed >= durationSeconds {
                        timer.invalidate()
                    }
                }
            } else {
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            }
        }
    }
}

// MARK: - App Intents & Shortcuts (Botão de Ação do iPhone / Siri Shortcuts)
@available(iOS 16.0, *)
struct BipeEmergencyIntent: AppIntent {
    static var title: LocalizedStringResource = "Enviar Emergência Guardiam"
    static var description = IntentDescription("Envia um alerta de emergência instantâneo pelo Guardiam.")
    
    static var openAppWhenRun: Bool = false
    
    @MainActor
    func perform() async throws -> some IntentResult {
        await withCheckedContinuation { continuation in
            BipeEmergencyHelper.sendEmergencyAlert { _ in
                continuation.resume()
            }
        }
        return .result()
    }
}

@available(iOS 16.0, *)
struct BipeShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: BipeEmergencyIntent(),
            phrases: [
                "Enviar emergência no \(.applicationName)",
                "Alerta de emergência no \(.applicationName)",
                "Socorro no \(.applicationName)"
            ],
            shortTitle: "Emergência Guardiam",
            systemImageName: "exclamationmark.triangle.fill"
        )
    }
}
