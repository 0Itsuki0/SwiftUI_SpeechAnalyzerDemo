//
//  AVAudio+Extensions.swift
//  SpeechAnalyzerDemo
//
//  Created by Itsuki on 2025/08/30.
//

import AVFAudio
import Accelerate
import SwiftUI


extension AVAudioPCMBuffer {
    
    static let kMinLevel: Float = 0.000_000_01 // -160 dB
    static let kMaxLevel: Float = 1.0 // 0 dB

    
    // Calculates the average (rms) and peak level of each channel in the PCM buffer and caches data.
    var powerLevel: [PowerLevel] {
        var powerLevels: [PowerLevel] = []
        
        let channelCount = Int(self.format.channelCount)
        let length = vDSP_Length(self.frameLength)

        if let floatData = self.floatChannelData {
            for channel in 0..<channelCount {
                powerLevels.append(calculatePowers(data: floatData[channel], strideFrames: self.stride, length: length, channel: channel))
            }
        } else if let int16Data = self.int16ChannelData {
            for channel in 0..<channelCount {
                // Convert the data from int16 to float values before calculating the power values.
                var floatChannelData: [Float] = Array(repeating: Float(0.0), count: Int(self.frameLength))
                vDSP_vflt16(int16Data[channel], self.stride, &floatChannelData, self.stride, length)
                var scalar = Float(INT16_MAX)
                vDSP_vsdiv(floatChannelData, self.stride, &scalar, &floatChannelData, self.stride, length)

                powerLevels.append(calculatePowers(data: floatChannelData, strideFrames: self.stride, length: length, channel: channel))
            }
        } else if let int32Data = self.int32ChannelData {
            for channel in 0..<channelCount {
                // Convert the data from int32 to float values before calculating the power values.
                var floatChannelData: [Float] = Array(repeating: Float(0.0), count: Int(self.frameLength))
                vDSP_vflt32(int32Data[channel], self.stride, &floatChannelData, self.stride, length)
                var scalar = Float(INT32_MAX)
                vDSP_vsdiv(floatChannelData, self.stride, &scalar, &floatChannelData, self.stride, length)

                powerLevels.append(calculatePowers(data: floatChannelData, strideFrames: self.stride, length: length, channel: channel))
            }
        }
        return powerLevels
    }

    private func calculatePowers(data: UnsafePointer<Float>, strideFrames: Int, length: vDSP_Length, channel: Int) -> PowerLevel {
        var max: Float = 0.0
        vDSP_maxv(data, strideFrames, &max, length)
        if max < Self.kMinLevel {
            max = Self.kMinLevel
        }

        var rms: Float = 0.0
        vDSP_rmsqv(data, strideFrames, &rms, length)
        if rms < Self.kMinLevel {
            rms = Self.kMinLevel
        }

        return PowerLevel(channel: channel, average: 20.0 * log10(rms), peak: 20.0 * log10(max))
    }
}


extension AVAudioTime {
    static var machineTimeSeconds: TimeInterval {
        return Self.seconds(forHostTime: mach_absolute_time())
    }

    var seconds: TimeInterval {
        return if self.isHostTimeValid {
            Self.seconds(forHostTime: self.hostTime)
        } else {
            Double(self.sampleTime) / self.sampleRate
        }
    }
}


extension AVAudioInputNode {
    
    // When the engine renders to and from an audio device, the AVAudioSession category and the availability of hardware determines whether an app performs input (for example, input hardware isn’t available in tvOS).
    // Check the input node’s input format (specifically, the hardware format) for a nonzero sample rate and channel count to see if input is in an enabled state.
    nonisolated
    var isEnabled: Bool {
        let inputFormat = self.inputFormat(forBus: 0)
        if inputFormat.sampleRate.isZero || inputFormat.sampleRate.isNaN {
            return false
        }
        if inputFormat.channelCount == 0 {
            return false
        }
        return true
    }
}
