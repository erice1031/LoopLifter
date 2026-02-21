//
//  ContentView.swift
//  LoopLifter
//
//  Main application view with drop zone and results
//

import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

/// Find the loudest sustained section of a stem (the "main" section)
/// Scans entire file and returns the start time of the section with highest average energy
func findEnergyOnset(in url: URL, windowDuration: Double = 4.0, chunkDuration: Double = 0.25) -> Double {
    do {
        let audioFile = try AVAudioFile(forReading: url)
        let sampleRate = audioFile.processingFormat.sampleRate
        let totalFrames = AVAudioFrameCount(audioFile.length)
        let chunkFrames = AVAudioFrameCount(chunkDuration * sampleRate)
        let chunksPerWindow = Int(windowDuration / chunkDuration)

        var chunkPeaks: [Float] = []
        var currentFrame: AVAudioFramePosition = 0

        // First pass: collect peak values for each chunk
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

            chunkPeaks.append(maxSample)
            currentFrame += AVAudioFramePosition(framesToRead)
        }

        // Second pass: find window with highest average energy
        var bestWindowStart = 0
        var bestWindowEnergy: Float = 0

        for windowStart in 0..<max(1, chunkPeaks.count - chunksPerWindow) {
            let windowEnd = min(windowStart + chunksPerWindow, chunkPeaks.count)
            let windowPeaks = Array(chunkPeaks[windowStart..<windowEnd])
            let avgEnergy = windowPeaks.reduce(0, +) / Float(windowPeaks.count)

            if avgEnergy > bestWindowEnergy {
                bestWindowEnergy = avgEnergy
                bestWindowStart = windowStart
            }
        }

        // Convert chunk index to time
        let timeSeconds = Double(bestWindowStart) * chunkDuration
        return timeSeconds

    } catch {
        print("⚠️ Error finding energy onset: \(error)")
        return 0
    }
}

struct ExportResult: Equatable {
    let successCount: Int
    let failCount: Int
    let folder: URL?
}

struct ContentView: View {
    @State private var analysisState: AnalysisState = .idle
    @State private var extractedSamples: [ExtractedSample] = []
    @State private var audioURL: URL?
    @State private var isTargeted = false
    @State private var detectedTempo: Double = 120.0
    @State private var exportToast: ExportResult? = nil
    @State private var isExporting = false
    @State private var exportDismissTask: Task<Void, Never>? = nil
    @State private var showExportSheet = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            switch analysisState {
            case .idle:
                DropZoneView(isTargeted: $isTargeted) { url in
                    audioURL = url
                    startAnalysis(url: url)
                }

            case .separating(let progress):
                processingView(label: "Separating stems...", progress: progress)

            case .analyzing(let stem, let progress):
                processingView(label: "Analyzing \(stem)...", progress: progress)

            case .complete:
                ResultsView(
                    samples: $extractedSamples,
                    onExport: { samples in
                        showExportSheet = true
                        return nil  // toast handled via sheet callback
                    },
                    onExportAll: { showExportSheet = true; return nil },
                    onOpenInLoOptimizer: openInLoOptimizer
                )

            case .error(let message):
                VStack(spacing: LoSuite.Spacing.md) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text("Error")
                        .font(.system(size: LoSuite.Typography.h2, weight: .semibold))
                        .foregroundColor(LoSuite.Colors.textPrimary)
                    Text(message)
                        .font(.system(size: LoSuite.Typography.body))
                        .foregroundColor(LoSuite.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                    Button("Try Again") { analysisState = .idle }
                }
                .padding(40)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(LoSuite.Colors.backgroundPrimary)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .background(LoSuite.Colors.backgroundPrimary)
        .overlay(alignment: .bottom) {
            if let toast = exportToast {
                ExportToastView(result: toast) { dismissExportToast() }
                    .padding(.bottom, LoSuite.Spacing.md)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(LoSuite.Motion.normal, value: exportToast != nil)
        .sheet(isPresented: $showExportSheet) {
            ExportSheet(
                samples: extractedSamples,
                songName: audioURL?.deletingPathExtension().lastPathComponent ?? "Untitled",
                tempo: detectedTempo,
                onExport: { format in await runExport(format: format) },
                onCancel: {}
            )
        }
    }

    // MARK: - Processing View

    @ViewBuilder
    private func processingView(label: String, progress: Double) -> some View {
        VStack(spacing: LoSuite.Spacing.md) {
            ProgressView(value: progress, total: 1.0)
                .progressViewStyle(.linear)
                .tint(LoSuite.Colors.accent)
                .frame(maxWidth: 340)
            Text(label)
                .font(.system(size: LoSuite.Typography.body))
                .foregroundColor(LoSuite.Colors.textSecondary)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LoSuite.Colors.backgroundPrimary)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 0) {

            // ── Left: logo + track info ──────────────────────────────────
            VStack(alignment: .leading, spacing: 2) {
                Text("LoopLifter")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(LoSuite.Colors.textPrimary)
                if let url = audioURL {
                    HStack(spacing: 5) {
                        Text(url.lastPathComponent)
                        Text("•")
                        Text("BPM \(Int(detectedTempo))")
                        if let projectName = ProjectManager.shared.currentProject?.name {
                            Text("•")
                            Text(projectName)
                        }
                    }
                    .font(.system(size: LoSuite.Typography.monoData, design: .monospaced))
                    .foregroundColor(LoSuite.Colors.textSecondary)
                } else {
                    Text("AI Sample Pack Generator")
                        .font(.system(size: 11))
                        .foregroundColor(LoSuite.Colors.textSecondary)
                }
            }
            .padding(.horizontal, LoSuite.Spacing.md)

            Spacer()

            // ── Center: workflow step pills ──────────────────────────────
            HStack(spacing: 3) {
                workflowStepPill("IMPORT",   phaseIndex: 0)
                workflowArrow()
                workflowStepPill("SEPARATE", phaseIndex: 1)
                workflowArrow()
                workflowStepPill("ANALYZE",  phaseIndex: 2)
                workflowArrow()
                workflowStepPill("EXTRACT",  phaseIndex: 3)
            }

            Spacer()

            // ── Right: file actions + export ─────────────────────────────
            HStack(spacing: LoSuite.Spacing.sm) {
                Button { openProject() } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .foregroundColor(LoSuite.Colors.textSecondary)
                .help("Open Project")

                if analysisState == .complete {
                    Button { saveProject() } label: {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(LoSuite.Colors.textSecondary)
                    .help("Save Project")

                    Button {
                        analysisState = .idle
                        extractedSamples = []
                        audioURL = nil
                        ProjectManager.shared.closeProject()
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(LoSuite.Colors.textSecondary)
                    .help("New Project")

                    Rectangle()
                        .fill(LoSuite.Colors.bordersDividers)
                        .frame(width: 1, height: 20)
                        .padding(.horizontal, 4)

                    Button("Send to LoOptimizer") { openInLoOptimizer() }
                        .buttonStyle(.plain)
                        .font(.system(size: LoSuite.Typography.body))
                        .foregroundColor(LoSuite.Colors.textSecondary)

                    Button(isExporting ? "Exporting…" : "Export Pack") {
                        showExportSheet = true
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: LoSuite.Typography.body, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(isExporting
                        ? LoSuite.Colors.accent.opacity(0.6)
                        : LoSuite.Colors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: LoSuite.Radius.md))
                    .disabled(isExporting)
                }
            }
            .padding(.horizontal, LoSuite.Spacing.md)
        }
        .frame(height: 52)
        .background(LoSuite.Colors.backgroundPrimary)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(LoSuite.Colors.bordersDividers)
                .frame(height: 1)
        }
    }

    // MARK: - Workflow Steps

    /// 0=import 1=separate 2=analyze 3=extract
    private var currentPhaseIndex: Int {
        switch analysisState {
        case .idle:        return 0
        case .separating:  return 1
        case .analyzing:   return 2
        case .complete, .error: return 3
        }
    }

    @ViewBuilder
    private func workflowStepPill(_ label: String, phaseIndex: Int) -> some View {
        let isActive  = currentPhaseIndex >= phaseIndex
        let isCurrent = currentPhaseIndex == phaseIndex
        Text(label)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(isActive ? LoSuite.Colors.textPrimary : LoSuite.Colors.disabled)
            .tracking(0.8)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: LoSuite.Radius.sm)
                    .fill(isCurrent
                        ? LoSuite.Colors.accent.opacity(0.12)
                        : (isActive ? LoSuite.Colors.elevatedSurface.opacity(0.5) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: LoSuite.Radius.sm)
                    .stroke(
                        isCurrent ? LoSuite.Colors.accent.opacity(0.7)
                            : (isActive ? LoSuite.Colors.bordersDividers : LoSuite.Colors.bordersDividers.opacity(0.3)),
                        lineWidth: isCurrent ? 1.5 : 1
                    )
            )
    }

    @ViewBuilder
    private func workflowArrow() -> some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 8, weight: .medium))
            .foregroundColor(LoSuite.Colors.disabled)
            .padding(.horizontal, 1)
    }

    // MARK: - Actions

    private func startAnalysis(url: URL) {
        Task {
            await analyzeFile(url: url)
        }
    }

    @MainActor
    /// Called by ExportSheet when the user confirms an export format.
    func runExport(format: ExportFormat) async -> ExportResult? {
        guard !isExporting else { return nil }
        isExporting = true
        let exporter = SamplePackExporter(
            samples: extractedSamples,
            songName: audioURL?.deletingPathExtension().lastPathComponent ?? "Untitled",
            tempo: detectedTempo,
            format: format
        )
        let result = await exporter.export()
        isExporting = false
        if let result { showExportToast(result) }
        return result
    }

    private func showExportToast(_ result: ExportResult) {
        exportDismissTask?.cancel()
        exportToast = result
        exportDismissTask = Task {
            try? await Task.sleep(for: .seconds(4))
            if !Task.isCancelled { await MainActor.run { dismissExportToast() } }
        }
    }

    private func dismissExportToast() {
        exportDismissTask?.cancel()
        exportToast = nil
    }

    @MainActor
    private func analyzeFile(url: URL) async {
        analysisState = .separating(progress: 0)

        do {
            let stemURLs: [StemType: URL]

            // Check cache first
            if let cachedStems = StemCache.shared.getCachedStems(for: url) {
                print("⚡ Using cached stems - skipping Demucs!")
                stemURLs = cachedStems
                analysisState = .separating(progress: 1.0)
            } else {
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
                let separatedStems = try await StemSeparator.separate(
                    audioURL: url,
                    outputDir: outputDir,
                    model: .htdemucs
                ) { progress in
                    Task { @MainActor in
                        self.analysisState = .separating(progress: progress)
                    }
                }

                // Cache the stems for next time
                StemCache.shared.cacheStems(separatedStems, for: url)
                stemURLs = separatedStems
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

                // Find the loudest section of this stem (main groove)
                let energyOnset = findEnergyOnset(in: stemURL)
                print("   Energy onset: \(String(format: "%.2f", energyOnset))s")

                // Filter onsets to only those after energy onset
                let sortedOnsets = onsets.sorted().filter { $0 >= energyOnset }
                print("   Onsets after energy: \(sortedOnsets.count), first 8: \(sortedOnsets.prefix(8).map { String(format: "%.2f", $0) })")
                for (hitIndex, onset) in sortedOnsets.prefix(8).enumerated() {
                    // Calculate hit duration (until next onset or max 500ms)
                    let nextOnset: Double = hitIndex + 1 < sortedOnsets.count ? sortedOnsets[hitIndex + 1] : onset + 0.5
                    let hitDuration: Double = Swift.min(nextOnset - onset, 0.5)

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
                    sample.tempo = tempo
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
                        sample.tempo = tempo
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
            // Store detected tempo from first stem with valid tempo
            if let firstTempo = allSamples.first?.tempo, firstTempo > 0 {
                detectedTempo = firstTempo
            }
            analysisState = .complete

        } catch {
            analysisState = .error(error.localizedDescription)
        }
    }


    private func openInLoOptimizer() {
        // TODO: Implement LoOptimizer handoff
        print("Opening in LoOptimizer")
    }

    // MARK: - Project Management

    private func saveProject() {
        guard let url = audioURL else { return }

        // Get tempo from first sample or use default
        let tempo = extractedSamples.first?.tempo ?? detectedTempo

        let success = ProjectManager.shared.save(
            samples: extractedSamples,
            audioURL: url,
            tempo: tempo
        )

        if success {
            print("✅ Project saved successfully")
        }
    }

    private func openProject() {
        guard let result = ProjectManager.shared.open() else {
            return
        }

        // Add to recent projects
        if let projectURL = ProjectManager.shared.currentProjectURL {
            ProjectManager.shared.addToRecent(projectURL)
        }

        // If samples restored successfully, show results
        if !result.samples.isEmpty {
            audioURL = result.audioURL
            extractedSamples = result.samples
            detectedTempo = result.tempo
            analysisState = .complete
            print("✅ Project loaded with \(result.samples.count) samples")
        } else {
            // Stems not in cache - need to re-analyze
            audioURL = result.audioURL
            detectedTempo = result.tempo
            print("⚠️ Stems not cached, re-analyzing...")
            startAnalysis(url: result.audioURL)
        }
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
