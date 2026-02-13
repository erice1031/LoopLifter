//
//  ResultsView.swift
//  LoopLifter
//
//  Displays extracted samples organized by stem type
//

import SwiftUI

struct ResultsView: View {
    let samples: [ExtractedSample]
    var onExport: ([ExtractedSample]) -> Void
    var onExportAll: () -> Void
    var onOpenInLoOptimizer: () -> Void

    @State private var selectedSamples: Set<UUID> = []
    @State private var expandedStems: Set<StemType> = Set(StemType.allCases)

    var body: some View {
        VStack(spacing: 0) {
            // Results list
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
                            stemColor: stemColor
                        ) {
                            if selectedSamples.contains(sample.id) {
                                selectedSamples.remove(sample.id)
                            } else {
                                selectedSamples.insert(sample.id)
                            }
                        }
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
    let stemColor: Color
    var onToggle: () -> Void

    @State private var isHovering = false
    @State private var isPlaying = false

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

                // Play button
                Button {
                    isPlaying.toggle()
                    // TODO: Implement preview playback
                } label: {
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
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

            // Confidence indicator
            HStack(spacing: 4) {
                Text("Confidence:")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                ProgressView(value: sample.confidence, total: 1.0)
                    .tint(confidenceColor)

                Text("\(sample.confidencePercent)%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(isSelected ? stemColor.opacity(0.15) : Color(NSColor.controlBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? stemColor : Color.clear, lineWidth: 2)
        )
        .cornerRadius(8)
        .onTapGesture {
            onToggle()
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

#Preview {
    ResultsView(
        samples: [
            ExtractedSample(name: "Main Loop", category: .loop, stemType: .drums, duration: 2.0, barLength: 2, confidence: 0.95),
            ExtractedSample(name: "Fill 1", category: .fill, stemType: .drums, duration: 0.5, barLength: nil, confidence: 0.82),
            ExtractedSample(name: "Kick", category: .hit, stemType: .drums, duration: 0.1, barLength: nil, confidence: 0.98),
        ],
        onExport: { _ in },
        onExportAll: { },
        onOpenInLoOptimizer: { }
    )
}
