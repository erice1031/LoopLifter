//
//  RotaryKnob.swift
//  LoopLifter
//
//  A rotary knob control for adjusting values with snap-to-grid support
//

import SwiftUI

struct RotaryKnob: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = -100...100
    var step: Double = 1.0
    var sensitivity: Double = 0.5  // How much drag = how much rotation
    var label: String = ""
    var valueFormatter: (Double) -> String = { String(format: "%.2f", $0) }
    var accentColor: Color = .orange
    var onChange: (() -> Void)? = nil

    @State private var isDragging = false
    @State private var lastDragValue: CGFloat = 0

    private var rotation: Angle {
        let normalized = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        let degrees = -135 + (normalized * 270)  // -135 to +135 range
        return .degrees(degrees)
    }

    var body: some View {
        VStack(spacing: 8) {
            // Knob
            ZStack {
                // Outer ring / track
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                    .frame(width: 80, height: 80)

                // Active arc
                Circle()
                    .trim(from: 0, to: CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)))
                    .stroke(accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-225))

                // Knob body
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.35), Color(white: 0.2)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 70, height: 70)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

                // Indicator line
                Rectangle()
                    .fill(accentColor)
                    .frame(width: 3, height: 20)
                    .offset(y: -20)
                    .rotationEffect(rotation)

                // Center cap
                Circle()
                    .fill(Color(white: 0.25))
                    .frame(width: 20, height: 20)
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

                        // Snap to step
                        let snapped = (newValue / step).rounded() * step
                        value = min(max(snapped, range.lowerBound), range.upperBound)

                        onChange?()
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )

            // Value display
            Text(valueFormatter(value))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(isDragging ? accentColor : .secondary)

            // Label
            if !label.isEmpty {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Draggable Value Text

struct DraggableValue: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1000
    var step: Double = 0.01
    var sensitivity: Double = 0.5
    var formatter: (Double) -> String = { String(format: "%.3f", $0) }
    var suffix: String = "s"
    var accentColor: Color = .orange
    var onChange: (() -> Void)? = nil

    @State private var isDragging = false
    @State private var lastDragValue: CGFloat = 0

    var body: some View {
        HStack(spacing: 2) {
            Text(formatter(value))
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
                .foregroundColor(isDragging ? accentColor : .primary)

            Text(suffix)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isDragging ? accentColor.opacity(0.15) : Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isDragging ? accentColor : Color.clear, lineWidth: 1)
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

                    // Snap to step
                    let snapped = (newValue / step).rounded() * step
                    value = min(max(snapped, range.lowerBound), range.upperBound)

                    onChange?()
                }
                .onEnded { _ in
                    isDragging = false
                }
        )
        .help("Drag up/down to adjust")
    }
}

#Preview {
    VStack(spacing: 40) {
        RotaryKnob(
            value: .constant(0),
            range: -10...10,
            step: 0.125,
            label: "Nudge",
            valueFormatter: { String(format: "%+.3fs", $0) }
        )

        DraggableValue(
            value: .constant(0.5),
            range: 0...10,
            step: 0.01,
            suffix: "s"
        )
    }
    .padding(40)
    .background(Color(NSColor.windowBackgroundColor))
}
