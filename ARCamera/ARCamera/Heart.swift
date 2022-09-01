//
//  Heart.swift
//  ARCamera
//
//  Created by Hyeonsoo Kim on 2022/09/01.
//

import RealityKit
import ARKit

class Heart: Entity, HasModel {
    
    private var heartColor: SimpleMaterial.Color = .gray
    private var heartEntity: ModelEntity?
    
    required init() {
        super.init()
        
        let heart = MeshResource.generateSphere(radius: 0.3)
        let material = SimpleMaterial(color: .gray, isMetallic: true)
        let heartEntity = ModelEntity(mesh: heart, materials: [material])
        addChild(heartEntity)
    }
}
