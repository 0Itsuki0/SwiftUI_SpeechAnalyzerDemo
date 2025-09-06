//
//  SpeechAnalyzerDemoApp.swift
//  SpeechAnalyzerDemo
//
//  Created by Itsuki on 2025/09/04.
//

import SwiftUI

@main
struct SpeechAnalyzerDemoApp: App {
    let manager: SpeechAnalyzeManager = SpeechAnalyzeManager()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView()
                    .environment(manager)
            }
        }
    }
}
