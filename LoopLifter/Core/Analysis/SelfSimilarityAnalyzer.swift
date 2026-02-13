//
//  SelfSimilarityAnalyzer.swift
//  LoopLifter
//
//  Computes self-similarity matrices for loop detection
//

import Foundation
import Accelerate

/// Analyzes audio for repeating patterns using self-similarity matrices
class SelfSimilarityAnalyzer {

    /// Compute self-similarity matrix from audio features
    /// - Parameters:
    ///   - features: 2D array of features per time segment (e.g., MFCCs per beat)
    /// - Returns: NxN similarity matrix where N is number of segments
    static func computeSimilarityMatrix(features: [[Float]]) -> [[Float]] {
        let n = features.count
        guard n > 0 else { return [] }

        var matrix = [[Float]](repeating: [Float](repeating: 0, count: n), count: n)

        for i in 0..<n {
            for j in i..<n {
                let similarity = cosineSimilarity(features[i], features[j])
                matrix[i][j] = similarity
                matrix[j][i] = similarity  // Symmetric
            }
        }

        return matrix
    }

    /// Find repeating patterns (loops) from similarity matrix
    /// - Parameters:
    ///   - matrix: Self-similarity matrix
    ///   - minLength: Minimum pattern length in segments
    ///   - threshold: Similarity threshold (0-1)
    /// - Returns: Array of detected patterns with start, length, and repeat count
    static func findRepeatingPatterns(
        matrix: [[Float]],
        minLength: Int = 2,
        threshold: Float = 0.85
    ) -> [DetectedPattern] {
        let n = matrix.count
        guard n > minLength else { return [] }

        var patterns: [DetectedPattern] = []

        // Look for diagonal lines (indicate repetition)
        // A pattern of length L repeating at offset K shows as diagonal at offset K
        for patternLength in [4, 2, 1] {  // Check 4-bar, 2-bar, 1-bar
            guard patternLength <= n / 2 else { continue }

            for startOffset in stride(from: 0, to: n - patternLength, by: patternLength) {
                var repeatCount = 1
                var currentOffset = startOffset + patternLength

                while currentOffset + patternLength <= n {
                    // Check if segment at currentOffset matches segment at startOffset
                    var avgSimilarity: Float = 0
                    for i in 0..<patternLength {
                        avgSimilarity += matrix[startOffset + i][currentOffset + i]
                    }
                    avgSimilarity /= Float(patternLength)

                    if avgSimilarity >= threshold {
                        repeatCount += 1
                        currentOffset += patternLength
                    } else {
                        break
                    }
                }

                if repeatCount >= 2 {
                    patterns.append(DetectedPattern(
                        startSegment: startOffset,
                        lengthSegments: patternLength,
                        repeatCount: repeatCount,
                        averageSimilarity: 0  // TODO: Calculate
                    ))
                }
            }
        }

        // Sort by repeat count (most repeated = main loop)
        patterns.sort { $0.repeatCount > $1.repeatCount }

        return patterns
    }

    /// Cosine similarity between two feature vectors
    private static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }

        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        vDSP_dotpr(a, 1, b, 1, &dotProduct, vDSP_Length(a.count))
        vDSP_dotpr(a, 1, a, 1, &normA, vDSP_Length(a.count))
        vDSP_dotpr(b, 1, b, 1, &normB, vDSP_Length(b.count))

        let denominator = sqrt(normA) * sqrt(normB)
        guard denominator > 0 else { return 0 }

        return dotProduct / denominator
    }
}

/// A detected repeating pattern
struct DetectedPattern {
    let startSegment: Int
    let lengthSegments: Int
    let repeatCount: Int
    let averageSimilarity: Float

    var isMainLoop: Bool {
        repeatCount >= 4 && lengthSegments >= 2
    }
}
