//
//  Heart.swift
//  ARCamera
//
//  Created by Hyeonsoo Kim on 2022/09/01.
//

import ARKit
import RealityKit
import Combine

class Heart: Entity, HasModel {
    
    private var cancellable: AnyCancellable?
    
    private var heartColor: SimpleMaterial.Color = .gray
    private var heartEntity: ModelEntity?
    
    required init() {
        super.init()
        
//        let heart = MeshResource.generateSphere(radius: 0.3)
//        let material = SimpleMaterial(color: .gray, isMetallic: true)
//        let heartEntity = ModelEntity(mesh: heart, materials: [material])
//        addChild(heartEntity)
        makeHeart()
    }
    
    func makeHeart() {
        cancellable = ModelEntity.loadAsync(named: "love")
            .sink { loadCompletion in
                if case let .failure(error) = loadCompletion {
                    print("Unable to load model \(error)")
                }
                self.cancellable?.cancel()
            } receiveValue: { [weak self] entity in
                print("하트 생성~!!")
                self?.addChild(entity)
            }
    }
}
