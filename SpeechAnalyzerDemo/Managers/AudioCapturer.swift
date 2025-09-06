//
//  AudioCapturer.swift
//  SpeechAnalyzerDemo
//
//  Created by Itsuki on 2025/09/06.
//

import SwiftUI
// @preconcurrency required for sending AVAudioPCMBuffer, AVAudioTime
@preconcurrency import AVFAudio


// MARK: AudioCapturer specific models
extension AudioCapturer {
    
    enum EngineState {
        case started
        case paused
        case stopped
    }
    
    enum _Error: Error {
        
        case permissionDenied
        case unknownPermission
        case builtinMicNotFound
        case inputNotEnabled
        
        var message: String {
            switch self  {
                
            case .permissionDenied:
                "Capturing Permission Denied."
            case .unknownPermission:
                "Unknown Capturing Permission."
                
            case .builtinMicNotFound:
                "Built in Mic is not found."
                           
            // When the engine renders to and from an audio device, the AVAudioSession category and the availability of hardware determines whether an app performs input (for example, input hardware isn't available in tvOS).
            // Check the input node's input format (specifically, the hardware format) for a nonzero sample rate and channel count to see if input is in an enabled state.
            case .inputNotEnabled:
                "Input node is not available to use"
            }
        }
    }
}


// MARK: Main Implementation
// `nonisolated` required because
// `installTap(onBus:bufferSize:format:block:)`: https://developer.apple.com/documentation/avfaudio/avaudionode/installtap(onbus:buffersize:format:block:) will crash if called from the main thread
nonisolated class AudioCapturer {

    let inputTapEventsStream: AsyncStream<(AVAudioPCMBuffer, AVAudioTime)>
    private let inputTapEventsContinuation: AsyncStream<(AVAudioPCMBuffer, AVAudioTime)>.Continuation
    
    private let audioEngine = AVAudioEngine()
    private let audioSession: AVAudioSession = AVAudioSession.sharedInstance()

    private let bufferSize: UInt32 = 1024

    init() throws {
        (self.inputTapEventsStream, self.inputTapEventsContinuation) = AsyncStream.makeStream(of: (AVAudioPCMBuffer, AVAudioTime).self)
        try self.configureAudioSession()
    }
    
    private func configureAudioSession() throws {
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker, .allowBluetoothHFP])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // not required, only for retrieving the input source a little easier
        // when configuring for stereo
        guard let availableInputs = audioSession.availableInputs,
              let builtInMicInput = availableInputs.first(where: { $0.portType == .builtInMic }) else {
            throw _Error.builtinMicNotFound
        }
        try audioSession.setPreferredInput(builtInMicInput)
    }


    func startCapturingInput() async throws {
        print(#function)
        try await self.checkRecordingPermission()
        
        self.audioEngine.reset()

        let inputNode = audioEngine.inputNode
        
        if !inputNode.isEnabled {
            throw _Error.inputNotEnabled
        }
        
        let format = inputNode.outputFormat(forBus: 0)
        
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: self.bufferSize, format: format) { (buffer: AVAudioPCMBuffer, time: AVAudioTime) in
            self.inputTapEventsContinuation.yield((buffer, time))
        }
        
        audioEngine.prepare()
        // This method calls the prepare() method if you don’t call it after invoking stop().
        try audioEngine.start()
    }
    
    func pauseCapturing() {
        self.audioEngine.pause()
    }
    
    func resumeCapturing() throws {
        try self.audioEngine.start()
    }

    func stopCapturing() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        // resets all audio nodes in the audio engine.
        // ie: same as calling AVAudioNode.reset() on all the individual nodes.
        // For example, use it to silence reverb and delay tails.
        //
        // this function will not detach/disconnect any nodes, nor set any parameters back to the default value
        self.audioEngine.reset()
    }
    
    // recording permission is needed when accessing mic
    private func checkRecordingPermission() async throws {
        let permission = AVAudioApplication.shared.recordPermission
        switch permission {
            
        case .undetermined:
            let result = await AVAudioApplication.requestRecordPermission()
            if !result {
                throw _Error.permissionDenied
            }
            return
            
        case .denied:
            throw _Error.permissionDenied
            
        case .granted:
            return
            
        @unknown default:
            throw _Error.unknownPermission
        }
    }
}
