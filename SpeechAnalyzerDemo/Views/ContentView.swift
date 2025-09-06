//
//  ContentView.swift
//  SpeechAnalyzerDemo
//
//  Created by Itsuki on 2025/09/04.
//

import SwiftUI


struct ContentView: View {
    @Environment(SpeechAnalyzeManager.self) private var manager

    @State private var supportedLocales: [Locale] = []
    @State private var locale: Locale = SpeechAnalyzeManager.defaultLocale
    
    var body: some View {
        @Bindable var manager = manager

        List {
            Section {
                Text("With Speech Analyzer")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowBackground(Color.clear)
                    .listRowInsets(.leading, 0)
                    .listRowInsets(.top, 0)
            }
            .listSectionMargins(.vertical, 0)
            
            Section {
                HStack {
                    Text("Locale")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Picker(selection: $locale, content: {
                        ForEach(self.supportedLocales, id: \.identifier) { locale in
                            Text(locale.language.maximalIdentifier)
                                .tag(locale)
                        }
                    }, label: {})
                }
                .foregroundStyle(.secondary)
                
            }
            .listSectionMargins(.top, 0)
            .listSectionMargins(.bottom, 8)
            
            Section {
                let disable = self.locale == manager.locale
                Button(action: {
                    Task {
                        do {
                            try await manager.updateLocale(locale)
                        } catch (let error) {
                            manager.error = error
                        }
                    }
                }, label: {
                    Text("Apply Change")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(ConcentricRectangle())
                })
                .buttonStyle(.borderless)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .listRowInsets(.all, 0)
                .disabled(disable)
                .listRowBackground(Color.blue.mix(with: .white, by: disable ? 0.3 : 0))
            }
            .listSectionMargins(.bottom, 24)

            
            Section {
                NavigationLink(destination: {
                    FileTranscriptionView()
                        .environment(self.manager)
                }, label: {
                    Text("Demo")
                })
            } header: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Transcribe From File")
                    Text("Select a file, and transcribe the contents.")
                        .font(.subheadline)
                }
            }
            .listSectionMargins(.bottom, 24)

            Section {
                NavigationLink(destination: {
                    RealTimeTranscriptionView()
                        .environment(self.manager)

                }, label: {
                    Text("Demo")
                })
            } header: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Real Time Transcription")
                    Text("Capture the input, and transcribe in real time.")
                        .font(.subheadline)
                }
            }

        }
        .contentMargins(.top, 0)
        .navigationTitle("Speech To Text")
        .navigationBarTitleDisplayMode(.large)
        .task {
            let supportedLocales = await Transcriber.supportedLocales
            self.supportedLocales = supportedLocales.map(\.0)
        }
        .disabled(manager.isSettingUp)
        .overlay(content: {
            if manager.isSettingUp {
                ProgressView()
                    .controlSize(.extraLarge)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.gray.opacity(0.3))
            }
        })
        .alert("Oops!", isPresented: $manager.showError, actions: {
            Button(action: {
                manager.showError = false
            }, label: {
                Text("OK")
            })
        }, message: {
                Text("\(manager.error?.message ?? "Unknown Error")")
        })

    }
}


#Preview {
    ContentView()
        .environment(SpeechAnalyzeManager(locale: .current))
}
