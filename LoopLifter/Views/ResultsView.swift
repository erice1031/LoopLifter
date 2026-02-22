//
//  ResultsView.swift
//  LoopLifter
//
//  Displays extracted samples organized by stem type
//

import SwiftUI
import AppKit
import AVFoundation

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Rotary Knob (Lo Suite Design)

struct RotaryKnob: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = -100...100
    var step: Double = 1.0
    var sensitivity: Double = 0.5
    var label: String = ""
    var valueFormatter: (Double) -> String = { String(format: "%.2f", $0) }
    var accentColor: Color = LoSuite.Colors.accent
    var onChange: (() -> Void)? = nil

    @State private var isDragging = false
    @State private var lastDragValue: CGFloat = 0

    private let knobSize: CGFloat = 56
    private let trackWidth: CGFloat = 2

    private var rotation: Angle {
        let normalized = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        let degrees = -135 + (normalized * 270)
        return .degrees(degrees)
    }

    private var normalizedValue: CGFloat {
        CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
    }

    var body: some View {
        VStack(spacing: LoSuite.Spacing.sm) {
            ZStack {
                Circle()
                    .stroke(LoSuite.Colors.bordersDividers, lineWidth: trackWidth)
                    .frame(width: knobSize, height: knobSize)
                Circle()
                    .trim(from: 0, to: normalizedValue)
                    .stroke(accentColor, style: StrokeStyle(lineWidth: trackWidth, lineCap: .round))
                    .frame(width: knobSize, height: knobSize)
                    .rotationEffect(.degrees(-225))
                Circle()
                    .fill(LoSuite.Colors.panelSurface)
                    .frame(width: knobSize - 8, height: knobSize - 8)
                Rectangle()
                    .fill(LoSuite.Colors.textPrimary)
                    .frame(width: trackWidth, height: 14)
                    .offset(y: -14)
                    .rotationEffect(rotation)
                Circle()
                    .fill(LoSuite.Colors.elevatedSurface)
                    .frame(width: 12, height: 12)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDragging {
                            isDragging = true
                            lastDragValue = gesture.location.y
                        }
                        let delta = lastDragValue - gesture.location.y
                        lastDragValue = gesture.location.y
                        let change = Double(delta) * sensitivity * step
                        let newValue = value + change
                        let snapped = (newValue / step).rounded() * step
                        value = Swift.min(Swift.max(snapped, range.lowerBound), range.upperBound)
                        onChange?()
                    }
                    .onEnded { _ in isDragging = false }
            )
            Text(valueFormatter(value))
                .font(.system(size: LoSuite.Typography.caption, design: .monospaced))
                .foregroundColor(isDragging ? accentColor : LoSuite.Colors.textSecondary)
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: LoSuite.Typography.caption2))
                    .foregroundColor(LoSuite.Colors.textSecondary)
            }
        }
    }
}

// MARK: - Draggable Value

struct DraggableValue: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1000
    var step: Double = 0.01
    var sensitivity: Double = 0.5
    var formatter: (Double) -> String = { String(format: "%.3f", $0) }
    var suffix: String = "s"
    var accentColor: Color = LoSuite.Colors.accent
    var onChange: (() -> Void)? = nil

    @State private var isDragging = false
    @State private var lastDragValue: CGFloat = 0

    var body: some View {
        HStack(spacing: 2) {
            Text(formatter(value))
                .font(.system(size: LoSuite.Typography.body, weight: .medium, design: .monospaced))
                .foregroundColor(isDragging ? accentColor : LoSuite.Colors.textPrimary)
            Text(suffix)
                .font(.system(size: LoSuite.Typography.caption))
                .foregroundColor(LoSuite.Colors.textSecondary)
        }
        .padding(.horizontal, LoSuite.Spacing.sm)
        .padding(.vertical, LoSuite.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: LoSuite.Radius.small)
                .fill(isDragging ? accentColor.opacity(0.15) : LoSuite.Colors.elevatedSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LoSuite.Radius.small)
                .stroke(isDragging ? accentColor : LoSuite.Colors.bordersDividers, lineWidth: 1)
        )
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { gesture in
                    if !isDragging {
                        isDragging = true
                        lastDragValue = gesture.location.y
                    }
                    let delta = lastDragValue - gesture.location.y
                    lastDragValue = gesture.location.y
                    let change = Double(delta) * sensitivity * step
                    let newValue = value + change
                    let snapped = (newValue / step).rounded() * step
                    value = Swift.min(Swift.max(snapped, range.lowerBound), range.upperBound)
                    onChange?()
                }
                .onEnded { _ in isDragging = false }
        )
        .help("Drag up/down to adjust")
    }
}

// MARK: - Waveform View

struct WaveformView: View {
    let audioURL: URL?
    var startTime: TimeInterval
    var endTime: TimeInterval
    var totalDuration: TimeInterval
    var accentColor: Color = LoSuite.Colors.accent
    var height: CGFloat = 140

    @State private var waveformData: [Float] = []
    @State private var isLoading = true

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: LoSuite.Radius.medium)
                    .fill(LoSuite.Colors.panelSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: LoSuite.Radius.medium)
                            .stroke(LoSuite.Colors.bordersDividers, lineWidth: 1)
                    )
                if isLoading {
                    ProgressView().scaleEffect(0.8).tint(LoSuite.Colors.textSecondary)
                } else if waveformData.isEmpty {
                    Text("No waveform")
                        .font(.system(size: LoSuite.Typography.caption))
                        .foregroundColor(LoSuite.Colors.textSecondary)
                } else {
                    Canvas { context, size in
                        let width = size.width
                        let height = size.height
                        let midY = height / 2
                        let samplesPerPixel = Swift.max(1, waveformData.count / Int(width))
                        var path = Path()
                        for x in 0..<Int(width) {
                            let idx = Swift.min(x * samplesPerPixel, waveformData.count - 1)
                            let amp = CGFloat(waveformData[idx]) * (height / 2) * 0.85
                            path.move(to: CGPoint(x: CGFloat(x), y: midY - amp))
                            path.addLine(to: CGPoint(x: CGFloat(x), y: midY + amp))
                        }
                        context.stroke(path, with: .color(Color(hex: "9CA3AF").opacity(0.65)), lineWidth: 1)
                        let regionStartX = (startTime / totalDuration) * width
                        let regionEndX   = (endTime   / totalDuration) * width
                        let regionRect = CGRect(x: regionStartX, y: 0, width: regionEndX - regionStartX, height: height)
                        context.fill(Path(regionRect), with: .color(accentColor.opacity(0.12)))
                        var regionPath = Path()
                        for x in Int(regionStartX)..<Int(regionEndX) {
                            let idx = Swift.min(x * samplesPerPixel, waveformData.count - 1)
                            let amp = CGFloat(waveformData[idx]) * (height / 2) * 0.85
                            regionPath.move(to: CGPoint(x: CGFloat(x), y: midY - amp))
                            regionPath.addLine(to: CGPoint(x: CGFloat(x), y: midY + amp))
                        }
                        context.stroke(regionPath, with: .color(accentColor), lineWidth: 1)
                        let boundaryPath = Path { p in
                            p.move(to: CGPoint(x: regionStartX, y: 0))
                            p.addLine(to: CGPoint(x: regionStartX, y: height))
                            p.move(to: CGPoint(x: regionEndX, y: 0))
                            p.addLine(to: CGPoint(x: regionEndX, y: height))
                        }
                        context.stroke(boundaryPath, with: .color(accentColor), lineWidth: 2)
                    }
                    VStack {
                        Spacer()
                        HStack {
                            Text(String(format: "%.1fs", startTime))
                                .font(.system(size: LoSuite.Typography.caption2, design: .monospaced))
                                .foregroundColor(accentColor)
                                .padding(.leading, LoSuite.Spacing.sm)
                            Spacer()
                            Text(String(format: "%.1fs", endTime))
                                .font(.system(size: LoSuite.Typography.caption2, design: .monospaced))
                                .foregroundColor(accentColor)
                                .padding(.trailing, LoSuite.Spacing.sm)
                        }
                        .padding(.bottom, LoSuite.Spacing.xs)
                    }
                }
            }
        }
        .frame(height: height)
        .onAppear { loadWaveform() }
        .onChange(of: audioURL) { _, _ in loadWaveform() }
    }

    private func loadWaveform() {
        guard let url = audioURL else { isLoading = false; return }
        isLoading = true
        Task {
            let data = await generateWaveformData(from: url, sampleCount: 500)
            await MainActor.run { waveformData = data; isLoading = false }
        }
    }

    private func generateWaveformData(from url: URL, sampleCount: Int) async -> [Float] {
        do {
            let audioFile = try AVAudioFile(forReading: url)
            let format = audioFile.processingFormat
            let frameCount = AVAudioFrameCount(audioFile.length)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return [] }
            try audioFile.read(into: buffer)
            guard let channelData = buffer.floatChannelData else { return [] }
            let framesPerSample = Int(frameCount) / sampleCount
            var peaks: [Float] = []
            for i in 0..<sampleCount {
                let startFrame = i * framesPerSample
                let endFrame = Swift.min(startFrame + framesPerSample, Int(frameCount))
                var maxSample: Float = 0
                for frame in startFrame..<endFrame {
                    let sample = abs(channelData[0][frame])
                    if sample > maxSample { maxSample = sample }
                }
                peaks.append(maxSample)
            }
            return peaks
        } catch { return [] }
    }
}

// MARK: - Zoomed Waveform View

struct ZoomedWaveformView: View {
    let audioURL: URL?
    var sampleStart: TimeInterval
    var sampleEnd: TimeInterval
    var viewStart: TimeInterval
    var viewEnd: TimeInterval
    var accentColor: Color = LoSuite.Colors.accent
    var height: CGFloat = 180

    @State private var waveformData: [Float] = []
    @State private var isLoading = true
    @State private var totalDuration: TimeInterval = 0

    private var viewDuration: TimeInterval { viewEnd - viewStart }

    var body: some View {
        GeometryReader { _ in
            ZStack {
                RoundedRectangle(cornerRadius: LoSuite.Radius.medium)
                    .fill(LoSuite.Colors.panelSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: LoSuite.Radius.medium)
                            .stroke(LoSuite.Colors.bordersDividers, lineWidth: 1)
                    )
                if isLoading {
                    ProgressView().scaleEffect(0.8).tint(LoSuite.Colors.textSecondary)
                } else if waveformData.isEmpty {
                    Text("No waveform")
                        .font(.system(size: LoSuite.Typography.caption))
                        .foregroundColor(LoSuite.Colors.textSecondary)
                } else if totalDuration > 0 && viewDuration > 0 {
                    Canvas { context, size in
                        let width = size.width
                        let height = size.height
                        let midY = height / 2
                        let startRatio = max(0, min(1, viewStart / totalDuration))
                        let endRatio   = max(0, min(1, viewEnd   / totalDuration))
                        let startSample = max(0, Int(startRatio * Double(waveformData.count)))
                        let endSample   = min(Int(endRatio * Double(waveformData.count)), waveformData.count)
                        let visibleSamples = max(1, endSample - startSample)
                        guard startSample < waveformData.count else { return }
                        var path = Path()
                        for x in 0..<Int(width) {
                            let idx = startSample + Int(Double(x) / width * Double(visibleSamples))
                            guard idx < waveformData.count else { continue }
                            let amp = CGFloat(waveformData[idx]) * (height / 2) * 0.85
                            path.move(to: CGPoint(x: CGFloat(x), y: midY - amp))
                            path.addLine(to: CGPoint(x: CGFloat(x), y: midY + amp))
                        }
                        context.stroke(path, with: .color(Color(hex: "9CA3AF").opacity(0.65)), lineWidth: 1)
                        let regionStartX = ((sampleStart - viewStart) / viewDuration) * width
                        let regionEndX   = ((sampleEnd   - viewStart) / viewDuration) * width
                        let regionRect = CGRect(
                            x: max(0, regionStartX), y: 0,
                            width: min(width, regionEndX) - max(0, regionStartX),
                            height: height
                        )
                        context.fill(Path(regionRect), with: .color(accentColor.opacity(0.15)))
                        var regionPath = Path()
                        for x in Int(max(0, regionStartX))..<Int(min(width, regionEndX)) {
                            let idx = startSample + Int(Double(x) / width * Double(visibleSamples))
                            guard idx < waveformData.count else { continue }
                            let amp = CGFloat(waveformData[idx]) * (height / 2) * 0.85
                            regionPath.move(to: CGPoint(x: CGFloat(x), y: midY - amp))
                            regionPath.addLine(to: CGPoint(x: CGFloat(x), y: midY + amp))
                        }
                        context.stroke(regionPath, with: .color(accentColor), lineWidth: 1)
                        let boundaryPath = Path { p in
                            if regionStartX >= 0 && regionStartX <= width {
                                p.move(to: CGPoint(x: regionStartX, y: 0))
                                p.addLine(to: CGPoint(x: regionStartX, y: height))
                            }
                            if regionEndX >= 0 && regionEndX <= width {
                                p.move(to: CGPoint(x: regionEndX, y: 0))
                                p.addLine(to: CGPoint(x: regionEndX, y: height))
                            }
                        }
                        context.stroke(boundaryPath, with: .color(accentColor), lineWidth: 2)
                    }
                    VStack {
                        Spacer()
                        HStack {
                            Text(String(format: "%.2fs", sampleStart))
                                .font(.system(size: LoSuite.Typography.caption2, design: .monospaced))
                                .foregroundColor(accentColor)
                                .padding(.leading, LoSuite.Spacing.sm)
                            Spacer()
                            Text(String(format: "%.3fs", sampleEnd - sampleStart))
                                .font(.system(size: LoSuite.Typography.caption, weight: .medium, design: .monospaced))
                                .foregroundColor(LoSuite.Colors.textPrimary)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(LoSuite.Colors.elevatedSurface.opacity(0.9))
                                .cornerRadius(4)
                            Spacer()
                            Text(String(format: "%.2fs", sampleEnd))
                                .font(.system(size: LoSuite.Typography.caption2, design: .monospaced))
                                .foregroundColor(accentColor)
                                .padding(.trailing, LoSuite.Spacing.sm)
                        }
                        .padding(.bottom, LoSuite.Spacing.xs)
                    }
                } else {
                    Text("Adjusting view...")
                        .font(.system(size: LoSuite.Typography.caption))
                        .foregroundColor(LoSuite.Colors.textSecondary)
                }
            }
        }
        .frame(height: height)
        .onAppear { loadWaveform() }
        .onChange(of: audioURL) { _, _ in loadWaveform() }
    }

    private func loadWaveform() {
        guard let url = audioURL else { isLoading = false; return }
        isLoading = true
        Task {
            let (data, duration) = await generateWaveformData(from: url, sampleCount: 1000)
            await MainActor.run { waveformData = data; totalDuration = duration; isLoading = false }
        }
    }

    private func generateWaveformData(from url: URL, sampleCount: Int) async -> ([Float], TimeInterval) {
        do {
            let audioFile = try AVAudioFile(forReading: url)
            let format = audioFile.processingFormat
            let frameCount = AVAudioFrameCount(audioFile.length)
            let duration = Double(frameCount) / format.sampleRate
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return ([], duration) }
            try audioFile.read(into: buffer)
            guard let channelData = buffer.floatChannelData else { return ([], duration) }
            let framesPerSample = Int(frameCount) / sampleCount
            var peaks: [Float] = []
            for i in 0..<sampleCount {
                let startFrame = i * framesPerSample
                let endFrame = Swift.min(startFrame + framesPerSample, Int(frameCount))
                var maxSample: Float = 0
                for frame in startFrame..<endFrame {
                    let sample = abs(channelData[0][frame])
                    if sample > maxSample { maxSample = sample }
                }
                peaks.append(maxSample)
            }
            return (peaks, duration)
        } catch { return ([], 0) }
    }
}

// MARK: - Results View

struct ResultsView: View {
    @Binding var samples: [ExtractedSample]
    var onExport: ([ExtractedSample]) async -> ExportResult?
    var onExportAll: () async -> ExportResult?
    var onOpenInLoOptimizer: () -> Void

    // Navigation
    @State private var selectedStemType: StemType = .drums
    // Selection & playback
    @State private var selectedSamples: Set<UUID> = []
    @State private var editingSampleID: UUID? = nil
    // Export feedback
    @State private var exportToast: ExportResult? = nil
    @State private var exportDismissTask: Task<Void, Never>? = nil
    @State private var isExporting: Bool = false
    // Extraction controls (UI state — not yet wired to extraction engine)
    @State private var targetBars: Int = 4
    @State private var sensitivity: Double = 0.70
    @State private var silenceRemoval: Bool = false
    @State private var minDuration: Double = 0.5
    @State private var confidence: Double = 0.85
    @State private var normalize: Bool = false
    @State private var autoTag: Bool = false
    // Sample editing
    @State private var isRenamingSample: Bool = false
    @State private var renameText: String = ""
    @State private var nudgeGrid: NudgeGrid = .eighth
    // Keyboard / playback
    @State private var showKeyboard: Bool = false
    // Loop scanner
    @State private var loopBarsCount: Int = 2
    @State private var loopBraceStart: TimeInterval = 0
    @State private var stemDuration: TimeInterval = 30.0

    // MARK: Derived
    private var stemSamples: [ExtractedSample] {
        samples.filter { $0.stemType == selectedStemType }
    }
    private var stemAudioURL: URL? { stemSamples.first?.audioURL }
    private var stemTempo: Double  { stemSamples.first?.tempo ?? 120.0 }
    private var selectedCountForStem: Int {
        stemSamples.filter { selectedSamples.contains($0.id) }.count
    }
    private var selectedSample: ExtractedSample? {
        guard let id = editingSampleID else { return nil }
        return samples.first { $0.id == id }
    }

    // MARK: Sample mutation helper
    private func updateSelected(_ mutation: (inout ExtractedSample) -> Void) {
        guard let id = editingSampleID,
              let idx = samples.firstIndex(where: { $0.id == id }) else { return }
        mutation(&samples[idx])
    }

    private func nudgeStart(by sign: Double) {
        guard let s = selectedSample else { return }
        let step = s.nudgeStepSize(for: nudgeGrid)
        updateSelected { $0.nudgeOffset = ($0.nudgeOffset + sign * step).clamped(to: -10...10) }
    }

    private func duplicateSelected() {
        guard let id = editingSampleID,
              let idx = samples.firstIndex(where: { $0.id == id }) else { return }
        let copy = samples[idx].duplicate()
        samples.insert(copy, at: idx + 1)
        editingSampleID = copy.id
    }

    // MARK: Loop scanner helpers

    private var secPerBeat: Double { 60.0 / max(1, stemTempo) }
    private var secPerBar:  Double { secPerBeat * 4 }
    private var loopBraceDuration: TimeInterval { Double(loopBarsCount) * secPerBar }
    private var loopBraceEnd: TimeInterval { loopBraceStart + loopBraceDuration }

    private func timeToBarsBeat(_ t: TimeInterval) -> String {
        guard secPerBeat > 0 else { return "1:1" }
        let totalBeats = t / secPerBeat
        let bar  = Int(totalBeats / 4) + 1
        let beat = Int(totalBeats.truncatingRemainder(dividingBy: 4)) + 1
        return "\(bar):\(beat)"
    }

    private func barsBeatToTime(_ s: String) -> TimeInterval? {
        let parts = s.trimmingCharacters(in: .whitespaces)
            .split(separator: ":").compactMap { Int($0) }
        if parts.count == 1      { return TimeInterval(max(0, parts[0] - 1)) * secPerBar }
        else if parts.count == 2 { return TimeInterval(max(0, parts[0] - 1)) * secPerBar
                                        + TimeInterval(max(0, parts[1] - 1)) * secPerBeat }
        return nil
    }

    private func snapToBeat(_ t: TimeInterval) -> TimeInterval {
        guard secPerBeat > 0 else { return t }
        return (t / secPerBeat).rounded() * secPerBeat
    }

    private func moveBrace(bars: Int) {
        let next = loopBraceStart + Double(bars) * secPerBar
        loopBraceStart = max(0, min(stemDuration - loopBraceDuration, next))
    }

    private func setBraceToSample(_ s: ExtractedSample) {
        loopBraceStart = s.startTime
        // If the sample's duration is close to a standard bar count, update loopBarsCount
        if secPerBar > 0 {
            let approxBars = Int(round((s.endTime - s.startTime) / secPerBar))
            if [1, 2, 4, 8, 16].contains(approxBars) { loopBarsCount = approxBars }
        }
    }

    private func saveScanLoop() {
        guard let audioURL = stemAudioURL else { return }
        var s = ExtractedSample(
            name: "\(selectedStemType.displayName) Loop \(timeToBarsBeat(loopBraceStart))",
            category: .loop,
            stemType: selectedStemType,
            duration: loopBraceDuration,
            barLength: loopBarsCount,
            confidence: 0.90
        )
        s.startTime  = loopBraceStart
        s.endTime    = loopBraceEnd
        s.audioURL   = audioURL
        s.tempo      = stemTempo
        samples.append(s)
        editingSampleID = s.id
        selectedSamples.insert(s.id)
    }

    private func auditBrace() {
        guard let audioURL = stemAudioURL else { return }
        var ghost = ExtractedSample(
            name: "preview", category: .loop, stemType: selectedStemType,
            duration: loopBraceDuration, barLength: loopBarsCount, confidence: 1
        )
        ghost.startTime = loopBraceStart
        ghost.endTime   = loopBraceEnd
        ghost.audioURL  = audioURL
        ghost.tempo     = stemTempo
        AudioPreviewPlayer.shared.setMode(.loop)
        AudioPreviewPlayer.shared.play(sample: ghost)
    }

    // MARK: Body

    var body: some View {
        HStack(spacing: 0) {

            // ── LEFT: Stem selector ──────────────────────────────────────
            stemSidebar

            Rectangle()
                .fill(LoSuite.Colors.bordersDividers)
                .frame(width: 1)

            // ── CENTER: Waveform + Assets ────────────────────────────────
            VStack(spacing: 0) {

                // Section title bar
                HStack {
                    Text("Waveform + AI Analysis (\(selectedStemType.displayName))")
                        .font(.system(size: LoSuite.Typography.body, weight: .semibold))
                        .foregroundColor(LoSuite.Colors.textPrimary)
                    Spacer()
                    Text("\(stemSamples.count) extracted")
                        .font(.system(size: LoSuite.Typography.caption))
                        .foregroundColor(LoSuite.Colors.textSecondary)
                }
                .padding(.horizontal, LoSuite.Spacing.md)
                .padding(.vertical, LoSuite.Spacing.sm)
                .background(LoSuite.Colors.backgroundPrimary)

                Rectangle()
                    .fill(LoSuite.Colors.bordersDividers)
                    .frame(height: 1)

                // ── Loop scanner: bar selector + position ────────────────
                LoopScanBar(
                    loopBarsCount: $loopBarsCount,
                    loopBraceStart: $loopBraceStart,
                    stemDuration: stemDuration,
                    loopBraceDuration: loopBraceDuration,
                    tempo: stemTempo,
                    timeToBarsBeat: timeToBarsBeat,
                    barsBeatToTime: barsBeatToTime
                )

                Rectangle()
                    .fill(LoSuite.Colors.bordersDividers)
                    .frame(height: 1)

                // ── Overview waveform + interactive brace ────────────────
                ZStack(alignment: .topLeading) {
                    StemWaveformRegionsView(
                        audioURL: stemAudioURL,
                        samples: stemSamples,
                        selectedSampleID: editingSampleID,
                        tempo: stemTempo,
                        accentColor: selectedStemType.designColor
                    )

                    GeometryReader { geo in
                        let dur = max(0.001, stemDuration)
                        let sx  = CGFloat(loopBraceStart / dur) * geo.size.width
                        let bw  = CGFloat(loopBraceDuration / dur) * geo.size.width

                        // Brace fill
                        Rectangle()
                            .fill(selectedStemType.designColor.opacity(0.22))
                            .frame(width: max(2, bw), height: geo.size.height)
                            .offset(x: sx)
                        // Left edge
                        Rectangle()
                            .fill(selectedStemType.designColor)
                            .frame(width: 2, height: geo.size.height)
                            .offset(x: sx)
                        // Right edge
                        Rectangle()
                            .fill(selectedStemType.designColor)
                            .frame(width: 2, height: geo.size.height)
                            .offset(x: sx + bw - 2)
                        // Bar tick labels inside brace
                        if bw > 60 {
                            ForEach(1..<loopBarsCount, id: \.self) { bar in
                                let tickX = sx + (bw * CGFloat(bar) / CGFloat(loopBarsCount))
                                Rectangle()
                                    .fill(selectedStemType.designColor.opacity(0.4))
                                    .frame(width: 1, height: geo.size.height * 0.4)
                                    .offset(x: tickX, y: geo.size.height * 0.3)
                            }
                        }
                        // Transparent drag target
                        Color.clear
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 1, coordinateSpace: .local)
                                    .onChanged { drag in
                                        let raw = Double(drag.location.x) / Double(geo.size.width) * stemDuration
                                        loopBraceStart = snapToBeat(max(0, min(stemDuration - loopBraceDuration, raw)))
                                        editingSampleID = nil
                                    }
                            )
                    }
                }
                .frame(height: 160)

                Rectangle()
                    .fill(LoSuite.Colors.bordersDividers)
                    .frame(height: 1)

                // ── Zoomed view of brace region with draggable markers ───
                ZoomedWaveformWithMarkersView(
                    audioURL: stemAudioURL,
                    startTime: $loopBraceStart,
                    endTime: Binding(
                        get: { loopBraceEnd },
                        set: { loopBraceStart = max(0, $0 - loopBraceDuration) }
                    ),
                    tempo: stemTempo,
                    accentColor: selectedStemType.designColor
                )
                .frame(height: 140)
                .id("\(stemAudioURL?.lastPathComponent ?? "")-\(loopBarsCount)")

                Rectangle()
                    .fill(LoSuite.Colors.bordersDividers)
                    .frame(height: 1)

                // ── Scan navigation + save ───────────────────────────────
                ScanNavBar(
                    onBack:    { moveBrace(bars: -1) },
                    onForward: { moveBrace(bars: +1) },
                    onPlay:    { auditBrace() },
                    onStop:    { AudioPreviewPlayer.shared.stop() },
                    onSave:    { saveScanLoop() },
                    onDuplicate: {
                        if let s = selectedSample { editingSampleID = nil; _ = s }
                        moveBrace(bars: 0)  // stay, user can save again
                        saveScanLoop()
                        moveBrace(bars: 1)  // advance to next
                    },
                    isPlaying: AudioPreviewPlayer.shared.isPlaying,
                    positionLabel: timeToBarsBeat(loopBraceStart),
                    endLabel: timeToBarsBeat(loopBraceEnd),
                    loopBarsCount: loopBarsCount,
                    accentColor: selectedStemType.designColor
                )

                Rectangle()
                    .fill(LoSuite.Colors.bordersDividers)
                    .frame(height: 1)

                // ── Playback controls + nudge + keyboard toggle ──────────
                PlaybackControlBar(
                    nudgeGrid: $nudgeGrid,
                    showKeyboard: $showKeyboard,
                    playbackMode: Binding(
                        get: { AudioPreviewPlayer.shared.playbackMode },
                        set: { AudioPreviewPlayer.shared.setMode($0) }
                    ),
                    onNudgeStart: { nudgeStart(by: $0) },
                    hasSelection: selectedSample != nil
                )

                Rectangle()
                    .fill(LoSuite.Colors.bordersDividers)
                    .frame(height: 1)

                // ── Keyboard (collapsible) ───────────────────────────────
                if showKeyboard {
                    AuditionKeyboardView(accentColor: selectedStemType.designColor) {
                        auditBrace()
                    }
                    .frame(height: 68)

                    Rectangle()
                        .fill(LoSuite.Colors.bordersDividers)
                        .frame(height: 1)
                }

                // ── Extracted assets ─────────────────────────────────────
                VStack(alignment: .leading, spacing: 0) {

                    // Header
                    HStack(spacing: LoSuite.Spacing.sm) {
                        Text("Extracted Assets")
                            .font(.system(size: LoSuite.Typography.body, weight: .semibold))
                            .foregroundColor(LoSuite.Colors.textPrimary)
                        Text("Total: \(stemSamples.count)  •  Selected: \(selectedCountForStem)")
                            .font(.system(size: LoSuite.Typography.caption))
                            .foregroundColor(LoSuite.Colors.textSecondary)
                        Spacer()
                        Button(selectedCountForStem == stemSamples.count ? "Deselect All" : "Select All") {
                            if selectedCountForStem == stemSamples.count {
                                stemSamples.forEach { selectedSamples.remove($0.id) }
                            } else {
                                stemSamples.forEach { selectedSamples.insert($0.id) }
                            }
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: LoSuite.Typography.caption))
                        .foregroundColor(LoSuite.Colors.accent)
                    }
                    .padding(.horizontal, LoSuite.Spacing.md)
                    .padding(.vertical, LoSuite.Spacing.sm)

                    // Horizontal tile row
                    if stemSamples.isEmpty {
                        Text("No samples extracted for this stem.")
                            .font(.system(size: LoSuite.Typography.body))
                            .foregroundColor(LoSuite.Colors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(LoSuite.Spacing.lg)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: LoSuite.Spacing.sm) {
                                ForEach(stemSamples) { sample in
                                    LoopAssetTile(
                                        sample: sample,
                                        isSelected: editingSampleID == sample.id,
                                        isChecked: selectedSamples.contains(sample.id),
                                        accentColor: selectedStemType.designColor,
                                        onTap: {
                                            editingSampleID = sample.id
                                            setBraceToSample(sample)
                                            AudioPreviewPlayer.shared.setMode(
                                                sample.category == .loop ? .loop : .oneShot
                                            )
                                            AudioPreviewPlayer.shared.togglePlay(sample: sample)
                                        },
                                        onToggleCheck: {
                                            if selectedSamples.contains(sample.id) {
                                                selectedSamples.remove(sample.id)
                                            } else {
                                                selectedSamples.insert(sample.id)
                                            }
                                        },
                                        onDuplicate: {
                                            editingSampleID = sample.id
                                            duplicateSelected()
                                        },
                                        onDelete: {
                                            let id = sample.id
                                            samples.removeAll { $0.id == id }
                                            editingSampleID = stemSamples.first?.id
                                        },
                                        onSetCategory: { cat in
                                            if let idx = samples.firstIndex(where: { $0.id == sample.id }) {
                                                samples[idx].category = cat
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, LoSuite.Spacing.md)
                            .padding(.vertical, LoSuite.Spacing.sm)
                        }
                        .frame(height: 140)
                    }
                }
                .background(LoSuite.Colors.backgroundPrimary)

                Spacer()
            }

            Rectangle()
                .fill(LoSuite.Colors.bordersDividers)
                .frame(width: 1)

            // ── RIGHT: Sample detail + Extraction controls ──────────────
            VStack(spacing: 0) {
                // Sample detail panel (shown when a tile is selected)
                if let sample = selectedSample,
                   let idx = samples.firstIndex(where: { $0.id == sample.id }) {
                    SampleDetailPanel(
                        sample: Binding(
                            get: { samples[idx] },
                            set: { samples[idx] = $0 }
                        ),
                        nudgeGrid: $nudgeGrid,
                        isRenaming: $isRenamingSample,
                        renameText: $renameText,
                        accentColor: selectedStemType.designColor,
                        onDuplicate: { duplicateSelected() },
                        onDelete: {
                            let deleteID = sample.id
                            samples.removeAll { $0.id == deleteID }
                            editingSampleID = stemSamples.first?.id
                        },
                        onNudgeStart: { nudgeStart(by: $0) }
                    )

                    Rectangle()
                        .fill(LoSuite.Colors.bordersDividers)
                        .frame(height: 1)
                }

                ExtractionControlsPanel(
                    targetBars: $targetBars,
                    sensitivity: $sensitivity,
                    silenceRemoval: $silenceRemoval,
                    minDuration: $minDuration,
                    confidence: $confidence,
                    normalize: $normalize,
                    autoTag: $autoTag,
                    isExporting: isExporting,
                    onGeneratePack: { triggerExport { await onExportAll() } }
                )
            }
            .frame(width: 260)
        }
        .background(LoSuite.Colors.backgroundPrimary)
        .overlay(alignment: .bottom) {
            if let toast = exportToast {
                ExportToastView(result: toast) { dismissToast() }
                    .padding(.bottom, LoSuite.Spacing.md)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(LoSuite.Motion.normal, value: exportToast != nil)
        .onAppear {
            selectedSamples = Set(samples.map { $0.id })
            editingSampleID = stemSamples.first?.id
            if let s = stemSamples.first { setBraceToSample(s) }
        }
        .onChange(of: selectedStemType) { _, _ in
            editingSampleID = stemSamples.first?.id
            loopBraceStart = 0
        }
        .task(id: stemAudioURL) {
            guard let url = stemAudioURL else { return }
            do {
                let file = try AVAudioFile(forReading: url)
                let dur = Double(file.length) / file.processingFormat.sampleRate
                await MainActor.run { stemDuration = dur }
            } catch {}
        }
    }

    // MARK: - Left Sidebar

    private var stemSidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("STEMS")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(LoSuite.Colors.textSecondary)
                .tracking(1.5)
                .padding(.horizontal, LoSuite.Spacing.md)
                .padding(.top, LoSuite.Spacing.md)

            ForEach(StemType.allCases, id: \.self) { stem in
                let isActive = stem == selectedStemType
                let count = samples.filter { $0.stemType == stem }.count
                Button { selectedStemType = stem } label: {
                    HStack(spacing: LoSuite.Spacing.sm) {
                        Image(systemName: stem.icon)
                            .font(.system(size: 13))
                            .frame(width: 18)
                        Text(stem.displayName)
                            .font(.system(size: LoSuite.Typography.body,
                                         weight: isActive ? .semibold : .regular))
                        Spacer()
                        if count > 0 {
                            Text("\(count)")
                                .font(.system(size: LoSuite.Typography.caption2, design: .monospaced))
                                .foregroundColor(isActive ? stem.designColor : LoSuite.Colors.disabled)
                        }
                    }
                    .foregroundColor(isActive ? LoSuite.Colors.textPrimary : LoSuite.Colors.textSecondary)
                    .padding(.horizontal, LoSuite.Spacing.sm)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: LoSuite.Radius.sm)
                            .fill(isActive ? stem.designColor.opacity(0.08) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: LoSuite.Radius.sm)
                            .stroke(
                                isActive ? stem.designColor.opacity(0.6) : LoSuite.Colors.bordersDividers,
                                lineWidth: 1
                            )
                    )
                    .padding(.horizontal, LoSuite.Spacing.sm)
                }
                .buttonStyle(.plain)
                .animation(LoSuite.Motion.fast, value: isActive)
            }

            Spacer()
        }
        .frame(width: 130)
        .background(LoSuite.Colors.panelSurface)
    }

    // MARK: - Export Helpers

    private func triggerExport(_ work: @escaping () async -> ExportResult?) {
        guard !isExporting else { return }
        isExporting = true
        Task {
            let result = await work()
            await MainActor.run {
                isExporting = false
                if let result { showToast(result) }
            }
        }
    }

    private func showToast(_ result: ExportResult) {
        exportDismissTask?.cancel()
        exportToast = result
        exportDismissTask = Task {
            try? await Task.sleep(for: .seconds(4))
            if !Task.isCancelled { await MainActor.run { dismissToast() } }
        }
    }

    private func dismissToast() {
        exportDismissTask?.cancel()
        exportToast = nil
    }
}

// MARK: - Stem Waveform with Region Overlays

struct StemWaveformRegionsView: View {
    let audioURL: URL?
    let samples: [ExtractedSample]
    let selectedSampleID: UUID?
    let tempo: Double
    let accentColor: Color

    @State private var waveformData: [Float] = []
    @State private var totalDuration: TimeInterval = 0
    @State private var isLoading = true

    var body: some View {
        GeometryReader { _ in
            ZStack {
                LoSuite.Colors.backgroundPrimary

                if isLoading {
                    ProgressView()
                        .tint(LoSuite.Colors.textSecondary)
                } else if waveformData.isEmpty {
                    Text("No audio loaded")
                        .font(.system(size: LoSuite.Typography.caption))
                        .foregroundColor(LoSuite.Colors.textSecondary)
                } else {
                    Canvas { context, size in
                        let w = size.width
                        let h = size.height
                        let midY = h / 2
                        guard totalDuration > 0 else { return }
                        let spp = max(1, waveformData.count / Int(w))

                        // Base waveform (dimmed)
                        var basePath = Path()
                        for x in 0..<Int(w) {
                            let idx = min(x * spp, waveformData.count - 1)
                            let amp = CGFloat(waveformData[idx]) * (h / 2) * 0.80
                            basePath.move(to: CGPoint(x: CGFloat(x), y: midY - amp))
                            basePath.addLine(to: CGPoint(x: CGFloat(x), y: midY + amp))
                        }
                        context.stroke(basePath,
                                       with: .color(Color(hex: "9CA3AF").opacity(0.35)),
                                       lineWidth: 1)

                        // Beat markers (thin blue verticals)
                        if tempo > 0 {
                            let beatInterval = 60.0 / tempo
                            var t = 0.0
                            while t <= totalDuration {
                                let x = CGFloat(t / totalDuration) * w
                                var p = Path()
                                p.move(to: CGPoint(x: x, y: 0))
                                p.addLine(to: CGPoint(x: x, y: h))
                                context.stroke(p,
                                               with: .color(Color(hex: "0A84FF").opacity(0.22)),
                                               lineWidth: 0.5)
                                t += beatInterval
                            }
                        }

                        // Sample region overlays (back-to-front: fill, waveform, border)
                        for sample in samples {
                            guard sample.effectiveEndTime > sample.effectiveStartTime else { continue }
                            let isSelected = sample.id == selectedSampleID
                            let sx = CGFloat(sample.effectiveStartTime / totalDuration) * w
                            let ex = CGFloat(sample.effectiveEndTime   / totalDuration) * w
                            let rw = max(2, ex - sx)
                            let rect = CGRect(x: sx, y: 0, width: rw, height: h)

                            context.fill(Path(rect),
                                         with: .color(accentColor.opacity(isSelected ? 0.18 : 0.08)))

                            var rPath = Path()
                            for x in Int(sx)..<min(Int(sx + rw), Int(w)) {
                                let idx = min(x * spp, waveformData.count - 1)
                                let amp = CGFloat(waveformData[idx]) * (h / 2) * 0.80
                                rPath.move(to: CGPoint(x: CGFloat(x), y: midY - amp))
                                rPath.addLine(to: CGPoint(x: CGFloat(x), y: midY + amp))
                            }
                            context.stroke(rPath,
                                           with: .color(accentColor.opacity(isSelected ? 1.0 : 0.60)),
                                           lineWidth: 1)

                            context.stroke(Path(rect),
                                           with: .color(accentColor.opacity(isSelected ? 0.85 : 0.40)),
                                           lineWidth: isSelected ? 2 : 1)
                        }
                    }
                }
            }
        }
        .onAppear { Task { await loadWaveform() } }
        .onChange(of: audioURL) { _, _ in
            waveformData = []
            isLoading = true
            Task { await loadWaveform() }
        }
    }

    private func loadWaveform() async {
        guard let url = audioURL else { await MainActor.run { isLoading = false }; return }
        do {
            let audioFile = try AVAudioFile(forReading: url)
            let format = audioFile.processingFormat
            let totalFrames = AVAudioFrameCount(audioFile.length)
            let dur = Double(totalFrames) / format.sampleRate
            let sampleCount = 800
            let chunk = max(1, Int(totalFrames) / sampleCount)
            var data: [Float] = []
            data.reserveCapacity(sampleCount)
            let buf = AVAudioPCMBuffer(pcmFormat: format,
                                       frameCapacity: AVAudioFrameCount(chunk))!
            audioFile.framePosition = 0
            for _ in 0..<sampleCount {
                do {
                    try audioFile.read(into: buf, frameCount: AVAudioFrameCount(chunk))
                    if let ch = buf.floatChannelData?[0] {
                        var peak: Float = 0
                        for i in 0..<Int(buf.frameLength) { peak = max(peak, abs(ch[i])) }
                        data.append(peak)
                    }
                } catch { break }
            }
            await MainActor.run { waveformData = data; totalDuration = dur; isLoading = false }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }
}

// MARK: - Loop Asset Tile

struct LoopAssetTile: View {
    let sample: ExtractedSample
    let isSelected: Bool
    let isChecked: Bool
    let accentColor: Color
    var onTap: () -> Void
    var onToggleCheck: () -> Void
    var onDuplicate: () -> Void = {}
    var onDelete: () -> Void = {}
    var onSetCategory: (SampleCategory) -> Void = { _ in }

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Name + category badge row
            HStack(spacing: 4) {
                Text(sample.name)
                    .font(.system(size: LoSuite.Typography.body, weight: .medium))
                    .foregroundColor(LoSuite.Colors.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 2)
                // Category badge
                Text(sample.category.rawValue.uppercased())
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(accentColor.opacity(0.75))
                    .clipShape(Capsule())
            }

            // BPM + bars
            HStack(spacing: 4) {
                Text("BPM \(Int(sample.tempo))")
                    .font(.system(size: LoSuite.Typography.caption, design: .monospaced))
                    .foregroundColor(LoSuite.Colors.textSecondary)
                if let bars = sample.barDescription {
                    Text("• \(bars)")
                        .font(.system(size: LoSuite.Typography.caption))
                        .foregroundColor(LoSuite.Colors.disabled)
                }
            }
            Text("Conf \(String(format: "%.2f", sample.confidence))")
                .font(.system(size: LoSuite.Typography.caption, design: .monospaced))
                .foregroundColor(LoSuite.Colors.textSecondary)

            // Labels (first two)
            if !sample.labels.isEmpty {
                HStack(spacing: 3) {
                    ForEach(sample.labels.prefix(2), id: \.self) { label in
                        Text(label)
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(accentColor)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .overlay(
                                Capsule().stroke(accentColor.opacity(0.5), lineWidth: 1)
                            )
                    }
                }
            }

            Spacer(minLength: 0)

            // Mini waveform + playback indicator
            ZStack(alignment: .trailing) {
                TileMiniWaveform(audioURL: sample.audioURL, accentColor: accentColor)
                Image(systemName: sample.category == .loop ? "repeat" : "play.fill")
                    .font(.system(size: 7))
                    .foregroundColor(accentColor.opacity(0.6))
            }
            .frame(height: 18)
        }
        .padding(.horizontal, LoSuite.Spacing.sm)
        .padding(.vertical, LoSuite.Spacing.sm)
        .frame(width: 150, height: 120)
        .background(
            RoundedRectangle(cornerRadius: LoSuite.Radius.sm)
                .fill(isSelected ? accentColor.opacity(0.06) : LoSuite.Colors.panelSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LoSuite.Radius.sm)
                .stroke(
                    isSelected ? accentColor : (isHovering ? LoSuite.Colors.textSecondary.opacity(0.4)
                                                           : LoSuite.Colors.bordersDividers),
                    lineWidth: isSelected ? 1.5 : 1
                )
        )
        .shadow(
            color: isSelected ? accentColor.opacity(LoSuite.Glow.selectedOpacity) : .clear,
            radius: LoSuite.Glow.selectedRadius, y: 2
        )
        .scaleEffect(isHovering && !isSelected ? 1.015 : 1.0)
        .animation(LoSuite.Motion.fast, value: isHovering)
        .animation(LoSuite.Motion.fast, value: isSelected)
        .onTapGesture { onTap() }
        .onHover { isHovering = $0 }
        .contextMenu {
            Button(isChecked ? "Deselect for Export" : "Select for Export") { onToggleCheck() }
            Divider()
            // Cycle through categories
            Menu("Set Category") {
                ForEach(SampleCategory.allCases, id: \.self) { cat in
                    Button {
                        onSetCategory(cat)
                    } label: {
                        Label(cat.rawValue, systemImage: cat.icon)
                    }
                }
            }
            Divider()
            Button("Duplicate") { onDuplicate() }
            Button("Delete", role: .destructive) { onDelete() }
        }
    }
}

// MARK: - Tile Mini Waveform

struct TileMiniWaveform: View {
    let audioURL: URL?
    var accentColor: Color
    @State private var bars: [Float] = []

    var body: some View {
        Canvas { context, size in
            guard !bars.isEmpty else { return }
            let barW: CGFloat = 2
            let gap:  CGFloat = 1
            let stride = barW + gap
            let count = Int(size.width / stride)
            let step = max(1, bars.count / max(1, count))
            for i in 0..<count {
                let idx = min(i * step, bars.count - 1)
                let h = CGFloat(bars[idx]) * size.height
                let x = CGFloat(i) * stride
                let rect = CGRect(x: x, y: (size.height - h) / 2, width: barW, height: max(1, h))
                context.fill(Path(rect), with: .color(accentColor.opacity(0.75)))
            }
        }
        .onAppear { Task { await load() } }
        .onChange(of: audioURL) { _, _ in Task { await load() } }
    }

    private func load() async {
        guard let url = audioURL else { return }
        do {
            let file = try AVAudioFile(forReading: url)
            let total = AVAudioFrameCount(file.length)
            let count = 60
            let chunk = max(1, Int(total) / count)
            let buf = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                       frameCapacity: AVAudioFrameCount(chunk))!
            var out: [Float] = []
            file.framePosition = 0
            for _ in 0..<count {
                do {
                    try file.read(into: buf, frameCount: AVAudioFrameCount(chunk))
                    if let ch = buf.floatChannelData?[0] {
                        var peak: Float = 0
                        for i in 0..<Int(buf.frameLength) { peak = max(peak, abs(ch[i])) }
                        out.append(peak)
                    }
                } catch { break }
            }
            await MainActor.run { bars = out }
        } catch {}
    }
}

// MARK: - Extraction Controls Panel

struct ExtractionControlsPanel: View {
    @Binding var targetBars: Int
    @Binding var sensitivity: Double
    @Binding var silenceRemoval: Bool
    @Binding var minDuration: Double
    @Binding var confidence: Double
    @Binding var normalize: Bool
    @Binding var autoTag: Bool
    let isExporting: Bool
    var onGeneratePack: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LoSuite.Spacing.lg) {

                Text("Extraction Controls")
                    .font(.system(size: LoSuite.Typography.h2, weight: .semibold))
                    .foregroundColor(LoSuite.Colors.textPrimary)
                    .padding(.top, LoSuite.Spacing.xs)

                // Loop Detection
                controlSection(title: "Loop Detection") {
                    HStack {
                        Text("Target Bars")
                            .font(.system(size: LoSuite.Typography.body))
                            .foregroundColor(LoSuite.Colors.textSecondary)
                        Spacer()
                        Text("\(targetBars)")
                            .font(.system(size: LoSuite.Typography.monoData, design: .monospaced))
                            .foregroundColor(LoSuite.Colors.textPrimary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sensitivity")
                            .font(.system(size: LoSuite.Typography.body))
                            .foregroundColor(LoSuite.Colors.textSecondary)
                        Slider(value: $sensitivity, in: 0...1)
                            .tint(LoSuite.Colors.accent)
                    }

                    HStack {
                        Text("Silence Removal")
                            .font(.system(size: LoSuite.Typography.body))
                            .foregroundColor(LoSuite.Colors.textSecondary)
                        Spacer()
                        Toggle("", isOn: $silenceRemoval)
                            .toggleStyle(.switch)
                            .tint(LoSuite.Colors.accent)
                            .labelsHidden()
                    }

                    Button(isExporting ? "Exporting…" : "Generate Pack") {
                        onGeneratePack()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(LoSuite.Colors.accent)
                    .frame(maxWidth: .infinity)
                    .controlSize(.large)
                    .disabled(isExporting)
                }

                // Phrase Detection
                controlSection(title: "Phrase Detection") {
                    HStack {
                        Text("Min Duration")
                            .font(.system(size: LoSuite.Typography.body))
                            .foregroundColor(LoSuite.Colors.textSecondary)
                        Spacer()
                        Text(String(format: "%.1fs", minDuration))
                            .font(.system(size: LoSuite.Typography.monoData, design: .monospaced))
                            .foregroundColor(LoSuite.Colors.textPrimary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Confidence")
                            .font(.system(size: LoSuite.Typography.body))
                            .foregroundColor(LoSuite.Colors.textSecondary)
                        Slider(value: $confidence, in: 0...1)
                            .tint(LoSuite.Colors.accent)
                    }
                }

                // Output
                controlSection(title: "Output") {
                    HStack {
                        Text("Normalize")
                            .font(.system(size: LoSuite.Typography.body))
                            .foregroundColor(LoSuite.Colors.textSecondary)
                        Spacer()
                        Toggle("", isOn: $normalize)
                            .toggleStyle(.switch)
                            .tint(LoSuite.Colors.accent)
                            .labelsHidden()
                    }
                    HStack {
                        Text("Auto-tag")
                            .font(.system(size: LoSuite.Typography.body))
                            .foregroundColor(LoSuite.Colors.textSecondary)
                        Spacer()
                        Toggle("", isOn: $autoTag)
                            .toggleStyle(.switch)
                            .tint(LoSuite.Colors.accent)
                            .labelsHidden()
                    }
                }
            }
            .padding(LoSuite.Spacing.md)
        }
        .background(LoSuite.Colors.panelSurface)
    }

    @ViewBuilder
    private func controlSection(title: String,
                                 @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: LoSuite.Spacing.sm) {
            Text(title)
                .font(.system(size: LoSuite.Typography.labelSmall, weight: .semibold))
                .foregroundColor(LoSuite.Colors.textPrimary)
            VStack(alignment: .leading, spacing: LoSuite.Spacing.sm) {
                content()
            }
            .padding(LoSuite.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: LoSuite.Radius.sm)
                    .fill(LoSuite.Colors.elevatedSurface)
            )
        }
    }
}

// MARK: - Export Toast

struct ExportToastView: View {
    let result: ExportResult
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: LoSuite.Spacing.sm) {
            Image(systemName: result.failCount == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(result.failCount == 0 ? Color(hex: "30D158") : Color(hex: "FF9F0A"))

            VStack(alignment: .leading, spacing: 2) {
                Text(toastTitle)
                    .font(.system(size: LoSuite.Typography.labelSmall, weight: .semibold))
                    .foregroundColor(LoSuite.Colors.textPrimary)
                if let folder = result.folder {
                    Text(folder.lastPathComponent)
                        .font(.system(size: LoSuite.Typography.caption, design: .monospaced))
                        .foregroundColor(LoSuite.Colors.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            if let folder = result.folder, result.successCount > 0 {
                Button("Reveal") { NSWorkspace.shared.open(folder) }
                    .buttonStyle(.plain)
                    .font(.system(size: LoSuite.Typography.caption, weight: .medium))
                    .foregroundColor(LoSuite.Colors.accent)
            }

            Button { onDismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(LoSuite.Colors.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, LoSuite.Spacing.md)
        .padding(.vertical, LoSuite.Spacing.sm + 2)
        .background(
            RoundedRectangle(cornerRadius: LoSuite.Radius.md)
                .fill(LoSuite.Colors.elevatedSurface)
                .shadow(color: .black.opacity(LoSuite.Shadow.liftedOpacity),
                        radius: LoSuite.Shadow.liftedRadius,
                        y: LoSuite.Shadow.liftedY)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LoSuite.Radius.md)
                .stroke(LoSuite.Colors.bordersDividers, lineWidth: 1)
        )
        .padding(.horizontal, LoSuite.Spacing.lg)
    }

    private var toastTitle: String {
        if result.successCount == 0 && result.failCount > 0 {
            return "Export failed (\(result.failCount) file\(result.failCount == 1 ? "" : "s"))"
        } else if result.failCount > 0 {
            return "\(result.successCount) exported, \(result.failCount) failed"
        } else {
            return "\(result.successCount) sample\(result.successCount == 1 ? "" : "s") exported"
        }
    }
}

// MARK: - Loop Scan Bar

struct LoopScanBar: View {
    @Binding var loopBarsCount: Int
    @Binding var loopBraceStart: TimeInterval
    let stemDuration: TimeInterval
    let loopBraceDuration: TimeInterval
    let tempo: Double
    let timeToBarsBeat: (TimeInterval) -> String
    let barsBeatToTime: (String) -> TimeInterval?

    @State private var isEditingStart = false
    @State private var startInput = ""

    private let barOptions = [1, 2, 4, 8, 16]

    var body: some View {
        HStack(spacing: LoSuite.Spacing.sm) {

            // Bar-length selector pills
            Text("LOOP")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(LoSuite.Colors.textSecondary)
                .tracking(1.0)

            HStack(spacing: 3) {
                ForEach(barOptions, id: \.self) { bars in
                    let isActive = loopBarsCount == bars
                    Button { loopBarsCount = bars } label: {
                        Text(bars == 1 ? "1" : bars <= 4 ? "\(bars)" : "\(bars)b")
                            .font(.system(size: 11, weight: isActive ? .bold : .regular, design: .monospaced))
                            .foregroundColor(isActive ? .white : LoSuite.Colors.textSecondary)
                            .frame(width: bars <= 4 ? 28 : 32, height: 24)
                            .background(isActive ? LoSuite.Colors.accent : LoSuite.Colors.elevatedSurface)
                            .cornerRadius(5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(isActive ? LoSuite.Colors.accent : LoSuite.Colors.bordersDividers, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("\(bars) bar\(bars == 1 ? "" : "s")")
                }
            }

            Text("bars")
                .font(.system(size: 10))
                .foregroundColor(LoSuite.Colors.disabled)

            Rectangle()
                .fill(LoSuite.Colors.bordersDividers)
                .frame(width: 1, height: 16)
                .padding(.horizontal, 2)

            // Position display: START → END (editable)
            Text("POS")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(LoSuite.Colors.disabled)
                .tracking(0.8)

            // Editable start field
            BarBeatField(
                time: loopBraceStart,
                tempo: tempo,
                onChange: { newTime in
                    loopBraceStart = max(0, min(stemDuration - loopBraceDuration, newTime))
                }
            )

            Text("→")
                .font(.system(size: 11))
                .foregroundColor(LoSuite.Colors.textSecondary)

            // End (read-only, shows result)
            Text(timeToBarsBeat(loopBraceStart + loopBraceDuration))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(LoSuite.Colors.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(LoSuite.Colors.elevatedSurface)
                .cornerRadius(LoSuite.Radius.sm)

            Spacer()

            // Duration label
            let bars = loopBarsCount
            Text("\(bars) bar\(bars == 1 ? "" : "s")")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(LoSuite.Colors.accent)
        }
        .padding(.horizontal, LoSuite.Spacing.md)
        .padding(.vertical, 8)
        .background(LoSuite.Colors.panelSurface)
    }
}

// MARK: - Bar:Beat Editable Field

struct BarBeatField: View {
    let time: TimeInterval
    let tempo: Double
    let onChange: (TimeInterval) -> Void

    @State private var isEditing = false
    @State private var text = ""
    @FocusState private var focused: Bool

    private var secPerBeat: Double { 60.0 / max(1, tempo) }
    private var secPerBar:  Double { secPerBeat * 4 }

    private var displayStr: String {
        guard secPerBeat > 0 else { return "1:1" }
        let totalBeats = time / secPerBeat
        let bar  = Int(totalBeats / 4) + 1
        let beat = Int(totalBeats.truncatingRemainder(dividingBy: 4)) + 1
        return "\(bar):\(beat)"
    }

    private func parseAndCommit() {
        let parts = text.split(separator: ":").compactMap { Int($0) }
        var newTime: TimeInterval? = nil
        if parts.count == 1      { newTime = TimeInterval(max(1, parts[0]) - 1) * secPerBar }
        else if parts.count == 2 { newTime = TimeInterval(max(1, parts[0]) - 1) * secPerBar
                                            + TimeInterval(max(1, parts[1]) - 1) * secPerBeat }
        if let t = newTime { onChange(t) }
        isEditing = false
    }

    var body: some View {
        Group {
            if isEditing {
                TextField("", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(LoSuite.Colors.textPrimary)
                    .frame(width: 48)
                    .focused($focused)
                    .onSubmit { parseAndCommit() }
                    .onExitCommand { isEditing = false }
            } else {
                Text(displayStr)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(LoSuite.Colors.textPrimary)
                    .frame(minWidth: 48, alignment: .center)
                    .onTapGesture {
                        text = displayStr
                        isEditing = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { focused = true }
                    }
                    .help("Click to enter bar:beat position")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isEditing ? LoSuite.Colors.accent.opacity(0.12) : LoSuite.Colors.elevatedSurface)
        .overlay(
            RoundedRectangle(cornerRadius: LoSuite.Radius.sm)
                .stroke(isEditing ? LoSuite.Colors.accent : LoSuite.Colors.bordersDividers, lineWidth: 1)
        )
        .cornerRadius(LoSuite.Radius.sm)
        .onChange(of: isEditing) { _, editing in focused = editing }
    }
}

// MARK: - Scan Navigation Bar

struct ScanNavBar: View {
    var onBack: () -> Void
    var onForward: () -> Void
    var onPlay: () -> Void
    var onStop: () -> Void
    var onSave: () -> Void
    var onDuplicate: () -> Void
    var isPlaying: Bool
    var positionLabel: String
    var endLabel: String
    var loopBarsCount: Int
    var accentColor: Color

    var body: some View {
        HStack(spacing: 0) {

            // ◀◀ back
            scanButton(symbol: "backward.end.fill", label: "−1 bar",  action: onBack)

            Rectangle().fill(LoSuite.Colors.bordersDividers).frame(width: 1, height: 28)

            // Play / Stop
            Button {
                isPlaying ? onStop() : onPlay()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text(isPlaying ? "Stop" : "Audition")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(isPlaying ? .white : LoSuite.Colors.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isPlaying ? LoSuite.Colors.accent : LoSuite.Colors.elevatedSurface)
            }
            .buttonStyle(.plain)

            Rectangle().fill(LoSuite.Colors.bordersDividers).frame(width: 1, height: 28)

            // Position readout (center)
            HStack(spacing: 4) {
                Text(positionLabel)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(accentColor)
                Text("→")
                    .font(.system(size: 10))
                    .foregroundColor(LoSuite.Colors.disabled)
                Text(endLabel)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(LoSuite.Colors.textSecondary)
                Text("·")
                    .foregroundColor(LoSuite.Colors.disabled)
                Text("\(loopBarsCount) bar\(loopBarsCount == 1 ? "" : "s")")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(LoSuite.Colors.disabled)
            }
            .frame(minWidth: 160)
            .padding(.horizontal, LoSuite.Spacing.md)

            Rectangle().fill(LoSuite.Colors.bordersDividers).frame(width: 1, height: 28)

            // ▶▶ forward
            scanButton(symbol: "forward.end.fill", label: "+1 bar", action: onForward)

            Spacer()

            // Duplicate (save + advance)
            Button {
                onDuplicate()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "plus.square.on.square")
                        .font(.system(size: 12))
                    Text("Save + Next")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(LoSuite.Colors.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(LoSuite.Colors.elevatedSurface)
            }
            .buttonStyle(.plain)
            .help("Save this loop and advance to next position")

            Rectangle().fill(LoSuite.Colors.bordersDividers).frame(width: 1, height: 28)

            // SAVE LOOP (primary action)
            Button { onSave() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Save Loop")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(accentColor)
            }
            .buttonStyle(.plain)
            .help("Save this region as a loop sample")
        }
        .frame(height: 44)
        .background(LoSuite.Colors.backgroundPrimary)
    }

    @ViewBuilder
    private func scanButton(symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button { action() } label: {
            VStack(spacing: 2) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                Text(label)
                    .font(.system(size: 8))
            }
            .foregroundColor(LoSuite.Colors.textSecondary)
            .frame(width: 58, height: 44)
            .background(LoSuite.Colors.panelSurface)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sample Detail Panel

struct SampleDetailPanel: View {
    @Binding var sample: ExtractedSample
    @Binding var nudgeGrid: NudgeGrid
    @Binding var isRenaming: Bool
    @Binding var renameText: String
    let accentColor: Color
    var onDuplicate: () -> Void
    var onDelete: () -> Void
    var onNudgeStart: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("SAMPLE")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(LoSuite.Colors.textSecondary)
                    .tracking(1.2)
                Spacer()
                Button { onDuplicate() } label: {
                    Image(systemName: "plus.square.on.square")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundColor(LoSuite.Colors.textSecondary)
                .help("Duplicate")

                Button { onDelete() } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundColor(LoSuite.Colors.textSecondary.opacity(0.7))
                .help("Delete")
            }
            .padding(.horizontal, LoSuite.Spacing.md)
            .padding(.vertical, LoSuite.Spacing.sm)
            .background(LoSuite.Colors.panelSurface)

            Rectangle().fill(LoSuite.Colors.bordersDividers).frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: LoSuite.Spacing.sm) {

                    // Name (tap to rename)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Name").detailLabel()
                        if isRenaming {
                            TextField("", text: $renameText)
                                .textFieldStyle(.plain)
                                .font(.system(size: LoSuite.Typography.body, weight: .medium))
                                .foregroundColor(LoSuite.Colors.textPrimary)
                                .padding(6)
                                .background(LoSuite.Colors.elevatedSurface)
                                .cornerRadius(LoSuite.Radius.sm)
                                .onSubmit {
                                    if !renameText.isEmpty { sample.name = renameText }
                                    isRenaming = false
                                }
                        } else {
                            Text(sample.name)
                                .font(.system(size: LoSuite.Typography.body, weight: .medium))
                                .foregroundColor(LoSuite.Colors.textPrimary)
                                .lineLimit(2)
                                .onTapGesture {
                                    renameText = sample.name
                                    isRenaming = true
                                }
                                .help("Tap to rename")
                        }
                    }

                    // Category (tap to cycle)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Category").detailLabel()
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 5) {
                                ForEach(SampleCategory.allCases.prefix(6), id: \.self) { cat in
                                    let isActive = sample.category == cat
                                    Button { sample.category = cat } label: {
                                        Label(cat.rawValue, systemImage: cat.icon)
                                            .font(.system(size: 10, weight: isActive ? .semibold : .regular))
                                            .foregroundColor(isActive ? .white : LoSuite.Colors.textSecondary)
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 4)
                                            .background(isActive ? accentColor : LoSuite.Colors.elevatedSurface)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Labels / Tags
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Tags").detailLabel()
                        let suggestions = LabelSuggestions.suggestions(for: sample.stemType)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 4)], spacing: 4) {
                            ForEach(suggestions.prefix(12), id: \.self) { label in
                                let hasLabel = sample.labels.contains(label)
                                Button {
                                    if hasLabel { sample.labels.removeAll { $0 == label } }
                                    else { sample.labels.append(label) }
                                } label: {
                                    Text(label)
                                        .font(.system(size: 9, weight: hasLabel ? .semibold : .regular))
                                        .foregroundColor(hasLabel ? accentColor : LoSuite.Colors.disabled)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 3)
                                        .frame(maxWidth: .infinity)
                                        .background(hasLabel ? accentColor.opacity(0.12) : LoSuite.Colors.elevatedSurface)
                                        .overlay(Capsule().stroke(hasLabel ? accentColor.opacity(0.5) : Color.clear, lineWidth: 1))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Timing (bars:beats primary, seconds secondary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Timing").detailLabel()
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Start").font(.system(size: 9)).foregroundColor(LoSuite.Colors.disabled)
                                Text(sample.positionString(for: sample.effectiveStartTime))
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(LoSuite.Colors.textPrimary)
                                Text(String(format: "%.2fs", sample.effectiveStartTime))
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundColor(LoSuite.Colors.disabled)
                            }
                            Spacer()
                            VStack(alignment: .center, spacing: 2) {
                                Text("Length").font(.system(size: 9)).foregroundColor(LoSuite.Colors.disabled)
                                if let bars = sample.barDescription {
                                    Text(bars)
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundColor(accentColor)
                                } else {
                                    Text(sample.durationString)
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundColor(accentColor)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("End").font(.system(size: 9)).foregroundColor(LoSuite.Colors.disabled)
                                Text(sample.positionString(for: sample.effectiveEndTime))
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(LoSuite.Colors.textPrimary)
                                Text(String(format: "%.2fs", sample.effectiveEndTime))
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundColor(LoSuite.Colors.disabled)
                            }
                        }
                        .padding(8)
                        .background(LoSuite.Colors.elevatedSurface)
                        .cornerRadius(LoSuite.Radius.sm)
                    }

                    // Nudge controls
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Nudge").detailLabel()
                            Spacer()
                            // Grid selector
                            HStack(spacing: 2) {
                                ForEach(NudgeGrid.allCases, id: \.self) { grid in
                                    Button(grid.displayName) { nudgeGrid = grid }
                                        .buttonStyle(.plain)
                                        .font(.system(size: 9, weight: nudgeGrid == grid ? .semibold : .regular))
                                        .foregroundColor(nudgeGrid == grid ? accentColor : LoSuite.Colors.disabled)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 3)
                                        .background(nudgeGrid == grid ? accentColor.opacity(0.12) : Color.clear)
                                        .cornerRadius(4)
                                }
                            }
                        }
                        HStack(spacing: 6) {
                            // Nudge start
                            HStack(spacing: 3) {
                                Text("Start")
                                    .font(.system(size: 10))
                                    .foregroundColor(LoSuite.Colors.textSecondary)
                                nudgeButton(symbol: "backward.end.fill", sign: -1)
                                nudgeButton(symbol: "forward.end.fill", sign: +1)
                            }
                            Spacer()
                            // Offset display
                            if sample.nudgeOffset != 0 {
                                Text(String(format: "%+.3fs", sample.nudgeOffset))
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(accentColor)
                                Button("Reset") { sample.nudgeOffset = 0 }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 9))
                                    .foregroundColor(LoSuite.Colors.disabled)
                            }
                        }
                        .padding(8)
                        .background(LoSuite.Colors.elevatedSurface)
                        .cornerRadius(LoSuite.Radius.sm)
                    }

                    // Playback mode
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Playback").detailLabel()
                        HStack(spacing: 6) {
                            ForEach(PlaybackMode.allCases, id: \.self) { mode in
                                let isActive = AudioPreviewPlayer.shared.playbackMode == mode
                                Button {
                                    AudioPreviewPlayer.shared.setMode(mode)
                                } label: {
                                    Label(mode.rawValue, systemImage: mode.icon)
                                        .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                                        .foregroundColor(isActive ? .white : LoSuite.Colors.textSecondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .frame(maxWidth: .infinity)
                                        .background(isActive ? accentColor : LoSuite.Colors.elevatedSurface)
                                        .cornerRadius(LoSuite.Radius.sm)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Pitch — only shown when confident enough (tonal samples)
                    if let noteName = sample.pitchNoteName, sample.pitchConfidence > 0.4 {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Pitch").detailLabel()
                            HStack(spacing: 0) {
                                // Note name — the key datum for producers
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(noteName)
                                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                                        .foregroundColor(accentColor)
                                    Text("Note")
                                        .font(.system(size: 9))
                                        .foregroundColor(LoSuite.Colors.textSecondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                // Frequency in Hz
                                VStack(alignment: .center, spacing: 2) {
                                    if let hz = sample.detectedPitch {
                                        Text(String(format: "%.1f Hz", hz))
                                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                                            .foregroundColor(LoSuite.Colors.textPrimary)
                                    }
                                    Text("Freq")
                                        .font(.system(size: 9))
                                        .foregroundColor(LoSuite.Colors.textSecondary)
                                }
                                .frame(maxWidth: .infinity)

                                // Cents offset (orange when noticeably detuned)
                                VStack(alignment: .trailing, spacing: 2) {
                                    let cents = sample.pitchCents
                                    Text(String(format: "%+.0f¢", cents))
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                        .foregroundColor(abs(cents) > 20 ? .orange : LoSuite.Colors.textPrimary)
                                    Text("Tune")
                                        .font(.system(size: 9))
                                        .foregroundColor(LoSuite.Colors.textSecondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            .padding(10)
                            .background(LoSuite.Colors.elevatedSurface)
                            .cornerRadius(LoSuite.Radius.sm)
                        }
                    }
                }
                .padding(LoSuite.Spacing.md)
            }
        }
        .background(LoSuite.Colors.panelSurface)
    }

    @ViewBuilder
    private func nudgeButton(symbol: String, sign: Double) -> some View {
        Button { onNudgeStart(sign) } label: {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(LoSuite.Colors.textPrimary)
                .frame(width: 26, height: 22)
                .background(LoSuite.Colors.backgroundPrimary)
                .cornerRadius(5)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Detail Label Modifier

private extension Text {
    func detailLabel() -> some View {
        self.font(.system(size: 9, weight: .semibold))
            .foregroundColor(LoSuite.Colors.textSecondary)
            .tracking(0.8)
            .textCase(.uppercase)
    }
}

// MARK: - Playback Control Bar

struct PlaybackControlBar: View {
    @Binding var nudgeGrid: NudgeGrid
    @Binding var showKeyboard: Bool
    @Binding var playbackMode: PlaybackMode
    var onNudgeStart: (Double) -> Void
    var hasSelection: Bool

    var body: some View {
        HStack(spacing: LoSuite.Spacing.sm) {

            // Playback mode toggle
            HStack(spacing: 2) {
                ForEach(PlaybackMode.allCases, id: \.self) { mode in
                    let isActive = playbackMode == mode
                    Button { playbackMode = mode } label: {
                        Image(systemName: mode.icon)
                            .font(.system(size: 11))
                            .foregroundColor(isActive ? .white : LoSuite.Colors.textSecondary)
                            .frame(width: 26, height: 22)
                            .background(isActive ? LoSuite.Colors.accent : LoSuite.Colors.elevatedSurface)
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .help(mode.rawValue)
                }
            }

            Rectangle()
                .fill(LoSuite.Colors.bordersDividers)
                .frame(width: 1, height: 18)

            // Nudge grid
            Text("GRID")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(LoSuite.Colors.textSecondary)
                .tracking(0.8)
            HStack(spacing: 2) {
                ForEach(NudgeGrid.allCases, id: \.self) { grid in
                    Button(grid.displayName) { nudgeGrid = grid }
                        .buttonStyle(.plain)
                        .font(.system(size: 10, weight: nudgeGrid == grid ? .semibold : .regular))
                        .foregroundColor(nudgeGrid == grid ? LoSuite.Colors.accent : LoSuite.Colors.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(nudgeGrid == grid ? LoSuite.Colors.accent.opacity(0.12) : Color.clear)
                        .cornerRadius(4)
                }
            }

            Rectangle()
                .fill(LoSuite.Colors.bordersDividers)
                .frame(width: 1, height: 18)

            // Nudge buttons (only when selection active)
            if hasSelection {
                Text("NUDGE")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(LoSuite.Colors.textSecondary)
                    .tracking(0.8)
                HStack(spacing: 2) {
                    nudgeBtn(symbol: "backward.end.fill", sign: -1)
                    nudgeBtn(symbol: "forward.end.fill", sign: +1)
                }
            }

            Spacer()

            // Keyboard toggle
            Button {
                withAnimation(LoSuite.Motion.fast) { showKeyboard.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "pianokeys")
                        .font(.system(size: 12))
                    Text("Keyboard")
                        .font(.system(size: 11))
                }
                .foregroundColor(showKeyboard ? LoSuite.Colors.accent : LoSuite.Colors.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(showKeyboard ? LoSuite.Colors.accent.opacity(0.12) : Color.clear)
                .cornerRadius(LoSuite.Radius.sm)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, LoSuite.Spacing.md)
        .padding(.vertical, 7)
        .background(LoSuite.Colors.panelSurface)
    }

    @ViewBuilder
    private func nudgeBtn(symbol: String, sign: Double) -> some View {
        Button { onNudgeStart(sign) } label: {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(LoSuite.Colors.textPrimary)
                .frame(width: 26, height: 22)
                .background(LoSuite.Colors.elevatedSurface)
                .cornerRadius(5)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Zoomed Waveform with Draggable Markers

struct ZoomedWaveformWithMarkersView: View {
    let audioURL: URL?
    @Binding var startTime: TimeInterval
    @Binding var endTime: TimeInterval
    let tempo: Double
    let accentColor: Color

    @State private var waveformData: [Float] = []
    @State private var totalDuration: TimeInterval = 0
    @State private var isLoading = true

    private var secPerBeat: Double { 60.0 / max(1, tempo) }
    private var secPerBar:  Double { secPerBeat * 4 }

    // Show context on each side of the selected region
    private var contextPad: TimeInterval { max(secPerBar, (endTime - startTime) * 0.5) }
    private var viewStart: TimeInterval { max(0, startTime - contextPad) }
    private var viewEnd:   TimeInterval { min(max(totalDuration, 0.1), endTime + contextPad) }
    private var viewDuration: TimeInterval { max(0.001, viewEnd - viewStart) }

    private func xFraction(for t: TimeInterval) -> CGFloat {
        CGFloat((t - viewStart) / viewDuration)
    }

    private func snapToBeat(_ t: TimeInterval) -> TimeInterval {
        guard secPerBeat > 0 else { return t }
        return (t / secPerBeat).rounded() * secPerBeat
    }

    private func timeToBarsBeat(_ t: TimeInterval) -> String {
        guard secPerBeat > 0 else { return "-" }
        let totalBeats = t / secPerBeat
        let bar  = Int(totalBeats / 4) + 1
        let beat = Int(totalBeats.truncatingRemainder(dividingBy: 4)) + 1
        return "\(bar):\(beat)"
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack(alignment: .topLeading) {
                LoSuite.Colors.backgroundPrimary

                if !waveformData.isEmpty && totalDuration > 0 {
                    // Waveform canvas
                    Canvas { ctx, size in
                        drawWaveform(ctx: ctx, size: size)
                    }
                    .frame(width: w, height: h)
                    .coordinateSpace(name: "zoomWaveform")

                    // Selected region fill
                    let sx = xFraction(for: startTime) * w
                    let ex = xFraction(for: endTime) * w
                    Rectangle()
                        .fill(accentColor.opacity(0.10))
                        .frame(width: max(2, ex - sx), height: h)
                        .offset(x: sx)

                    // ── Start marker (green / left brace) ──────────────
                    markerLine(x: sx, color: Color(hex: "30D158"), h: h)
                    markerGrabHandle(x: sx, color: Color(hex: "30D158"), h: h)
                        .gesture(DragGesture(coordinateSpace: .named("zoomWaveform"))
                            .onChanged { drag in
                                let t = viewStart + (Double(max(0, drag.location.x)) / Double(w)) * viewDuration
                                startTime = max(0, min(endTime - 0.05, snapToBeat(t)))
                            }
                        )

                    // ── End marker (accent / right brace) ──────────────
                    markerLine(x: ex, color: accentColor, h: h)
                    markerGrabHandle(x: ex, color: accentColor, h: h)
                        .gesture(DragGesture(coordinateSpace: .named("zoomWaveform"))
                            .onChanged { drag in
                                let t = viewStart + (Double(max(0, drag.location.x)) / Double(w)) * viewDuration
                                endTime = min(totalDuration, max(startTime + 0.05, snapToBeat(t)))
                            }
                        )

                    // Bars:beats labels at bottom
                    VStack {
                        Spacer()
                        HStack {
                            Text(timeToBarsBeat(startTime))
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .foregroundColor(Color(hex: "30D158"))
                                .padding(.leading, max(4, sx))
                            Spacer()
                            // Duration in bars
                            let bars = (endTime - startTime) / secPerBar
                            Text(bars >= 0.99
                                 ? String(format: "%g bar%@", bars.rounded(), bars.rounded() == 1 ? "" : "s")
                                 : String(format: "%.2f bars", bars))
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .foregroundColor(accentColor)
                            Spacer()
                            Text(timeToBarsBeat(endTime))
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .foregroundColor(accentColor)
                                .padding(.trailing, max(4, w - ex))
                        }
                        .padding(.bottom, 4)
                    }
                }

                if isLoading {
                    ProgressView()
                        .tint(LoSuite.Colors.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .coordinateSpace(name: "zoomWaveform")
        }
        .overlay(alignment: .top) {
            // Zoom level hint
            Text("ZOOM — drag handles to trim")
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(LoSuite.Colors.disabled)
                .padding(.top, 4)
        }
        .onAppear { Task { await load() } }
        .onChange(of: audioURL) { _, _ in
            waveformData = []
            isLoading = true
            Task { await load() }
        }
    }

    @ViewBuilder
    private func markerLine(x: CGFloat, color: Color, h: CGFloat) -> some View {
        Rectangle()
            .fill(color.opacity(0.85))
            .frame(width: 1.5, height: h)
            .offset(x: max(0, x - 0.75))
    }

    @ViewBuilder
    private func markerGrabHandle(x: CGFloat, color: Color, h: CGFloat) -> some View {
        ZStack(alignment: .top) {
            // Visible grip tab at top
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 10, height: 18)
                .overlay(
                    VStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { _ in
                            Rectangle().fill(.white.opacity(0.5)).frame(width: 4, height: 1)
                        }
                    }
                )
                .offset(x: x - 5, y: 2)

            // Wide invisible hit area for easier grabbing
            Color.clear
                .contentShape(Rectangle())
                .frame(width: 32, height: h)
                .offset(x: max(0, x - 16))
        }
    }

    private func drawWaveform(ctx: GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        let midY = h / 2
        guard totalDuration > 0, viewDuration > 0, !waveformData.isEmpty else { return }

        let startIdx = Int(max(0, viewStart / totalDuration) * Double(waveformData.count))
        let endIdx   = Int(min(1, viewEnd   / totalDuration) * Double(waveformData.count))
        let count    = max(1, endIdx - startIdx)

        // Base waveform (dimmed)
        var basePath = Path()
        for xi in 0..<Int(w) {
            let idx = startIdx + Int(Double(xi) / w * Double(count))
            guard idx < waveformData.count else { continue }
            let amp = CGFloat(waveformData[idx]) * (h / 2) * 0.80
            basePath.move(to: CGPoint(x: CGFloat(xi), y: midY - amp))
            basePath.addLine(to: CGPoint(x: CGFloat(xi), y: midY + amp))
        }
        ctx.stroke(basePath, with: .color(Color(hex: "9CA3AF").opacity(0.35)), lineWidth: 1)

        // Beat grid
        if tempo > 0 {
            let beat = 60.0 / tempo
            var t = floor(viewStart / beat) * beat
            while t <= viewEnd {
                if t >= viewStart {
                    let bx = CGFloat((t - viewStart) / viewDuration) * w
                    var p = Path()
                    p.move(to: CGPoint(x: bx, y: 0))
                    p.addLine(to: CGPoint(x: bx, y: h))
                    ctx.stroke(p, with: .color(Color(hex: "0A84FF").opacity(0.18)), lineWidth: 0.5)
                }
                t += beat
            }
        }

        // Highlighted waveform inside selected region
        let sx = CGFloat((startTime - viewStart) / viewDuration) * w
        let ex = CGFloat((endTime   - viewStart) / viewDuration) * w
        var regionPath = Path()
        for xi in Int(max(0, sx))..<Int(min(w, ex)) {
            let idx = startIdx + Int(Double(xi) / w * Double(count))
            guard idx < waveformData.count else { continue }
            let amp = CGFloat(waveformData[idx]) * (h / 2) * 0.80
            regionPath.move(to: CGPoint(x: CGFloat(xi), y: midY - amp))
            regionPath.addLine(to: CGPoint(x: CGFloat(xi), y: midY + amp))
        }
        ctx.stroke(regionPath, with: .color(accentColor.opacity(0.9)), lineWidth: 1.2)
    }

    private func load() async {
        guard let url = audioURL else {
            await MainActor.run { isLoading = false }
            return
        }
        do {
            let file = try AVAudioFile(forReading: url)
            let fmt  = file.processingFormat
            let total = AVAudioFrameCount(file.length)
            let dur  = Double(total) / fmt.sampleRate
            let count = 1200
            let chunk = max(1, Int(total) / count)
            let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(chunk))!
            var data: [Float] = []
            data.reserveCapacity(count)
            file.framePosition = 0
            for _ in 0..<count {
                do {
                    try file.read(into: buf, frameCount: AVAudioFrameCount(chunk))
                    if let ch = buf.floatChannelData?[0] {
                        var peak: Float = 0
                        for i in 0..<Int(buf.frameLength) { peak = max(peak, abs(ch[i])) }
                        data.append(peak)
                    }
                } catch { break }
            }
            await MainActor.run { waveformData = data; totalDuration = dur; isLoading = false }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }
}

// MARK: - Audition Keyboard

struct AuditionKeyboardView: View {
    let accentColor: Color
    var onPlay: () -> Void

    // White key note offsets in a chromatic octave (C=0)
    private let whiteSteps: [Int] = [0, 2, 4, 5, 7, 9, 11]
    // Black key positions between white keys (index into white keys, offset)
    private let blackKeys: [(whiteIndex: Int, step: Int)] = [
        (0, 1), (1, 3), (3, 6), (4, 8), (5, 10)
    ]

    @State private var pressedKey: Int? = nil

    var body: some View {
        GeometryReader { geo in
            let totalWhiteKeys = 14  // 2 octaves
            let keyW: CGFloat = (geo.size.width - 16) / CGFloat(totalWhiteKeys)
            let keyH = geo.size.height - 8

            ZStack(alignment: .topLeading) {
                LoSuite.Colors.panelSurface

                // White keys
                ForEach(0..<totalWhiteKeys, id: \.self) { i in
                    let x: CGFloat = 8 + CGFloat(i) * keyW
                    let note = noteNumber(whiteIndex: i)
                    let isRoot = (i % 7) == 0  // C notes
                    let isPressed = pressedKey == note

                    RoundedRectangle(cornerRadius: 3)
                        .fill(isPressed ? accentColor.opacity(0.4) : Color.white.opacity(isRoot ? 0.95 : 0.88))
                        .frame(width: keyW - 1.5, height: keyH)
                        .overlay(alignment: .bottom) {
                            if isRoot {
                                Text(noteName(whiteIndex: i))
                                    .font(.system(size: 7, weight: .medium))
                                    .foregroundColor(LoSuite.Colors.textSecondary.opacity(0.7))
                                    .padding(.bottom, 3)
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(LoSuite.Colors.bordersDividers.opacity(0.5), lineWidth: 1)
                        )
                        .offset(x: x, y: 4)
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                if pressedKey != note {
                                    pressedKey = note
                                    onPlay()
                                }
                            }
                            .onEnded { _ in pressedKey = nil }
                        )
                }

                // Black keys
                ForEach(0..<2, id: \.self) { octave in
                    ForEach(blackKeys, id: \.whiteIndex) { bk in
                        let wIdx = octave * 7 + bk.whiteIndex
                        let x: CGFloat = 8 + CGFloat(wIdx) * keyW + keyW * 0.6
                        let note = 48 + octave * 12 + bk.step
                        let isPressed = pressedKey == note

                        RoundedRectangle(cornerRadius: 2)
                            .fill(isPressed ? accentColor : LoSuite.Colors.backgroundPrimary)
                            .frame(width: keyW * 0.55, height: keyH * 0.60)
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(Color.black.opacity(0.3), lineWidth: 0.5)
                            )
                            .offset(x: x, y: 4)
                            .gesture(DragGesture(minimumDistance: 0)
                                .onChanged { _ in
                                    if pressedKey != note {
                                        pressedKey = note
                                        onPlay()
                                    }
                                }
                                .onEnded { _ in pressedKey = nil }
                            )
                    }
                }
            }
        }
        .background(LoSuite.Colors.panelSurface)
    }

    private func noteNumber(whiteIndex i: Int) -> Int {
        let octave = i / 7
        let step   = whiteSteps[i % 7]
        return 48 + octave * 12 + step
    }

    private func noteName(whiteIndex i: Int) -> String {
        let names = ["C", "D", "E", "F", "G", "A", "B"]
        let octave = 3 + i / 7
        return "\(names[i % 7])\(octave)"
    }
}

// MARK: - Preview

struct ResultsView_Previews: PreviewProvider {
    @State static var samples = [
        ExtractedSample(name: "Main Loop", category: .loop, stemType: .drums, duration: 2.0, barLength: 2, confidence: 0.95),
        ExtractedSample(name: "Fill 1",    category: .fill, stemType: .drums, duration: 0.5, barLength: nil, confidence: 0.82),
        ExtractedSample(name: "Kick",      category: .hit,  stemType: .drums, duration: 0.1, barLength: nil, confidence: 0.98),
    ]

    static var previews: some View {
        ResultsView(
            samples: $samples,
            onExport: { _ in nil },
            onExportAll: { nil },
            onOpenInLoOptimizer: { }
        )
        .frame(width: 1100, height: 700)
    }
}
