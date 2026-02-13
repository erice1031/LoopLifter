//
//  HitIsolator.swift
//  LoopLifter
//
//  Isolates single hits (kick, snare, hat) from sparse regions
//

import Foundation
import AVFoundation

/// Isolates single drum hits and one-shots from audio
class HitIsolator {

    /// Find isolated hits in audio based on onset density
    /// - Parameters:
    ///   - onsets: Detected onset times
    ///   - duration: Total audio duration
    ///   - minGapBefore: Minimum silence before hit (seconds)
    ///   - minGapAfter: Minimum silence after hit (seconds)
    /// - Returns: Time ranges of isolated hits
    static func findIsolatedHits(
        onsets: [TimeInterval],
        duration: TimeInterval,
        minGapBefore: TimeInterval = 0.3,
        minGapAfter: TimeInterval = 0.2
    ) -> [IsolatedHit] {
        guard onsets.count > 1 else { return [] }

        var hits: [IsolatedHit] = []
        let sortedOnsets = onsets.sorted()

        for i in 0..<sortedOnsets.count {
            let onset = sortedOnsets[i]

            // Check gap before
            let gapBefore: TimeInterval
            if i == 0 {
                gapBefore = onset  // Gap from start
            } else {
                gapBefore = onset - sortedOnsets[i - 1]
            }

            // Check gap after
            let gapAfter: TimeInterval
            if i == sortedOnsets.count - 1 {
                gapAfter = duration - onset  // Gap to end
            } else {
                gapAfter = sortedOnsets[i + 1] - onset
            }

            // Is this hit sufficiently isolated?
            if gapBefore >= minGapBefore && gapAfter >= minGapAfter {
                // Estimate hit duration (until next onset or gap limit)
                let hitDuration = min(gapAfter, 0.5)  // Max 500ms per hit

                hits.append(IsolatedHit(
                    startTime: onset,
                    duration: hitDuration,
                    gapBefore: gapBefore,
                    gapAfter: gapAfter
                ))
            }
        }

        return hits
    }

    /// Classify drum hits by spectral characteristics
    /// - Parameters:
    ///   - audioURL: URL to audio file
    ///   - hits: Detected isolated hits
    /// - Returns: Hits with drum type classification
    static func classifyDrumHits(
        audioURL: URL,
        hits: [IsolatedHit]
    ) async throws -> [ClassifiedHit] {
        // TODO: Implement spectral analysis for drum classification
        // - Low frequency dominant = Kick
        // - Mid frequency with sharp attack = Snare
        // - High frequency, short = Hi-hat
        // - Mid-low, longer decay = Tom

        // Placeholder: Basic classification by position/duration
        return hits.enumerated().map { index, hit in
            let type: DrumHitType
            if hit.duration < 0.1 {
                type = .hihat
            } else if index % 2 == 0 {
                type = .kick
            } else {
                type = .snare
            }

            return ClassifiedHit(
                hit: hit,
                drumType: type,
                confidence: 0.7
            )
        }
    }
}

/// An isolated hit with timing info
struct IsolatedHit {
    let startTime: TimeInterval
    let duration: TimeInterval
    let gapBefore: TimeInterval
    let gapAfter: TimeInterval
}

/// A hit with drum type classification
struct ClassifiedHit {
    let hit: IsolatedHit
    let drumType: DrumHitType
    let confidence: Float
}

/// Types of drum hits
enum DrumHitType: String, CaseIterable {
    case kick = "Kick"
    case snare = "Snare"
    case hihat = "HiHat"
    case tom = "Tom"
    case clap = "Clap"
    case rim = "Rim"
    case cymbal = "Cymbal"
    case percussion = "Percussion"

    var icon: String {
        switch self {
        case .kick: return "circle.fill"
        case .snare: return "circle.bottomhalf.filled"
        case .hihat: return "triangle.fill"
        case .tom: return "circle.dashed"
        case .clap: return "hands.clap.fill"
        case .rim: return "circle.circle"
        case .cymbal: return "star.fill"
        case .percussion: return "waveform"
        }
    }
}
