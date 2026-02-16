//
//  AudioPreviewPlayer.swift
//  LoopLifter
//
//  Audio player for sample preview using AVAudioEngine for precise seeking
//

import Foundation
import AVFoundation

/// Playback modes for sample preview
enum PlaybackMode: String, CaseIterable {
    case oneShot = "One-Shot"
    case loop = "Loop"

    var icon: String {
        switch self {
        case .oneShot: return "play.fill"
        case .loop: return "repeat"
        }
    }
}

/// Singleton audio player for previewing samples
@Observable
class AudioPreviewPlayer {
    static let shared = AudioPreviewPlayer()

    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var currentFile: AVAudioFile?
    private var currentBuffer: AVAudioPCMBuffer?
    private var playTimer: Timer?
    private var isEngineSetup = false

    var isPlaying: Bool = false
    var currentSampleID: UUID?
    var playbackMode: PlaybackMode = .oneShot

    private init() {
        setupEngine()
    }

    private func setupEngine() {
        audioEngine.attach(playerNode)
        playerNode.volume = 2.0  // Boost for quiet stems
        isEngineSetup = true
        print("🔊 Audio engine initialized")
    }

    /// Play a sample from its audio URL and time range
    func play(sample: ExtractedSample) {
        stop()

        guard let url = sample.audioURL else {
            print("❌ No audio URL for sample: \(sample.name)")
            return
        }

        // Use effective times (with nudge offset applied)
        let playStartTime = sample.effectiveStartTime
        let playEndTime = sample.effectiveEndTime

        print("🎵 Sample: \(sample.name)")
        print("   URL: \(url.lastPathComponent)")
        print("   Time: \(playStartTime)s - \(playEndTime)s\(sample.nudgeOffset != 0 ? " (nudged \(String(format: "%+.3f", sample.nudgeOffset))s)" : "")")

        do {
            // Load audio file
            let audioFile = try AVAudioFile(forReading: url)
            currentFile = audioFile

            let sampleRate = audioFile.processingFormat.sampleRate
            let totalFrames = AVAudioFrameCount(audioFile.length)
            let audioDuration = Double(totalFrames) / sampleRate

            print("   Audio duration: \(audioDuration)s, Sample rate: \(sampleRate)")

            // Calculate frame positions using effective times
            var startFrame = AVAudioFramePosition(max(0, playStartTime) * sampleRate)
            let endFrame = AVAudioFramePosition(min(playEndTime, audioDuration) * sampleRate)

            // Validate
            if startFrame >= audioFile.length {
                print("   ⚠️ Start frame beyond audio, playing from 0")
                startFrame = 0
            }

            let frameCount = AVAudioFrameCount(endFrame - startFrame)
            guard frameCount > 0 else {
                print("   ⚠️ Invalid frame count")
                return
            }

            print("   Frames: \(startFrame) to \(endFrame) (\(frameCount) frames)")

            // Reconnect player to engine with correct format for this file
            if audioEngine.isRunning {
                audioEngine.stop()
            }

            // Disconnect and reconnect with new format
            audioEngine.disconnectNodeOutput(playerNode)
            audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: audioFile.processingFormat)

            try audioEngine.start()

            print("   Engine running: \(audioEngine.isRunning), Format: \(audioFile.processingFormat)")

            // Read the specific segment into a buffer first (more reliable for large files)
            audioFile.framePosition = startFrame
            let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: frameCount)!
            try audioFile.read(into: buffer, frameCount: frameCount)

            // Check buffer peak and apply gain normalization
            var maxSample: Float = 0
            if let channelData = buffer.floatChannelData {
                let frameCount = Int(buffer.frameLength)
                let channelCount = Int(buffer.format.channelCount)

                // Find peak across all channels
                for ch in 0..<channelCount {
                    for i in 0..<frameCount {
                        let sample = abs(channelData[ch][i])
                        if sample > maxSample { maxSample = sample }
                    }
                }

                // Normalize very quiet audio (target peak of 0.5, conservative boost)
                // Only boost if peak is very low, and cap gain to prevent clipping
                if maxSample > 0 && maxSample < 0.05 {
                    let gain = min(0.5 / maxSample, 10.0)  // Cap at 10x gain (~20dB)
                    print("   Buffer: \(buffer.frameLength) frames, peak: \(String(format: "%.4f", maxSample)), applying \(String(format: "%.1f", gain))x gain")

                    for ch in 0..<channelCount {
                        for i in 0..<frameCount {
                            channelData[ch][i] *= gain
                        }
                    }
                } else {
                    print("   Buffer: \(buffer.frameLength) frames, peak: \(String(format: "%.4f", maxSample))")
                }
            }

            // Store buffer for potential looping
            currentBuffer = buffer

            // Schedule the buffer with looping if enabled
            if playbackMode == .loop {
                playerNode.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
            } else {
                playerNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
            }
            playerNode.play()

            isPlaying = true
            currentSampleID = sample.id

            let playDuration = Double(frameCount) / sampleRate

            // Schedule stop only for one-shot mode
            if playbackMode == .oneShot {
                playTimer = Timer.scheduledTimer(withTimeInterval: playDuration + 0.05, repeats: false) { [weak self] _ in
                    self?.stop()
                }
            }

            print("   ▶️ Playing \(frameCount) frames (\(String(format: "%.3f", playDuration))s) - \(playbackMode.rawValue)")

        } catch {
            print("❌ Failed to play sample: \(error.localizedDescription)")
        }
    }

    /// Stop current playback
    func stop() {
        playTimer?.invalidate()
        playTimer = nil

        playerNode.stop()
        // Don't stop the engine, just the player

        currentFile = nil
        currentBuffer = nil
        isPlaying = false
        currentSampleID = nil
    }

    /// Toggle playback - stops if same sample is playing, plays if different or stopped
    func togglePlay(sample: ExtractedSample) {
        if isPlaying(sample: sample) {
            stop()
        } else {
            play(sample: sample)
        }
    }

    /// Check if a specific sample is currently playing
    func isPlaying(sample: ExtractedSample) -> Bool {
        return isPlaying && currentSampleID == sample.id
    }

    /// Set playback mode
    func setMode(_ mode: PlaybackMode) {
        playbackMode = mode
        // If currently playing and switching to one-shot, let it finish
        // If switching to loop while playing, we'd need to restart - for simplicity, don't change mid-play
    }
}
