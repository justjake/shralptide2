//
//  SwipeRecognizer.swift
//  ShralpTide2
//
//  Created by Jake Teton-Landis on 11/26/23.
//

import Foundation
import SwiftUI
import UIKit

public typealias SwipeAction = (UISwipeGestureRecognizer.Direction) -> Void
public typealias PanAction = (UIPanGestureRecognizer) -> Void

struct SwipeRecognizerView: UIViewRepresentable {
    let swipe: SwipeAction?
    let pan: PanAction?
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        
        if swipe != nil {
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
        }
        
        if pan != nil {
            let panRecognizer = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.respondToPanGesture))
            view.addGestureRecognizer(panRecognizer)
        }
        
        return view
    }
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let swipe: SwipeAction?
        let pan: PanAction?
        
        init(swipe: SwipeAction?, pan: PanAction?) {
            self.swipe = swipe
            self.pan = pan
        }
        
        @objc func respondToSwipeGesture(gesture: UIGestureRecognizer) {
            guard let swipeGesture = gesture as? UISwipeGestureRecognizer else { return }
            guard let onSwipe = swipe else { return }
            onSwipe(swipeGesture.direction)
        }
        
        @objc func respondToPanGesture(gesture: UIGestureRecognizer) {
            guard let panGesture = gesture as? UIPanGestureRecognizer else { return }
            guard let onPan = pan else { return }
            onPan(panGesture)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(swipe: swipe, pan: pan)
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct SwipeModifier: ViewModifier {
    let swipe: SwipeAction?
    let pan: PanAction?
    
    func body(content: Content) -> some View {
        content
            .overlay {
                SwipeRecognizerView(swipe: swipe, pan: pan)
                    .focusable()
                    .onMoveCommand(perform: { direction in
                        guard let swipe = swipe else { return }
                        switch direction {
                            case .down:
                                swipe(.down)
                            case .up:
                                swipe(.up)
                            case .left:
                                swipe(.left)
                            case .right:
                                swipe(.right)
                        }
                    })
            }
    }
}

struct PanModifier: ViewModifier {
    let action: PanAction
    
    func body(content: Content) -> some View {
        content
            .overlay {
                SwipeRecognizerView(swipe: nil, pan: action)
                    .focusable()
            }
    }
}

public extension View {
    func onSwipeGesture(swipe: @escaping SwipeAction, pan: @escaping PanAction) -> some View {
        return modifier(SwipeModifier(swipe: swipe, pan: pan))
    }
}
