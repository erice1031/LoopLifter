//
//  AudioPreviewPlayer.swift
//  LoopLifter
//
//  Audio player for sample preview using AVAudioEngine for precise seeking
//

import Foundation
import AVFoundation

/// Singleton audio player for previewing samples
@Observable
class AudioPreviewPlayer {
    static let shared = AudioPreviewPlayer()

    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var currentFile: AVAudioFile?
    private var playTimer: Timer?
    private var isEngineSetup = false

    var isPlaying: Bool = false
    var currentSampleID: UUID?

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

        print("🎵 Sample: \(sample.name)")
        print("   URL: \(url.lastPathComponent)")
        print("   Time: \(sample.startTime)s - \(sample.endTime)s")

        do {
            // Load audio file
            let audioFile = try AVAudioFile(forReading: url)
            currentFile = audioFile

            let sampleRate = audioFile.processingFormat.sampleRate
            let totalFrames = AVAudioFrameCount(audioFile.length)
            let audioDuration = Double(totalFrames) / sampleRate

            print("   Audio duration: \(audioDuration)s, Sample rate: \(sampleRate)")

            // Calculate frame positions
            var startFrame = AVAudioFramePosition(sample.startTime * sampleRate)
            let endFrame = AVAudioFramePosition(min(sample.endTime, audioDuration) * sampleRate)

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

            // Schedule playback from specific position
            playerNode.scheduleSegment(
                audioFile,
                startingFrame: startFrame,
                frameCount: frameCount,
                at: nil
            )

            playerNode.play()

            isPlaying = true
            currentSampleID = sample.id

            // Schedule stop
            let playDuration = Double(frameCount) / sampleRate
            playTimer = Timer.scheduledTimer(withTimeInterval: playDuration + 0.05, repeats: false) { [weak self] _ in
                self?.stop()
            }

            print("   ▶️ Playing \(frameCount) frames (\(String(format: "%.3f", playDuration))s)")

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
        isPlaying = false
        currentSampleID = nil
    }

    /// Check if a specific sample is currently playing
    func isPlaying(sample: ExtractedSample) -> Bool {
        return isPlaying && currentSampleID == sample.id
    }
}
