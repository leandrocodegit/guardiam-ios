//
//  FriendsTVC.swift
//  OwnTracks
//
//  Created by Christoph Krey on 16.03.26.
//  Copyright © 2026 OwnTracks. All rights reserved.
//

import Foundation
import UIKit
import CoreLocation
import Contacts

@objc(FriendsTVC)

class FriendsTVC: OwnTracksEditFetchTVC {
    private var frc : NSFetchedResultsController<Friend>?;
    
    required init?(coder: NSCoder) {
        super.init(coder: coder);
        let ad = UIApplication.shared.delegate as! OwnTracksAppDelegate;
        ad.addObserver(self, forKeyPath: "inQueue", options: [.initial, .new], context: nil);
    }
    
    override func viewDidLoad() {
        super.viewDidLoad();

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "reload"),
                                               object: nil,
                                               queue: nil) { _ in
            self.reset();
        }
        
        let locked = Settings.theLocked(inMOC: CoreData.sharedInstance().mainMOC);
        if !locked {
            let status = CNContactStore.authorizationStatus(for: CNEntityType.contacts);
            switch status {
            case .notDetermined:
                UserDefaults.standard.set(true, forKey: "contactsAuthorization");
                let store = CNContactStore();
                store.requestAccess(for: .contacts) { granted, error in
                    if granted {
                        let logger = Logger(subsystem: "org.mqttitude", category: "MQTTitude");
                        logger.debug("requestAccessForEntityType granted");
                    } else {
                        let logger = Logger(subsystem: "org.mqttitude", category: "MQTTitude");
                        logger.debug("requestAccessForEntityType denied \(error)");
                    }
                }
            case .authorized:
                let logger = Logger(subsystem: "org.mqttitude", category: "MQTTitude");
                logger.debug("CNAuthorizationStatus: CNAuthorizationStatusAuthorized");
            case .denied:
                if UserDefaults.standard.bool(forKey: "contactsAuthorization") {
                    let logger = Logger(subsystem: "org.mqttitude", category: "MQTTitude");
                    logger.debug("CNAuthorizationStatus: CNAuthorizationStatusDenied");
                    let ac = UIAlertController(title: NSLocalizedString("Addressbook Access",
                                                                        comment: "Headline in addressbook related error messages"),
                                               message: NSLocalizedString("has been denied by user. If you allow OwnTracks to access your contacts, you can link your devices to contacts. OwnTracks will then display the contact name and image instead of the device Id. No information of your address book will be uploaded to any server. Go to Settings/Privacy/Contacts to change",
                                                                          comment: "CNAuthorizationStatusDenied"),
                                               preferredStyle: .alert);
                    let ok = UIAlertAction(title: NSLocalizedString("Continue",
                                                                    comment: "Continue button title"),
                                           style: .default);
                    ac.addAction(ok);
                    present(ac, animated: true);
                    UserDefaults.standard.set(true, forKey: "contactsAuthorization");
                }
            case .limited:
                let logger = Logger(subsystem: "org.mqttitude", category: "MQTTitude");
                logger.debug("CNAuthorizationStatus: CNAuthorizationStatusLimited");
            case .restricted:
                if UserDefaults.standard.bool(forKey: "contactsAuthorization") {
                    let logger = Logger(subsystem: "org.mqttitude", category: "MQTTitude");
                    logger.debug("CNAuthorizationStatus: CNAuthorizationStatusRestricted");
                    let ac = UIAlertController(title: NSLocalizedString("Addressbook Access",
                                                                        comment: "Headline in addressbook related error messages"),
                                               message: NSLocalizedString("has been restricted, possibly due to restrictions such as parental controls.",
                                                                          comment: "CNAuthorizationStatusRestricted"),
                                               preferredStyle: .alert);
                    let ok = UIAlertAction(title: NSLocalizedString("Continue",
                                                                    comment: "Continue button title"),
                                           style: .default);
                    ac.addAction(ok);
                    present(ac, animated: true);
                    UserDefaults.standard.set(true, forKey: "contactsAuthorization");
                }

            default:
                break;
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);
        reset();
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        DispatchQueue.main.async {
            let ad = UIApplication.shared.delegate as! OwnTracksAppDelegate;
            let inQueue = ad.inQueue.uintValue;
            if inQueue > 0 {
                self.navigationItem.searchController?.tabBarItem.badgeValue = "\(inQueue)";
            } else {
                self.navigationItem.searchController?.tabBarItem.badgeValue = nil;
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if sender is UITableViewCell {
            let indexPath = tableView.indexPath(for: sender as! UITableViewCell)!;
            if segue.identifier == "showWaypointFromFriends" {
                if segue.destination is WaypointTVC {
                    let friend = frc!.object(at: indexPath);
                    let waypoint = friend.newestWaypoint;
                    if waypoint != nil {
                        let wpTVC = segue.destination as! WaypointTVC;
                        wpTVC.waypoint = waypoint;
                    }
                }
            }
        }
    }
    
    private func reset() {
        let moc = CoreData.sharedInstance().mainMOC;
        let fr = Friend.fetchRequestAllNonStale(moc);
        self.frc = NSFetchedResultsController(fetchRequest: fr,
                                              managedObjectContext: moc,
                                              sectionNameKeyPath: nil,
                                              cacheName: nil);
        self.frc?.delegate = self;
        do {
            try self.frc?.performFetch();
        } catch {
        }
        if tableView != nil {
            tableView.reloadData();
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let friend = frc!.object(at: indexPath);
        let tbc = tabBarController;
        let vcs = tbc?.viewControllers;
        let nc = vcs?[0];
        if nc != nil && nc is NavigationController {
            let navigationController = nc as! NavigationController;
            let vc = navigationController.topViewController;
            if vc != nil && vc is ViewController {
                let viewController = vc as! ViewController;
                viewController.setCenter(annotation: friend);
            }
            tabBarController?.selectedIndex = 0;
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        if frc != nil && frc!.sections != nil {
            if frc!.sections!.count == 0 {
                empty();
                return 0;
            } else {
                var numberOfObjects: Int = 0;
                
                for section in frc!.sections!.indices {
                    let sectionInfo = frc!.sections![section];
                    numberOfObjects += sectionInfo.numberOfObjects;
                }
                if numberOfObjects > 0 {
                    nonempty();
                } else {
                    empty();
                }
                return frc!.sections!.count;
            }
        } else {
            empty();
            return 0;
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if frc != nil && frc!.sections != nil {
            let sectionInfo = frc!.sections![section];
            return sectionInfo.numberOfObjects;
        }
        return 0;
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true;
    }
    
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return false;
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "friend", for: indexPath);
        let friendTableViewCell = cell as! FriendTableViewCell;
        
        let friend = frc?.object(at: indexPath);
        if friend != nil {
            friendTableViewCell.name.text = friend!.name ?? friend!.tid;
            
            let friendAnnotationV = FriendAnnotationV(frame: CGRect(x: 0, y: 0, width: 40, height: 40));
            if friend!.image != nil {
                friendAnnotationV.personImage = UIImage(data: friend!.image!);
            } else {
                friendAnnotationV.personImage = nil;
            }
            friendAnnotationV.me = friend!.topic == Settings.theGeneralTopic(inMOC: CoreData.sharedInstance().mainMOC);
            friendAnnotationV.tid = friend?.effectiveTid;
            
            let waypoint = friend!.newestWaypoint;
            if waypoint != nil {
                if waypoint!.placemark != nil {
                    friendTableViewCell.address.text = waypoint!.placemark;
                } else {
                    let logger = Logger(subsystem: "org.mqttitude", category: "MQTTitude");
                    logger.debug("[FriendsTVC] configureCell resolving \(waypoint)");
                    friendTableViewCell.address.text = NSLocalizedString("resolving...",
                                                                         comment: "temporary display while resolving address");
                    friendTableViewCell.deferredReverseGeoCode(waypoint: waypoint);
                }
                
                friendAnnotationV.speed = waypoint!.vel?.doubleValue ?? 0;
                friendAnnotationV.course = waypoint!.cog?.doubleValue ?? 0;
            } else {
                friendTableViewCell.address.text = "";
                friendAnnotationV.speed = -1;
                friendAnnotationV.course = -1;
            }
            
            let thisMorning = NSCalendar.current.startOfDay(for: Date());
            if waypoint != nil && waypoint!.tst != nil {
                if waypoint!.tst!.timeIntervalSince(thisMorning) > 0 {
                    friendTableViewCell.timestamp.text = DateFormatter.localizedString(from: waypoint!.tst!, dateStyle: .none, timeStyle: .short);
                } else {
                    friendTableViewCell.timestamp.text = DateFormatter.localizedString(from: waypoint!.tst!, dateStyle: .short, timeStyle: .none);
                }
            } else {
                friendTableViewCell.timestamp.text = "";
            }
            
            friendTableViewCell.friendImage.image = friendAnnotationV.getImage();
        }
        
        return cell;
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let context = frc?.managedObjectContext;
            if context != nil {
                let friend = frc?.object(at: indexPath);
                if friend != nil {
                    if friend!.topic != nil && friend!.topic!.isEmpty == false {
                        let ad = UIApplication.shared.delegate as! OwnTracksAppDelegate;
                        ad.sendEmpty(friend!.topic!);
                    }
                    context?.delete(friend!);
                    CoreData.sharedInstance().sync(context!);
                }
            }
        }
    }

}
