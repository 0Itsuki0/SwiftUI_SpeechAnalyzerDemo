//
//  TimeInterval.swift
//  SpeechAnalyzerDemo
//
//  Created by Itsuki on 2025/08/25.
//

import SwiftUI

extension TimeInterval {
    var secondString: String {
        "\(self.formatted(.number.precision(.fractionLength(0)))) sec"
    }
}
