//
//  FeatureExtractor.swift
//  LoopLifter
//
//  Extracts per-beat spectral feature vectors for use by SelfSimilarityAnalyzer
//  and NoveltyDetector. Uses 8 log-spaced frequency bands computed via vDSP FFT.
//

import Foundation
import AVFoundation
import Accelerate

struct FeatureExtractor {

    // Log-spaced band boundaries in Hz (8 bands from 20 Hz to 16 kHz)
    private static let bandEdges: [Double] = [20, 63, 200, 500, 1_000, 2_000, 4_000, 8_000, 16_000]

    // MARK: - Public API

    /// Extract an 8-element L2-normalised spectral feature vector for each beat onset.
    ///
    /// - Parameters:
    ///   - audioURL: Source audio file.
    ///   - beatOnsets: Sorted array of onset times in seconds (from AubioAnalyzer).
    ///   - sampleRate: Sample rate of the audio file (default 44 100 Hz).
    /// - Returns: One 8-element `[Float]` per onset — `features[i]` describes the
    ///            beat window starting at `beatOnsets[i]`.
    static func extractBeatFeatures(
        audioURL: URL,
        beatOnsets: [TimeInterval],
        sampleRate: Double = 44100
    ) async throws -> [[Float]] {
        guard !beatOnsets.isEmpty else { return [] }

        // Read the full file once as mono Float32
        let allSamples = try await readAllMonoSamples(audioURL: audioURL)
        guard !allSamples.isEmpty else { return [] }

        let sr = sampleRate
        var features: [[Float]] = []
        features.reserveCapacity(beatOnsets.count)

        for i in 0..<beatOnsets.count {
            let onset     = beatOnsets[i]
            let nextOnset = i + 1 < beatOnsets.count
                          ? beatOnsets[i + 1]
                          : onset + 60.0 / 120.0   // fallback: one beat at 120 BPM

            let startSample = Int(onset    * sr)
            let endSample   = min(allSamples.count, Int(nextOnset * sr))

            guard startSample < allSamples.count, endSample > startSample else {
                features.append([Float](repeating: 0, count: bandEdges.count - 1))
                continue
            }

            let window = Array(allSamples[startSample..<endSample])
            let vector = spectralBandEnergy(samples: window, sampleRate: sr)
            features.append(l2Normalize(vector))
        }

        return features
    }

    // MARK: - FFT + band energy

    /// Compute energy in 8 log-spaced frequency bands for a sample window.
    private static func spectralBandEnergy(samples: [Float], sampleRate: Double) -> [Float] {
        let fftSize  = 1024
        let halfSize = fftSize / 2
        let log2n    = vDSP_Length(log2(Float(fftSize)))

        guard let fftSetup = vDSP_create_fftsetup(log2n, Int32(kFFTRadix2)) else {
            return [Float](repeating: 0, count: bandEdges.count - 1)
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        // Pad / truncate and apply Hann window
        var windowed = [Float](repeating: 0, count: fftSize)
        let copyCount = min(samples.count, fftSize)
        windowed[0..<copyCount] = ArraySlice(samples[0..<copyCount])

        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul(windowed, 1, window, 1, &windowed, 1, vDSP_Length(fftSize))

        // Pack into split-complex and run forward FFT
        var realPart   = [Float](repeating: 0, count: halfSize)
        var imagPart   = [Float](repeating: 0, count: halfSize)
        var magnitudes = [Float](repeating: 0, count: halfSize)

        windowed.withUnsafeBufferPointer { wPtr in
            realPart.withUnsafeMutableBufferPointer { rPtr in
                imagPart.withUnsafeMutableBufferPointer { iPtr in
                    var split = DSPSplitComplex(realp: rPtr.baseAddress!, imagp: iPtr.baseAddress!)
                    wPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfSize) { cPtr in
                        vDSP_ctoz(cPtr, 2, &split, 1, vDSP_Length(halfSize))
                    }
                    vDSP_fft_zrip(fftSetup, &split, 1, log2n, Int32(FFT_FORWARD))
                    vDSP_zvmags(&split, 1, &magnitudes, 1, vDSP_Length(halfSize))
                }
            }
        }

        // Sum power in each log-spaced band
        let freqRes  = sampleRate / Double(fftSize)
        let numBands = bandEdges.count - 1
        var bandEnergy = [Float](repeating: 0, count: numBands)

        for band in 0..<numBands {
            let loIdx = max(1, Int(bandEdges[band]     / freqRes))
            let hiIdx = min(halfSize - 1, Int(bandEdges[band + 1] / freqRes))
            guard hiIdx > loIdx else { continue }
            bandEnergy[band] = magnitudes[loIdx...hiIdx].reduce(0, +)
        }

        return bandEnergy
    }

    // MARK: - L2 normalisation

    private static func l2Normalize(_ v: [Float]) -> [Float] {
        var sumSq: Float = 0
        vDSP_svesq(v, 1, &sumSq, vDSP_Length(v.count))
        let norm = sqrt(sumSq)
        guard norm > 1e-8 else { return v }
        var result = v
        var scale  = 1.0 / norm
        vDSP_vsmul(v, 1, &scale, &result, 1, vDSP_Length(v.count))
        return result
    }

    // MARK: - Audio reading

    /// Read the full file as mono Float32 (AVFoundation auto-downmixes stereo).
    private static func readAllMonoSamples(audioURL: URL) async throws -> [Float] {
        let asset = AVURLAsset(url: audioURL)
        guard let track = try await asset.load(.tracks).first(where: { $0.mediaType == .audio }) else {
            return []
        }

        let reader = try AVAssetReader(asset: asset)

        let settings: [String: Any] = [
            AVFormatIDKey:               Int(kAudioFormatLinearPCM),
            AVLinearPCMBitDepthKey:      32,
            AVLinearPCMIsBigEndianKey:   false,
            AVLinearPCMIsFloatKey:       true,
            AVLinearPCMIsNonInterleaved: false,
            AVNumberOfChannelsKey:       1
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
