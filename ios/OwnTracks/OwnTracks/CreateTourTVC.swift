//
//  CreateTourTVC.swift
//  OwnTracks
//
//  Created by Christoph Krey on 18.12.25.
//  Copyright © 2025-2026 OwnTracks. All rights reserved.
//

import Foundation
import UIKit

@objc(CreateTourTVC)

class CreateTourTVC: UITableViewController, UITextFieldDelegate {
    @IBOutlet weak var saveButton: UIBarButtonItem!
    @IBOutlet weak var label: UITextField!
    @IBOutlet weak var from: UIDatePicker!
    @IBOutlet weak var to: UIDatePicker!
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated);
        from.date = Date.now;
        to.date = Date(timeInterval:3600, since:from.date);
        saveButton.isEnabled = false;
        label.delegate = self;
    }
    
    @IBAction func labelChanged(_ sender: UITextField) {
        if (label.text != "") {
            saveButton.isEnabled = true;
        } else {
            saveButton.isEnabled = false;
        }
    }
    
    @IBAction func tappedOutsideText(_ sender: UITapGestureRecognizer) {
        label.resignFirstResponder()
    }
}
