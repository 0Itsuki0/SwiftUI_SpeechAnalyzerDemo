//
//  AudioMetricsView.swift
//  SpeechAnalyzerDemo
//
//  Created by Itsuki on 2025/09/05.
//


import SwiftUI
import AVFAudio

struct AudioMetricsView: View {
    var powerLevels: [PowerLevel]
    var elapsedTime: TimeInterval
    
    
    var body: some View {
        let total = AVAudioPCMBuffer.kMaxLevel - AVAudioPCMBuffer.kMinLevel

        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text("Elapsed time: ")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(elapsedTime.secondString)
                    .foregroundStyle(.secondary)

            }


            ForEach(powerLevels, id: \.self) { metric in
                
                let linearAverage = metric.average.linearPower
                let linearPeak = metric.peak.linearPower
                
                VStack {
                    Text(String("Channel (Bus): \(metric.channel)"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    ProgressView(value: linearAverage, total: total, label: {
                        Text("Average Power: \(metric.average.powerString)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    })

                    ProgressView(value: linearPeak, total: total, label: {
                        Text("Peak Power: \(metric.peak.powerString)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    })

                }

            }

        }
    }
}

