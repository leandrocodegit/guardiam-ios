//
//  CertificatesTVC.swift
//  OwnTracks
//
//  Created by Christoph Krey on 16.02.26.
//  Copyright © 2026 OwnTracks. All rights reserved.
//

import Foundation
import UIKit

@objc(CertificatesTVC)

class CertificatesTVC: UITableViewController {
    @objc public var selectedFileName = "";
    var fileList : [URL] = [];
    
    func load() {
        fileList = [];
        do {
            let directory = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true );
            let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isDirectoryKey]);
            for url in enumerator?.allObjects as! [URL] {
                if url.pathExtension == "otrp" {
                    let resourceValues = try url.resourceValues(forKeys:[.isDirectoryKey])
                    if !resourceValues.isDirectory! {
                        fileList.append(url);
                    }
                }
            }
        } catch {
            
        }
        tableView.reloadData();
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);
        load();
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1;
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fileList.count;
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "certificate", for: indexPath);
        let file = fileList[indexPath.row];
        cell.textLabel?.text = file.lastPathComponent;
        
        if file.lastPathComponent == selectedFileName {
            cell.accessoryType = .checkmark;
        } else {
            cell.accessoryType = .none;
        }
        return cell;
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true;
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let file = fileList[indexPath.row];
            if file.lastPathComponent == selectedFileName {
                selectedFileName = "";
            }
            
            do {
                try FileManager.default.removeItem(at: file);
            } catch {
                
            }
            load();
        }
    }
    
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return false;
    }
    
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        let file = fileList[indexPath.row];
        
        if file.lastPathComponent == selectedFileName {
            selectedFileName = "";
        } else {
            selectedFileName = file.lastPathComponent;
        }
        tableView.reloadData();
        return nil;
    }
}
