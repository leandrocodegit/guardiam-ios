//
//  CreateCardTVC.swift
//  OwnTracks
//
//  Created by Christoph Krey on 12.01.26.
//  Copyright © 2026 OwnTracks. All rights reserved.
//

import Foundation
import UIKit

@objc(CreateCardTVC)

class CreateCardTVC: UITableViewController, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    @IBOutlet weak public var name: UITextField!
    @IBOutlet weak public var cardImage: UIImageView!
    @IBOutlet weak var saveButton: UIBarButtonItem!
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated);
        let moc = CoreData.sharedInstance().mainMOC;
        let topic = Settings.theGeneralTopic(inMOC: moc);
        let myself = Friend(topic: topic, in: moc);
        
        if name.text == nil || name.text!.isEmpty {
            if myself.name != nil && !myself.name!.isEmpty {
                name.text = myself.name!
            } else {
                name.text = myself.effectiveTid;
            }
        }
        
        if cardImage.image == nil {
            if myself.image != nil {
                cardImage.image = UIImage(data: myself.image!);
            }
        }
        
        adjustSaveButton();
    }
    func adjustSaveButton () {
        saveButton.isEnabled = !name.text!.isEmpty && cardImage.image != nil;
    }
    
    @IBAction func editingChanged(_ sender: Any) {
        adjustSaveButton();
    }
    @IBAction func takePhotoPressed(_ sender: Any) {
        let imagePicker = UIImagePickerController();
        imagePicker.delegate = self;
        imagePicker.sourceType = .camera;
        imagePicker.mediaTypes = ["public.image"];
        imagePicker.allowsEditing = true;
        present(imagePicker, animated: true, completion: nil);
    }
    
    @IBAction func selectPressed(_ sender: Any) {
        let imagePicker = UIImagePickerController();
        imagePicker.delegate = self;
        imagePicker.sourceType = .photoLibrary;
        imagePicker.mediaTypes = ["public.image"];
        imagePicker.allowsEditing = true;
        present(imagePicker, animated: true, completion: nil);
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil);
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[UIImagePickerController.InfoKey.editedImage] as? UIImage {
            let scale = 192.0 / (image.size.width < image.size.height ? image.size.width : image.size.height);
            let size = CGSizeApplyAffineTransform(image.size,CGAffineTransformMakeScale(scale, scale));
            
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(192.0, 192.0), false, 1.0);
            image.draw(in: CGRect(x: (192.0 - size.width) / 2.0, y: (192.0 - size.height) / 2.0, width: size.width, height: size.height));
            image.withRenderingMode(.alwaysTemplate);
            let scaledImage = UIGraphicsGetImageFromCurrentImageContext()!;
            UIGraphicsEndImageContext();
            
            cardImage.image = scaledImage;
            adjustSaveButton();
        }
        dismiss(animated: true, completion: nil);
    }
}
