//
//  FriendAnnotationV.swift
//  OwnTracks
//
//  Created by Christoph Krey on 12.03.26.
//  Copyright © 2026 OwnTracks. All rights reserved.
//

import Foundation
import MapKit

@objc(FriendAnnotationV)

class FriendAnnotationV: MKAnnotationView {
    @objc public var tid: String? = nil;
    @objc public var personImage: UIImage?;
    @objc public var speed: Double = 0.0;
    @objc public var course: Double = 0.0;
    @objc public var automatic: Bool = false;
    @objc public var me: Bool = false;
    
    let circleSize = 40.0;
    let fenceWidth = 5.0;
    let idFontSize = 20.0;
    let idInset = 3.0;
    let courseWidth = 10.0;
    let tachoScale = 30.0;
    let tachoMax = 260.0;
    
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
        
        UIKit.UIColor(named: "circleColor")?.setFill();
        circle.fill();
        
        if personImage != nil  && personImage!.cgImage != nil {
            let scaledImage = UIImage(cgImage:personImage!.cgImage!,
                                      scale:max(personImage!.size.width, personImage!.size.height) / circleSize,
                                      orientation:.up);
            scaledImage.draw(in: rect);
        } else {
            if tid != nil && !tid!.isEmpty {
                let font = UIFont.boldSystemFont(ofSize: CGFloat(idFontSize));
                let attributes: [NSAttributedString.Key : Any] = [NSAttributedString.Key.font: font,
                                                                  NSAttributedString.Key.foregroundColor: UIKit.UIColor(named: "idColor") ?? UIColor.black];
                let boundingRect = tid!.boundingRect(with: rect.size,
                                                     options: [],
                                                     attributes: attributes,
                                                     context: nil);
                let textRect = CGRect(x: rect.origin.x + (rect.size.width - boundingRect.size.width) / 2.0,
                                      y: rect.origin.y + (rect.size.height - boundingRect.size.height) / 2.0,
                                      width: boundingRect.size.width,
                                      height: boundingRect.size.height);
                tid!.draw(in: textRect, withAttributes: attributes as [NSAttributedString.Key : Any]);
            }
        }

        if speed > 0.0 {
            let tacho = UIBezierPath();
            tacho.move(to: CGPoint(x: rect.origin.x + rect.size.width / 2.0,
                                   y: rect.origin.y + rect.size.height / 2.0));
            tacho.append(UIBezierPath(arcCenter: CGPoint(x: rect.size.width / 2.0,
                                                         y: rect.size.height / 2.0),
                                      radius: circleSize / 2.0,
                                      startAngle: .pi / 2.0 + .pi / 6.0,
                                      endAngle: .pi / 2.0 + .pi / 6.0 + .pi * 2.0 * 5.0 / 6.0 * min(speed / tachoMax, 1.0),
                                      clockwise: true));
            tacho.addLine(to: CGPoint(x:rect.origin.x + rect.size.width / 2.0,
                                      y:rect.origin.y + rect.size.height / 2.0));
            tacho.close()
            UIKit.UIColor(named: "tachoColor")?.setFill();
            tacho.fill();
            UIKit.UIColor(named: "circleColor")?.setStroke();
            tacho.lineWidth = 1.0;
            tacho.stroke();
        }
        
        circle.lineWidth = CGFloat(fenceWidth);
        if me {
            UIKit.UIColor(named: "meColor")?.setStroke();
        } else {
            UIKit.UIColor(named: "friendColor")?.setStroke();
        }
        circle.stroke();
        
        if course > 0.0 {
            let courseRect = CGRect(x: rect.origin.x + rect.size.width / 2.0 + circleSize / 2.0 * cos((course - 90.0) / 360.0 * 2.0 * .pi) - courseWidth / 2.0,
                                    y: rect.origin.y + rect.size.height / 2.0 + circleSize / 2.0 * sin((course - 90.0) / 360.0 * 2.0 * .pi) - courseWidth / 2.0,
                                    width: courseWidth,
                                    height: courseWidth);
            let course = UIBezierPath(ovalIn: courseRect);
            UIKit.UIColor(named: "courseColor")?.setFill();
            course.fill();
            UIKit.UIColor(named: "circleColor")?.setStroke();
            course.lineWidth = 1.0;
            course.stroke();
            
        }
    }
    
    @objc func getImage() -> UIImage {
        UIGraphicsBeginImageContextWithOptions(CGSize(width: circleSize, height: circleSize), false, 0.0);
        draw(CGRect(x: 0.0, y: 0.0, width: circleSize, height: circleSize));
        let image: UIImage = UIGraphicsGetImageFromCurrentImageContext()!;
        UIGraphicsEndImageContext();
        return image;
    }
    
    override func setDragState(_ newDragState: MKAnnotationView.DragState, animated: Bool) {
        switch newDragState {
        case .starting:
            dragState = .dragging;
        case .dragging:
            break;
        case .canceling:
            dragState = .none;
        case .ending:
            dragState = .none;
        case .none:
            break;
        @unknown default:
            break;
        }
    }
}
