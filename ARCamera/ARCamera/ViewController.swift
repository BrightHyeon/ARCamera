//
//  ViewController.swift
//  ARCamera
//
//  Created by Hyeonsoo Kim on 2022/08/31.
//

import ARKit
import RealityKit

class ViewController: UIViewController {
    
    @IBOutlet var arView: ARView!
    
    private lazy var fixButton: UIButton = {
        let button = UIButton(frame: CGRect(x: 100, y: 600, width: 80, height: 80))
        button.setTitle("FIX", for: .normal)
        button.setTitleColor(UIColor.black, for: .normal)
        button.backgroundColor = .white
        button.layer.cornerRadius = 8
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 1.0, height: 4.0)
        button.layer.shadowRadius = 2
        button.layer.shadowOpacity = 0.4
        button.addTarget(self, action: #selector(fixHeart), for: .touchUpInside)
        return button
    }()
    
    // coreml model
    private var model: HandPose?
    private var handPoseRequest = VNDetectHumanHandPoseRequest()
    
    // smoothly
    private var frameCounter: Int = 0
    private var handPosePredictionInterval: Int = 5
    
    private var cameraAnchor: AnchorEntity?
    private var heart: Heart?
    let configuration = ARWorldTrackingConfiguration()
    
    private var previousValue = 0
    private var count: Int = 0
    private var click: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupModel()
        
        handPoseRequest.maximumHandCount = 1
        handPoseRequest.revision = VNDetectHumanHandPoseRequestRevision1
        
        arView.session.delegate = self
        
        cameraAnchor = AnchorEntity(.camera)
        arView.scene.addAnchor(cameraAnchor!)
        
        arView.addSubview(fixButton)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        arView.session.run(configuration)
    }
    
    private func setupModel() {
        do {
            let config = MLModelConfiguration()
            self.model = try HandPose(configuration: config)
        } catch {
            fatalError("Cannot configure coreml model")
        }
    }
    
    private func addHeartPreview() {
        self.cameraAnchor = AnchorEntity(.camera)
        arView.scene.addAnchor(cameraAnchor!)
    }
    
    private func updateHeartPreview(simd: SIMD3<Float>) {
        if let cameraAnchor = cameraAnchor {
            print("child: \(cameraAnchor.children.count)")
            if cameraAnchor.children.count == 0 {
                heart = Heart()
                print("새로 생성")
                cameraAnchor.addChild(heart!)
                cameraAnchor.position = SIMD3(SCNVector3(simd.x * 50, simd.y * 50, simd.z * 50))
            } else {
                cameraAnchor.position = SIMD3(SCNVector3(simd.x * 50, simd.y * 50, simd.z * 50))
                print("Z: \(simd.z * 40)")
                
//                if simd.z * 40 > previousValue - 10 || simd.z * 40 < previousValue + 10 {
//                    count += 1
//                } else {
//                    previousValue = simd.z * 40
//                }
//                if count > 30 {
//                    click = true
//                }
//                if click {
//                    click()
//                    count = 0
//                    click = false
//                }
            }
        } else {
            addHeartPreview()
        }
    }
    
    @objc
    func fixHeart() {
        guard let heart = heart, heart.isEnabled else { return }
        let heartWorldTransform = heart.transformMatrix(relativeTo: nil)
        heart.anchor?.reanchor(.world(transform: heartWorldTransform))
        self.heart = nil
        self.cameraAnchor = nil
    }
}

/*
 실제 1m = 화면에서의 200mm라 할 때.
 100mm 이동하면 50cm이동하는 수식.
 */

extension ViewController: ARSessionDelegate {
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
    
        frameCounter += 1
        
        if frameCounter % handPosePredictionInterval == 0 {
            
            let pixelBuffer = frame.capturedImage // 1. Image Capture
//            pixelBuffer
            
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:]) // 2. Make Handler
            
            do {
                try handler.perform([handPoseRequest]) // 3. Perform
                
            } catch {
                assertionFailure("Human Pose Request failed: \(error)")
            }
            
            // 4. Get results.  VNHumanHandPoseObservations.
            guard let handPoses = handPoseRequest.results, !handPoses.isEmpty else { return }
            
            let handObservation = handPoses.first // 5. One hand
            
            guard let keypointsMultiArray = try? handObservation?.keypointsMultiArray() else { fatalError() }
            
            // 6. Model Operation
            let handPosePrediction = try? model?.prediction(poses: keypointsMultiArray)
            
            // 7. confidence
            let confidence = handPosePrediction?.labelProbabilities[handPosePrediction?.label ?? "nil이다."]
            
            guard let label = handPosePrediction?.label,
                  let confidence = confidence else { return }
            
            if label == "heart" && confidence > 0.9 {
                if let fingerPoint = try? handObservation?.recognizedPoint(.thumbTip) {
                    // Question. x, y 왜 바뀐 느낌이지.
                    // x는 위일수록 0, 아래일수록 1. y는 왼일수록 0, 우일수록 1.\
                    let heartFingerPostion = CGPoint(x: fingerPoint.y * arView.bounds.width,
                                                     y: fingerPoint.x * arView.bounds.height)
                    let simd = arView.unproject(heartFingerPostion, viewport: arView.bounds)!
                    updateHeartPreview(simd: simd)
                }
            } else {
                guard let cameraAnchor = cameraAnchor else { return }
                cameraAnchor.children.removeAll()
            }
        }
    }
}
