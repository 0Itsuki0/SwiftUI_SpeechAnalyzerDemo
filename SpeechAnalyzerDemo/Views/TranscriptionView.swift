//
//  TranscriptionView.swift
//  SpeechAnalyzerDemo
//
//  Created by Itsuki on 2025/09/06.
//

import SwiftUI

struct TranscriptionView: View {
    @Environment(SpeechAnalyzeManager.self) private var manager

    var body: some View {
        Group {
            if manager.volatileTranscript.characters.isEmpty && manager.finalizedTranscript.characters.isEmpty {
                Text("No Transcripts Available.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 24) {
                    Text(manager.finalizedTranscript + manager.volatileTranscript)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let confidence = manager.finalizedTranscript.transcriptionConfidence {
                        HStack {
                            Text("Confidence")
                                .font(.subheadline)
                                .fontWeight(.semibold)
            
                            Text(confidence.string(precision: 2))
            
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listRowInsets(.horizontal, 20)
    }

}
