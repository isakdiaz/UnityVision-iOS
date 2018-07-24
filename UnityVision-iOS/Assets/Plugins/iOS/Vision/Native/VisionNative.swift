//
//  Vision.swift
//  Vision
//
//  Created by Adam Hegedus on 2018. 05. 23..
//  Copyright © 2018. Possible Zrt. All rights reserved.
//

import Foundation
import AVFoundation
import Vision

@objc public class VisionNative: NSObject {
    
    // Shared instance
    @objc static let shared = VisionNative()
    
    // Used to cache vision requests to be performed
    private lazy var visionRequests = [VNRequest]()
    
    // Unique serial queue reserved for vision requests
    private let visionRequestQueue = DispatchQueue(label: "com.possible.boxar.visionqueue")
    
    // Id of the managed Unity game object to forward messages to
    private var callbackTarget: String = "Vision"
    
    // Exposed buffer for caching the results of an image classification request
    @objc public var classificationBuffer: [VisionClassification] = []
    private var maxClassificationResults: Int = 10
    
    // Exposed buffer for caching the results of a rectangle recognition request
    @objc public var pointBuffer: [CGPoint] = []
    
    @objc func allocateVisionRequests(requestType: Int, maxObservations: Int)
    {
        // Empty request buffer
        visionRequests.removeAll()
        
        if (requestType == 0) {
            print("[VisionNative] No requests specified.")
            return
        }
        
        let classifierEnabled = requestType != 2;
        let rectangleRecognitionEnabled = requestType != 1
        
        if classifierEnabled {
            
            // Set up CoreML model
            guard let selectedModel = try? VNCoreMLModel(for: Inceptionv3().model) else {
                // (Optional) This can be replaced with other models on https://developer.apple.com/machine-learning/
                fatalError("[VisionNative] Could not load model. Ensure model has been drag and dropped (copied) to XCode Project from https://developer.apple.com/machine-learning/ . Also ensure the model is part of a target (see: https://stackoverflow.com/questions/45884085/model-is-not-part-of-any-target-add-the-model-to-a-target-to-enable-generation ")
            }
            
            // Set up Vision-CoreML request
            let classificationRequest = VNCoreMLRequest(model: selectedModel, completionHandler: classificationCompleteHandler)
            
            // Crop from centre of images and scale to appropriate size
            classificationRequest.imageCropAndScaleOption = VNImageCropAndScaleOption.centerCrop
            
            // Set the number of maximum image classifications results kept in store
            self.maxClassificationResults = maxObservations
            
            // Register request
            visionRequests.append(classificationRequest)
            
            print("[VisionNative] Classification request allocated.")
        }
        
        if rectangleRecognitionEnabled {
            
            // Set up rectangle detection request
            let rectangleRequest = VNDetectRectanglesRequest(completionHandler: rectangleRecognitionCompleteHandler)
            rectangleRequest.maximumObservations = maxObservations
            rectangleRequest.quadratureTolerance = 15
            
            // Register request
            visionRequests.append(rectangleRequest)
            
            print("[VisionNative] Rectangle detection request allocated.")
        }
    }
    
    @objc func evaluate(texture: MTLTexture) -> Bool {
        
        // Create an image from the current state of the buffer
        guard let image = CIImage(mtlTexture: texture, options: nil) else { return false }
        
        // Perform vision request
        performVisionRequest(for: image)
        
        return true
    }
    
    @objc func evaluate(buffer: CVPixelBuffer) -> Bool {
        
        // Lock the buffer
        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags.readOnly)
        
        // Create an image from the current state of the buffer
        let image = CIImage(cvPixelBuffer: buffer)
        
        // Unlock the buffer
        CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags.readOnly)
        
        // Perform vision request
        performVisionRequest(for: image)
        
        return true
    }
    
    private func performVisionRequest(for image: CIImage) {
        
        visionRequestQueue.async {
            // Prepare image request
            let imageRequestHandler = VNImageRequestHandler(ciImage: image, options: [:])
            
            // Run image request
            do {
                try imageRequestHandler.perform(self.visionRequests)
            } catch {
                print(error)
            }
        }
    }
    
    @objc func setCallbackTarget(target: String) {
        
        // Set the target for unity messaging
        self.callbackTarget = target
    }
    
    private func classificationCompleteHandler(request: VNRequest, error: Error?) {
        
        // Fall back to main thread
        DispatchQueue.main.async {
            
            // Catch errors
            if error != nil {
                let error = "[VisionNative] Error: " + (error?.localizedDescription)!
                UnitySendMessage(self.callbackTarget, "OnClassificationComplete", error)
                return
            }
            
            guard let observations = request.results as? [VNClassificationObservation],
                let _ = observations.first else {
                    UnitySendMessage(self.callbackTarget, "OnClassificationComplete", "No results")
                    return
            }
            
            // Cache classifications
            self.classificationBuffer.removeAll()
            for o in observations.prefix(self.maxClassificationResults) {
                self.classificationBuffer.append(
                    VisionClassification(identifier: o.identifier, confidence:o.confidence))
            }
            
            // Call unity object with no errors
            UnitySendMessage(self.callbackTarget, "OnClassificationComplete", "")
        }
    }
    
    private func rectangleRecognitionCompleteHandler(request: VNRequest, error: Error?) {
        
        // Fall back to main thread
        DispatchQueue.main.async {
            
            // Catch errors
            if error != nil {
                let error = "[VisionNative] Error: " + (error?.localizedDescription)!
                UnitySendMessage(self.callbackTarget, "OnRectangleRecognitionComplete", error)
                return
            }
            
            guard let observations = request.results as? [VNRectangleObservation],
                let _ = observations.first else {
                    UnitySendMessage(self.callbackTarget, "OnRectangleRecognitionComplete", "No results")
                    return
            }
            
            // Cache points
            self.pointBuffer.removeAll()
            for observation in observations {
                self.pointBuffer.append(contentsOf: [
                    observation.topLeft,
                    observation.topRight,
                    observation.bottomRight,
                    observation.bottomLeft])
            }
            
            // Call unity object with no errors
            UnitySendMessage(self.callbackTarget, "OnRectangleRecognitionComplete", "")
        }
    }
}
