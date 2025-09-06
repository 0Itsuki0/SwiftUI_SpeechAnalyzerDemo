//
//  Float.swift
//  SpeechAnalyzerDemo
//
//  Created by Itsuki on 2025/08/25.
//

import SwiftUI

extension Float {
    // decibels full-scale (dBFS)
    // The returned value ranges from –160 dBFS, indicating minimum power, to 0 dBFS, indicating maximum power.
    var powerString: String {
        "\(self.formatted(.number.precision(.fractionLength(0)))) dBFS"
    }
    
    var linearPower: Float {
        pow(10, self/20)
    }

}

