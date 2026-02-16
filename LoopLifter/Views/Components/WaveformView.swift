//
//  WaveformView.swift
//  LoopLifter
//
//  Displays audio waveform with highlighted region for sample preview
//

import SwiftUI
import AVFoundation

struct WaveformView: View {
    let audioURL: URL?
    var startTime: TimeInterval
    var endTime: TimeInterval
    var totalDuration: TimeInterval
    var accentColor: Color = .orange

    @State private var waveformData: [Float] = []
    @State private var isLoading = true

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(NSColor.controlBackgroundColor))

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                } else if waveformData.isEmpty {
                    Text("No waveform")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    // Waveform
                    Canvas { context, size in
                        let width = size.width
                        let height = size.height
                        let midY = height / 2
                        let samplesPerPixel = max(1, waveformData.count / Int(width))

                        // Draw full waveform (dimmed)
                        var path = Path()
                        for x in 0..<Int(width) {
                            let sampleIndex = min(x * samplesPerPixel, waveformData.count - 1)
                            let sample = waveformData[sampleIndex]
                            let amplitude = CGFloat(sample) * (height / 2) * 0.9

                            path.move(to: CGPoint(x: CGFloat(x), y: midY - amplitude))
                            path.addLine(to: CGPoint(x: CGFloat(x), y: midY + amplitude))
                        }
                        context.stroke(path, with: .color(.gray.opacity(0.4)), lineWidth: 1)

                        // Calculate region position
                        let regionStartX = (startTime / totalDuration) * width
                        let regionEndX = (endTime / totalDuration) * width

                        // Draw highlighted region background
                        let regionRect = CGRect(
                            x: regionStartX,
                            y: 0,
                            width: regionEndX - regionStartX,
                            height: height
                        )
                        context.fill(
                            Path(regionRect),
                            with: .color(accentColor.opacity(0.2))
                        )

                        // Draw highlighted waveform in region
                        var regionPath = Path()
                        for x in Int(regionStartX)..<Int(regionEndX) {
                            let sampleIndex = min(x * samplesPerPixel, waveformData.count - 1)
                            let sample = waveformData[sampleIndex]
                            let amplitude = CGFloat(sample) * (height / 2) * 0.9

                            regionPath.move(to: CGPoint(x: CGFloat(x), y: midY - amplitude))
                            regionPath.addLine(to: CGPoint(x: CGFloat(x), y: midY + amplitude))
                        }
                        context.stroke(regionPath, with: .color(accentColor), lineWidth: 1)

                        // Draw region boundaries
                        let boundaryPath = Path { p in
                            p.move(to: CGPoint(x: regionStartX, y: 0))
                            p.addLine(to: CGPoint(x: regionStartX, y: height))
                            p.move(to: CGPoint(x: regionEndX, y: 0))
                            p.addLine(to: CGPoint(x: regionEndX, y: height))
                        }
                        context.stroke(boundaryPath, with: .color(accentColor), lineWidth: 2)
                    }
                }
            }
        }
        .frame(height: 60)
        .onAppear {
            loadWaveform()
        }
        .onChange(of: audioURL) { _, _ in
            loadWaveform()
        }
    }

    private func loadWaveform() {
        guard let url = audioURL else {
            isLoading = false
            return
        }

        isLoading = true

        Task {
            let data = await generateWaveformData(from: url, sampleCount: 500)
            await MainActor.run {
                waveformData = data
                isLoading = false
            }
        }
    }

    private func generateWaveformData(from url: URL, sampleCount: Int) async -> [Float] {
        do {
            let audioFile = try AVAudioFile(forReading: url)
            let format = audioFile.processingFormat
            let frameCount = AVAudioFrameCount(audioFile.length)

            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                return []
            }

            try audioFile.read(into: buffer)

            guard let channelData = buffer.floatChannelData else {
                return []
            }

            let framesPerSample = Int(frameCount) / sampleCount
            var peaks: [Float] = []

            for i in 0..<sampleCount {
                let startFrame = i * framesPerSample
                let endFrame = min(startFrame + framesPerSample, Int(frameCount))

                var maxSample: Float = 0
                for frame in startFrame..<endFrame {
                    let sample = abs(channelData[0][frame])
                    if sample > maxSample {
                        maxSample = sample
                    }
                }
                peaks.append(maxSample)
            }

            return peaks
        } catch {
            print("Error generating waveform: \(error)")
            return []
        }
    }
}

// MARK: - Mini Waveform for Cards

struct MiniWaveformView: View {
    let audioURL: URL?
    var accentColor: Color = .orange

    @State private var waveformData: [Float] = []

    var body: some View {
        Canvas { context, size in
            guard !waveformData.isEmpty else { return }

            let width = size.width
            let height = size.height
            let midY = height / 2
            let barWidth: CGFloat = 2
            let barSpacing: CGFloat = 1
            let barCount = Int(width / (barWidth + barSpacing))
            let samplesPerBar = max(1, waveformData.count / barCount)

            for i in 0..<barCount {
                let sampleIndex = min(i * samplesPerBar, waveformData.count - 1)
                let sample = waveformData[sampleIndex]
                let amplitude = CGFloat(sample) * (height / 2) * 0.85

                let x = CGFloat(i) * (barWidth + barSpacing)
                let rect = CGRect(
                    x: x,
                    y: midY - amplitude,
                    width: barWidth,
                    height: amplitude * 2
                )

                context.fill(
                    Path(roundedRect: rect, cornerRadius: 1),
                    with: .color(accentColor.opacity(0.7))
                )
            }
        }
        .frame(height: 24)
        .onAppear {
            loadWaveform()
        }
    }

    private func loadWaveform() {
        guard let url = audioURL else { return }

        Task {
            let data = await generateWaveformData(from: url, sampleCount: 100)
            await MainActor.run {
                waveformData = data
            }
        }
    }

    private func generateWaveformData(from url: URL, sampleCount: Int) async -> [Float] {
        do {
            let audioFile = try AVAudioFile(forReading: url)
            let format = audioFile.processingFormat
            let frameCount = AVAudioFrameCount(audioFile.length)

            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                return []
            }

            try audioFile.read(into: buffer)

            guard let channelData = buffer.floatChannelData else {
                return []
            }

            let framesPerSample = Int(frameCount) / sampleCount
            var peaks: [Float] = []

            for i in 0..<sampleCount {
                let startFrame = i * framesPerSample
                let endFrame = min(startFrame + framesPerSample, Int(frameCount))

                var maxSample: Float = 0
                for frame in startFrame..<endFrame {
                    let sample = abs(channelData[0][frame])
                    if sample > maxSample {
                        maxSample = sample
                    }
                }
                peaks.append(maxSample)
            }

            return peaks
        } catch {
            return []
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        WaveformView(
            audioURL: nil,
            startTime: 2.0,
            endTime: 5.0,
            totalDuration: 10.0
        )

        MiniWaveformView(audioURL: nil)
    }
    .padding()
    .frame(width: 300)
    .background(Color(NSColor.windowBackgroundColor))
}
