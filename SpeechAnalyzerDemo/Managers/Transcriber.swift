//
//  Transcriber.swift
//  SpeechAnalyzerDemo
//
//  Created by Itsuki on 2025/09/06.
//

import SwiftUI
import Speech

// MARK: Static properties
extension Transcriber {
    // (locale, installed or not)
    static var supportedLocales: [(Locale, Bool)] {
        get async {
            let supported = await SpeechTranscriber.supportedLocales
            let installed = await SpeechTranscriber.installedLocales
            
            return supported.map({($0, installed.contains($0))})
        }
    }
}

// MARK: Transcriber specific models
extension Transcriber {
    enum _Error: Error {
        case notAvailable
        case localeNotSupported
        case audioConverterCreationFailed
        case failedToConvertBuffer(String?)

        var message: String {
            return switch self {
                
            case .notAvailable:
                "Transcriber is not available on the given device."
            case .localeNotSupported:
                "Locale selected is not supported by transcriber."
            case .audioConverterCreationFailed:
                "Fail to create Audio Converter"
            case .failedToConvertBuffer(let s):
                "Failed to convert buffer to the destination format. \(s, default: "")"
            }
        }
    }

}

// MARK: Main Implementation
// https://developer.apple.com/documentation/speech/speechtranscriber
class Transcriber {
    
    let transcriptionResults: any AsyncSequence<SpeechTranscriber.Result, any Error>

    
    private let analyzer: SpeechAnalyzer
    
    private let transcriber: SpeechTranscriber
    
    // for audio engine to use when capturing input
    private var bestAvailableAudioFormat: AVAudioFormat? = nil
    
    // for real time transcribing
    private var inputStream: AsyncStream<AnalyzerInput>? = nil
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation? = nil
        

    // https://developer.apple.com/documentation/speech/speechtranscriber/preset
    //
    // timeIndexedProgressiveTranscription:
    // transcriptionOptions: []
    // reportingOptions: [.volatileResults, .fastResults]
    // attributeOptions: [.audioTimeRange]
    private let preset: SpeechTranscriber.Preset = .timeIndexedProgressiveTranscription
    
    private let locale: Locale

    private var audioConverter: AVAudioConverter?
    
    init(locale: Locale) async throws {
        guard SpeechTranscriber.isAvailable else {
            throw _Error.notAvailable
        }
        // Return Value: A locale in the supported locales list, or nil if there is no equivalent locale in that list.
        // If there is no exact equivalent, this method will return a near-equivalent:
        // a supported (and by preference already-installed) locale that shares the same Locale.LanguageCode value but has a different Locale.Region value.
        // This may result in an unexpected transcription, such as between “color” and “colour”.
        //
        // use the supportedLocale(equivalentTo:) function just in case a locale not within the Transcriber.supportedLocales is used
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            throw _Error.localeNotSupported
        }

        self.locale = locale
        
        // Assign your app’s asset reservations to those locales.
        // The AssetInventory class does this automatically if needed, but we can also call reserve(locale:) to do this manually.
        // This step is only necessary for modules with locale-specific assets; that is, modules conforming to LocaleDependentSpeechModule.
        // We can skip this step for other modules.
        //
        // An error if the number of locales would exceed maximumReservedLocales or if there is no asset that can support the locale.
        // return value: false if the locale was already reserved.
        try await AssetInventory.reserve(locale: locale)
        
        transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: self.preset.transcriptionOptions,
            reportingOptions: self.preset.reportingOptions.union([.alternativeTranscriptions]),
            attributeOptions: self.preset.attributeOptions.union([.transcriptionConfidence])
        )
        
        transcriptionResults = transcriber.results
                
        // To delay or prevent unloading an analyzer’s resources by caching them for later use by a different analyzer instance
        // we can select a SpeechAnalyzer.Options.ModelRetention option and create the analyzer with an appropriate SpeechAnalyzer.Options object.
        // we can also add/remove module after analyzer creation using analyzer.setModules
        analyzer = SpeechAnalyzer(modules: [transcriber], options: .init(priority: .userInitiated, modelRetention: .processLifetime))
        
        self.bestAvailableAudioFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])

        try await analyzer.prepareToAnalyze(in: self.bestAvailableAudioFormat, withProgressReadyHandler: nil)

        let installed = (await SpeechTranscriber.installedLocales).contains(locale)
        
        // Before using the SpeechAnalyzer class, we must install assets required by the modules (Locale) we plan to use.
        // These assets are machine-learning models downloaded from Apple’s servers and managed by the system.
        if !installed {
            // If the current status is .installed, returns nil, indicating that nothing further needs to be done.
            // An error if the assets are not supported or no reservations are available.
            // If some of the assets require locales that aren’t reserved, it automatically reserves those locales. If that would exceed maximumReservedLocales, then it throws an error.
            if let installationRequest = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await installationRequest.downloadAndInstall()
            }
        }
    }
    

    deinit {
        Task { [weak self] in
            await self?.finishAnalysisSession()
        }
    }
    
    // At the return of the finish(after:) method or any other ones that finish the analysis session,
    // the modules’ (SpeechTranscriber, and etc.) result streams will have ended and the modules will not accept further input from the input sequence.
    // The analyzer will not be able to resume analysis with a different input sequence and will not accept module changes; most methods will do nothing.
    func finishAnalysisSession() async {
        self.inputContinuation?.finish()
        
        // To end an analysis session, we must use one of the analyzer’s finish methods or parameters, or deallocate the analyzer.
        await self.analyzer.cancelAndFinishNow()
            
        // Removes an asset locale reservation
        // The system will remove the assets at a later time.
        await AssetInventory.release(reservedLocale: self.locale)

    }

    
    // for transcribing file
    func transcribeFile(_ fileURL: URL) async throws {
        
        print(#function)
        
        // To ensure the previous analysis is finished
        try await self.finalizePreviousTranscribing()
        
        // sometimes startAccessingSecurityScopedResource is not necessary and we might get a false for the return value.
        // Will move onto trying to create an AVAudioFile anyway.
        //
        // If we try to create an AVAudioFile using a security-scoped URL without calling startAccessingSecurityScopedResource, we will get this com.apple.coreaudio.avfaudio error -54.
        let _ = fileURL.startAccessingSecurityScopedResource()
        let audioFile = try AVAudioFile(forReading: fileURL)
                

        // NOTE:
        // Reason for not using analyzer.start: ie:  try await analyzer.start(inputAudioFile: audioFile, finishAfterFile: false)
        //
        // analyzer.start with finishAfterFile set to false will NOT analyze the last couple buffer of the file correctly, nor finalize the output result.
        // For short files, we will NEVER receive a result within the `transcriber.results` stream with the `isFinal` property being true.
        //
        // We could set finishAfterFile the true and that will indeed finalize the analysis correctly.
        // However, when set to true, the analysis will automatically finish the analysis session after the audio file has been fully processed.
        // Equivalent to calling finalizeAndFinishThroughEndOfInput().
        // Since we want to be able to reuse the analyzer, that won't work.
        //
        // I have also tried to call `analyzer.finalize` after calling analyzer.start
        // However, since we don't have a CMTime, The time-code of the last audio sample of the input,
        // calling finalize immediately after analyzer.start also won't solve the problem.
        let cmTime = try await analyzer.analyzeSequence(from: audioFile)
        
        // similar to the note above, without calling finalize, the last couple buffer of the file won't be read correctly.
        try await self.analyzer.finalize(through: cmTime)
        
        fileURL.stopAccessingSecurityScopedResource()
    }
    
    
    // for real time transcription
    func startRealTimeTranscription() async throws {
        print(#function)
        // To ensure the previous analysis is finished
        try await self.finalizePreviousTranscribing()

        (inputStream, inputContinuation) = AsyncStream<AnalyzerInput>.makeStream()
        
        try await analyzer.start(inputSequence: inputStream!)
    }
    

    func streamAudioToTranscriber(_ buffer: AVAudioPCMBuffer) {
        
        let format: AVAudioFormat = self.bestAvailableAudioFormat ?? buffer.format
        
        // fall back to the original one if conversion fails
        var convertedBuffer: AVAudioPCMBuffer = buffer
        
        do {
            convertedBuffer = try self.convertBuffer(buffer, to: format)
        } catch(let error) {
            print("error converting buffer: \(error)")
        }
        
        let input: AnalyzerInput = AnalyzerInput(buffer: convertedBuffer)
        self.inputContinuation?.yield(input)
    }
    
    
    // // https://developer.apple.com/documentation/speech/bringing-advanced-speech-to-text-capabilities-to-your-app
    func convertBuffer(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) throws -> AVAudioPCMBuffer {
        let inputFormat = buffer.format
        
        guard inputFormat != format else {
            return buffer
        }
        
        if audioConverter == nil || audioConverter?.outputFormat != format {
            audioConverter = AVAudioConverter(from: inputFormat, to: format)
            audioConverter?.primeMethod = .none // Sacrifice quality of first samples in order to avoid any timestamp drift from source
        }
        
        guard let audioConverter = audioConverter else {
            throw _Error.audioConverterCreationFailed
        }
        
        let sampleRateRatio = audioConverter.outputFormat.sampleRate / audioConverter.inputFormat.sampleRate
        let scaledInputFrameLength = Double(buffer.frameLength) * sampleRateRatio
        let frameCapacity = AVAudioFrameCount(scaledInputFrameLength.rounded(.up))
        guard let conversionBuffer = AVAudioPCMBuffer(pcmFormat: audioConverter.outputFormat, frameCapacity: frameCapacity) else {
            throw _Error.failedToConvertBuffer("Failed to create AVAudioPCMBuffer.")
        }
        
        var nsError: NSError?
        var bufferProcessed = false
        
        let status = audioConverter.convert(to: conversionBuffer, error: &nsError) { packetCount, inputStatusPointer in
            defer { bufferProcessed = true }
            // This closure can be called multiple times, but it only offers a single buffer.
            inputStatusPointer.pointee = bufferProcessed ? .noDataNow : .haveData
            return bufferProcessed ? nil : buffer
        }
        
        guard status != .error else {
            throw _Error.failedToConvertBuffer(nsError?.localizedDescription)
        }
        
        return conversionBuffer
    }
    
    
    // Important:
    // Use Finalize to ensure the previous sequence’s input is fully consumed
    // instead of finish(after:) method (or any other ones that finish the analysis session).
    //
    // Reason:
    // At the return of the finish(after:) method or any other ones that finish the analysis session,
    // the modules’ (SpeechTranscriber, and etc.) result streams will have ended and the modules will not accept further input from the input sequence.
    // The analyzer will not be able to resume analysis with a different input sequence and will not accept module changes; most methods will do nothing.
    // That is, we cannot reuse those SpeechModule or SpeechAnalyzer for any further transcribing tasks anymore!
    func finalizePreviousTranscribing() async throws {
        self.inputContinuation?.finish()
        self.inputStream = nil
        self.inputContinuation = nil
        // When nil, finalizes up to and including the last audio the analyzer has taken from the input sequence, and
        try await self.analyzer.finalize(through: nil)
    }
    
}
