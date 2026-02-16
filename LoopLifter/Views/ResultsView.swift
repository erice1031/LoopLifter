//
//  ResultsView.swift
//  LoopLifter
//
//  Displays extracted samples organized by stem type
//

import SwiftUI
import AVFoundation

// MARK: - Lo Suite Design Tokens

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

private enum LoSuite {
    enum Colors {
        static let backgroundPrimary = Color(hex: "0E1014")
        static let panelSurface = Color(hex: "151821")
        static let elevatedSurface = Color(hex: "1C202B")
        static let bordersDividers = Color(hex: "272C38")
        static let textPrimary = Color(hex: "E6E8ED")
        static let textSecondary = Color(hex: "9CA3AF")
        static let disabled = Color(hex: "4B5563")
        static let accent = Color(hex: "7C5CFF")
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
    }

    enum Radius {
        static let small: CGFloat = 6
        static let medium: CGFloat = 8
        static let large: CGFloat = 10
        static let xl: CGFloat = 12
    }

    enum Typography {
        static let caption2: CGFloat = 10
        static let caption: CGFloat = 11
        static let body: CGFloat = 13
    }
}

private extension StemType {
    var designColor: Color {
        switch self {
        case .drums: return Color(hex: "FF9500")
        case .bass: return Color(hex: "AF52DE")
        case .vocals: return Color(hex: "30D158")
        case .other: return Color(hex: "0A84FF")
        }
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

    private let knobSize: CGFloat = 56  // Slightly larger for usability
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
                // Track (inactive)
                Circle()
                    .stroke(LoSuite.Colors.bordersDividers, lineWidth: trackWidth)
                    .frame(width: knobSize, height: knobSize)

                // Track (active arc)
                Circle()
                    .trim(from: 0, to: normalizedValue)
                    .stroke(accentColor, style: StrokeStyle(lineWidth: trackWidth, lineCap: .round))
                    .frame(width: knobSize, height: knobSize)
                    .rotationEffect(.degrees(-225))

                // Knob body (flat, no 3D)
                Circle()
                    .fill(LoSuite.Colors.panelSurface)
                    .frame(width: knobSize - 8, height: knobSize - 8)

                // Indicator line
                Rectangle()
                    .fill(LoSuite.Colors.textPrimary)
                    .frame(width: trackWidth, height: 14)
                    .offset(y: -14)
                    .rotationEffect(rotation)

                // Center cap
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

            // Value readout (SF Mono)
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

// MARK: - Draggable Value (Lo Suite Design)

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

// MARK: - Waveform View (Lo Suite Design)

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
                // Background
                RoundedRectangle(cornerRadius: LoSuite.Radius.medium)
                    .fill(LoSuite.Colors.panelSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: LoSuite.Radius.medium)
                            .stroke(LoSuite.Colors.bordersDividers, lineWidth: 1)
                    )

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(LoSuite.Colors.textSecondary)
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

                        // Draw full waveform (inactive color from spec)
                        var path = Path()
                        for x in 0..<Int(width) {
                            let sampleIndex = Swift.min(x * samplesPerPixel, waveformData.count - 1)
                            let sample = waveformData[sampleIndex]
                            let amplitude = CGFloat(sample) * (height / 2) * 0.85
                            path.move(to: CGPoint(x: CGFloat(x), y: midY - amplitude))
                            path.addLine(to: CGPoint(x: CGFloat(x), y: midY + amplitude))
                        }
                        // Waveform inactive: #9CA3AF at 65%
                        context.stroke(path, with: .color(Color(hex: "9CA3AF").opacity(0.65)), lineWidth: 1)

                        // Calculate region position
                        let regionStartX = (startTime / totalDuration) * width
                        let regionEndX = (endTime / totalDuration) * width

                        // Draw region overlay (12-15% opacity per spec)
                        let regionRect = CGRect(x: regionStartX, y: 0, width: regionEndX - regionStartX, height: height)
                        context.fill(Path(regionRect), with: .color(accentColor.opacity(0.12)))

                        // Draw highlighted waveform in region
                        var regionPath = Path()
                        for x in Int(regionStartX)..<Int(regionEndX) {
                            let sampleIndex = Swift.min(x * samplesPerPixel, waveformData.count - 1)
                            let sample = waveformData[sampleIndex]
                            let amplitude = CGFloat(sample) * (height / 2) * 0.85
                            regionPath.move(to: CGPoint(x: CGFloat(x), y: midY - amplitude))
                            regionPath.addLine(to: CGPoint(x: CGFloat(x), y: midY + amplitude))
                        }
                        context.stroke(regionPath, with: .color(accentColor), lineWidth: 1)

                        // Draw region boundaries (2px accent per spec)
                        let boundaryPath = Path { p in
                            p.move(to: CGPoint(x: regionStartX, y: 0))
                            p.addLine(to: CGPoint(x: regionStartX, y: height))
                            p.move(to: CGPoint(x: regionEndX, y: 0))
                            p.addLine(to: CGPoint(x: regionEndX, y: height))
                        }
                        context.stroke(boundaryPath, with: .color(accentColor), lineWidth: 2)

                        // Draw timeline ruler markers
                        let markerInterval = totalDuration / 10
                        for i in 0...10 {
                            let time = Double(i) * markerInterval
                            let x = (time / totalDuration) * width
                            let tickHeight: CGFloat = i % 5 == 0 ? 8 : 4
                            let tickPath = Path { p in
                                p.move(to: CGPoint(x: x, y: height - tickHeight))
                                p.addLine(to: CGPoint(x: x, y: height))
                            }
                            context.stroke(tickPath, with: .color(Color(hex: "272C38")), lineWidth: 1)
                        }
                    }

                    // Time labels overlay
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

// MARK: - Zoomed Waveform View (shows sample region with context)

struct ZoomedWaveformView: View {
    let audioURL: URL?
    var sampleStart: TimeInterval  // Sample start time
    var sampleEnd: TimeInterval    // Sample end time
    var viewStart: TimeInterval    // Visible window start
    var viewEnd: TimeInterval      // Visible window end
    var accentColor: Color = LoSuite.Colors.accent
    var height: CGFloat = 180

    @State private var waveformData: [Float] = []
    @State private var isLoading = true
    @State private var totalDuration: TimeInterval = 0

    private var viewDuration: TimeInterval {
        viewEnd - viewStart
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: LoSuite.Radius.medium)
                    .fill(LoSuite.Colors.panelSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: LoSuite.Radius.medium)
                            .stroke(LoSuite.Colors.bordersDividers, lineWidth: 1)
                    )

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(LoSuite.Colors.textSecondary)
                } else if waveformData.isEmpty {
                    Text("No waveform")
                        .font(.system(size: LoSuite.Typography.caption))
                        .foregroundColor(LoSuite.Colors.textSecondary)
                } else {
                    Canvas { context, size in
                        let width = size.width
                        let height = size.height
                        let midY = height / 2

                        // Calculate which samples to show based on view window
                        let startRatio = viewStart / totalDuration
                        let endRatio = viewEnd / totalDuration
                        let startSample = Int(startRatio * Double(waveformData.count))
                        let endSample = min(Int(endRatio * Double(waveformData.count)), waveformData.count)
                        let visibleSamples = endSample - startSample

                        guard visibleSamples > 0 else { return }

                        // Draw waveform for visible region
                        var path = Path()
                        for x in 0..<Int(width) {
                            let sampleIndex = startSample + Int(Double(x) / width * Double(visibleSamples))
                            guard sampleIndex < waveformData.count else { continue }
                            let sample = waveformData[sampleIndex]
                            let amplitude = CGFloat(sample) * (height / 2) * 0.85
                            path.move(to: CGPoint(x: CGFloat(x), y: midY - amplitude))
                            path.addLine(to: CGPoint(x: CGFloat(x), y: midY + amplitude))
                        }
                        // Inactive waveform color
                        context.stroke(path, with: .color(Color(hex: "9CA3AF").opacity(0.65)), lineWidth: 1)

                        // Calculate sample region position within view
                        let regionStartX = ((sampleStart - viewStart) / viewDuration) * width
                        let regionEndX = ((sampleEnd - viewStart) / viewDuration) * width

                        // Draw region overlay
                        let regionRect = CGRect(
                            x: max(0, regionStartX),
                            y: 0,
                            width: min(width, regionEndX) - max(0, regionStartX),
                            height: height
                        )
                        context.fill(Path(regionRect), with: .color(accentColor.opacity(0.15)))

                        // Draw highlighted waveform in region
                        var regionPath = Path()
                        for x in Int(max(0, regionStartX))..<Int(min(width, regionEndX)) {
                            let sampleIndex = startSample + Int(Double(x) / width * Double(visibleSamples))
                            guard sampleIndex < waveformData.count else { continue }
                            let sample = waveformData[sampleIndex]
                            let amplitude = CGFloat(sample) * (height / 2) * 0.85
                            regionPath.move(to: CGPoint(x: CGFloat(x), y: midY - amplitude))
                            regionPath.addLine(to: CGPoint(x: CGFloat(x), y: midY + amplitude))
                        }
                        context.stroke(regionPath, with: .color(accentColor), lineWidth: 1)

                        // Draw region boundaries
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

                    // Time labels
                    VStack {
                        Spacer()
                        HStack {
                            Text(String(format: "%.2fs", sampleStart))
                                .font(.system(size: LoSuite.Typography.caption2, design: .monospaced))
                                .foregroundColor(accentColor)
                                .padding(.leading, LoSuite.Spacing.sm)

                            Spacer()

                            // Duration in center
                            Text(String(format: "%.3fs", sampleEnd - sampleStart))
                                .font(.system(size: LoSuite.Typography.caption, weight: .medium, design: .monospaced))
                                .foregroundColor(LoSuite.Colors.textPrimary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
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
            await MainActor.run {
                waveformData = data
                totalDuration = duration
                isLoading = false
            }
        }
    }

    private func generateWaveformData(from url: URL, sampleCount: Int) async -> ([Float], TimeInterval) {
        do {
            let audioFile = try AVAudioFile(forReading: url)
            let format = audioFile.processingFormat
            let frameCount = AVAudioFrameCount(audioFile.length)
            let sampleRate = format.sampleRate
            let duration = Double(frameCount) / sampleRate

            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                return ([], duration)
            }
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
        } catch {
            return ([], 0)
        }
    }
}

// MARK: - Results View

struct ResultsView: View {
    @Binding var samples: [ExtractedSample]
    var onExport: ([ExtractedSample]) -> Void
    var onExportAll: () -> Void
    var onOpenInLoOptimizer: () -> Void

    @State private var selectedSamples: Set<UUID> = []
    @State private var expandedStems: Set<StemType> = Set(StemType.allCases)
    @State private var editingSampleID: UUID? = nil
    @State private var nudgeGrid: NudgeGrid = .eighth

    // Get the currently editing sample
    private var editingSample: ExtractedSample? {
        guard let id = editingSampleID else { return samples.first }
        return samples.first { $0.id == id }
    }

    private var editingSampleBinding: Binding<ExtractedSample>? {
        guard let id = editingSampleID,
              let index = samples.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        return $samples[index]
    }

    var body: some View {
        VStack(spacing: 0) {
            // TOP: Large Waveform Area
            VStack(spacing: 0) {
                // Waveform header
                HStack {
                    if let sample = editingSample {
                        Image(systemName: sample.category.icon)
                            .foregroundColor(sample.stemType.designColor)

                        Text(sample.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(LoSuite.Colors.textPrimary)

                        Text("•")
                            .foregroundColor(LoSuite.Colors.textSecondary)

                        Text(sample.stemType.displayName)
                            .font(.system(size: LoSuite.Typography.body))
                            .foregroundColor(LoSuite.Colors.textSecondary)

                        Text("•")
                            .foregroundColor(LoSuite.Colors.textSecondary)

                        Text("\(Int(sample.tempo)) BPM")
                            .font(.system(size: LoSuite.Typography.body, design: .monospaced))
                            .foregroundColor(LoSuite.Colors.textSecondary)
                    } else {
                        Text("Select a sample to view waveform")
                            .font(.system(size: LoSuite.Typography.body))
                            .foregroundColor(LoSuite.Colors.textSecondary)
                    }

                    Spacer()

                    // Playback mode toggle
                    Picker("Mode", selection: Binding(
                        get: { AudioPreviewPlayer.shared.playbackMode },
                        set: { AudioPreviewPlayer.shared.setMode($0) }
                    )) {
                        ForEach(PlaybackMode.allCases, id: \.self) { mode in
                            Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)

                    // Play button
                    if let sample = editingSample {
                        Button {
                            AudioPreviewPlayer.shared.togglePlay(sample: sample)
                        } label: {
                            Image(systemName: AudioPreviewPlayer.shared.isPlaying(sample: sample) ? "stop.fill" : "play.fill")
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(sample.stemType.designColor)
                        .controlSize(.small)
                    }

                    // Grid picker for nudge
                    if editingSampleID != nil {
                        Picker("Grid", selection: $nudgeGrid) {
                            ForEach(NudgeGrid.allCases, id: \.self) { grid in
                                Text(grid.displayName).tag(grid)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 160)
                    }
                }
                .padding(.horizontal, LoSuite.Spacing.md)
                .padding(.vertical, LoSuite.Spacing.sm)

                // Large waveform display - zoomed to sample region with context
                if let sample = editingSample {
                    // Calculate zoom window: show sample with ~20% padding on each side
                    let sampleDuration = sample.effectiveEndTime - sample.effectiveStartTime
                    let padding = max(sampleDuration * 0.25, 0.5) // At least 0.5s padding
                    let viewStart = max(0, sample.effectiveStartTime - padding)
                    let viewEnd = sample.effectiveEndTime + padding

                    ZoomedWaveformView(
                        audioURL: sample.audioURL,
                        sampleStart: sample.effectiveStartTime,
                        sampleEnd: sample.effectiveEndTime,
                        viewStart: viewStart,
                        viewEnd: viewEnd,
                        accentColor: sample.stemType.designColor,
                        height: 180
                    )
                    .padding(.horizontal, LoSuite.Spacing.md)
                    .padding(.bottom, LoSuite.Spacing.sm)
                } else {
                    // Placeholder waveform
                    RoundedRectangle(cornerRadius: LoSuite.Radius.medium)
                        .fill(LoSuite.Colors.panelSurface)
                        .frame(height: 180)
                        .overlay(
                            Text("Drop audio or select a sample")
                                .foregroundColor(LoSuite.Colors.textSecondary)
                        )
                        .padding(.horizontal, LoSuite.Spacing.md)
                        .padding(.bottom, LoSuite.Spacing.sm)
                }

                // Nudge controls (when editing)
                if let binding = editingSampleBinding {
                    let isLoop = binding.wrappedValue.category == .loop
                    let tempo = binding.wrappedValue.tempo
                    let secondsPerBeat = 60.0 / tempo
                    let secondsPerBar = secondsPerBeat * 4

                    HStack(spacing: LoSuite.Spacing.lg) {
                        // Rotary knob for fine adjustment
                        RotaryKnob(
                            value: binding.nudgeOffset,
                            range: -30...30,
                            step: binding.wrappedValue.nudgeStepSize(for: nudgeGrid),
                            sensitivity: 0.3,
                            label: "Nudge",
                            valueFormatter: { String(format: "%+.3fs", $0) },
                            accentColor: binding.wrappedValue.stemType.designColor,
                            onChange: { AudioPreviewPlayer.shared.play(sample: binding.wrappedValue) }
                        )

                        // Start time +/- buttons
                        VStack(alignment: .leading, spacing: LoSuite.Spacing.xs) {
                            Text("Start Offset")
                                .font(.system(size: LoSuite.Typography.caption))
                                .foregroundColor(LoSuite.Colors.textSecondary)

                            HStack(spacing: LoSuite.Spacing.sm) {
                                Button {
                                    binding.wrappedValue.nudgeOffset -= binding.wrappedValue.nudgeStepSize(for: nudgeGrid)
                                    AudioPreviewPlayer.shared.play(sample: binding.wrappedValue)
                                } label: {
                                    Image(systemName: "minus")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                Text(String(format: "%+.3fs", binding.wrappedValue.nudgeOffset))
                                    .font(.system(size: LoSuite.Typography.body, weight: .medium, design: .monospaced))
                                    .foregroundColor(LoSuite.Colors.textPrimary)
                                    .frame(width: 80)

                                Button {
                                    binding.wrappedValue.nudgeOffset += binding.wrappedValue.nudgeStepSize(for: nudgeGrid)
                                    AudioPreviewPlayer.shared.play(sample: binding.wrappedValue)
                                } label: {
                                    Image(systemName: "plus")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                if binding.wrappedValue.nudgeOffset != 0 {
                                    Button("Reset") {
                                        binding.wrappedValue.nudgeOffset = 0
                                        AudioPreviewPlayer.shared.play(sample: binding.wrappedValue)
                                    }
                                    .font(.system(size: LoSuite.Typography.caption))
                                    .foregroundColor(LoSuite.Colors.accent)
                                }
                            }
                        }

                        Spacer()

                        // Loop Length selector (only for loops)
                        if isLoop {
                            VStack(alignment: .leading, spacing: LoSuite.Spacing.xs) {
                                Text("Loop Length")
                                    .font(.system(size: LoSuite.Typography.caption))
                                    .foregroundColor(LoSuite.Colors.textSecondary)

                                HStack(spacing: 4) {
                                    // Beat-based lengths (fractions of a bar)
                                    ForEach([(1, "1 beat"), (2, "2 beats"), (4, "1 bar")], id: \.0) { beats, label in
                                        let isSelected = abs(binding.wrappedValue.duration - Double(beats) * secondsPerBeat) < 0.01
                                        Button {
                                            let newDuration = Double(beats) * secondsPerBeat
                                            binding.wrappedValue.duration = newDuration
                                            binding.wrappedValue.barLength = beats == 4 ? 1 : nil
                                            binding.wrappedValue.endTime = binding.wrappedValue.startTime + newDuration
                                            AudioPreviewPlayer.shared.play(sample: binding.wrappedValue)
                                        } label: {
                                            Text(label)
                                                .font(.system(size: LoSuite.Typography.caption2, weight: .medium))
                                                .frame(height: 28)
                                                .padding(.horizontal, 6)
                                        }
                                        .buttonStyle(.plain)
                                        .background(isSelected ? binding.wrappedValue.stemType.designColor : LoSuite.Colors.elevatedSurface)
                                        .foregroundColor(isSelected ? .white : LoSuite.Colors.textPrimary)
                                        .cornerRadius(LoSuite.Radius.small)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: LoSuite.Radius.small)
                                                .stroke(isSelected ? binding.wrappedValue.stemType.designColor : LoSuite.Colors.bordersDividers, lineWidth: 1)
                                        )
                                    }

                                    Rectangle()
                                        .fill(LoSuite.Colors.bordersDividers)
                                        .frame(width: 1, height: 20)

                                    // Bar-based lengths
                                    ForEach([2, 4, 8], id: \.self) { bars in
                                        Button {
                                            let newDuration = Double(bars) * secondsPerBar
                                            binding.wrappedValue.duration = newDuration
                                            binding.wrappedValue.barLength = bars
                                            binding.wrappedValue.endTime = binding.wrappedValue.startTime + newDuration
                                            AudioPreviewPlayer.shared.play(sample: binding.wrappedValue)
                                        } label: {
                                            Text("\(bars) bars")
                                                .font(.system(size: LoSuite.Typography.caption2, weight: .medium))
                                                .frame(height: 28)
                                                .padding(.horizontal, 6)
                                        }
                                        .buttonStyle(.plain)
                                        .background(
                                            binding.wrappedValue.barLength == bars
                                                ? binding.wrappedValue.stemType.designColor
                                                : LoSuite.Colors.elevatedSurface
                                        )
                                        .foregroundColor(
                                            binding.wrappedValue.barLength == bars
                                                ? .white
                                                : LoSuite.Colors.textPrimary
                                        )
                                        .cornerRadius(LoSuite.Radius.small)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: LoSuite.Radius.small)
                                                .stroke(
                                                    binding.wrappedValue.barLength == bars
                                                        ? binding.wrappedValue.stemType.designColor
                                                        : LoSuite.Colors.bordersDividers,
                                                    lineWidth: 1
                                                )
                                        )
                                    }
                                }
                            }
                        }

                        // Duration info (read-only for loops, editable for hits)
                        VStack(alignment: .leading, spacing: LoSuite.Spacing.xs) {
                            Text("Duration")
                                .font(.system(size: LoSuite.Typography.caption))
                                .foregroundColor(LoSuite.Colors.textSecondary)

                            HStack(spacing: LoSuite.Spacing.sm) {
                                Text(binding.wrappedValue.durationString)
                                    .font(.system(size: LoSuite.Typography.body, weight: .medium, design: .monospaced))
                                    .foregroundColor(LoSuite.Colors.textPrimary)

                                if let bars = binding.wrappedValue.barLength {
                                    Text("(\(bars) \(bars == 1 ? "bar" : "bars"))")
                                        .font(.system(size: LoSuite.Typography.caption))
                                        .foregroundColor(LoSuite.Colors.textSecondary)
                                }
                            }
                        }

                        // Duplicate button
                        Button {
                            let newSample = binding.wrappedValue.duplicate()
                            samples.append(newSample)
                            selectedSamples.insert(newSample.id)
                            editingSampleID = newSample.id
                        } label: {
                            Label("Duplicate", systemImage: "plus.square.on.square")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.horizontal, LoSuite.Spacing.md)
                    .padding(.bottom, LoSuite.Spacing.md)
                }
            }
            .background(LoSuite.Colors.elevatedSurface)

            // Audition Keyboard (for one-shots)
            let hasHits = samples.contains { $0.category == .hit }
            if hasHits {
                SampleKeyboardView(samples: samples)
                    .padding(.horizontal, LoSuite.Spacing.md)
                    .padding(.vertical, LoSuite.Spacing.sm)
            }

            // Divider
            Rectangle()
                .fill(LoSuite.Colors.bordersDividers)
                .frame(height: 1)

            // BOTTOM: Sample Cards Grid
            ScrollView {
                VStack(spacing: LoSuite.Spacing.md) {
                    ForEach(StemType.allCases, id: \.self) { stemType in
                        let stemSamples = samples.filter { $0.stemType == stemType }
                        if !stemSamples.isEmpty {
                            StemSection(
                                stemType: stemType,
                                samples: stemSamples,
                                isExpanded: expandedStems.contains(stemType),
                                selectedSamples: $selectedSamples,
                                editingSampleID: $editingSampleID,
                                onToggleExpand: {
                                    if expandedStems.contains(stemType) {
                                        expandedStems.remove(stemType)
                                    } else {
                                        expandedStems.insert(stemType)
                                    }
                                }
                            )
                        }
                    }
                }
                .padding(LoSuite.Spacing.md)
            }
            .background(LoSuite.Colors.backgroundPrimary)

            // Divider
            Rectangle()
                .fill(LoSuite.Colors.bordersDividers)
                .frame(height: 1)

            // Export bar
            HStack {
                Text("\(selectedSamples.count) of \(samples.count) selected")
                    .font(.system(size: LoSuite.Typography.body))
                    .foregroundColor(LoSuite.Colors.textSecondary)

                Spacer()

                Button("Open in LoOptimizer") {
                    onOpenInLoOptimizer()
                }
                .disabled(selectedSamples.isEmpty)

                Button("Export Selected") {
                    let selected = samples.filter { selectedSamples.contains($0.id) }
                    onExport(selected)
                }
                .disabled(selectedSamples.isEmpty)

                Button("Export All") {
                    onExportAll()
                }
                .buttonStyle(.borderedProminent)
                .tint(LoSuite.Colors.accent)
            }
            .padding(LoSuite.Spacing.md)
            .background(LoSuite.Colors.panelSurface)
        }
        .onAppear {
            // Select all by default
            selectedSamples = Set(samples.map { $0.id })
            // Auto-select first sample for waveform display
            if editingSampleID == nil, let first = samples.first {
                editingSampleID = first.id
            }
        }
    }
}

// MARK: - Stem Section

struct StemSection: View {
    let stemType: StemType
    let samples: [ExtractedSample]
    let isExpanded: Bool
    @Binding var selectedSamples: Set<UUID>
    @Binding var editingSampleID: UUID?
    var onToggleExpand: () -> Void

    private var allSelected: Bool {
        samples.allSatisfy { selectedSamples.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LoSuite.Spacing.sm) {
            // Header
            HStack {
                Button {
                    onToggleExpand()
                } label: {
                    HStack {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .frame(width: 16)
                            .foregroundColor(LoSuite.Colors.textSecondary)

                        Image(systemName: stemType.icon)
                            .foregroundColor(stemColor)

                        Text(stemType.displayName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(LoSuite.Colors.textPrimary)

                        Text("(\(samples.count))")
                            .foregroundColor(LoSuite.Colors.textSecondary)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Button(allSelected ? "Deselect All" : "Select All") {
                    if allSelected {
                        for sample in samples {
                            selectedSamples.remove(sample.id)
                        }
                    } else {
                        for sample in samples {
                            selectedSamples.insert(sample.id)
                        }
                    }
                }
                .font(.system(size: LoSuite.Typography.caption))
                .foregroundColor(LoSuite.Colors.accent)
            }

            // Samples grid (160x110 per spec)
            if isExpanded {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 160, maximum: 180), spacing: 12)
                ], spacing: 12) {
                    ForEach(samples) { sample in
                        SampleCard(
                            sample: sample,
                            isSelected: selectedSamples.contains(sample.id),
                            isEditing: editingSampleID == sample.id,
                            stemColor: stemColor,
                            onToggleSelect: {
                                if selectedSamples.contains(sample.id) {
                                    selectedSamples.remove(sample.id)
                                } else {
                                    selectedSamples.insert(sample.id)
                                }
                            },
                            onEdit: {
                                editingSampleID = sample.id
                            }
                        )
                    }
                }
                .padding(.leading, LoSuite.Spacing.lg)
            }
        }
        .padding(LoSuite.Spacing.md)
        .background(LoSuite.Colors.panelSurface)
        .cornerRadius(LoSuite.Radius.xl)
        .overlay(
            RoundedRectangle(cornerRadius: LoSuite.Radius.xl)
                .stroke(LoSuite.Colors.bordersDividers, lineWidth: 1)
        )
    }

    private var stemColor: Color {
        switch stemType {
        case .drums: return Color(hex: "FF9500")
        case .bass: return Color(hex: "AF52DE")
        case .vocals: return Color(hex: "30D158")
        case .other: return Color(hex: "0A84FF")
        }
    }
}

// MARK: - Sample Card (Lo Suite Asset Tile Design)

struct SampleCard: View {
    let sample: ExtractedSample
    let isSelected: Bool
    let isEditing: Bool
    let stemColor: Color
    var onToggleSelect: () -> Void
    var onEdit: () -> Void

    @State private var isHovering = false
    var player: AudioPreviewPlayer { AudioPreviewPlayer.shared }

    var body: some View {
        VStack(alignment: .leading, spacing: LoSuite.Spacing.sm) {
            // Header row
            HStack {
                Image(systemName: sample.category.icon)
                    .foregroundColor(stemColor)

                Text(sample.name)
                    .font(.system(size: LoSuite.Typography.body, weight: .medium))
                    .foregroundColor(LoSuite.Colors.textPrimary)
                    .lineLimit(1)

                Spacer()

                // Edit button
                Button {
                    onEdit()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: LoSuite.Typography.caption))
                        .foregroundColor(LoSuite.Colors.textSecondary)
                }
                .buttonStyle(.plain)
                .opacity(isHovering || isEditing ? 1 : 0.4)

                // Play button
                Button {
                    if player.isPlaying(sample: sample) {
                        player.stop()
                    } else {
                        player.play(sample: sample)
                    }
                } label: {
                    Image(systemName: player.isPlaying(sample: sample) ? "stop.fill" : "play.fill")
                        .font(.system(size: LoSuite.Typography.caption))
                        .foregroundColor(LoSuite.Colors.textPrimary)
                }
                .buttonStyle(.plain)
            }

            // Metadata row
            HStack {
                Text(sample.category.rawValue)
                    .font(.system(size: LoSuite.Typography.caption2))
                    .foregroundColor(LoSuite.Colors.textPrimary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(stemColor.opacity(0.2))
                    .cornerRadius(LoSuite.Radius.small)

                if let barDesc = sample.barDescription {
                    Text(barDesc)
                        .font(.system(size: LoSuite.Typography.caption2))
                        .foregroundColor(LoSuite.Colors.textSecondary)
                }

                Spacer()

                Text(sample.durationString)
                    .font(.system(size: LoSuite.Typography.caption2, design: .monospaced))
                    .foregroundColor(LoSuite.Colors.textSecondary)
            }

            // Position indicator (shows nudge offset if any)
            if sample.nudgeOffset != 0 {
                Text("Start: \(sample.positionString(for: sample.effectiveStartTime))")
                    .font(.system(size: LoSuite.Typography.caption2, design: .monospaced))
                    .foregroundColor(LoSuite.Colors.accent)
            }
        }
        .padding(LoSuite.Spacing.md)
        .frame(height: 110)  // Per spec: 160x110 tiles
        .background(isEditing ? LoSuite.Colors.elevatedSurface : (isSelected ? LoSuite.Colors.elevatedSurface : LoSuite.Colors.panelSurface))
        .overlay(
            RoundedRectangle(cornerRadius: LoSuite.Radius.medium)
                .stroke(
                    isEditing ? stemColor :
                    (isSelected ? stemColor : LoSuite.Colors.bordersDividers),
                    lineWidth: isEditing ? 2 : 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: LoSuite.Radius.medium))
        .shadow(color: isHovering ? Color.black.opacity(0.15) : Color.clear, radius: 4, y: 2)
        .offset(y: isHovering ? -1 : 0)  // Subtle lift on hover per spec
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .onTapGesture {
            // Toggle playback on tap
            player.togglePlay(sample: sample)
            onToggleSelect()
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private var confidenceColor: Color {
        if sample.confidence > 0.8 {
            return Color(hex: "30D158")
        } else if sample.confidence > 0.6 {
            return Color(hex: "FFD60A")
        } else {
            return Color(hex: "FF9500")
        }
    }
}

// MARK: - Sample Detail Panel (Lo Suite Design)

struct SampleDetailPanel: View {
    @Binding var sample: ExtractedSample
    @Binding var nudgeGrid: NudgeGrid
    var onDuplicate: () -> Void
    var onClose: () -> Void

    var player: AudioPreviewPlayer { AudioPreviewPlayer.shared }

    // For end time adjustment (hits only)
    @State private var endTimeOffset: TimeInterval = 0

    private var stepSize: TimeInterval {
        sample.nudgeStepSize(for: nudgeGrid)
    }

    private var stemColor: Color {
        switch sample.stemType {
        case .drums: return Color(hex: "FF9500")
        case .bass: return Color(hex: "AF52DE")
        case .vocals: return Color(hex: "30D158")
        case .other: return Color(hex: "0A84FF")
        }
    }

    private var isHit: Bool {
        sample.category == .hit
    }

    private var audioDuration: TimeInterval {
        sample.effectiveEndTime + 30
    }

    var body: some View {
        VStack(spacing: 0) {
            // Large waveform at top
            VStack(spacing: 0) {
                // Compact header over waveform
                HStack {
                    Image(systemName: sample.category.icon)
                        .foregroundColor(stemColor)

                    Text(sample.name)
                        .font(.system(size: LoSuite.Typography.body, weight: .medium))
                        .foregroundColor(LoSuite.Colors.textPrimary)

                    Text("•")
                        .foregroundColor(LoSuite.Colors.textSecondary)

                    Text("\(sample.stemType.displayName)")
                        .font(.system(size: LoSuite.Typography.caption))
                        .foregroundColor(LoSuite.Colors.textSecondary)

                    Spacer()

                    // Play button
                    Button {
                        playPreview()
                    } label: {
                        Image(systemName: player.isPlaying(sample: sample) ? "stop.fill" : "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(stemColor)
                    .controlSize(.small)

                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(LoSuite.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, LoSuite.Spacing.md)
                .padding(.vertical, LoSuite.Spacing.sm)

                // Large waveform
                WaveformView(
                    audioURL: sample.audioURL,
                    startTime: sample.effectiveStartTime,
                    endTime: sample.effectiveEndTime,
                    totalDuration: audioDuration,
                    accentColor: stemColor,
                    height: 140
                )
                .padding(.horizontal, LoSuite.Spacing.sm)
                .padding(.bottom, LoSuite.Spacing.sm)
            }
            .background(LoSuite.Colors.elevatedSurface)

            // Controls below waveform
            ScrollView {
                VStack(alignment: .leading, spacing: LoSuite.Spacing.md) {
                    // Grid resolution picker
                    VStack(alignment: .leading, spacing: LoSuite.Spacing.sm) {
                        Text("Grid")
                            .font(.system(size: LoSuite.Typography.caption, weight: .medium))
                            .foregroundColor(LoSuite.Colors.textSecondary)

                        HStack(spacing: 6) {
                            ForEach(NudgeGrid.allCases, id: \.self) { grid in
                                Button {
                                    nudgeGrid = grid
                                } label: {
                                    Text(grid.displayName)
                                        .font(.system(size: LoSuite.Typography.caption))
                                        .padding(.horizontal, LoSuite.Spacing.sm)
                                        .padding(.vertical, 5)
                                }
                                .buttonStyle(.plain)
                                .background(nudgeGrid == grid ? stemColor : LoSuite.Colors.elevatedSurface)
                                .foregroundColor(nudgeGrid == grid ? .white : LoSuite.Colors.textPrimary)
                                .cornerRadius(LoSuite.Radius.small)
                                .overlay(
                                    RoundedRectangle(cornerRadius: LoSuite.Radius.small)
                                        .stroke(nudgeGrid == grid ? stemColor : LoSuite.Colors.bordersDividers, lineWidth: 1)
                                )
                            }

                            Spacer()

                            Text("\(Int(sample.tempo)) BPM")
                                .font(.system(size: LoSuite.Typography.caption, design: .monospaced))
                                .foregroundColor(LoSuite.Colors.textSecondary)
                        }
                    }

                    // Knob and time controls
                    HStack(alignment: .top, spacing: LoSuite.Spacing.lg) {
                        // Rotary knob for start time nudge
                        VStack(spacing: LoSuite.Spacing.xs) {
                            RotaryKnob(
                                value: $sample.nudgeOffset,
                                range: -30...30,
                                step: stepSize,
                                sensitivity: 0.3,
                                label: "Start",
                                valueFormatter: { String(format: "%+.3fs", $0) },
                                accentColor: stemColor,
                                onChange: { playPreview() }
                            )

                            // Reset button
                            Button {
                                sample.nudgeOffset = 0
                                playPreview()
                            } label: {
                                Text("Reset")
                                    .font(.system(size: LoSuite.Typography.caption2))
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(LoSuite.Colors.textSecondary)
                            .opacity(sample.nudgeOffset != 0 ? 1 : 0.3)
                            .disabled(sample.nudgeOffset == 0)
                        }

                        // Time info
                        VStack(alignment: .leading, spacing: LoSuite.Spacing.md) {
                            // Start time
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Start Time")
                                    .font(.system(size: LoSuite.Typography.caption2, weight: .medium))
                                    .foregroundColor(LoSuite.Colors.textSecondary)

                                HStack {
                                    Text(sample.positionString(for: sample.effectiveStartTime))
                                        .font(.system(size: 17, weight: .medium, design: .monospaced))
                                        .foregroundColor(LoSuite.Colors.textPrimary)

                                    DraggableValue(
                                        value: $sample.nudgeOffset,
                                        range: -30...30,
                                        step: stepSize,
                                        sensitivity: 0.5,
                                        formatter: { String(format: "%+.3f", $0) },
                                        suffix: "s",
                                        accentColor: stemColor,
                                        onChange: { playPreview() }
                                    )
                                }
                            }

                            // End time (for hits, allow adjustment)
                            if isHit {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Duration")
                                        .font(.system(size: LoSuite.Typography.caption2, weight: .medium))
                                        .foregroundColor(LoSuite.Colors.textSecondary)

                                    DraggableValue(
                                        value: Binding(
                                            get: { sample.duration },
                                            set: { newDuration in
                                                sample.duration = max(0.01, newDuration)
                                                sample.endTime = sample.startTime + sample.duration
                                            }
                                        ),
                                        range: 0.01...2.0,
                                        step: 0.01,
                                        sensitivity: 0.3,
                                        formatter: { String(format: "%.3f", $0) },
                                        suffix: "s",
                                        accentColor: stemColor,
                                        onChange: { playPreview() }
                                    )
                                }
                            } else {
                                // For loops, show duration as read-only
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Duration")
                                        .font(.system(size: LoSuite.Typography.caption2, weight: .medium))
                                        .foregroundColor(LoSuite.Colors.textSecondary)

                                    HStack(spacing: 4) {
                                        Text(sample.durationString)
                                            .font(.system(size: LoSuite.Typography.body, design: .monospaced))
                                            .foregroundColor(LoSuite.Colors.textPrimary)
                                            .monospacedDigit()

                                        if let bars = sample.barLength {
                                            Text("(\(bars) \(bars == 1 ? "bar" : "bars"))")
                                                .font(.system(size: LoSuite.Typography.caption))
                                                .foregroundColor(LoSuite.Colors.textSecondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(LoSuite.Spacing.md)
                    .background(LoSuite.Colors.panelSurface)
                    .cornerRadius(LoSuite.Radius.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: LoSuite.Radius.medium)
                            .stroke(LoSuite.Colors.bordersDividers, lineWidth: 1)
                    )

                    // Divider
                    Rectangle()
                        .fill(LoSuite.Colors.bordersDividers)
                        .frame(height: 1)

                    // Action buttons
                    HStack(spacing: LoSuite.Spacing.md) {
                        // Reset to default button
                        Button {
                            resetToDefault()
                        } label: {
                            Label("Reset", systemImage: "arrow.counterclockwise")
                        }
                        .buttonStyle(.bordered)
                        .disabled(!hasChanges)

                        // Duplicate button
                        Button {
                            onDuplicate()
                        } label: {
                            Label("Duplicate", systemImage: "plus.square.on.square")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(stemColor)

                        Spacer()
                    }

                    // Info footer
                    VStack(alignment: .leading, spacing: LoSuite.Spacing.xs) {
                        Text("Confidence: \(sample.confidencePercent)%")
                        if sample.nudgeOffset != 0 {
                            Text("Original start: \(String(format: "%.2f", sample.startTime))s")
                        }
                    }
                    .font(.system(size: LoSuite.Typography.caption2, design: .monospaced))
                    .foregroundColor(LoSuite.Colors.textSecondary)
                }
                .padding(LoSuite.Spacing.md)
            }
        }
        .background(LoSuite.Colors.backgroundPrimary)
    }

    private var hasChanges: Bool {
        sample.nudgeOffset != 0
    }

    private func resetToDefault() {
        sample.nudgeOffset = 0
        // Reset duration to original (calculated from original end - start)
        let originalDuration = sample.endTime - sample.startTime
        if originalDuration > 0 {
            sample.duration = originalDuration
        }
        playPreview()
    }

    private func playPreview() {
        player.play(sample: sample)
    }
}

// MARK: - Virtual MIDI Keyboard

struct MiniKeyboard: View {
    let samples: [ExtractedSample]
    let stemType: StemType
    @State private var activeKey: Int? = nil

    // Filter to just hits for this stem
    private var hitSamples: [ExtractedSample] {
        samples.filter { $0.stemType == stemType && $0.category == .hit }
            .prefix(12)
            .map { $0 }
    }

    // Key layout: white keys only for simplicity (C D E F G A B C D E F G)
    private let keyCount = 12

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<keyCount, id: \.self) { index in
                let hasSample = index < hitSamples.count
                let sample = hasSample ? hitSamples[index] : nil

                Button {
                    if let s = sample {
                        activeKey = index
                        AudioPreviewPlayer.shared.play(sample: s)
                        // Reset active key after short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            if activeKey == index { activeKey = nil }
                        }
                    }
                } label: {
                    VStack(spacing: 2) {
                        Text(keyLabel(index))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(activeKey == index ? .white : LoSuite.Colors.textSecondary)

                        if hasSample {
                            Circle()
                                .fill(stemType.designColor)
                                .frame(width: 6, height: 6)
                        }
                    }
                    .frame(width: 28, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(activeKey == index ? stemType.designColor : (hasSample ? LoSuite.Colors.elevatedSurface : LoSuite.Colors.panelSurface))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(hasSample ? stemType.designColor.opacity(0.5) : LoSuite.Colors.bordersDividers, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!hasSample)
            }
        }
    }

    private func keyLabel(_ index: Int) -> String {
        let keys = ["C", "D", "E", "F", "G", "A", "B", "C", "D", "E", "F", "G"]
        return keys[index % keys.count]
    }
}

struct SampleKeyboardView: View {
    let samples: [ExtractedSample]

    var body: some View {
        VStack(alignment: .leading, spacing: LoSuite.Spacing.sm) {
            Text("AUDITION KEYBOARD")
                .font(.system(size: LoSuite.Typography.caption2, weight: .semibold))
                .foregroundColor(LoSuite.Colors.textSecondary)

            HStack(spacing: LoSuite.Spacing.lg) {
                ForEach(StemType.allCases, id: \.self) { stemType in
                    let stemSamples = samples.filter { $0.stemType == stemType }
                    let hitCount = stemSamples.filter { $0.category == .hit }.count

                    if hitCount > 0 {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: stemType.icon)
                                    .font(.system(size: 10))
                                    .foregroundColor(stemType.designColor)
                                Text(stemType.shortName)
                                    .font(.system(size: LoSuite.Typography.caption2, weight: .medium))
                                    .foregroundColor(LoSuite.Colors.textSecondary)
                            }
                            MiniKeyboard(samples: samples, stemType: stemType)
                        }
                    }
                }
            }
        }
        .padding(LoSuite.Spacing.md)
        .background(LoSuite.Colors.panelSurface)
        .cornerRadius(LoSuite.Radius.medium)
    }
}

struct ResultsView_Previews: PreviewProvider {
    @State static var samples = [
        ExtractedSample(name: "Main Loop", category: .loop, stemType: .drums, duration: 2.0, barLength: 2, confidence: 0.95),
        ExtractedSample(name: "Fill 1", category: .fill, stemType: .drums, duration: 0.5, barLength: nil, confidence: 0.82),
        ExtractedSample(name: "Kick", category: .hit, stemType: .drums, duration: 0.1, barLength: nil, confidence: 0.98),
    ]

    static var previews: some View {
        ResultsView(
            samples: $samples,
            onExport: { _ in },
            onExportAll: { },
            onOpenInLoOptimizer: { }
        )
    }
}

