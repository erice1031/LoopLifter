//
//  ResultsView.swift
//  LoopLifter
//
//  Displays extracted samples organized by stem type
//

import SwiftUI

struct ResultsView: View {
    @Binding var samples: [ExtractedSample]
    var onExport: ([ExtractedSample]) -> Void
    var onExportAll: () -> Void
    var onOpenInLoOptimizer: () -> Void

    @State private var selectedSamples: Set<UUID> = []
    @State private var expandedStems: Set<StemType> = Set(StemType.allCases)
    @State private var editingSampleID: UUID? = nil
    @State private var nudgeGrid: NudgeGrid = .eighth

    var body: some View {
        HSplitView {
            // Left: Results list
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
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
                    .padding()
                }

                Divider()

                // Export bar
                HStack {
                    Text("\(selectedSamples.count) of \(samples.count) selected")
                        .foregroundColor(.secondary)

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
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
            }

            // Right: Detail panel (when editing)
            if let editingID = editingSampleID,
               let sampleIndex = samples.firstIndex(where: { $0.id == editingID }) {
                SampleDetailPanel(
                    sample: $samples[sampleIndex],
                    nudgeGrid: $nudgeGrid,
                    onDuplicate: {
                        let newSample = samples[sampleIndex].duplicate()
                        samples.append(newSample)
                        selectedSamples.insert(newSample.id)
                        editingSampleID = newSample.id
                    },
                    onClose: {
                        editingSampleID = nil
                    }
                )
                .frame(minWidth: 280, maxWidth: 320)
            }
        }
        .onAppear {
            // Select all by default
            selectedSamples = Set(samples.map { $0.id })
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
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Button {
                    onToggleExpand()
                } label: {
                    HStack {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .frame(width: 16)

                        Image(systemName: stemType.icon)
                            .foregroundColor(stemColor)

                        Text(stemType.displayName)
                            .font(.headline)

                        Text("(\(samples.count))")
                            .foregroundColor(.secondary)
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
                .font(.caption)
            }

            // Samples grid
            if isExpanded {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 12)
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
                .padding(.leading, 24)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
    }

    private var stemColor: Color {
        switch stemType {
        case .drums: return .orange
        case .bass: return .purple
        case .vocals: return .green
        case .other: return .blue
        }
    }
}

// MARK: - Sample Card

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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: sample.category.icon)
                    .foregroundColor(stemColor)

                Text(sample.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer()

                // Edit button
                Button {
                    onEdit()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .opacity(isHovering || isEditing ? 1 : 0.3)

                // Play button
                Button {
                    if player.isPlaying(sample: sample) {
                        player.stop()
                    } else {
                        player.play(sample: sample)
                    }
                } label: {
                    Image(systemName: player.isPlaying(sample: sample) ? "stop.fill" : "play.fill")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }

            HStack {
                Text(sample.category.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(stemColor.opacity(0.2))
                    .cornerRadius(4)

                if let barDesc = sample.barDescription {
                    Text(barDesc)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(sample.durationString)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Position indicator (shows nudge offset if any)
            if sample.nudgeOffset != 0 {
                Text("Start: \(sample.positionString(for: sample.effectiveStartTime))")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
        .padding(12)
        .background(isEditing ? stemColor.opacity(0.25) : (isSelected ? stemColor.opacity(0.15) : Color(NSColor.controlBackgroundColor)))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isEditing ? stemColor : (isSelected ? stemColor.opacity(0.5) : Color.clear), lineWidth: isEditing ? 3 : 2)
        )
        .cornerRadius(8)
        .onTapGesture {
            onToggleSelect()
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private var confidenceColor: Color {
        if sample.confidence > 0.8 {
            return .green
        } else if sample.confidence > 0.6 {
            return .yellow
        } else {
            return .orange
        }
    }
}

// MARK: - Sample Detail Panel

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
        case .drums: return .orange
        case .bass: return .purple
        case .vocals: return .green
        case .other: return .blue
        }
    }

    private var isHit: Bool {
        sample.category == .hit
    }

    private var audioDuration: TimeInterval {
        // Estimate from audio file or use a reasonable default
        sample.effectiveEndTime + 30  // Allow nudging forward
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Image(systemName: sample.category.icon)
                        .foregroundColor(stemColor)
                        .font(.title2)

                    VStack(alignment: .leading) {
                        Text(sample.name)
                            .font(.headline)
                        Text("\(sample.stemType.displayName) \(sample.category.rawValue)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Play button
                    Button {
                        playPreview()
                    } label: {
                        Image(systemName: player.isPlaying(sample: sample) ? "stop.fill" : "play.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(stemColor)

                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                // Waveform view
                VStack(alignment: .leading, spacing: 4) {
                    Text("Waveform")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    WaveformView(
                        audioURL: sample.audioURL,
                        startTime: sample.effectiveStartTime,
                        endTime: sample.effectiveEndTime,
                        totalDuration: audioDuration,
                        accentColor: stemColor
                    )
                }

                Divider()

                // Grid resolution picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Grid")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 6) {
                        ForEach(NudgeGrid.allCases, id: \.self) { grid in
                            Button {
                                nudgeGrid = grid
                            } label: {
                                Text(grid.displayName)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                            }
                            .buttonStyle(.plain)
                            .background(nudgeGrid == grid ? stemColor : Color(NSColor.controlBackgroundColor))
                            .foregroundColor(nudgeGrid == grid ? .white : .primary)
                            .cornerRadius(4)
                        }

                        Spacer()

                        Text("\(Int(sample.tempo)) BPM")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Knob and time controls
                HStack(alignment: .top, spacing: 20) {
                    // Rotary knob for start time nudge
                    VStack(spacing: 4) {
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
                                .font(.caption2)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                        .opacity(sample.nudgeOffset != 0 ? 1 : 0.3)
                        .disabled(sample.nudgeOffset == 0)
                    }

                    // Time info
                    VStack(alignment: .leading, spacing: 12) {
                        // Start time
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Start Time")
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            HStack {
                                Text(sample.positionString(for: sample.effectiveStartTime))
                                    .font(.title2)
                                    .fontWeight(.medium)
                                    .monospacedDigit()

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
                                    .font(.caption2)
                                    .foregroundColor(.secondary)

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
                                    .font(.caption2)
                                    .foregroundColor(.secondary)

                                HStack(spacing: 4) {
                                    Text(sample.durationString)
                                        .font(.body)
                                        .monospacedDigit()

                                    if let bars = sample.barLength {
                                        Text("(\(bars) \(bars == 1 ? "bar" : "bars"))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)

                Divider()

                // Action buttons
                HStack(spacing: 12) {
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
                VStack(alignment: .leading, spacing: 4) {
                    Text("Confidence: \(sample.confidencePercent)%")
                    if sample.nudgeOffset != 0 {
                        Text("Original start: \(String(format: "%.2f", sample.startTime))s")
                    }
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            .padding()
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func playPreview() {
        player.play(sample: sample)
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

