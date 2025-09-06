//
//  PowerLevel.swift
//  AVAudioEngineDemo
//
//  Created by Itsuki on 2025/08/30.
//

import SwiftUI

// Power of a specific channel
//
// average and peak are expressed in decibels full-scale (dBFS)
//
// - min: -160 dB (0.000_000_01)
// - max: 0 dB (1.0)
struct PowerLevel: Identifiable, Hashable {
    let channel: Int
    let average: Float
    let peak: Float
    
    var id: Int {
        return channel
    }
}
