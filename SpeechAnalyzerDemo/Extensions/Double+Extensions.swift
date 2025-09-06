//
//  Double+Extensions.swift
//  SpeechAnalyzerDemo
//
//  Created by Itsuki on 2025/09/06.
//

import SwiftUI

extension Double {
    func string(precision: Int) -> String {
        "\(self.formatted(.number.precision(.fractionLength(precision))))"
    }
}
