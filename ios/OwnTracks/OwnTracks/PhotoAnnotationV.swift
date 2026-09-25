//
//  PhotoAnnotationV.swift
//  OwnTracks
//
//  Created by Christoph Krey on 12.03.26.
//  Copyright © 2026 OwnTracks. All rights reserved.
//

import Foundation
import UIKit
import MapKit

@objc(PhotoAnnotationV)

class PhotoAnnotationV: MKAnnotationView {
    @objc public  var poiImage: UIImage?;
    let circleSize: CGFloat = 50.0;
    let fenceWidth: CGFloat = 3.0;
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(annotation: (any MKAnnotation)?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier);
        internalInit();
    }
    
    func internalInit() {
        backgroundColor = UIKit.UIColor(white: 1.0, alpha: 0.0);
        frame = CGRectMake(0.0, 0.0, circleSize, circleSize);
    }
        
    override func draw(_ rect: CGRect) {
        let circle = UIBezierPath(ovalIn: rect);
        circle.addClip();
        UIKit.UIColor.systemRed.setFill();
        circle.fill();
        
        if poiImage != nil && poiImage!.cgImage != nil {
            let scaledImage = UIImage(cgImage: poiImage!.cgImage!, scale: max(poiImage!.size.width, poiImage!.size.height) / circleSize,
                                      orientation: .up);
            scaledImage.draw(in: rect);
        }
        
        circle.lineWidth = fenceWidth;
        UIColor.systemYellow.setStroke();
        circle.stroke();
    }
    
}
