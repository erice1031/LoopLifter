//
//  ContentView.swift
//  LoopLifter
//
//  Main application view with drop zone and results
//

import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

/// Find when a stem actually has sustained significant audio content
/// Requires multiple consecutive chunks above threshold to avoid false positives from isolated transients
func findEnergyOnset(in url: URL, threshold: Float = 0.12, chunkDuration: Double = 0.25, requiredConsecutive: Int = 3) -> Double {
    do {
        let audioFile = try AVAudioFile(forReading: url)
        let sampleRate = audioFile.processingFormat.sampleRate
        let totalFrames = AVAudioFrameCount(audioFile.length)
        let chunkFrames = AVAudioFrameCount(chunkDuration * sampleRate)

        var currentFrame: AVAudioFramePosition = 0
        var consecutiveAboveThreshold = 0
        var firstAboveThresholdFrame: AVAudioFramePosition = 0

        while currentFrame < totalFrames {
            let framesToRead = min(chunkFrames, AVAudioFrameCount(totalFrames - AVAudioFrameCount(currentFrame)))
            guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: framesToRead) else {
                break
            }

            audioFile.framePosition = currentFrame
            try audioFile.read(into: buffer, frameCount: framesToRead)

            // Find peak in this chunk
            var maxSample: Float = 0
            if let channelData = buffer.floatChannelData {
                let frameCount = Int(buffer.frameLength)
                let channelCount = Int(buffer.format.channelCount)

                for ch in 0..<channelCount {
                    for i in 0..<frameCount {
                        let sample = abs(channelData[ch][i])
                        if sample > maxSample { maxSample = sample }
                    }
                }
            }

            // Track consecutive chunks above threshold
            if maxSample >= threshold {
                if consecutiveAboveThreshold == 0 {
                    firstAboveThresholdFrame = currentFrame
                }
                consecutiveAboveThreshold += 1

                // Found sustained energy
                if consecutiveAboveThreshold >= requiredConsecutive {
                    let timeSeconds = Double(firstAboveThresholdFrame) / sampleRate
                    return timeSeconds
                }
            } else {
                // Reset if we drop below threshold
                consecutiveAboveThreshold = 0
            }

            currentFrame += AVAudioFramePosition(framesToRead)
        }

        // No sustained content found, return 0
        return 0
    } catch {
        print("⚠️ Error finding energy onset: \(error)")
        return 0
    }
}

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

                // Find where this stem actually has significant audio content
                let energyOnset = findEnergyOnset(in: stemURL, threshold: 0.05)
                print("   Energy onset: \(String(format: "%.2f", energyOnset))s")

                // Filter onsets to only those after energy onset
                let sortedOnsets = onsets.sorted().filter { $0 >= energyOnset }
                print("   Onsets after energy: \(sortedOnsets.count), first 8: \(sortedOnsets.prefix(8).map { String(format: "%.2f", $0) })")
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
                // Start loop from energy onset (where stem actually kicks in)
                if sortedOnsets.count > 4 {
                    let secondsPerBeat = 60.0 / tempo
                    let secondsPerBar = secondsPerBeat * 4

                    // Quantize energy onset to nearest beat for cleaner loop start
                    let quantizedStart = round(energyOnset / secondsPerBeat) * secondsPerBeat

                    // Try to find 2-bar loop starting from where the stem kicks in
                    let twoBarDuration = secondsPerBar * 2
                    if duration >= quantizedStart + twoBarDuration {
                        var sample = ExtractedSample(
                            name: "\(stemType.displayName) Loop",
                            category: .loop,
                            stemType: stemType,
                            duration: twoBarDuration,
                            barLength: 2,
                            confidence: 0.85
                        )
                        sample.startTime = quantizedStart
                        sample.endTime = quantizedStart + twoBarDuration
                        sample.audioURL = stemURL
                        allSamples.append(sample)
                        print("   Loop: \(String(format: "%.2f", quantizedStart))s - \(String(format: "%.2f", quantizedStart + twoBarDuration))s")
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
