//
//  ViewController.swift
//  ARCamera
//
//  Created by Hyeonsoo Kim on 2022/08/31.
//

import UIKit
import ARKit
import RealityKit

class ViewController: UIViewController {
    
    @IBOutlet var arView: ARView!
    
    private var handPoseRequest = VNDetectHumanHandPoseRequest()
    private var model: HeartPose1?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupModel()
        handPoseRequest.maximumHandCount = 1
        handPoseRequest.revision = VNDetectHumanHandPoseRequestRevision1
        
        // Load the "Box" scene from the "Experience" Reality File
        let boxAnchor = try! Experience.loadBox()
        
        // Add the box anchor to the scene
        arView.scene.anchors.append(boxAnchor)
    }
    
    func setupModel() {
        do {
            let config = MLModelConfiguration()
            self.model = try HeartPose1(configuration: config)
        } catch {
            fatalError("Cannot configure coreml model")
        }
    }
    
}


extension ViewController: ARSessionDelegate {
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        
        let pixelBuffer = frame.capturedImage //Depth Data?
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try handler.perform([handPoseRequest])
        } catch {
            assertionFailure("Human Pose Request failed: \(error)")
        }
        
        // VNHumanHandPoseObservations
        guard let handPoses = handPoseRequest.results, !handPoses.isEmpty else {
            return // No effects to draw, so clear out current graphics
        }
        
        let handObservation = handPoses.first
        
        
        guard let keypointsMultiArray = try? handObservation?.keypointsMultiArray() else { fatalError() }
//        let handPosePrediction = try HeartPose1().model.prediction(from: key)
    }
}

/*
 1. VNDetectHumanHandPoseRequest (손 모양을 감지할 수 있는 이미지 기반 vision request)
    - .maximumHandCount : 최대 인식 손의 수. default 2.
 
 2. VNHumanHandPoseObservation
    - request를 보내면, results 배열로 들어오는 타입.
    - handPoseRequest.results?.first가 하나의 손에 접근하는 것.
    - 최대 인식 손의 수 만큼 손들을 판단할 수 있음. 1로 제한되어있으면 result도 하나만 들어온다.
 
 3.
 
 
 */
