//
//  NoveltyDetector.swift
//  LoopLifter
//
//  Detects structural changes (fills, transitions) via novelty curves
//

import Foundation
import Accelerate

/// Detects structural novelty (changes) in audio for fill/transition detection
class NoveltyDetector {

    /// Compute novelty curve from audio features
    /// High values indicate structural changes (potential fills)
    /// - Parameters:
    ///   - features: Feature vectors per time segment
    ///   - kernelSize: Size of comparison kernel (segments before/after)
    /// - Returns: Novelty value per segment
    static func computeNoveltyCurve(
        features: [[Float]],
        kernelSize: Int = 4
    ) -> [Float] {
        let n = features.count
        guard n > kernelSize * 2 else { return [] }

        var novelty = [Float](repeating: 0, count: n)

        for i in kernelSize..<(n - kernelSize) {
            // Compare features before and after this point
            var beforeSum: Float = 0
            var afterSum: Float = 0

            for j in 0..<kernelSize {
                beforeSum += euclideanDistance(features[i], features[i - j - 1])
                afterSum += euclideanDistance(features[i], features[i + j + 1])
            }

            // Novelty is high when current point differs from both before and after
            novelty[i] = (beforeSum + afterSum) / Float(kernelSize * 2)
        }

        return novelty
    }

    /// Find peaks in novelty curve (potential fill locations)
    /// - Parameters:
    ///   - noveltyCurve: Computed novelty values
    ///   - threshold: Minimum novelty to consider
    ///   - minDistance: Minimum segments between peaks
    /// - Returns: Indices of novelty peaks
    static func findNoveltyPeaks(
        noveltyCurve: [Float],
        threshold: Float = 0.5,
        minDistance: Int = 4
    ) -> [Int] {
        var peaks: [Int] = []
        let n = noveltyCurve.count

        for i in 1..<(n - 1) {
            // Is this a local maximum above threshold?
            if noveltyCurve[i] > threshold &&
               noveltyCurve[i] > noveltyCurve[i - 1] &&
               noveltyCurve[i] > noveltyCurve[i + 1] {

                // Check minimum distance from last peak
                if let lastPeak = peaks.last {
                    if i - lastPeak < minDistance {
                        // Keep the higher peak
                        if noveltyCurve[i] > noveltyCurve[lastPeak] {
                            peaks.removeLast()
                            peaks.append(i)
                        }
                        continue
                    }
                }
                peaks.append(i)
            }
        }

        return peaks
    }

    /// Euclidean distance between two vectors
    private static func euclideanDistance(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0 }

        var sum: Float = 0
        for i in 0..<a.count {
            let diff = a[i] - b[i]
            sum += diff * diff
        }
        return sqrt(sum)
    }
}
