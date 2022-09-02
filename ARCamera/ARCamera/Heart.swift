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
//    let material = SimpleMaterial(color: .gray, isMetallic: true)
    
    required init() {
        super.init()

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

/*
 occlusion,
 model color,
 mlmodel 멍청함.
 */
