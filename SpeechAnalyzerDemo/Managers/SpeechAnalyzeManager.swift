//
//  SpeechAnalyzeManager.swift
//  SpeechAnalyzerDemo
//
//  Created by Itsuki on 2025/09/04.
//


import SwiftUI
import Speech

// MARK: Static properties
extension SpeechAnalyzeManager {
    static let defaultLocale: Locale = Locale(languageCode: .english, script: nil, languageRegion: .unitedStates)
}

// MARK: Manager specific models
extension SpeechAnalyzeManager {
    enum _Error: Error {
        case failToCreateAudioCapturer
        case failToCreateTranscriber
        var message: String {
            switch self  {
                
            case .failToCreateAudioCapturer:
                "Failed to setup Audio Engine."
            case .failToCreateTranscriber:
                "Failed to set up speech analyzer."
            }
        }
        
    }
}

// MARK: Main Implementation
@Observable
class SpeechAnalyzeManager {

    var error: Error? {
        didSet {
            if let error = self.error {
                print(error.message)
                self.showError = true
                self.isSettingUp = false
            }
        }
    }

    var showError: Bool = false {
        didSet {
            if !showError {
                self.error = nil
            }
        }
    }
    
    private(set) var isSettingUp: Bool = false
    
    private(set) var locale: Locale
    
    private(set) var volatileTranscript: AttributedString = ""
    private(set) var finalizedTranscript: AttributedString = ""
    private(set) var isTranscribing: Bool = false
    

    private(set) var audioCapturerState: AudioCapturer.EngineState = .stopped {
        didSet {
            if self.audioCapturerState == .started {
                self.audioCapturingStartTime = AVAudioTime.machineTimeSeconds
                return
            }
            if self.audioCapturerState == .stopped {
                self.audioCapturingStartTime = nil
                self.audioInputEvents = nil
                return
            }
        }
    }
    private(set) var audioInputEvents: ([PowerLevel], ElapsedTime)? = nil
    private var audioCapturingStartTime: TimeInterval? = nil

    private var transcriber: Transcriber?
    private var audioCapturer: AudioCapturer?
    
    private var transcriptionResultsTask: Task<Void, Error>?
    private var audioInputTask: Task<Void, Error>?
        
    private let font = Font(.init(.message, size: 16, language: nil))
    private let lineHeight: AttributedString.LineHeight = .multiple(factor: 1.5)


    init(locale: Locale = SpeechAnalyzeManager.defaultLocale) {
        self.isSettingUp = true

        self.locale = locale
        
        self.setTranscriptsStyle()
        

        Task {
            do {
                try await self.setupTranscriber(locale: locale)
                try self.setupAudioCapturer()
                self.isSettingUp = false
            } catch (let error) {
                self.error = error
            }
        }
    }
    
    
    deinit {
        self.transcriptionResultsTask?.cancel()
        self.transcriptionResultsTask = nil
        
        self.audioInputTask?.cancel()
        self.audioInputTask = nil
        
        Task { [weak self] in
            await self?.transcriber?.finishAnalysisSession()
        }
    }

}

// MARK: functions for performing transcription
extension SpeechAnalyzeManager {
    // transcribe the entire file
    func transcribeFile(_ fileURL: URL) async throws {
        guard let transcriber = self.transcriber else {
            throw _Error.failToCreateTranscriber
        }
        guard self.isTranscribing == false else { return }

        self.resetTranscripts()
        self.isTranscribing = true
        
        defer {
            self.isTranscribing = false
        }
        
        try await transcriber.transcribeFile(fileURL)
    }
    
    
    func startRealTimeTranscription() async throws {
        guard self.isTranscribing == false else { return }
        guard self.audioCapturerState == .stopped else { return }
        
        guard let transcriber = self.transcriber else {
            throw _Error.failToCreateTranscriber
        }

        guard let audioCapturer = self.audioCapturer else {
            throw _Error.failToCreateAudioCapturer
        }


        try await audioCapturer.startCapturingInput()
        try await transcriber.startRealTimeTranscription()
        
        self.resetTranscripts()
        self.isTranscribing = true
        self.audioCapturerState = .started
        
    }
    
    func pauseRealTimeTranscription() {
        audioCapturerState = .paused
        self.audioCapturer?.pauseCapturing()
    }
    
    func resumeRealTimeTranscription() throws {
        try audioCapturer?.resumeCapturing()
        self.audioCapturerState = .started
    }
    
    
    // for both real time and file
    func stopTranscription() async throws {
        self.audioCapturer?.stopCapturing()
        try await self.transcriber?.finalizePreviousTranscribing()
        self.audioCapturerState = .stopped
        self.isTranscribing = false
    }
}


// MARK: functions for updating transcriber locale
extension SpeechAnalyzeManager {
    func updateLocale(_ locale: Locale) async throws {
        guard locale != self.locale else { return }
        guard self.isTranscribing == false else { return }
        
        print(#function)

        self.isSettingUp = true
        self.resetTranscripts()
        self.locale = locale
        
        await self.transcriber?.finishAnalysisSession()
        self.transcriber = nil

        self.transcriptionResultsTask?.cancel()
        self.transcriptionResultsTask = nil
        
        try await self.setupTranscriber(locale: locale)
        self.isSettingUp = false
    }
    
}


// MARK: functions for setting up audio capturer and transcriber
extension SpeechAnalyzeManager {
    private func setupAudioCapturer() throws {
        self.audioCapturer = try AudioCapturer()

        audioInputTask = Task {
            guard let audioCapturer = self.audioCapturer else {
                return
            }
            for await (buffer, time) in audioCapturer.inputTapEventsStream {
                if self.audioCapturerState == .started {

                    self.transcriber?.streamAudioToTranscriber(buffer)

                    if let startTime = self.audioCapturingStartTime {
                        self.audioInputEvents = (buffer.powerLevel, time.seconds - startTime)
                    }
                }
            }
        }
    }
    
    private func setupTranscriber(locale: Locale) async throws {
        self.transcriber = try await Transcriber(locale: locale)
        
        transcriptionResultsTask = Task {
            guard let transcriber = self.transcriber else {
                return
            }
            do {
                for try await result in transcriber.transcriptionResults {
                    let text = result.text

                    if result.isFinal {
                        let previousConfidence = finalizedTranscript.transcriptionConfidence
                        
                        finalizedTranscript.append(text)
                        
                        // update with the newest confidence if available
                        if let confidence = text.transcriptionConfidence {
                            finalizedTranscript.transcriptionConfidence = confidence
                        } else {
                            finalizedTranscript.transcriptionConfidence = previousConfidence
                        }
                        
                        print(finalizedTranscript)
                        volatileTranscript = ""
                    } else {
                        volatileTranscript = text
                    }
                    self.setTranscriptsStyle()
                }
            } catch(let error) {
                if error is CancellationError {
                    print("task cancelled")
                    return
                }
                
                self.error = error
                
                if self.isTranscribing {
                    try await self.stopTranscription()
                }
            }
        }
    }
}


// MARK: Other Helper functions
extension SpeechAnalyzeManager {

    func resetTranscripts() {
        self.volatileTranscript = ""
        self.finalizedTranscript = ""
    }
   
   private func setTranscriptsStyle() {
       self.finalizedTranscript.font = self.font
       self.finalizedTranscript.lineHeight = self.lineHeight
       
       self.volatileTranscript.foregroundColor = .redGray
       self.volatileTranscript.font = self.font.italic()
       self.volatileTranscript.lineHeight = self.lineHeight
   }
 
}
