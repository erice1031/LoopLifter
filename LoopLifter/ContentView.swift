//
//  ContentView.swift
//  LoopLifter
//
//  Main application view with drop zone and results
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var analysisState: AnalysisState = .idle
    @State private var extractedSamples: [ExtractedSample] = []
    @State private var audioURL: URL?
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerBar

            // Main content
            switch analysisState {
            case .idle:
                DropZoneView(isTargeted: $isTargeted) { url in
                    audioURL = url
                    startAnalysis(url: url)
                }

            case .separating(let progress):
                ProgressView("Separating stems...", value: progress, total: 1.0)
                    .padding(40)

            case .analyzing(let stem, let progress):
                VStack(spacing: 16) {
                    Text("Analyzing \(stem)...")
                        .font(.headline)
                    ProgressView(value: progress, total: 1.0)
                }
                .padding(40)

            case .complete:
                ResultsView(
                    samples: extractedSamples,
                    onExport: exportSamples,
                    onExportAll: exportAllSamples,
                    onOpenInLoOptimizer: openInLoOptimizer
                )

            case .error(let message):
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text("Error")
                        .font(.headline)
                    Text(message)
                        .foregroundColor(.secondary)
                    Button("Try Again") {
                        analysisState = .idle
                    }
                }
                .padding(40)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Image(systemName: "waveform.circle.fill")
                .font(.title)
                .foregroundColor(.accentColor)

            Text("LoopLifter")
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            if audioURL != nil && analysisState == .complete {
                Button {
                    analysisState = .idle
                    extractedSamples = []
                    audioURL = nil
                } label: {
                    Label("New File", systemImage: "plus")
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Actions

    private func startAnalysis(url: URL) {
        Task {
            await analyzeFile(url: url)
        }
    }

    @MainActor
    private func analyzeFile(url: URL) async {
        analysisState = .separating(progress: 0)

        // TODO: Implement actual analysis
        // 1. Separate stems with Demucs
        // 2. Analyze each stem for loops, hits, phrases
        // 3. Populate extractedSamples

        // Placeholder: simulate progress
        for i in 0...10 {
            try? await Task.sleep(for: .milliseconds(200))
            analysisState = .separating(progress: Double(i) / 10.0)
        }

        // Simulate analysis phase
        let stems = ["Drums", "Bass", "Vocals", "Other"]
        for (index, stem) in stems.enumerated() {
            for i in 0...5 {
                try? await Task.sleep(for: .milliseconds(100))
                analysisState = .analyzing(stem: stem, progress: Double(i) / 5.0)
            }
        }

        // Placeholder samples
        extractedSamples = [
            ExtractedSample(name: "Main Loop", category: .loop, stemType: .drums, duration: 2.0, barLength: 2, confidence: 0.95),
            ExtractedSample(name: "Fill 1", category: .fill, stemType: .drums, duration: 0.5, barLength: nil, confidence: 0.82),
            ExtractedSample(name: "Kick", category: .hit, stemType: .drums, duration: 0.1, barLength: nil, confidence: 0.98),
            ExtractedSample(name: "Snare", category: .hit, stemType: .drums, duration: 0.15, barLength: nil, confidence: 0.96),
        ]

        analysisState = .complete
    }

    private func exportSamples(_ samples: [ExtractedSample]) {
        // TODO: Implement export
        print("Exporting \(samples.count) samples")
    }

    private func exportAllSamples() {
        exportSamples(extractedSamples)
    }

    private func openInLoOptimizer() {
        // TODO: Implement LoOptimizer handoff
        print("Opening in LoOptimizer")
    }
}

// MARK: - Analysis State

enum AnalysisState: Equatable {
    case idle
    case separating(progress: Double)
    case analyzing(stem: String, progress: Double)
    case complete
    case error(String)
}

#Preview {
    ContentView()
}
