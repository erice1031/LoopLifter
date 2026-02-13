//
//  QuantizationSettings.swift
//  LoopLifter
//
//  Quantization settings for snapping beat onsets to a musical grid
//  Shared with LoOptimizer
//

import Foundation

/// Musical grid division for quantization
enum GridDivision: String, CaseIterable, Codable {
    case quarter = "1/4"
    case eighth = "1/8"
    case sixteenth = "1/16"
    case thirtySecond = "1/32"

    /// Number of grid positions per beat (quarter note)
    var divisionsPerBeat: Int {
        switch self {
        case .quarter: return 1
        case .eighth: return 2
        case .sixteenth: return 4
        case .thirtySecond: return 8
        }
    }

    /// Display name for UI
    var displayName: String {
        rawValue
    }
}

/// Settings for quantizing beat onsets to a musical grid
struct QuantizationSettings: Codable, Equatable {
    var gridDivision: GridDivision = .eighth
    var strength: Double = 1.0  // 0.0 to 1.0
    var isEnabled: Bool = false

    /// Calculate grid positions based on tempo and duration
    func gridPositions(tempo: Double, duration: TimeInterval) -> [TimeInterval] {
        guard tempo > 0 else { return [] }

        let secondsPerBeat = 60.0 / tempo
        let secondsPerGridUnit = secondsPerBeat / Double(gridDivision.divisionsPerBeat)

        var positions: [TimeInterval] = []
        var currentTime: TimeInterval = 0

        while currentTime <= duration {
            positions.append(currentTime)
            currentTime += secondsPerGridUnit
        }

        return positions
    }

    /// Quantize an onset time to the nearest grid position
    func quantize(onset: TimeInterval, tempo: Double, duration: TimeInterval) -> TimeInterval {
        guard tempo > 0, strength > 0 else { return onset }

        let gridPositions = gridPositions(tempo: tempo, duration: duration)
        guard !gridPositions.isEmpty else { return onset }

        // Find nearest grid position
        var nearestPosition = gridPositions[0]
        var minDistance = abs(onset - nearestPosition)

        for position in gridPositions {
            let distance = abs(onset - position)
            if distance < minDistance {
                minDistance = distance
                nearestPosition = position
            }
        }

        // Apply strength (interpolate between original and quantized)
        return onset + (nearestPosition - onset) * strength
    }
}
