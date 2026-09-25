//
//  FriendTableViewCell.swift
//  OwnTracks
//
//  Created by Christoph Krey on 16.03.26.
//  Copyright © 2026 OwnTracks. All rights reserved.
//

import Foundation
import MapKit

@objc(FriendTableViewCell)

class FriendTableViewCell: UITableViewCell {
    @IBOutlet weak var friendImage: UIImageView!
    @IBOutlet weak var timestamp: UILabel!
    @IBOutlet weak var name: UILabel!
    @IBOutlet weak var address: UILabel!
    
    func deferredReverseGeoCode(waypoint: Waypoint?) {
        DispatchQueue.cancelPreviousPerformRequests(withTarget: self);
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.0, execute: {
            if waypoint != nil {
                if waypoint!.isDeleted == false {
                    if UserDefaults.standard.integer(forKey: "noRevgeo") > 0 {
                        waypoint!.getReverseGeoCode();
                    } else {
                        waypoint!.placemark = waypoint!.defaultPlacemark;
                        waypoint!.belongsTo?.topic = waypoint!.belongsTo?.topic;
                        if waypoint!.managedObjectContext != nil {
                            CoreData.sharedInstance().sync(waypoint!.managedObjectContext!);
                        }
                    }
                }
            }
        });
    }
}

