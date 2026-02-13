//
//  StemSeparator.swift
//  LoopLifter
//
//  Demucs CLI wrapper for stem separation
//  Shared with LoOptimizer
//

import Foundation

/// The four stem types that Demucs separates audio into
enum StemType: String, CaseIterable, Codable, Identifiable {
    case drums = "drums"
    case bass = "bass"
    case vocals = "vocals"
    case other = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .drums: return "Drums"
        case .bass: return "Bass"
        case .vocals: return "Vocals"
        case .other: return "Other"
        }
    }

    var shortName: String {
        switch self {
        case .drums: return "DRM"
        case .bass: return "BAS"
        case .vocals: return "VOX"
        case .other: return "OTH"
        }
    }

    var icon: String {
        switch self {
        case .drums: return "circle.grid.3x3.fill"
        case .bass: return "waveform.path"
        case .vocals: return "mic.fill"
        case .other: return "guitars.fill"
        }
    }

    var color: String {
        switch self {
        case .drums: return "orange"
        case .bass: return "purple"
        case .vocals: return "green"
        case .other: return "blue"
        }
    }

    /// MIDI note range for this stem type (16 notes per stem)
    var midiNoteRange: ClosedRange<UInt8> {
        switch self {
        case .drums: return 36...51   // C2-D#3
        case .bass: return 52...67    // E3-G4
        case .vocals: return 68...83  // G#4-B5
        case .other: return 84...99   // C6-D#7
        }
    }

    /// Base MIDI note for this stem type
    var baseMidiNote: UInt8 {
        midiNoteRange.lowerBound
    }
}

/// Error types for stem separation
enum StemSeparationError: LocalizedError {
    case demucsNotFound
    case pythonNotFound
    case separationFailed(String)
    case outputNotFound(StemType)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .demucsNotFound:
            return "Demucs is not installed. Install it using:\n1. brew install python@3.11\n2. python3.11 -m venv ~/demucs-env\n3. source ~/demucs-env/bin/activate && pip install demucs"
        case .pythonNotFound:
            return "Python 3 is not found. Please install Python 3.9 or later using: brew install python@3.11"
        case .separationFailed(let message):
            return "Stem separation failed: \(message)"
        case .outputNotFound(let stem):
            return "Output file for \(stem.displayName) stem was not found"
        case .cancelled:
            return "Stem separation was cancelled"
        }
    }
}

/// Wrapper for Demucs CLI tool to separate audio into stems
struct StemSeparator {

    /// Available Demucs models
    enum DemucsModel: String, CaseIterable {
        case htdemucs = "htdemucs"        // Hybrid Transformer (best quality)
        case htdemucs_ft = "htdemucs_ft"  // Fine-tuned version
        case mdx_extra = "mdx_extra"       // MDX-Net architecture
        case demucs = "demucs"             // Original model

        var displayName: String {
            switch self {
            case .htdemucs: return "Hybrid Transformer (Recommended)"
            case .htdemucs_ft: return "Hybrid Transformer Fine-tuned"
            case .mdx_extra: return "MDX-Net Extra"
            case .demucs: return "Original Demucs"
            }
        }
    }

    /// Get the real home directory (not sandbox container)
    static var realHomeDirectory: String {
        // Try to get real home from environment or passwd
        if let home = ProcessInfo.processInfo.environment["HOME"],
           !home.contains("Containers") {
            return home
        }
        // Fall back to passwd entry
        if let pw = getpwuid(getuid()) {
            return String(cString: pw.pointee.pw_dir)
        }
        // Last resort
        return NSHomeDirectory()
    }

    /// Path to the Demucs wrapper script (virtual environment)
    static var demucsWrapperPath: String {
        return "\(realHomeDirectory)/demucs-env/bin/demucs-run"
    }

    /// Path to the Demucs executable in the virtual environment
    static var demucsVenvPath: String {
        return "\(realHomeDirectory)/demucs-env/bin/demucs"
    }

    /// Check if Demucs is installed
    static func isDemucsInstalled() async -> Bool {
        print("🔍 Checking Demucs installation...")
        print("🔍 Real home directory: \(realHomeDirectory)")
        print("🔍 Wrapper path: \(demucsWrapperPath)")
        print("🔍 Venv path: \(demucsVenvPath)")

        // First check for the wrapper script (preferred method)
        if FileManager.default.fileExists(atPath: demucsWrapperPath) {
            print("✅ Found wrapper script")
            return true
        }

        // Then check for demucs in the venv directly
        if FileManager.default.fileExists(atPath: demucsVenvPath) {
            print("✅ Found venv demucs")
            return true
        }
        print("⚠️ Demucs not found in venv, checking system...")

        // Finally try system-wide installation
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["python3", "-m", "demucs", "--help"]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            try process.run()
            process.waitUntilExit()

            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// Find the best Demucs executable path
    /// Returns executable and args, using bash -l -c for sandbox compatibility
    static func findDemucsExecutable() -> (executable: String, args: [String])? {
        // Check for demucs in venv - run via login shell to avoid sandbox issues
        if FileManager.default.fileExists(atPath: demucsVenvPath) {
            // Use login shell with explicit source and demucs path
            let activateScript = "\(realHomeDirectory)/demucs-env/bin/activate"
            let demucsPath = demucsVenvPath
            return ("/bin/bash", ["-l", "-c", "source '\(activateScript)' && '\(demucsPath)'"])
        }

        // Check for wrapper script
        if FileManager.default.fileExists(atPath: demucsWrapperPath) {
            return ("/bin/bash", ["-l", "-c", "'\(demucsWrapperPath)'"])
        }

        // Fall back to system Python
        if let pythonPath = findPython3Path() {
            return (pythonPath, ["-m", "demucs"])
        }

        return nil
    }

    /// Find the Python 3 executable path
    static func findPython3Path() -> String? {
        let possiblePaths = [
            "/usr/bin/python3",
            "/usr/local/bin/python3",
            "/opt/homebrew/bin/python3",
            "/opt/local/bin/python3"
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        // Try using 'which' to find python3
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["python3"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty {
                return path
            }
        } catch {
            return nil
        }

        return nil
    }

    /// Separate audio file into stems using Demucs
    /// - Parameters:
    ///   - audioURL: URL to the input audio file
    ///   - outputDir: Directory to write the separated stems
    ///   - model: Demucs model to use (default: htdemucs)
    ///   - onProgress: Progress callback (0.0 to 1.0)
    /// - Returns: Dictionary mapping stem types to their output file URLs
    static func separate(
        audioURL: URL,
        outputDir: URL,
        model: DemucsModel = .htdemucs,
        onProgress: @escaping (Double) -> Void
    ) async throws -> [StemType: URL] {

        // Find Demucs executable
        guard let demucsExec = findDemucsExecutable() else {
            // Check if it's a Python issue vs Demucs issue
            if findPython3Path() == nil {
                throw StemSeparationError.pythonNotFound
            }
            throw StemSeparationError.demucsNotFound
        }

        // Create output directory if needed
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        // Build Demucs command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: demucsExec.executable)

        // Build arguments based on the executable type
        var args: [String]

        if demucsExec.executable == "/bin/bash" && demucsExec.args.contains("-c") {
            // Using bash -l -c with inline command - append demucs args to the command string
            // Find the -c argument and get the base command after it
            if let cIndex = demucsExec.args.firstIndex(of: "-c"),
               cIndex + 1 < demucsExec.args.count {
                let baseCmd = demucsExec.args[cIndex + 1]
                let demucsArgs = "-n '\(model.rawValue)' -o '\(outputDir.path)' --filename '{stem}.{ext}' '\(audioURL.path)'"
                // Preserve any args before -c (like -l)
                let prefixArgs = Array(demucsExec.args[0..<cIndex])
                args = prefixArgs + ["-c", "\(baseCmd) \(demucsArgs)"]
            } else {
                // Fallback
                args = demucsExec.args
            }
        } else {
            // Direct execution (Python or demucs binary)
            args = demucsExec.args + [
                "-n", model.rawValue,
                "-o", outputDir.path,
                "--filename", "{stem}.{ext}",
                audioURL.path
            ]
        }

        process.arguments = args
        print("🔬 Running: \(demucsExec.executable) \(args.joined(separator: " "))")

        // Set up output pipes for progress parsing
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Track progress by parsing Demucs output
        var lastProgress: Double = 0

        // Read stderr asynchronously for progress updates
        let errorHandle = errorPipe.fileHandleForReading

        Task {
            for try await line in errorHandle.bytes.lines {
                // Parse progress from Demucs output (e.g., "100%|" progress bars)
                if let percentMatch = line.range(of: #"(\d+)%\|"#, options: .regularExpression) {
                    let percentStr = line[percentMatch].dropLast(2)  // Remove "%|"
                    if let percent = Double(percentStr) {
                        let progress = percent / 100.0
                        if progress > lastProgress {
                            lastProgress = progress
                            await MainActor.run {
                                onProgress(progress)
                            }
                        }
                    }
                }
            }
        }

        // Run Demucs
        try process.run()

        // Report initial progress
        onProgress(0.0)

        // Wait for completion
        process.waitUntilExit()

        // Check for success
        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw StemSeparationError.separationFailed(errorMessage)
        }

        onProgress(1.0)

        // Find output files
        // With --filename '{stem}.{ext}', Demucs creates: outputDir/model_name/stem.wav
        let modelOutputDir = outputDir.appendingPathComponent(model.rawValue)

        var stemURLs: [StemType: URL] = [:]

        for stemType in StemType.allCases {
            let stemFile = modelOutputDir.appendingPathComponent("\(stemType.rawValue).wav")
            print("🔍 Looking for stem: \(stemFile.path)")

            if FileManager.default.fileExists(atPath: stemFile.path) {
                print("✅ Found: \(stemType.rawValue)")
                stemURLs[stemType] = stemFile
            } else {
                print("❌ Not found: \(stemType.rawValue)")
                throw StemSeparationError.outputNotFound(stemType)
            }
        }

        return stemURLs
    }

    /// Get the estimated separation time based on audio duration
    static func estimatedTime(for duration: TimeInterval) -> String {
        // Rough estimate: Demucs processes at ~5x realtime on modern hardware
        let estimatedSeconds = duration / 5.0

        if estimatedSeconds < 60 {
            return "~\(Int(estimatedSeconds)) seconds"
        } else {
            let minutes = Int(estimatedSeconds / 60)
            let seconds = Int(estimatedSeconds.truncatingRemainder(dividingBy: 60))
            return "~\(minutes)m \(seconds)s"
        }
    }
}
