//
//  TabBarController.swift
//  OwnTracks
//
//  Created by Christoph Krey on 18.03.26.
//  Copyright © 2026 OwnTracks. All rights reserved.
//

import Foundation
import UIKit

@objc(TabBarController)

class TabBarController: UITabBarController {
    var regionTVC: UIViewController? = nil;
    var historyVC: UIViewController? = nil;

    override func viewDidLoad() {
        super.viewDidLoad();
        
        if viewControllers != nil {
            for vc in viewControllers! {
                if vc.tabBarItem.tag == 96 {
                    regionTVC = vc;
                }
                if vc.tabBarItem.tag == 97 {
                    historyVC = vc;
                }
            }
        }
        
        NotificationCenter.default.addObserver(forName:  NSNotification.Name(rawValue: "reload"),
                                               object: nil,
                                               queue: OperationQueue.main) { [self] notification in
            DispatchQueue.main.async {
                self.adjust();
            }
        };
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);
        self.tabBar.isHidden = true;
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated);
        self.tabBar.isHidden = true;
        adjust();
    }
    
    func adjust() -> () {
        var vCs = viewControllers;
    
        if vCs != nil {
            if historyVC != nil {
                if Settings.theMaximumHistory(inMOC: CoreData.sharedInstance().mainMOC) > 0 {
                    if !vCs!.contains(historyVC!) {
                        vCs!.insert(historyVC!, at: vCs!.count);
                    }
                } else {
                    if vCs!.contains(historyVC!) {
                        vCs!.removeAll(where: { $0 === historyVC! });
                    }

                }
            }
            
            if regionTVC != nil {
                if !Settings.theLocked(inMOC: CoreData.sharedInstance().mainMOC) {
                    if !vCs!.contains(regionTVC!) {
                        if vCs!.contains(historyVC!) {
                            vCs!.insert(regionTVC!, at: vCs!.count - 1);
                        } else {
                            vCs!.insert(regionTVC!, at: vCs!.count);
                        }
                    }
                } else {
                    if vCs!.contains(regionTVC!) {
                        vCs!.removeAll(where: { $0 === regionTVC! });
                    }
                }
            }
        }
        
        setViewControllers(vCs, animated: true);
    }

}
