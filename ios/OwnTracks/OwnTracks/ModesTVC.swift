//
//  ModesTVC.swift
//  OwnTracks
//
//  Created by Christoph Krey on 12.01.26.
//  Copyright © 2026 OwnTracks. All rights reserved.
//

import Foundation
import UIKit

@objc(ModesTVC)

class ModesTVC: UITableViewController {
    @IBOutlet weak var mqttDescription: UITextView!
    @IBOutlet weak var httpDescription: UITextView!
    @IBOutlet weak var pleaseNote: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad();
        mqttDescription.text = NSLocalizedString("Setup your own OwnTracks server for full privacy protection. More Info on https://owntracks.org/booklet",
                                                 comment: "MQTT Description Text");
        httpDescription.text = NSLocalizedString("Similar to MQTT mode, except data transmission uses HTTP, not MQTT.",
                                                 comment: "HTTP Description Text");
        pleaseNote.text = NSLocalizedString("When switching between modes, all OwnTracks data will be deleted for privacy reasons.",
                                            comment: "Please Note Text");
                                                 
    }
}

