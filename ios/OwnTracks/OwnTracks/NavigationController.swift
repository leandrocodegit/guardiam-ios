//
//  NavigationController.swift
//  OwnTracks
//
//  Created by Christoph Krey on 19.03.26.
//  Copyright © 2026 OwnTracks. All rights reserved.
//

import Foundation
import UIKit

@objc(NavigationController)

class NavigationController: UINavigationController {
    static var sharedInstance: NavigationController? = nil;
    
    var queuedAlerts: [(String, String, String?, TimeInterval?, (() -> Void)?)] = [];
    let progressView = UIProgressView(progressViewStyle: .bar);

    override func viewDidLoad() {
        super.viewDidLoad();
        NavigationController.sharedInstance = self;
        view.addSubview(progressView);
    }
    
    override func viewDidLayoutSubviews() {
        progressView.frame = CGRect(x: 0,
                                    y: navigationBar.frame.origin.y +
                                    navigationBar.frame.size.height -
                                    progressView.bounds.size.height,
                                    width: view.bounds.size.width,
                                    height: progressView.bounds.size.height);
        super.viewDidLayoutSubviews()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);
        let ad = UIApplication.shared.delegate as! OwnTracksAppDelegate;
        ad.addObserver(self, forKeyPath: "connectionState", options: [.initial, .new], context: nil);
        ad.addObserver(self, forKeyPath: "connectionBuffered", options: [.initial, .new], context: nil);
        ad.addObserver(self, forKeyPath: "processingMessage", options: [.initial, .new], context: nil);
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        let ad = UIApplication.shared.delegate as! OwnTracksAppDelegate;
        ad.removeObserver(self, forKeyPath: "connectionState");
        ad.removeObserver(self, forKeyPath: "connectionBuffered");
        ad.removeObserver(self, forKeyPath: "processingMessage");
        super.viewWillDisappear(animated);
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "processingMessage" {
            let ad = UIApplication.shared.delegate as! OwnTracksAppDelegate;
            if ad.processingMessage != nil {
                NavigationController.alert(title:"openURL", message: ad.processingMessage!);
                ad.processingMessage = nil;
            }
        }
        DispatchQueue.main.async {
            let ad = UIApplication.shared.delegate as! OwnTracksAppDelegate;
            switch ad.connectionState?.uint32Value {
            case state_starting.rawValue:
                self.progressView.progressTintColor = UIColor(named: "idleColor");
                self.progressView.progress = 1.0;
            case state_connecting.rawValue:
                self.progressView.progressTintColor = UIColor(named: "connectingColor");
                self.progressView.progress = 1.0;
            case state_error.rawValue:
                self.progressView.progressTintColor = UIColor(named: "connectionErrorColor");
                self.progressView.progress = 1.0;
            case state_connected.rawValue:
                self.progressView.progressTintColor = UIColor(named: "connectedColor");
                self.progressView.progress = 0.0;
            case state_closing.rawValue:
                self.progressView.progressTintColor = UIColor(named: "connectingColor");
                self.progressView.progress = 1.0;
            case state_closed.rawValue:
                self.progressView.progressTintColor = UIColor(named: "connectingColor");
                self.progressView.progress = 1.0;
            default:
                self.progressView.progressTintColor = UIColor(named: "connectionErrorColor");
                self.progressView.progress = 1.0;
            };
        }
    }
    
    @objc class func alert(title: String, message: String) {
        NavigationController.sharedInstance?.showAlert(title, message: message, url: nil, dismissAfter: 0, operation: nil);
    }
    
    @objc class func alert(title: String, message: String, dismissAfter: TimeInterval) {
        NavigationController.sharedInstance?.showAlert(title, message: message, url: nil, dismissAfter: dismissAfter, operation: nil);
    }
    
    @objc class func alert(title: String, message: String, url: String) {
        NavigationController.sharedInstance?.showAlert(title, message: message, url: url, dismissAfter: 0, operation: nil);
    }
    
    @objc class func alert(title: String, message: String, operation: (() -> Void)? = nil) {
        NavigationController.sharedInstance?.showAlert(title, message: message, url: nil, dismissAfter: 0, operation: operation);
    }

    @objc class func shared() -> NavigationController? {
        return sharedInstance;
    }
    
    func showAlert(_ title: String, message: String, url: String? = nil, dismissAfter: TimeInterval!, operation: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            if self.presentedViewController != nil {
                self.queuedAlerts.append( (title, message, url, dismissAfter, operation) );
            } else {
                let ac = UIAlertController(title: title, message: message, preferredStyle: .alert);
                if dismissAfter == 0 {
                    let cancel = UIAlertAction(title: NSLocalizedString("Cancel",
                                                                    comment: "Cancel button title"),
                                           style: .cancel) { action in
                        if self.queuedAlerts.count > 0 {
                            let nextAlert = self.queuedAlerts.removeFirst();
                            self.showAlert(nextAlert.0, message: nextAlert.1, url: nextAlert.2, dismissAfter: nextAlert.3, operation: nextAlert.4);
                        }
                    }

                    let ok = UIAlertAction(title: NSLocalizedString("Continue",
                                                                    comment: "Continue button title"),
                                           style: operation == nil ? .default : .destructive) { action in
                        if operation != nil {
                            operation!();
                        }
                        if self.queuedAlerts.count > 0 {
                            let nextAlert = self.queuedAlerts.removeFirst();
                            self.showAlert(nextAlert.0, message: nextAlert.1, url: nextAlert.2, dismissAfter: nextAlert.3, operation: nextAlert.4);
                        }
                    }
                    if operation != nil {
                        ac.addAction(cancel);
                    }
                    ac.addAction(ok);
                    if url != nil {
                        let open = UIAlertAction(title: NSLocalizedString("Open",
                                                                          comment: "Open button title"),
                                                 style: .default) { action in
                            if let url = URL(string: url!) {
                                UIApplication.shared.open(url);
                            }
                            if self.queuedAlerts.count > 0 {
                                let nextAlert = self.queuedAlerts.removeFirst();
                                self.showAlert(nextAlert.0, message: nextAlert.1, url: nextAlert.2, dismissAfter: nextAlert.3);
                            }
                        }
                        ac.addAction(open);
                    }
                }
                self.present(ac, animated: true);
                if dismissAfter > 0.0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + dismissAfter!) {
                        self.dismiss(animated: true);
                    }
                }
            }
        }
    }
}
