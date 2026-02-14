//
//  AudioPreviewPlayer.swift
//  LoopLifter
//
//  Simple audio player for sample preview
//

import Foundation
import AVFoundation

/// Singleton audio player for previewing samples
@Observable
class AudioPreviewPlayer {
    static let shared = AudioPreviewPlayer()

    private var audioPlayer: AVAudioPlayer?
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
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()

            print("   Audio duration: \(audioPlayer?.duration ?? 0)s")

            // Validate start time is within bounds
            let audioDuration = audioPlayer?.duration ?? 0
            var startTime = sample.startTime
            if startTime >= audioDuration {
                print("   ⚠️ Start time beyond audio, playing from 0")
                startTime = 0
            }

            // Set start position
            audioPlayer?.currentTime = startTime
            audioPlayer?.play()

            isPlaying = true
            currentSampleID = sample.id

            // Schedule stop at end time
            let playDuration = min(sample.endTime - sample.startTime, audioDuration - startTime)
            playTimer = Timer.scheduledTimer(withTimeInterval: max(playDuration, 0.1), repeats: false) { [weak self] _ in
                self?.stop()
            }

            print("   ▶️ Playing from \(startTime)s for \(playDuration)s")

        } catch {
            print("❌ Failed to play sample: \(error.localizedDescription)")
        }
    }

    /// Stop current playback
    func stop() {
        playTimer?.invalidate()
        playTimer = nil
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentSampleID = nil
    }

    /// Check if a specific sample is currently playing
    func isPlaying(sample: ExtractedSample) -> Bool {
        return isPlaying && currentSampleID == sample.id
    }
}
