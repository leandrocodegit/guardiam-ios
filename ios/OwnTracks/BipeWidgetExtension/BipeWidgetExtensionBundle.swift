//
//  BipeWidgetExtensionBundle.swift
//  BipeWidgetExtension
//
//  Created by user291221 on 8/18/26.
//  Copyright © 2026 OwnTracks. All rights reserved.
//

import WidgetKit
import SwiftUI

@main
struct BipeWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        BipeWidgetExtension()
        BipeWidgetExtensionControl()
        BipeWidgetExtensionLiveActivity()
    }
}
