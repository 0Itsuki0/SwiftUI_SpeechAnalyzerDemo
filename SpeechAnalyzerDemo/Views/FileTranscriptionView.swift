//
//  FileTranscriptionView.swift
//  SpeechAnalyzerDemo
//
//  Created by Itsuki on 2025/09/06.
//


import SwiftUI
import Speech

struct FileTranscriptionView: View {
    @Environment(SpeechAnalyzeManager.self) private var manager

    @State var showImporter: Bool = false
    @State var url: URL? = nil

    var body: some View {
        @Bindable var manager = manager
        List {
            Section {
                Text("- Select an Audio File \n- Transcribe the Contents")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .listRowInsets(.leading, 8)
                
            }
            .listSectionMargins(.bottom, 0)

            Section {
                HStack {
                    Group {
                        if let name = url?.lastPathComponent {
                            Text(name)
                        } else {
                            Text("No file selected.")
                        }
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)

                    Spacer()
                    
                    Button(action: {
                        self.showImporter = true
                    }, label: {
                        Image(systemName: "plus.app")
                            .resizable()
                            .scaledToFit()
                            .contentShape(.circle)
                            .frame(width: 20)
                    })
                    .buttonStyle(.borderless)

    
                }
                .foregroundStyle(.secondary)
                .listRowInsets(.horizontal, 20)
                
            }
            .listSectionMargins(.bottom, 24)

            
            Section {
                let disable = manager.isTranscribing || self.url == nil
                Button(action: {
                    Task {
                        do {
                            guard let url = url else {
                                return
                            }
                            try await manager.transcribeFile(url)
                        } catch (let error) {
                            manager.error = error
                        }
                    }
                }, label: {
                    Text("Load & Transcribe")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(ConcentricRectangle())
                })
                .buttonStyle(.borderless)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .listRowInsets(.all, 0)
                .listRowBackground(Color.blue.mix(with: .white, by: disable ? 0.3 : 0))
                .disabled(disable)
                

            }
            .listSectionMargins(.bottom, 0)
            
            Section {
                let disable = !manager.isTranscribing

                Button(action: {
                    Task {
                        do {
                            try await manager.stopTranscription()
                        } catch (let error) {
                            manager.error = error
                        }
                    }
                }, label: {
                    Text("Stop Transcription")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(ConcentricRectangle())
                })
                .buttonStyle(.borderless)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .listRowInsets(.all, 0)
                .listRowBackground(Color.redGray.mix(with: .white, by: disable ? 0.3 : 0))
                .disabled(disable)

            }
            .listSectionMargins(.bottom, 24)


            Section("Transcripts") {
                TranscriptionView()
            }
            .listSectionMargins(.bottom, 24)
            
        }
        .navigationTitle("From File")
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
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false,
            onCompletion: { result in
                switch result {
                    
                case .success(let urls):
                    print(urls)
                    self.url = urls.first
                    
                case .failure(let error):
                    self.manager.error = error
                }
            }
        )
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
 
}

