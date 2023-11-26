//
//  Number.swift
//  ShralpTide2
//
//  Created by Jake Teton-Landis on 11/26/23.
//

import Foundation

extension Float {
    func formatFeet() -> String {
        Measurement(value: Double(self), unit: UnitLength.feet).formatted()
    }
}
