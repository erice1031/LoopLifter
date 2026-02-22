//
//  PitchDetector.swift
//  LoopLifter
//
//  Monophonic pitch detection using the YIN algorithm (de Cheveigné & Kawahara, 2002).
//  Accelerate/vDSP accelerated for real-time performance.
//

import Foundation
import AVFoundation
import Accelerate

/// Result of a pitch detection pass on a single audio window.
struct PitchResult {
    /// Fundamental frequency in Hz.
    let frequency: Double
    /// Nearest MIDI note number (0–127).
    let midiNote: Int
    /// Human-readable note name, e.g. "A2", "D#3".
    let noteName: String
    /// Deviation from the exact MIDI pitch in cents (–50…+50).
    let centsOffset: Double
    /// YIN confidence (0.0 = completely uncertain, 1.0 = perfect).
    let confidence: Float
}

struct PitchDetector {

    // MARK: - Public API

    /// Detect the fundamental pitch of a time-bounded region in an audio file.
    ///
    /// - Returns: A `PitchResult` when a tonal pitch is detected with confidence ≥ 0.4.
    ///            Returns `nil` for atonal/noise signals (drums, noise, etc.).
    static func detect(
        audioURL: URL,
        startTime: TimeInterval,
        duration: TimeInterval
    ) async throws -> PitchResult? {
        let samples = try await readMonoSamples(
            audioURL: audioURL,
            startTime: startTime,
            duration: duration
        )

        guard samples.count >= 256 else { return nil }

        return yin(samples: samples, sampleRate: 44100)
    }

    // MARK: - YIN Algorithm

    /// Core YIN pitch estimator.
    ///
    /// Uses up to 4096 samples (covers fundamentals down to ~10 Hz at 44.1 kHz).
    /// τ_max is capped at half the buffer length, giving a minimum detectable
    /// frequency of `sampleRate / (bufferSize / 2)`.
    private static func yin(samples: [Float], sampleRate: Double) -> PitchResult? {
        // Work with at most 4096 samples
        let bufSize = min(samples.count, 4096)
        let buf     = Array(samples.prefix(bufSize))

        // τ range: limits the detectable frequency range
        //   τ_min → f_max ~= 2000 Hz  (sampleRate / τ_min)
        //   τ_max → f_min ~=   50 Hz  (sampleRate / τ_max)
        let tauMin = Int(sampleRate / 2000.0)   // ~22 samples @ 44.1kHz
        let tauMax = min(bufSize / 2, Int(sampleRate / 50.0))  // ~441 samples @ 44.1kHz

        guard tauMax > tauMin else { return nil }

        // Step 1 & 2: Difference function, then cumulative mean normalized difference (CMNDF)
        let cmndf = cumulativeMeanNormalizedDifference(buf: buf, tauMin: tauMin, tauMax: tauMax)

        // Step 3: Absolute threshold — first τ where CMNDF dips below 0.15
        let threshold: Float = 0.15
        var bestTau = tauMin
        var found   = false

        for tau in tauMin..<tauMax {
            if cmndf[tau - tauMin] < threshold {
                // Walk to the local minimum
                var t = tau
                while t + 1 < tauMax && cmndf[t + 1 - tauMin] < cmndf[t - tauMin] {
                    t += 1
                }
                bestTau = t
                found   = true
                break
            }
        }

        // Fallback: global minimum if no threshold crossing
        if !found {
            var globalMin: Float = .infinity
            for tau in tauMin..<tauMax {
                let v = cmndf[tau - tauMin]
                if v < globalMin {
                    globalMin = v
                    bestTau   = tau
                }
            }
        }

        // Step 4: Parabolic interpolation for sub-sample accuracy
        let tauInterp = parabolicInterpolation(cmndf: cmndf, tau: bestTau, tauMin: tauMin, tauMax: tauMax)

        // Confidence = 1 − CMNDF(τ_best)  (higher CMNDF = less periodic = less confident)
        let rawConfidence = 1.0 - cmndf[bestTau - tauMin]
        let confidence = max(0, min(1, rawConfidence))

        // Reject weak/atonal signals
        guard confidence >= 0.4 else { return nil }

        let frequency = sampleRate / tauInterp

        // Sanity check: must be in a musically useful range (20 Hz – 4 kHz)
        guard frequency >= 20 && frequency <= 4000 else { return nil }

        let midi  = midiNote(from: frequency)
        let name  = noteName(from: midi)
        let cents = centsOffset(from: frequency, midiNote: midi)

        return PitchResult(
            frequency:   frequency,
            midiNote:    midi,
            noteName:    name,
            centsOffset: cents,
            confidence:  Float(confidence)
        )
    }

    // MARK: - YIN helpers

    /// Compute the Cumulative Mean Normalized Difference function for τ in [tauMin, tauMax).
    ///
    /// d(τ)  = Σ_n (x[n] − x[n+τ])²
    /// d'(τ) = d(τ) / ((1/τ) Σ_{j=1}^{τ} d(j))     [d'(1) = 1 by definition]
    ///
    /// Returns an array of length (tauMax − tauMin) indexed from τ = tauMin.
    private static func cumulativeMeanNormalizedDifference(
        buf: [Float],
        tauMin: Int,
        tauMax: Int
    ) -> [Float] {
        let N     = tauMax
        var d     = [Float](repeating: 0, count: N)

        // Compute d(τ) using vDSP for each lag
        // d(τ) = Σ_n (x[n] − x[n+τ])²
        // Equivalent to: d(τ) = Σ x[n]² + Σ x[n+τ]² − 2 Σ x[n]·x[n+τ]
        // We compute it directly (simpler & correct for short buffers)
        let maxN = buf.count - N

        for tau in 1..<N {
            guard maxN > 0 else { break }
            var diff = [Float](repeating: 0, count: maxN)
            // diff[n] = x[n] - x[n+tau]
            vDSP_vsub(
                buf.withUnsafeBufferPointer { $0.baseAddress! + tau }, 1,
                buf,                                                    1,
                &diff,                                                  1,
                vDSP_Length(maxN)
            )
            // d[tau] = Σ diff²
            var sumSq: Float = 0
            vDSP_svesq(diff, 1, &sumSq, vDSP_Length(maxN))
            d[tau] = sumSq
        }

        // Cumulative mean normalization
        var cmndf = [Float](repeating: 0, count: N)
        cmndf[0] = 1.0  // d'(0) = 1 by convention

        var runningSum: Float = 0
        for tau in 1..<N {
            runningSum += d[tau]
            if runningSum > 0 {
                cmndf[tau] = d[tau] * Float(tau) / runningSum
            } else {
                cmndf[tau] = 1.0
            }
        }

        // Return only the slice we care about
        return Array(cmndf[tauMin..<tauMax])
    }

    /// Fit a parabola through three adjacent CMNDF values and return the interpolated minimum τ.
    private static func parabolicInterpolation(
        cmndf: [Float],
        tau: Int,
        tauMin: Int,
        tauMax: Int
    ) -> Double {
        let idx = tau - tauMin
        guard idx > 0, idx + 1 < cmndf.count else {
            return Double(tau)
        }

        let y0 = cmndf[idx - 1]
        let y1 = cmndf[idx]
        let y2 = cmndf[idx + 1]
        let denom = 2 * (2 * y1 - y2 - y0)

        guard abs(denom) > 1e-6 else { return Double(tau) }

        let delta = (y2 - y0) / denom
        return Double(tau) + Double(delta)
    }

    // MARK: - MIDI / note helpers

    /// Convert Hz to nearest MIDI note (A4 = 440 Hz = MIDI 69).
    static func midiNote(from hz: Double) -> Int {
        let note = 69.0 + 12.0 * log2(hz / 440.0)
        return max(0, min(127, Int(note.rounded())))
    }

    /// Human-readable note name including octave, e.g. "A2", "D#3".
    static func noteName(from midi: Int) -> String {
        let names  = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = (midi / 12) - 1
        let name   = names[midi % 12]
        return "\(name)\(octave)"
    }

    /// Deviation in cents between `hz` and the exact frequency of `midiNote`.
    /// Result is in –50…+50 (values outside that range shouldn't occur after rounding).
    static func centsOffset(from hz: Double, midiNote: Int) -> Double {
        let exactHz = 440.0 * pow(2.0, Double(midiNote - 69) / 12.0)
        return 1200.0 * log2(hz / exactHz)
    }

    // MARK: - Audio reading

    /// Read the specified time window from an audio file as mono Float32 samples.
    /// `AVNumberOfChannelsKey: 1` lets AVFoundation downmix stereo automatically.
    private static func readMonoSamples(
        audioURL: URL,
        startTime: TimeInterval,
        duration: TimeInterval
    ) async throws -> [Float] {
        let asset = AVURLAsset(url: audioURL)
        guard let track = try await asset.load(.tracks).first(where: { $0.mediaType == .audio }) else {
            return []
        }

        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = CMTimeRange(
            start:    CMTime(seconds: startTime,  preferredTimescale: 44100),
            duration: CMTime(seconds: duration,   preferredTimescale: 44100)
        )

        let settings: [String: Any] = [
            AVFormatIDKey:             Int(kAudioFormatLinearPCM),
            AVLinearPCMBitDepthKey:    32,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey:     true,
            AVLinearPCMIsNonInterleaved: false,
            AVNumberOfChannelsKey:     1
        ]

        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        reader.add(output)
        reader.startReading()

        var samples: [Float] = []

        while let buffer = output.copyNextSampleBuffer(),
              let block  = CMSampleBufferGetDataBuffer(buffer) {
            let length = CMBlockBufferGetDataLength(block)
            var data   = Data(count: length)
            _ = data.withUnsafeMutableBytes { ptr in
                CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length,
                                           destination: ptr.baseAddress!)
            }
            data.withUnsafeBytes { ptr in
                samples.append(contentsOf: ptr.bindMemory(to: Float.self))
            }
        }

        return samples
    }
}
