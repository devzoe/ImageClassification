//
//  ViewController.swift
//  idea1
//
//  Created by 남경민 on 2023/02/02.
//

import UIKit
import CoreML
import Vision
import ImageIO
import PhotosUI

class ViewController: UIViewController {
    /// - Tag: MLModelSetup
    lazy var classificationRequest: VNCoreMLRequest = {
        do {
            // 모델 파일에 접근할 수 있도록 인스턴스 생성
            let model = try VNCoreMLModel(for: mymodel(configuration: MLModelConfiguration()).model)
            
            // Core ML 리퀘스트 인스턴스
            // CompletionHandler: 모델 초기화가 완료되면 처리할 내용
            let request = VNCoreMLRequest(model: model, completionHandler: { [weak self] request, error in
                self?.processClassifications(for: request, error: error)
            })
            
            // 이미지 분류를 요청할 때, 이미지가 크거나 비율이 다를 경우 이미지를 어디서 취할 것인가?
            // .centerCrop이 가장 많이 사용됨
            request.imageCropAndScaleOption = .centerCrop
            return request
        } catch {
            fatalError("Failed to load Vision ML model: \(error)")
        }
    }()
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var label: UILabel!
    
    @IBOutlet weak var button: UIButton!
    let imagePicker = UIImagePickerController()
    override func viewDidLoad() {
        
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.imagePicker.delegate = self // picker delegate
    }

    @IBAction func takeAPicture(_ sender: UIButton) {
        // 카메라를 사용할 수 있는 경우에만 source picker에 대한 옵션을 표시합니다.
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                return}
        
        presentPhotoPicker(sourceType: .camera)
    }
    @IBAction func chooseAPicture(_ sender: UIButton) {
        presentPhotoPicker(sourceType: .photoLibrary)
    }
    func presentPhotoPicker(sourceType: UIImagePickerController.SourceType) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = sourceType
        present(picker, animated: true)
    }
    
    /// 분류 결과를 바탕으로 UI를 업데이트합니다.
    /// - Tag: ProcessClassifications
    func processClassifications(for request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            guard let results = request.results else {
                self.label.text = "Unable to classify image.\n\(error!.localizedDescription)"
                return
            }
            // `result`는 이 프로젝트의 Core ML 모델에서 지정한 대로 항상 'VNClassificationObservation'이 됩니다.
            let classifications = results as! [VNClassificationObservation]
        
            if classifications.isEmpty {
                self.label.text = "Nothing recognized."
            } else {
                let topClassifications = classifications.prefix(2)
                let descriptions = topClassifications.map { classification in
                    // 표시할 분류 형식을 지정합니다. 예) "(0.37) Dog".
                   return String(format: "  (%.2f) %@", classification.confidence, classification.identifier)
                }
                self.label.text = "Classification:\n" + descriptions.joined(separator: "\n")
            }
        }
    }
    
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    // MARK: - Handling Image Picker Selection
    
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
               
               var newImage: UIImage? = nil // update 할 이미지
               
               if let possibleImage = info[UIImagePickerController.InfoKey.editedImage] as? UIImage {
                   newImage = possibleImage // 수정된 이미지가 있을 경우
               } else if let possibleImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
                   newImage = possibleImage // 원본 이미지가 있을 경우
               }
               
               self.imageView.image = newImage // 받아온 이미지를 update
               picker.dismiss(animated: true, completion: nil) // picker를 닫아줌
                updateClassifications(for: newImage!)

           }
            
    /// - Tag: PerformRequests
    func updateClassifications(for image: UIImage) {
        label.text = "Classifying..."
        
        let orientation = CGImagePropertyOrientation(image.imageOrientation) // 이미지 방향
        guard let ciImage = CIImage(image: image) else { fatalError("Unable to create \(CIImage.self) from \(image).") }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation)
            do {
                try handler.perform([self.classificationRequest])
            } catch {
                /*
                 이 핸들러는 일반적인 이미지 처리 오류를 포착합니다. `classificationRequest`의 완료 핸들러 `processClassifications(_:error:)`는 해당 요청 처리와 관련된 오류를 포착합니다.
                 */
                print("Failed to perform classification.\n\(error.localizedDescription)")
            }
        }
    }
      
}

extension CGImagePropertyOrientation {
    /**
     Converts a `UIImageOrientation` to a corresponding
     `CGImagePropertyOrientation`. The cases for each
     orientation are represented by different raw values.
     
     - Tag: ConvertOrientation
     */
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default:
            fatalError()
        }
    }
}

