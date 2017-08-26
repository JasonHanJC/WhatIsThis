//
//  ViewController.swift
//  WhatIsThis
//
//  Created by Juncheng Han on 8/26/17.
//  Copyright © 2017 Jason H. All rights reserved.
//

import UIKit
import CoreML
import Vision

class ViewController: UIViewController {
    
    
    @IBOutlet weak var textLabel: UILabel!
    @IBOutlet weak var titleItem: UINavigationItem!
    @IBOutlet weak var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }

    
    
    @IBAction func cameraButtonAction(_ sender: UIBarButtonItem) {
        
        let imagePickerController = MultiImagePickerViewController()
        imagePickerController.numberOfSelect = 1
        imagePickerController.pickerMediaType = .MediaTypeImage
        imagePickerController.shouldShowPreviewForCamera = true
        
        presentCustomAlbumPhotoView(imagePickerController, delegate: self)
        
    }
    
    private func presentCustomAlbumPhotoView(_ pickerViewController: MultiImagePickerViewController, delegate:MultiImagePickerControllerDelegate) {
        
        let status = PHPhotoLibrary.authorizationStatus()
        if status == .authorized {
            pickerViewController.delegate = delegate
            self.present(pickerViewController, animated: true, completion: nil)
        }
        else if status == .denied || status == .restricted {
            delegate.imagePickerViewControllerRecieveCameraAccessDenied(pickerViewController)
            
        } else if status == .notDetermined {
            
            PHPhotoLibrary.requestAuthorization({ (status) in
                DispatchQueue.main.async {
                    if status == .authorized {
                        pickerViewController.delegate = delegate
                        self.present(pickerViewController, animated: true, completion: nil)
                    } else {
                        delegate.imagePickerViewControllerRecieveCameraAccessDenied(pickerViewController)
                    }
                }
            })
        }
    }
    
    func detect(image: CIImage) {
        
        guard let model = Inceptionv3().model else {
            fatalError("Can't get the inceptionv3 model")
        }
        
        guard let vnModel = try? VNCoreMLModel.init(for: model) else {
            fatalError("Loading CoreML Model Failed")
        }
        
        let request = VNCoreMLRequest(model: vnModel) { (request, error) in
            if error != nil {
                fatalError(error.debugDescription)
            } else {
                guard let results = request.results as? [VNClassificationObservation] else {
                    fatalError("Model failed to process the image.")
                }
                
                if let first = results.first {
                
                    DispatchQueue.main.async {
                        self.titleItem.title = first.identifier;
                    }
                }
            }
        }
        
        let handler = VNImageRequestHandler(ciImage: image)
        
        
        do {
            try handler.perform([request])
        } catch {
            print(error)
        }
        
    }
}

extension ViewController: MultiImagePickerControllerDelegate {
    func imagePickerViewControllerRecievePhotoAlbumAccessDenied(_ picker: MultiImagePickerViewController!) {
        
    }
    
    func imagePickerViewControllerRecieveCameraAccessDenied(_ picker: MultiImagePickerViewController!) {
        
    }
    
    func imagePickerViewControllerDidCancel(_ picker: MultiImagePickerViewController!) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerViewController(_ picker: MultiImagePickerViewController!, didFinishPicking image: UIImage!) {
        picker.dismiss(animated: true, completion: nil)
        
        DispatchQueue.main.async {
            self.imageView.image = image
        }
        
        DispatchQueue.global(qos: .userInteractive).async {
            guard let ciImage = CIImage(image: image) else {
                fatalError("Can't get ciimage")
            }
        
        
            self.detect(image: ciImage)
        }
    }
}

