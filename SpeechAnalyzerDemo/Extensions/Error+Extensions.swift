//
//  Error.swift
//  SpeechAnalyzerDemo
//
//  Created by Itsuki on 2025/08/25.
//


import SwiftUI
import AVFAudio
import Speech

extension Error {
    var message: String {
        if let error = self as? SpeechAnalyzeManager._Error {
            return error.message
        }
        if let error = self as? Transcriber._Error {
            return error.message
        }
        if let error = self as? AudioCapturer._Error {
            return error.message
        }
        
        let nsError: NSError = self as NSError
        let code = nsError.code
        let domain = nsError.domain
        
        // SFSpeechError.Code: https://developer.apple.com/documentation/speech/sfspeecherror/code
        if domain == SFSpeechError.errorDomain {
            switch code {
                
            // Audio input errors
            case SFSpeechError.Code.audioDisordered.rawValue:
                return "The audio input time-code overlaps or precedes prior audio input."
                
            case SFSpeechError.Code.audioReadFailed.rawValue:
                return "Fail to read audio file."
             
            // Audio format errors
            case SFSpeechError.Code.incompatibleAudioFormats.rawValue:
                return "The selected modules do not have an audio format in common."

            case SFSpeechError.Code.unexpectedAudioFormat.rawValue:
                return "The audio input is in unexpected format."

            // Asset errors
            case SFSpeechError.Code.assetLocaleNotAllocated.rawValue:
                return "The asset locale has not been allocated."

            case SFSpeechError.Code.cannotAllocateUnsupportedLocale.rawValue:
                return "The asset locale being requested is not supported by SpeechFramework."

            case SFSpeechError.Code.noModel.rawValue:
                return "The selected locale/options does not have an appropriate model available or downloadable."

            case SFSpeechError.Code.timeout.rawValue:
                return "The operation timed out."
                
            case SFSpeechError.Code.tooManyAssetLocalesAllocated.rawValue:
                return "The application has allocated too many locales."
                
                
            // Custom language model errors
            case SFSpeechError.Code.malformedSupplementalModel.rawValue:
                return "The custom language model file was malformed."
                
            case SFSpeechError.Code.missingParameter.rawValue:
                return "Required parameter is missing/nil."

            case SFSpeechError.Code.undefinedTemplateClassName.rawValue:
                return "The custom language model templates were malformed."

                
            // Other errors
            case SFSpeechError.Code.insufficientResources.rawValue:
                return "There are not sufficient resources available on-device to process the incoming transcription request."

            case SFSpeechError.Code.internalServiceError.rawValue:
                return "An internal error occurred."

            case SFSpeechError.Code.moduleOutputFailed.rawValue:
                return "The module’s result task failed."

            default:
                break
            }
        }
        
        // AVAudioSession.ErrorCode: https://developer.apple.com/documentation/coreaudiotypes/avaudiosession/errorcode
        return switch code {
            // AVAudioSession.ErrorCode: https://developer.apple.com/documentation/coreaudiotypes/avaudiosession/errorcode
        case AVAudioSession.ErrorCode.cannotInterruptOthers.rawValue:
            "Please try again while the app is in the foreground."
        
        case AVAudioSession.ErrorCode.cannotStartPlaying.rawValue:
            "Start audio playback is not allowed."
        
        case AVAudioSession.ErrorCode.cannotStartRecording.rawValue:
            "Start audio recording failed."
        
        case AVAudioSession.ErrorCode.expiredSession.rawValue:
            "Audio Session expired."
        
        case AVAudioSession.ErrorCode.resourceNotAvailable.rawValue:
            "Hardware resources is insufficient."

        case AVAudioSession.ErrorCode.sessionNotActive.rawValue:
            "Session is not active."

        case AVAudioSession.ErrorCode.siriIsRecording.rawValue:
            "Action not allowed due to Siri is recording."

        case AVAudioSession.ErrorCode.insufficientPriority.rawValue:
            "Same audio category is used by other apps. Please terminate those and try again."

        default:
            self.localizedDescription
        }
    }
}
