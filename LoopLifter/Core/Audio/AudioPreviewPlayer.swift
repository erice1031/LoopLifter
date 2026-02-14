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

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()

            // Set start position
            audioPlayer?.currentTime = sample.startTime
            audioPlayer?.play()

            isPlaying = true
            currentSampleID = sample.id

            // Schedule stop at end time
            let duration = sample.endTime - sample.startTime
            playTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                self?.stop()
            }

            print("▶️ Playing: \(sample.name) (\(sample.startTime)s - \(sample.endTime)s)")

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
