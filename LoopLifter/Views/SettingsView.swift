//
//  SettingsView.swift
//  LoopLifter
//
//  Application settings
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("exportFormat") private var exportFormat: String = "wav"
    @AppStorage("exportBitDepth") private var exportBitDepth: Int = 24
    @AppStorage("includeMetadata") private var includeMetadata: Bool = true
    @AppStorage("autoSelectAll") private var autoSelectAll: Bool = true
    @AppStorage("confidenceThreshold") private var confidenceThreshold: Double = 0.5

    var body: some View {
        TabView {
            // Export Settings
            Form {
                Section("Export Format") {
                    Picker("Format", selection: $exportFormat) {
                        Text("WAV").tag("wav")
                        Text("AIFF").tag("aiff")
                    }
                    .pickerStyle(.segmented)

                    Picker("Bit Depth", selection: $exportBitDepth) {
                        Text("16-bit").tag(16)
                        Text("24-bit").tag(24)
                        Text("32-bit float").tag(32)
                    }

                    Toggle("Include metadata JSON", isOn: $includeMetadata)
                }

                Section("Folder Structure") {
                    Text("Exports will be organized by stem type and category")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .tabItem {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .padding()

            // Analysis Settings
            Form {
                Section("Detection") {
                    VStack(alignment: .leading) {
                        Text("Minimum Confidence: \(Int(confidenceThreshold * 100))%")
                        Slider(value: $confidenceThreshold, in: 0.3...0.9, step: 0.1)
                    }

                    Text("Samples below this confidence will be hidden")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }

                Section("Selection") {
                    Toggle("Auto-select all samples", isOn: $autoSelectAll)
                }
            }
            .tabItem {
                Label("Analysis", systemImage: "waveform.badge.magnifyingglass")
            }
            .padding()
        }
        .frame(width: 400, height: 300)
    }
}

#Preview {
    SettingsView()
}
