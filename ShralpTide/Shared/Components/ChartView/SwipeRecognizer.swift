//
//  SwipeRecognizer.swift
//  ShralpTide2
//
//  Created by Jake Teton-Landis on 11/26/23.
//

import Foundation
import SwiftUI
import UIKit

typealias SwipeAction = (UISwipeGestureRecognizer.Direction) -> Void

struct SwipeRecognizerView: UIViewRepresentable {
    let action: SwipeAction
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let upSwipeRecognizer = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.respondToSwipeGesture))
        upSwipeRecognizer.direction = .up
        
        let downSwipeRecognizer = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.respondToSwipeGesture))
        downSwipeRecognizer.direction = .down
        
        let leftSwipeRecognizer = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.respondToSwipeGesture))
        leftSwipeRecognizer.direction = .left
        
        let rightSwipeRecognizer = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.respondToSwipeGesture))
        rightSwipeRecognizer.direction = .right
        
        view.addGestureRecognizer(upSwipeRecognizer)
        view.addGestureRecognizer(downSwipeRecognizer)
        view.addGestureRecognizer(leftSwipeRecognizer)
        view.addGestureRecognizer(rightSwipeRecognizer)
        
        return view
    }
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let action: SwipeAction
        
        init(action: @escaping SwipeAction) {
            self.action = action
        }
        
        @objc func respondToSwipeGesture(gesture: UIGestureRecognizer) {
            guard let swipeGesture = gesture as? UISwipeGestureRecognizer else { return }
            action(swipeGesture.direction)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct SwipeModifier: ViewModifier {
    let action: SwipeAction
    
    func body(content: Content) -> some View {
        content
            .overlay {
                SwipeRecognizerView(action: action)
                    .focusable()
                    .onMoveCommand(perform: { direction in
                        switch direction {
                            case .down:
                                action(.down)
                            case .up:
                                action(.up)
                            case .left:
                                action(.left)
                            case .right:
                                action(.right)
                        }
                    })
            }
    }
}

extension View {
    func onSwipeGesture(perform: @escaping SwipeAction) -> some View {
        return modifier(SwipeModifier(action: perform))
    }
}
