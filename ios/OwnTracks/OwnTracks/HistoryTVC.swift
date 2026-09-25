//
//  HistoryTVC.swift
//  OwnTracks
//
//  Created by Christoph Krey on 26.02.26.
//  Copyright © 2026 OwnTracks. All rights reserved.
//

import Foundation
import UIKit

@objc(HistoryTVC)

class HistoryTVC: OwnTracksEditFetchTVC {
    private var frc : NSFetchedResultsController<History>?;
    
    override func viewDidLoad() {
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                               object: nil,
                                               queue: nil) { _ in
            self.reset();
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        tableView.sectionIndexMinimumDisplayRowCount = 4;
        super.viewWillAppear(animated);
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated);
        reset();
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

    override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return frc?.sectionIndexTitles;
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if frc != nil && frc!.sections != nil {
            let sectionInfo = frc!.sections![section];
            return sectionInfo.numberOfObjects;
        }
        return 0;
    }
    
    override func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        return frc?.section(forSectionIndexTitle: title, at: index) ?? 0;
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "historyCell", for: indexPath);
        let history = frc?.object(at: indexPath);
        if history != nil {
            cell.textLabel?.text = "\(history!.seen?.boolValue ?? true ? " " : "*")\(history!.text ?? "no text")";
            cell.detailTextLabel?.text = OwnTracksFormatter.timestamp(from: history!.timestamp);
        } else {
            cell.textLabel?.text = "no history";
        }
        return cell;
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true;
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let context = frc?.managedObjectContext;
            if context != nil {
                let history = frc?.object(at: indexPath);
                if history != nil {
                    context!.delete(history!);
                    CoreData.sharedInstance().sync(context!);
                }
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return false;
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if frc != nil && frc!.sections != nil {
            let sectionInfo = frc!.sections![section];
            return sectionInfo.name;
        }
        return nil;
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let history = frc?.object(at: indexPath);
        if history != nil {
            history!.seen = NSNumber(booleanLiteral: true);
            CoreData.sharedInstance().sync(history!.managedObjectContext!);
        }
    }
    
    @IBAction func trashPressed(_ sender: UIBarButtonItem) {
        let histories = History.allHistories(in: CoreData.sharedInstance().mainMOC);
        for history in histories {
            CoreData.sharedInstance().mainMOC.delete(history);
        }
        CoreData.sharedInstance().sync(CoreData.sharedInstance().mainMOC);
    }
    
    private func reset() {
        let fr = NSFetchRequest<History>();
        let e = NSEntityDescription.entity(forEntityName: "History", in: CoreData.sharedInstance().mainMOC);
        fr.entity = e;
        let s1 = NSSortDescriptor(key: "group", ascending: false);
        let s2 = NSSortDescriptor(key: "timestamp", ascending: false);
        fr.sortDescriptors = [s1, s2];
        self.frc = NSFetchedResultsController(fetchRequest: fr,
                                              managedObjectContext: CoreData.sharedInstance().mainMOC,
                                              sectionNameKeyPath: "group",
                                              cacheName: nil);
        self.frc?.delegate = self;
        do {
            try self.frc?.performFetch();
        } catch {
            print("fetch failed");
        }

        if tableView != nil {
            tableView.reloadData();
        }
    }
}
