//
//  OwnTracksEditFetchTVC.swift
//  OwnTracks
//
//  Created by Christoph Krey on 26.02.26.
//  Copyright © 2026 OwnTracks. All rights reserved.
//

import Foundation
import UIKit

@objc(OwnTracksEditFetchTVC)

class OwnTracksEditFetchTVC: OwnTracksEditTVC, NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<any NSFetchRequestResult>) {
        if Thread.current.isMainThread {
            begin();
        } else {
            DispatchQueue.main.sync {
                begin();
            }
        }
    }
    
    func begin() {
        tableView.beginUpdates();
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<any NSFetchRequestResult>) {
        if Thread.current.isMainThread {
            end();
        } else {
            DispatchQueue.main.sync {
                end();
            }
        }
    }
    
    func end() {
        tableView.endUpdates();
    }
    
    func controller(_ controller: NSFetchedResultsController<any NSFetchRequestResult>, didChange sectionInfo: any NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        if Thread.current.isMainThread {
            sectionChange(type, sectionIndex: sectionIndex);
        } else {
            DispatchQueue.main.sync {
                sectionChange(type, sectionIndex: sectionIndex);
            }
        }
    }
    
    func sectionChange(_ type: NSFetchedResultsChangeType, sectionIndex: Int) -> () {
        switch(type) {
        case .insert:
            tableView.insertSections(IndexSet(integer: sectionIndex), with: .automatic);
        case .delete:
            tableView.deleteSections(IndexSet(integer: sectionIndex), with: .automatic);
        default:
            print("NSFetchResultsChangeType \(type)");
        }
    }
        
    func controller(_ controller: NSFetchedResultsController<any NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        if Thread.current.isMainThread {
            rowChange(type, indexPath: indexPath, newIndexPath: newIndexPath);
        } else {
            DispatchQueue.main.sync {
                rowChange(type, indexPath: indexPath, newIndexPath: newIndexPath);
            }
        }
    }
    
    func rowChange(_ type: NSFetchedResultsChangeType, indexPath: IndexPath?, newIndexPath: IndexPath?) -> () {
        switch(type) {
        case .insert:
            tableView.insertRows(at: [newIndexPath!], with: .automatic);
        case .delete:
            tableView.deleteRows(at: [indexPath!], with: .automatic);
        case .update:
            tableView.reloadRows(at: [indexPath!], with: .automatic);
        case .move:
            tableView.deleteRows(at: [indexPath!], with: .automatic);
            tableView.insertRows(at: [newIndexPath!], with: .automatic);
        default:
            print("NSFetchResultsChangeType \(type)");
        }
    }
}
