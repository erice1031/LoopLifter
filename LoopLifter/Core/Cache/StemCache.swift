//
//  StemCache.swift
//  LoopLifter
//
//  Caches separated stems to avoid re-running Demucs on the same file
//

import Foundation
import CryptoKit

/// Manages cached stem files to speed up repeated analysis of the same audio
class StemCache {
    static let shared = StemCache()

    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    private init() {
        // Use ~/Library/Caches/LoopLifter/stems/
        let cachesDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cachesDir.appendingPathComponent("LoopLifter/stems", isDirectory: true)

        // Create cache directory if needed
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        print("📦 Stem cache directory: \(cacheDirectory.path)")
    }

    // MARK: - Cache Key Generation

    /// Generate a unique cache key for an audio file based on path, size, and modification date
    func cacheKey(for audioURL: URL) -> String? {
        guard let attributes = try? fileManager.attributesOfItem(atPath: audioURL.path),
              let fileSize = attributes[.size] as? Int64,
              let modDate = attributes[.modificationDate] as? Date else {
            return nil
        }

        // Create a unique identifier from path + size + modification date
        let identifier = "\(audioURL.path)|\(fileSize)|\(modDate.timeIntervalSince1970)"

        // Hash it for a clean directory name
        let hash = SHA256.hash(data: Data(identifier.utf8))
        return hash.prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    /// Get the cache directory for a specific audio file
    func cacheDirectory(for audioURL: URL) -> URL? {
        guard let key = cacheKey(for: audioURL) else { return nil }
        return cacheDirectory.appendingPathComponent(key, isDirectory: true)
    }

    // MARK: - Cache Operations

    /// Check if stems are cached for an audio file
    func hasCachedStems(for audioURL: URL) -> Bool {
        guard let dir = cacheDirectory(for: audioURL) else { return false }

        // Check if all 4 stem files exist
        let stemNames = ["drums", "bass", "vocals", "other"]
        for stem in stemNames {
            let stemPath = dir.appendingPathComponent("\(stem).wav")
            if !fileManager.fileExists(atPath: stemPath.path) {
                return false
            }
        }

        print("✅ Found cached stems for: \(audioURL.lastPathComponent)")
        return true
    }

    /// Get cached stem URLs for an audio file
    func getCachedStems(for audioURL: URL) -> [StemType: URL]? {
        guard hasCachedStems(for: audioURL),
              let dir = cacheDirectory(for: audioURL) else {
            return nil
        }

        var stems: [StemType: URL] = [:]
        stems[.drums] = dir.appendingPathComponent("drums.wav")
        stems[.bass] = dir.appendingPathComponent("bass.wav")
        stems[.vocals] = dir.appendingPathComponent("vocals.wav")
        stems[.other] = dir.appendingPathComponent("other.wav")

        print("📦 Loading stems from cache: \(dir.lastPathComponent)")
        return stems
    }

    /// Save stems to cache after separation
    func cacheStems(_ stems: [StemType: URL], for audioURL: URL) {
        guard let dir = cacheDirectory(for: audioURL) else {
            print("⚠️ Could not create cache key for: \(audioURL.lastPathComponent)")
            return
        }

        do {
            // Create cache directory for this file
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)

            // Copy each stem to cache
            for (stemType, stemURL) in stems {
                let destURL = dir.appendingPathComponent("\(stemType.rawValue).wav")

                // Remove existing if present
                try? fileManager.removeItem(at: destURL)

                // Copy stem file
                try fileManager.copyItem(at: stemURL, to: destURL)
            }

            print("💾 Cached stems for: \(audioURL.lastPathComponent) → \(dir.lastPathComponent)")

        } catch {
            print("⚠️ Failed to cache stems: \(error.localizedDescription)")
        }
    }

    // MARK: - Cache Management

    /// Get total cache size in bytes
    func cacheSize() -> Int64 {
        var totalSize: Int64 = 0

        if let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(size)
                }
            }
        }

        return totalSize
    }

    /// Format cache size for display
    func formattedCacheSize() -> String {
        let bytes = cacheSize()
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    /// Clear all cached stems
    func clearCache() {
        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for item in contents {
                try fileManager.removeItem(at: item)
            }
            print("🗑️ Cleared stem cache")
        } catch {
            print("⚠️ Failed to clear cache: \(error.localizedDescription)")
        }
    }

    /// Remove cached stems for a specific audio file
    func removeCachedStems(for audioURL: URL) {
        guard let dir = cacheDirectory(for: audioURL) else { return }
        try? fileManager.removeItem(at: dir)
        print("🗑️ Removed cached stems for: \(audioURL.lastPathComponent)")
    }
}
