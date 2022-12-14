//
//  ViewController.swift
//  ARCamera
//
//  Created by Hyeonsoo Kim on 2022/08/31.
//

import ARKit
import RealityKit

class ViewController: UIViewController {
    
    // MARK: Properties
    
    @IBOutlet var arView: ARView!
    
    // coreml model
    private var model: HandPose?
    private var handPoseRequest = VNDetectHumanHandPoseRequest()
    
    // smoothly
    private var frameCounter: Int = 0
    private var handPosePredictionInterval: Int = 5
    
    private var cameraAnchor: AnchorEntity?
    private var heart: Heart?
    let configuration = ARWorldTrackingConfiguration()
    
    private var backCount: Int = 0
    private var preX: Float = 0.0
    private var preY: Float = 0.0
    private var count: Int = 0
    private var pick: Bool = false
    
    private lazy var snapButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "metalButton"), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(snapShot), for: .touchUpInside)
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupModel()
        
        handPoseRequest.maximumHandCount = 1
        handPoseRequest.revision = VNDetectHumanHandPoseRequestRevision1
        
        arView.session.delegate = self
        
        cameraAnchor = AnchorEntity(.camera)
        arView.scene.addAnchor(cameraAnchor!)
        
        arView.addSubview(snapButton)
        makeConstraints()
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
            if cameraAnchor.children.count == 0 {
                heart = Heart()
                cameraAnchor.addChild(heart!)
                cameraAnchor.position = SIMD3(SCNVector3(simd.x * 50, simd.y * 50, simd.z * 50))
            } else {
                cameraAnchor.position = SIMD3(SCNVector3(simd.x * 50, simd.y * 50, simd.z * 50))
//                print("X??????: \(simd.x * 50)")
//                print("Y??????: \(simd.y * 50)")
                print(count)
                
                if simd.x*50 > preX - 0.03 &&
                    simd.x*50 < preX + 0.03 &&
                    simd.y*50 > preY - 0.03 &&
                    simd.y*50 < preY + 0.03 {
                    count += 1
                } else {
                    count = 0
                    preX = simd.x*50
                    preY = simd.y*50
                }
                
                if count > 20 {
                    count = 0
                    fixHeart()
                }
                
                // ????????? ????????????????????? ??? ??? ?????? background??? ?????? ??????, count reset.
            }
        } else {
            addHeartPreview()
        }
    }
    
    private func fixHeart() {
        guard let heart = heart, heart.isEnabled else { return }
        let heartWorldTransform = heart.transformMatrix(relativeTo: nil)
        heart.anchor?.reanchor(.world(transform: heartWorldTransform))
        self.heart = nil
        self.cameraAnchor = nil
    }
    /*
     //1. Create A Snapshot
     let snapShot = self.augmentedRealityView.snapshot()

     //2. Save It The Photos Album
     UIImageWriteToSavedPhotosAlbum(snapShot, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
     */
    @objc
    func snapShot() {
        // saveToHDR??? false??? ?????? ????????? ????????? ????????? ?????????.
        SystemSound.shared.playSystemSound(id: 1108)
        self.arView.snapshot(saveToHDR: false) { image in
            UIImageWriteToSavedPhotosAlbum(image ?? UIImage(), nil, nil, nil)
        }
    }
}

/*
 ?????? 1m = ??????????????? 200mm??? ??? ???.
 100mm ???????????? 50cm???????????? ??????.
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
            let confidence = handPosePrediction?.labelProbabilities[handPosePrediction?.label ?? "nil??????."]
            
            guard let label = handPosePrediction?.label,
                  let confidence = confidence else { return }
            
            if label == "heart" && confidence > 0.8 {
                if let fingerPoint = try? handObservation?.recognizedPoint(.thumbTip) {
                    // Question. x, y ??? ?????? ????????????.
                    // x??? ???????????? 0, ??????????????? 1. y??? ???????????? 0, ???????????? 1.\
                    let heartFingerPostion = CGPoint(x: fingerPoint.y * arView.bounds.width,
                                                     y: fingerPoint.x * arView.bounds.height)
                    let simd = arView.unproject(heartFingerPostion, viewport: arView.bounds)!
                    updateHeartPreview(simd: simd)
                }
                backCount = 0
            } else {
                guard let cameraAnchor = cameraAnchor else { return }
                cameraAnchor.children.removeAll()
                backCount += 1
                if backCount > 7 {
                    count = 0
                }
            }
        }
    }
    
    private func makeConstraints() {
        let constraints = [
            snapButton.bottomAnchor.constraint(equalTo: arView.bottomAnchor, constant: -30),
            snapButton.centerXAnchor.constraint(equalTo: arView.centerXAnchor),
            snapButton.widthAnchor.constraint(equalToConstant: 80),
            snapButton.heightAnchor.constraint(equalToConstant: 80)
        ]
        NSLayoutConstraint.activate(constraints)
    }
}
