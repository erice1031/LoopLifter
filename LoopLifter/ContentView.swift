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

        do {
            // Check if Demucs is installed
            guard await StemSeparator.isDemucsInstalled() else {
                analysisState = .error(StemSeparationError.demucsNotFound.localizedDescription)
                return
            }

            // Create output directory for stems
            let outputDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("LoopLifter")
                .appendingPathComponent(UUID().uuidString)

            try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

            // Separate stems with Demucs
            let stemURLs = try await StemSeparator.separate(
                audioURL: url,
                outputDir: outputDir,
                model: .htdemucs
            ) { progress in
                Task { @MainActor in
                    self.analysisState = .separating(progress: progress)
                }
            }

            // Analyze each stem
            var allSamples: [ExtractedSample] = []
            let stemTypes = Array(stemURLs.keys).sorted { $0.rawValue < $1.rawValue }

            for (index, stemType) in stemTypes.enumerated() {
                guard let stemURL = stemURLs[stemType] else { continue }

                let stemProgress = Double(index) / Double(stemTypes.count)
                analysisState = .analyzing(stem: stemType.displayName, progress: stemProgress)

                // Detect tempo and onsets using Aubio
                print("🔍 Analyzing \(stemType.displayName): \(stemURL.lastPathComponent)")
                let tempo = try await AubioAnalyzer.detectTempo(in: stemURL)
                let onsets = try await AubioAnalyzer.detectOnsets(in: stemURL)
                print("   Tempo: \(tempo) BPM, Onsets: \(onsets.count)")

                // Load audio to get duration
                let audioFile = try AudioFile(url: stemURL)
                try await Task.sleep(for: .milliseconds(100)) // Let duration load
                let duration = audioFile.duration > 0 ? audioFile.duration : 30.0

                // Create hit samples from onset times directly
                // Use first 8 onsets as individual hits
                let sortedOnsets = onsets.sorted()
                print("   First 8 onsets: \(sortedOnsets.prefix(8).map { String(format: "%.2f", $0) })")
                for (hitIndex, onset) in sortedOnsets.prefix(8).enumerated() {
                    // Calculate hit duration (until next onset or max 500ms)
                    let nextOnset = hitIndex + 1 < sortedOnsets.count ? sortedOnsets[hitIndex + 1] : onset + 0.5
                    let hitDuration = min(nextOnset - onset, 0.5)

                    var sample = ExtractedSample(
                        name: "\(stemType.displayName) Hit \(hitIndex + 1)",
                        category: .hit,
                        stemType: stemType,
                        duration: hitDuration,
                        barLength: nil,
                        confidence: 0.8
                    )
                    sample.startTime = onset
                    sample.endTime = onset + hitDuration
                    sample.audioURL = stemURL
                    allSamples.append(sample)
                }
                print("   Created \(min(8, sortedOnsets.count)) hits for \(stemURL.lastPathComponent)")

                // Create loop samples based on onset density
                if onsets.count > 4 {
                    let secondsPerBeat = 60.0 / tempo
                    let secondsPerBar = secondsPerBeat * 4

                    // Try to find 2-bar loop
                    let twoBarDuration = secondsPerBar * 2
                    if duration >= twoBarDuration {
                        var sample = ExtractedSample(
                            name: "\(stemType.displayName) Loop",
                            category: .loop,
                            stemType: stemType,
                            duration: twoBarDuration,
                            barLength: 2,
                            confidence: 0.85
                        )
                        sample.startTime = 0
                        sample.endTime = twoBarDuration
                        sample.audioURL = stemURL
                        allSamples.append(sample)
                    }
                }

                analysisState = .analyzing(
                    stem: stemType.displayName,
                    progress: Double(index + 1) / Double(stemTypes.count)
                )
            }

            extractedSamples = allSamples
            analysisState = .complete

        } catch {
            analysisState = .error(error.localizedDescription)
        }
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
