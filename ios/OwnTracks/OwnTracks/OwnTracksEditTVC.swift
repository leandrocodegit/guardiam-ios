//
//  OwnTracksEditTVC.swift
//  OwnTracks
//
//  Created by Christoph Krey on 18.03.26.
//  Copyright © 2026 OwnTracks. All rights reserved.
//

import Foundation
import UIKit

@objc(OwnTracksEditTVC)

class OwnTracksEditTVC: UITableViewController {
    public var emptyText: String? = nil;
    
    var emptyLabel: UILabel? = nil;
    var constraints: [NSLayoutConstraint]? = nil;
    
    func empty() {
        if constraints == nil {
            emptyLabel = UILabel();
            emptyLabel!.translatesAutoresizingMaskIntoConstraints = false;
            if emptyText != nil {
                emptyLabel!.text = emptyText;
            } else {
                emptyLabel!.text = NSLocalizedString("Table is empty",
                                                    comment:"Table is empty");
            }
            tableView.backgroundView = emptyLabel;
            let center = NSLayoutConstraint(item: emptyLabel!,
                                            attribute: .centerX,
                                            relatedBy: .equal,
                                            toItem: tableView,
                                            attribute: .centerX,
                                            multiplier: 1,
                                            constant: 0);
            let middle = NSLayoutConstraint(item: emptyLabel!,
                                            attribute: .centerY,
                                            relatedBy: .equal,
                                            toItem: tableView,
                                            attribute: .centerY,
                                            multiplier: 1,
                                            constant: 0);
            constraints = [center, middle];
            NSLayoutConstraint.activate(constraints!);
        }
    }
    
    func nonempty() {
        if constraints != nil {
            NSLayoutConstraint.deactivate(constraints!);
            tableView.backgroundView = nil;
            constraints = nil;
            emptyLabel = nil;
        }
    }
}
