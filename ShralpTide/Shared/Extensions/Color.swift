//
//  Color.swift
//  ShralpTide
//
//  Created by Jake Teton-Landis on 11/23/23.
//

import Foundation
import SwiftUI

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: alpha
        )
    }
    
    static let RustGrey = Color(hex: 0x47585c)  // dark
    static let WillowGrey = Color(hex: 0xc8d5bb) // light
    
    static let IndigoFlowerGrey = Color(hex: 0x4d80e6) // saturated
    static let WhitePlumGrey = Color(hex: 0xe5e4e6) // light grey
    
    static let LightGreyCloud = Color(hex: 0xd4dcda) // light grey cloud ;)
    static let MinatoVillageGrey = Color(hex: 0x80989b) // dark green grey
}

extension ShapeStyle where Self == Color {
    static var willowGrey: Color {
        Color.WillowGrey
    }
    
    static var rustGrey: Color {
        Color.RustGrey
    }
}
