//
//  ToursTVC.swift
//  OwnTracks
//
//  Created by Christoph Krey on 28.12.25.
//  Copyright © 2025-2026 OwnTracks. All rights reserved.
//

import Foundation
import UIKit

@objc(ToursTVC)

class ToursTVC: OwnTracksEditTVC {
    override func viewDidLoad() {
        super.viewDidLoad();
        
        emptyText = NSLocalizedString("No or empty tour list received from backend",
                                      value: "No or empty tour list received from backend",
                                      comment: "");
        
        refreshControl = UIRefreshControl();
        refreshControl?.attributedTitle =
        NSAttributedString(string: NSLocalizedString("Fetching tour list from backend",
                                                     value: "Fetching tour list from backend",
                                                     comment: ""));
        refreshControl?.addTarget(self, action: #selector(refresh) , for: .valueChanged);
                            
    }
    
    @IBAction func refreshPressed(_ sender: UIBarButtonItem) {
        refreshControl?.beginRefreshing();
        Tours.sharedInstance().refresh();
    }
    
    @objc func refresh() -> () {
        refreshControl?.beginRefreshing();
        Tours.sharedInstance().refresh();
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated);
        
        let tours = Tours.sharedInstance();
        
        tours.addObserver(self, forKeyPath: "timestamp", options: [.initial, .new], context: nil);
        tours.addObserver(self, forKeyPath: "message", options: [.initial, .new], context: nil);
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated);
        
        let tours = Tours.sharedInstance();

        tours.removeObserver(self, forKeyPath: "timestamp");
        tours.removeObserver(self, forKeyPath: "message");
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "timestamp" || keyPath == "message" {
            DispatchQueue.main.async {
                self.refreshControl?.endRefreshing()
                self.tableView.reloadData();
            }
        }

    }
    
    @IBAction func tourSaved(_ segue: UIStoryboardSegue) {
        if segue.source is CreateTourTVC {
            let createTourTVC = segue.source as! CreateTourTVC;
            let tour = Tour();
            tour.label = createTourTVC.label.text!;
            tour.from = createTourTVC.from.date;
            tour.to = createTourTVC.to.date;
            
            Tours.sharedInstance().request(tour);
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2;
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let tours = Tours.sharedInstance();
        if tours.count() == 0 {
            empty();
        } else {
            nonempty();
        }
        
        if section == 0 {
            return tours.count();
        } else {
            return 1;
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "TourCell", for: indexPath);
            let tour = Tours.sharedInstance().tour(at: indexPath.row);
            cell.textLabel?.text = tour?.label;
            
            let dateFormatter = DateFormatter();
            dateFormatter.dateStyle = .short;
            dateFormatter.timeStyle = .short;

            cell.detailTextLabel?.text = "\(dateFormatter.string(from: tour?.from ?? Date())) - \(dateFormatter.string(from: tour?.to ?? Date()))";
            
            return cell;
        } else {
            let statusCell = tableView.dequeueReusableCell(withIdentifier: "ToursStatusCell", for: indexPath) as! ToursStatusCell;
            if Tours.sharedInstance().activity.boolValue == true {
                statusCell.activity.startAnimating();
            } else {
                statusCell.activity.stopAnimating();
            }
            statusCell.label.text = Tours.sharedInstance().message;
            
            return statusCell;
        }
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if indexPath.section == 0 {
            return true;
        } else {
            return false;
        }
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            Tours.sharedInstance().removeTour(at: indexPath.row);
            tableView.deleteRows(at: [indexPath], with: .fade);
        }
    }
    
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if indexPath.section == 0 {
            if Tours.sharedInstance().tour(at: indexPath.row)?.uuid != nil {
                return indexPath;
            } else {
                return nil;
            }
        } else {
            return nil;
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let tour = Tours.sharedInstance().tour(at: indexPath.row);
        if tour?.uuid != nil {
            UIPasteboard.general.string = tour?.url;
            NavigationController.alert(title:NSLocalizedString("Copied", comment: "Alert message header for copy"),
                                       message:"\(tour?.url ?? "<URL not available>") " +
                                       NSLocalizedString("URL copied to Clipboard",
                                                         comment: "URL copied to Clipboard"));
        }
        tableView.deselectRow(at: indexPath, animated: true);
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return NSLocalizedString("Tours", comment: "Tours list header");
        } else {
            return NSLocalizedString("Tours status", comment: "Tours status header");
        }
    }
}
