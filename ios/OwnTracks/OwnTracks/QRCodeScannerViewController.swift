//
//  QRCodeScannerViewController.swift
//  OwnTracks
//

import UIKit
import AVFoundation

protocol QRCodeScannerViewControllerDelegate: AnyObject {
    func qrCodeScanner(_ scanner: QRCodeScannerViewController, didScanResult result: String)
    func qrCodeScannerDidCancel(_ scanner: QRCodeScannerViewController)
}

class QRCodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: QRCodeScannerViewControllerDelegate?
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isScanning = true
    private var isTorchOn = false
    
    private let scanBoxView = UIView()
    private let scanLine = UIView()
    private let flashButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        setupCamera()
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isScanning = true
        startScanning()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
        turnTorch(on: false)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        setupScanBoxPosition()
    }
    
    // MARK: - Camera Setup
    
    private func setupCamera() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .denied || status == .restricted {
            showCameraAccessAlert()
            return
        }
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            showErrorAlert(message: "Sua câmera não pôde ser inicializada.")
            return
        }
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            let session = AVCaptureSession()
            
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
            } else {
                showErrorAlert(message: "Não foi possível conectar a câmera ao leitor.")
                return
            }
            
            let metadataOutput = AVCaptureMetadataOutput()
            if session.canAddOutput(metadataOutput) {
                session.addOutput(metadataOutput)
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                metadataOutput.metadataObjectTypes = [.qr]
            } else {
                showErrorAlert(message: "O leitor de QR Code não pôde ser configurado.")
                return
            }
            
            captureSession = session
            
            let preview = AVCaptureVideoPreviewLayer(session: session)
            preview.videoGravity = .resizeAspectFill
            preview.frame = view.bounds
            view.layer.addSublayer(preview)
            previewLayer = preview
            
        } catch {
            showErrorAlert(message: "Erro ao abrir câmera: \(error.localizedDescription)")
        }
    }
    
    private func startScanning() {
        guard let session = captureSession, !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
        animateScanLine()
    }
    
    private func stopScanning() {
        guard let session = captureSession, session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            session.stopRunning()
        }
    }
    
    // MARK: - AVCaptureMetadataOutputObjectsDelegate
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard isScanning else { return }
        
        if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
           let stringValue = metadataObject.stringValue, !stringValue.isEmpty {
            
            isScanning = false
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            stopScanning()
            
            dismiss(animated: true) { [weak self] in
                guard let self = self else { return }
                self.delegate?.qrCodeScanner(self, didScanResult: stringValue)
            }
        }
    }
    
    // MARK: - UI Layout & Custom Viewfinder
    
    private func setupUI() {
        // Title Label
        titleLabel.text = "Escanear QR Code"
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        // Subtitle Label
        subtitleLabel.text = "Aponte a câmera para o QR Code de compartilhamento"
        subtitleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 2
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitleLabel)
        
        // Close Button
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .white
        closeButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)
        view.addSubview(closeButton)
        
        // Flash Button
        flashButton.setImage(UIImage(systemName: "bolt.circle.fill"), for: .normal)
        flashButton.tintColor = .white
        flashButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        flashButton.translatesAutoresizingMaskIntoConstraints = false
        flashButton.addTarget(self, action: #selector(didTapFlash), for: .touchUpInside)
        view.addSubview(flashButton)
        
        // Scan Box Target Viewfinder
        scanBoxView.layer.borderColor = UIColor(red: 0.18, green: 0.80, blue: 0.44, alpha: 1.0).cgColor
        scanBoxView.layer.borderWidth = 2.5
        scanBoxView.layer.cornerRadius = 16
        scanBoxView.backgroundColor = .clear
        scanBoxView.clipsToBounds = true
        scanBoxView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scanBoxView)
        
        // Scanning Laser Line
        scanLine.backgroundColor = UIColor(red: 0.18, green: 0.80, blue: 0.44, alpha: 0.85)
        scanLine.translatesAutoresizingMaskIntoConstraints = false
        scanBoxView.addSubview(scanLine)
        
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),
            
            flashButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            flashButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            flashButton.widthAnchor.constraint(equalToConstant: 44),
            flashButton.heightAnchor.constraint(equalToConstant: 44),
            
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])
    }
    
    private func setupScanBoxPosition() {
        let boxSize: CGFloat = min(view.bounds.width * 0.72, 280)
        let rect = CGRect(
            x: (view.bounds.width - boxSize) / 2,
            y: (view.bounds.height - boxSize) / 2 - 20,
            width: boxSize,
            height: boxSize
        )
        scanBoxView.frame = rect
        
        scanLine.frame = CGRect(x: 0, y: 0, width: boxSize, height: 3)
    }
    
    private func animateScanLine() {
        scanLine.layer.removeAllAnimations()
        let boxHeight = scanBoxView.bounds.height > 0 ? scanBoxView.bounds.height : 260
        scanLine.frame = CGRect(x: 0, y: 0, width: scanBoxView.bounds.width, height: 3)
        
        UIView.animate(withDuration: 2.0, delay: 0.0, options: [.repeat, .autoreverse, .curveEaseInOut], animations: {
            self.scanLine.frame.origin.y = boxHeight - 3
        }, completion: nil)
    }
    
    // MARK: - Actions
    
    @objc private func didTapClose() {
        turnTorch(on: false)
        dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            self.delegate?.qrCodeScannerDidCancel(self)
        }
    }
    
    @objc private func didTapFlash() {
        isTorchOn.toggle()
        turnTorch(on: isTorchOn)
        let iconName = isTorchOn ? "bolt.circle.fill" : "bolt.slash.circle.fill"
        flashButton.setImage(UIImage(systemName: iconName), for: .normal)
        flashButton.tintColor = isTorchOn ? .yellow : .white
    }
    
    private func turnTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        } catch {
            NSLog("[QRCodeScannerViewController] Erro ao alterar lanterna: %@", error.localizedDescription)
        }
    }
    
    private func showCameraAccessAlert() {
        let alert = UIAlertController(
            title: "Permissão de Câmera Necessária",
            message: "Por favor, ative a permissão da câmera nas Ajustes do iOS para utilizar o leitor de QR Code.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Abrir Ajustes", style: .default) { _ in
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel) { [weak self] _ in
            self?.didTapClose()
        })
        present(alert, animated: true)
    }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "Erro no Leitor", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.didTapClose()
        })
        present(alert, animated: true)
    }
}
