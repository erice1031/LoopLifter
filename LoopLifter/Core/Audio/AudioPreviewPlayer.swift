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

    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var audioFile: AVAudioFile?
    private var playTimer: Timer?

    var isPlaying: Bool = false
    var currentSampleID: UUID?

    private init() {}

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
            audioFile = try AVAudioFile(forReading: url)
            guard let audioFile = audioFile else { return }

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

            // Set up audio engine
            audioEngine = AVAudioEngine()
            playerNode = AVAudioPlayerNode()

            guard let engine = audioEngine, let player = playerNode else { return }

            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: audioFile.processingFormat)

            try engine.start()

            // Schedule playback from specific position
            player.scheduleSegment(
                audioFile,
                startingFrame: startFrame,
                frameCount: frameCount,
                at: nil
            )

            player.play()

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

        playerNode?.stop()
        audioEngine?.stop()

        playerNode = nil
        audioEngine = nil
        audioFile = nil

        isPlaying = false
        currentSampleID = nil
    }

    /// Check if a specific sample is currently playing
    func isPlaying(sample: ExtractedSample) -> Bool {
        return isPlaying && currentSampleID == sample.id
    }
}
