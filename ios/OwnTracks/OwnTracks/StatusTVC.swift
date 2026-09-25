//
//  StatusTVC.swift
//  OwnTracks
//
//  Created by Christoph Krey on 05.02.26.
//  Copyright © 2026 OwnTracks. All rights reserved.
//

import Foundation
import UIKit
import OSLog

extension OSLogEntryLog.Level {
  fileprivate var description: String {
    switch self {
    case .undefined: "undefined"
    case .debug: "debug"
    case .info: "info"
    case .notice: "notice"
    case .error: "error"
    case .fault: "fault"
    @unknown default: "default"
    }
  }
}

@objc(StatusTVC)
class StatusTVC: UITableViewController, UIDocumentInteractionControllerDelegate {
    @IBOutlet weak var parameters: UITextView!
    @IBOutlet weak var status: UITextView!
    @IBOutlet weak var version: UITextField!
    @IBOutlet weak var coordinates: UITextField!
    @IBOutlet weak var locationAge: UILabel!
    @IBOutlet weak var pressure: UITextField!
    @IBOutlet weak var altitude: UILabel!
    @IBOutlet weak var motionActivities: UITextField!
    @IBOutlet weak var trackPoints: UITextField!
    @IBOutlet weak var exportLogsActivity: UIActivityIndicatorView!
    @IBOutlet weak var exportTrackButton: UIButton!
    @IBOutlet weak var exportTrackActivity: UIActivityIndicatorView!
    var dic: UIDocumentInteractionController?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);
        
        let ad = UIApplication.shared.delegate as! OwnTracksAppDelegate;
        ad.addObserver(self, forKeyPath: "connectionState", options: [.initial, .new], context: nil);
        ad.addObserver(self, forKeyPath: "connectionBuffered", options: [.initial, .new], context: nil);
        
        let lm = LocationManager.sharedInstance();
        lm.addObserver(self, forKeyPath: "lastUsedLocation", options: [.initial, .new], context: nil);
        lm.addObserver(self, forKeyPath: "altitudeData", options: [.initial, .new], context: nil);
        lm.addObserver(self, forKeyPath: "motionActivity", options: [.initial, .new], context: nil);
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        let ad = UIApplication.shared.delegate as! OwnTracksAppDelegate;
        ad.removeObserver(self, forKeyPath: "connectionState", context: nil);
        ad.removeObserver(self, forKeyPath: "connectionBuffered", context: nil);

        let lm = LocationManager.sharedInstance();
        lm.removeObserver(self, forKeyPath: "lastUsedLocation", context: nil);
        lm.removeObserver(self, forKeyPath: "altitudeData", context: nil);
        lm.removeObserver(self, forKeyPath: "motionActivity", context: nil);

        super.viewWillDisappear(animated);
    }
    
    override func observeValue(forKeyPath keyPath: String?, of _: Any?, change: [NSKeyValueChangeKey : Any]?, context _: UnsafeMutableRawPointer?) {
        DispatchQueue.main.async {
            self.updatedStatus();
        }
    }
    
    private func connectionStateDescription(state: NSNumber) -> String {
        let description: String;
        
        switch state.uint32Value {
        case state_starting.rawValue:
            description = NSLocalizedString("idle", comment: "description connection idle state");
        case state_connecting.rawValue:
            description = NSLocalizedString("connecting", comment: "description connection connecting state");
        case state_error.rawValue:
            description = NSLocalizedString("error", comment: "description connection error state");
        case state_connected.rawValue:
            description = NSLocalizedString("connected", comment: "description connection connected state");
        case state_closing.rawValue:
            description = NSLocalizedString("closing", comment: "description connection closing state");
        case state_closed.rawValue:
            description = NSLocalizedString("closed", comment: "description connection closed state");
        default:
            description = (NSLocalizedString("unknown state", comment: "description connection unknown state") +
            "\(state)");
        }
        return description;
    }
    
    func updatedStatus() -> () {
        let ad = UIApplication.shared.delegate as! OwnTracksAppDelegate;
        let connection = ad.connection;
        let lastErrorCode = connection?.lastErrorCode;
        
        status?.text = ("""
                    \(connectionStateDescription(state:ad.connectionState ?? NSNumber(-1))) \
                    \(lastErrorCode?.localizedDescription ?? "")
                    """);
        
        let location = LocationManager.sharedInstance().location;
        self.coordinates?.text = OwnTracksFormatter.coordinate(from: location);
        
        let thisMorning = NSCalendar.current.startOfDay(for: Date());
        let relativeFormatter = RelativeDateTimeFormatter()
        relativeFormatter.unitsStyle = .full;
        relativeFormatter.dateTimeStyle = .numeric;
        let relative = " (" + RelativeDateTimeFormatter().localizedString(for: location.timestamp, relativeTo: Date.now.addingTimeInterval(1)) + ")";
        
        if location.timestamp.timeIntervalSince(thisMorning) > 0 {
            self.locationAge?.text = DateFormatter.localizedString(from: location.timestamp, dateStyle: .none, timeStyle: .medium) + relative;
        } else {
            self.locationAge?.text = DateFormatter.localizedString(from: location.timestamp, dateStyle: .short, timeStyle: .none) + relative;
        }
        
        let altitudeData = LocationManager.sharedInstance().altitudeData
        if altitudeData != nil {
            self.pressure?.text = OwnTracksFormatter.pressure(from: altitudeData!.pressure.doubleValue);
        } else {
            self.pressure?.text = NSLocalizedString("No pressure available",  comment: "No pressure available");
        }

        self.altitude?.text = OwnTracksFormatter.altitude(from: location);
        self.parameters?.text = "\(connection?.parameters ?? "")";
        
        var ma = "()";
        let motionActivity = LocationManager.sharedInstance().motionActivity;
        if motionActivity != nil {
            switch motionActivity!.confidence {
            case .low:
                ma = "(L)";
            case .medium:
                ma = "(M)";
            case .high:
                ma = "(H)";
            @unknown default:
                break;
            }
            
            if motionActivity!.stationary {
                ma += " stationary";
            }
            if motionActivity!.walking {
                ma += " walking";
            }
            if motionActivity!.running {
                ma += " running";
            }
            if motionActivity!.automotive {
                ma += " automotive";
            }
            if motionActivity!.cycling {
                ma += " cycling";
            }
            if motionActivity!.unknown {
                ma += " unknown";
            }
        }
        self.motionActivities?.text = ma;
        
        self.version?.text = """
                    \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "")/\
                    \(Locale.current.identifier)
                    """;
        
        let topic = Settings.theGeneralTopic(inMOC: CoreData.sharedInstance().mainMOC);
        let myself = Friend.existsFriend(withTopic: topic, in: CoreData.sharedInstance().mainMOC);
        let waypoints = myself?.hasWaypoints;
        self.trackPoints?.text = "\(waypoints?.count ?? 0)";
        self.tableView.setNeedsDisplay();
    }
    
    @IBAction func sendDebugStatusPressed(_ sender: UIButton) {
        let ad = UIApplication.shared.delegate as! OwnTracksAppDelegate;
        ad.status();
    }
    
    @IBAction func documentationPressed(_ sender: UIButton) {
        UIApplication.shared.open(URL(string: "https://owntracks.org/booklet")!);
    }
    
    @IBAction func webPressed(_ sender: UIButton) {
        UIApplication.shared.open(URL(string: "https://owntracks.org")!);
    }
    
    @IBAction func githubPressed(_ sender: UIButton) {
        UIApplication.shared.open(URL(string: "https://github.com/owntracks/talk")!);
    }
    
    @IBAction func mastodonPressed(_ sender: UIButton) {
        UIApplication.shared.open(URL(string: "https://fosstodon.org/@owntracks")!);
    }
    
    @IBAction func exportTrackPressed(_ sender: UIButton) {
        exportTrackActivity.isHidden = false;
        exportTrackActivity.startAnimating();
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1));

        do {
            let directoryURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true);
            let fileURL = directoryURL.appendingPathComponent("track.gpx");
            
            let topic = Settings.theGeneralTopic(inMOC: CoreData.sharedInstance().mainMOC);
            let myself = Friend.existsFriend(withTopic: topic, in: CoreData.sharedInstance().mainMOC);

            let output = OutputStream(url: fileURL, append: false)!;
            output.open();
            myself?.track(toGPX: output);
            output.close();

            dic = UIDocumentInteractionController(url:fileURL as URL) ;
            dic?.delegate = self;
            dic?.presentOptionsMenu(from: self.exportTrackButton.frame, in: self.exportTrackButton, animated: true);
        } catch {
        }
        exportTrackActivity.stopAnimating();
        exportTrackActivity.isHidden = true;
    }
    
    @IBAction func exportLogsPressed(_ sender: UIButton) {
        exportLogsActivity.isHidden = false;
        exportLogsActivity.startAnimating();
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1));

        let store: OSLogStore?;
        do {
            store = try OSLogStore(scope: .currentProcessIdentifier);
        } catch {
            store = nil;
        }

        let position = store?.position(date: Date(timeIntervalSinceNow: -3600.0));
        let predicate = NSPredicate(format: "(subsystem == %@) && ((messageType == info) || (messageType == default) || (messageType == error) || (messageType == fault))",
                                    "org.mqttitude");

        let entries: AnySequence<OSLogEntry>?
        do {
            entries = try store?.getEntries(at: position,
                                            matching: predicate);

        } catch {
            entries = nil;
        }
        
        do {
            let directoryURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true);
            let fileURL = directoryURL.appendingPathComponent("owntracks.log");
            let output = OutputStream(url: fileURL, append: false)!;
            output.open();
            let isoFormatter = ISO8601DateFormatter();
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds];

            entries?.forEach { entry in
                let line: String;
                if let log = entry as? OSLogEntryLog {
                    line = ("""
                    \(isoFormatter.string(from:entry.date)):\
                    \(log.level.description): \
                    \(entry.composedMessage)\n
                    """)
                } else {
                    line = ("\(isoFormatter.string(from:entry.date)): \(entry.composedMessage)\n")
                }
                output.write(line, maxLength: line.utf8.count);
            }
            output.close();

            dic = UIDocumentInteractionController(url:fileURL as URL) ;
            dic?.delegate = self;
            dic?.presentPreview(animated: true)

        } catch {
        }
        exportLogsActivity.stopAnimating();
        exportLogsActivity.isHidden = true;
    }
    
    func documentInteractionControllerDidEndPreview(_ controller: UIDocumentInteractionController) {
        do {
            try FileManager.default.removeItem(at: controller.url!);
        } catch {
        }
    }
        
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return self;
    }

    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        let tableViewCell = tableView.cellForRow(at: indexPath);
        if tableViewCell?.tag == 98 {
            let location = LocationManager.sharedInstance().location;
            UIPasteboard.general.string = ("\(location.coordinate.latitude),\(location.coordinate.longitude)");
            NavigationController.alert(title: NSLocalizedString("Clipboard",
                                                                comment: "Clipboard"),
                                       message: NSLocalizedString("Location copied to clipboard",
                                                                  comment: "Location copied to clipboard"),
                                       dismissAfter: 1.0);
        }
        return nil;
    }
}
