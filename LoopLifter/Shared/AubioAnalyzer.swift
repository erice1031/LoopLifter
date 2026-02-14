//
//  AubioAnalyzer.swift
//  LoopLifter
//
//  Wrapper for Aubio beat detection using CLI tool
//  Shared with LoOptimizer
//

import Foundation

/// Analyzes audio files using Aubio's onset detection
struct AubioAnalyzer {

    /// Detect onsets in an audio file using aubioonset CLI
    /// - Parameter audioURL: URL to the audio file
    /// - Returns: Array of onset times in seconds
    static func detectOnsets(in audioURL: URL) async throws -> [TimeInterval] {
        // Check if aubioonset is available
        let aubioPath = try findAubioTool()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: aubioPath)
        process.arguments = [
            "-i", audioURL.path,
            "-O", "txt"  // Output format: text
        ]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw AubioError.executionFailed(errorString)
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let outputString = String(data: outputData, encoding: .utf8) else {
            throw AubioError.invalidOutput
        }

        return parseOnsets(from: outputString)
    }

    /// Find the aubioonset executable
    private static func findAubioTool() throws -> String {
        // Common installation paths
        let possiblePaths = [
            "/opt/homebrew/bin/aubioonset",  // Apple Silicon Homebrew
            "/usr/local/bin/aubioonset",      // Intel Homebrew
            "/usr/bin/aubioonset"              // System installation
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        // Try to find it using 'which'
        let whichProcess = Process()
        whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        whichProcess.arguments = ["aubioonset"]

        let pipe = Pipe()
        whichProcess.standardOutput = pipe

        try? whichProcess.run()
        whichProcess.waitUntilExit()

        if whichProcess.terminationStatus == 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty {
                return path
            }
        }

        throw AubioError.aubioNotInstalled
    }

    /// Parse onset times from aubioonset output
    private static func parseOnsets(from output: String) -> [TimeInterval] {
        var onsets: [TimeInterval] = []

        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let time = Double(trimmed) {
                onsets.append(time)
            }
        }

        return onsets
    }

    /// Detect tempo using aubio
    static func detectTempo(in audioURL: URL) async throws -> Double {
        // Use "aubio tempo" command (newer aubio versions)
        let aubioPath = try findAubioTool().replacingOccurrences(of: "aubioonset", with: "aubio")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: aubioPath)
        process.arguments = ["tempo", "-i", audioURL.path]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let outputString = String(data: outputData, encoding: .utf8) else {
            throw AubioError.invalidOutput
        }

        // Parse tempo from output
        // Format is: "XXX.XX bpm"
        if let tempoMatch = outputString.range(of: #"[\d.]+(?=\s*bpm)"#, options: .regularExpression) {
            let tempoString = String(outputString[tempoMatch])
            if let tempo = Double(tempoString) {
                return tempo
            }
        }

        // Fallback: try to find any number
        if let tempoMatch = outputString.range(of: #"\d+\.?\d*"#, options: .regularExpression) {
            let tempoString = String(outputString[tempoMatch])
            if let tempo = Double(tempoString) {
                return tempo
            }
        }

        throw AubioError.invalidOutput
    }
}

enum AubioError: LocalizedError {
    case aubioNotInstalled
    case executionFailed(String)
    case invalidOutput

    var errorDescription: String? {
        switch self {
        case .aubioNotInstalled:
            return """
            Aubio is not installed. Please install it using Homebrew:
            brew install aubio
            """
        case .executionFailed(let error):
            return "Aubio execution failed: \(error)"
        case .invalidOutput:
            return "Could not parse Aubio output"
        }
    }
}
