//
//  RealTimeTranscriptionView.swift
//  SpeechAnalyzerDemo
//
//  Created by Itsuki on 2025/09/06.
//

import SwiftUI

struct RealTimeTranscriptionView: View {
    @Environment(SpeechAnalyzeManager.self) private var manager

    var body: some View {
        @Bindable var manager = manager
        List {
            Section {
                Text("- Capture the Audio Input \n- Transcribe in Real time")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .listRowInsets(.leading, 8)
                
            }
            .listSectionMargins(.bottom, 0)

            
            Section {
                switch manager.audioCapturerState {
                case .stopped:
                    Button(action: {
                        Task {
                            do {
                                try await manager.startRealTimeTranscription()
                            } catch (let error) {
                                manager.error = error
                            }
                        }
                    }, label: {
                        Text("Capture & Transcribe")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(ConcentricRectangle())
                    })
                    .buttonStyle(.borderless)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .listRowInsets(.all, 0)
                    .listRowBackground(Color.blue)
                    
                case .paused:
                    
                    VStack(spacing: 24) {
                        HStack {
                            Text("Paused")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Spacer()
                            HStack(spacing: 16) {
                                button(imageName: "stop.circle", action: {
                                    Task {
                                        do {
                                            try await manager.stopTranscription()
                                        } catch (let error) {
                                            manager.error = error
                                        }

                                    }
                                })
                                
                                button(imageName: "play.circle", action: {
                                    do {
                                        try manager.resumeRealTimeTranscription()
                                    } catch (let error) {
                                        manager.error = error
                                    }
                                })
                                
                            }
                        }
                        
                    }

                case .started:
                    
                    VStack(spacing: 24) {
                        HStack {
                            Text("Transcribing")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Spacer()
                            HStack(spacing: 16) {
                                button(imageName: "stop.circle", action: {
                                    Task {
                                        do {
                                            try await manager.stopTranscription()
                                        } catch (let error) {
                                            manager.error = error
                                        }
                                    }
                                })

                                button(imageName: "pause.circle", action: {
                                    manager.pauseRealTimeTranscription()
                                })

                            }
                        }
                        
                    }
                    
                }


                if manager.audioCapturerState != .stopped, let event = manager.audioInputEvents {
                    AudioMetricsView(powerLevels: event.0, elapsedTime: event.1)
                }
            }
            .listSectionMargins(.bottom, 24)


            Section("Transcripts") {
                TranscriptionView()
            }
            .listSectionMargins(.bottom, 24)
            
        }
        .navigationTitle("Real-Time")
        .navigationBarTitleDisplayMode(.large)
        .alert("Oops!", isPresented: $manager.showError, actions: {
            Button(action: {
                manager.showError = false
            }, label: {
                Text("OK")
            })
        }, message: {
                Text("\(manager.error?.message ?? "Unknown Error")")
        })
        .onDisappear {
            manager.resetTranscripts()
            Task {
                do {
                    try await manager.stopTranscription()
                } catch (let error) {
                    manager.error = error
                }
            }
        }

    }
    
    private func button(imageName: String, action: @escaping () -> Void) -> some View {
        Button(action: action, label: {
            Image(systemName: imageName)
                .resizable()
                .scaledToFit()
                .contentShape(.circle)
                .frame(width: 32)
        })
        .buttonStyle(.borderless)
    }

}

