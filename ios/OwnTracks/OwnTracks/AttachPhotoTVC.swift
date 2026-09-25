//
//  AttachPhotoTVC.swift
//  OwnTracks
//
//  Created by Christoph Krey on 18.03.26.
//  Copyright © 2026 OwnTracks. All rights reserved.
//

import Foundation
import UIKit
import PhotosUI

@objc(AttachPhotoTVC)

class AttachPhotoTVC : UITableViewController, PHPickerViewControllerDelegate {
    @IBOutlet weak var poi: UITextView!;
    @IBOutlet weak var photo: UIImageView!;
    @IBOutlet weak var saveButton: UIBarButtonItem!;
    @objc public var imageName: String?;
    @objc public var data: Data?;
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated);
        adjustSaveButton()
    }

     func adjustSaveButton() {
        saveButton.isEnabled = (poi.text != nil &&
                                poi.text.count > 0 &&
                                photo.image != nil);
    }

    @IBAction func editingChanged(_ sender: UITextField) {
        adjustSaveButton();
    }
    
    @IBAction func selectPressed(_ sender: UIButton) {
        let pickerConfiguration = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared());
        let pickerViewController = PHPickerViewController(configuration: pickerConfiguration);
        pickerViewController.delegate = self;
        present(pickerViewController, animated: true);
    }
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        for result in results {
            imageName = result.itemProvider.suggestedName
            if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                result.itemProvider.loadObject(ofClass: UIImage.self) { (image, error) in
                    if let image = image as? UIImage {
                        DispatchQueue.main.async {
                            let scale = 192.0 / min(image.size.width, image.size.height);
                            let size = CGSizeApplyAffineTransform(image.size, CGAffineTransform(scaleX: scale, y: scale));
                            UIGraphicsBeginImageContextWithOptions(CGSize(width: 192.0, height: 192.0), false, 1.0);
                            image.draw(in: CGRect(origin: CGPoint(x: (192.0 - size.width) / 2,
                                                                  y: (192.0 - size.height) / 2),
                                                  size: size))
                            let scaledImage = UIGraphicsGetImageFromCurrentImageContext()!
                            UIGraphicsEndImageContext()
                            self.photo.image = scaledImage;
                        }
                    }
                }
            }
        }
        picker.dismiss(animated: true) {
            self.adjustSaveButton();
        }
    }
}
