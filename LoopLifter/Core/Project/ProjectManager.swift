//
//  ProjectManager.swift
//  LoopLifter
//
//  Handles project save/load operations and file dialogs
//

import Foundation
import AppKit

/// Manages LoopLifter project files
@Observable
class ProjectManager {
    static let shared = ProjectManager()

    /// Current project (if any)
    var currentProject: LoopLifterProject?

    /// Current project file URL (for "Save" vs "Save As")
    var currentProjectURL: URL?

    /// Whether the project has unsaved changes
    var hasUnsavedChanges = false

    /// File extension for LoopLifter projects
    static let fileExtension = "looplifter"

    private init() {}

    // MARK: - Save Operations

    /// Save current project (Save As if no current file)
    func save(samples: [ExtractedSample], audioURL: URL, tempo: Double) -> Bool {
        if let existingURL = currentProjectURL {
            return saveToURL(existingURL, samples: samples, audioURL: audioURL, tempo: tempo)
        } else {
            return saveAs(samples: samples, audioURL: audioURL, tempo: tempo)
        }
    }

    /// Save As - always show file dialog
    func saveAs(samples: [ExtractedSample], audioURL: URL, tempo: Double) -> Bool {
        let panel = NSSavePanel()
        panel.title = "Save LoopLifter Project"
        panel.nameFieldLabel = "Project Name:"
        panel.nameFieldStringValue = audioURL.deletingPathExtension().lastPathComponent + ".\(Self.fileExtension)"
        panel.allowedContentTypes = []
        panel.allowsOtherFileTypes = true
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, var url = panel.url else {
            return false
        }

        // Ensure the file always ends with .looplifter regardless of what the panel returns
        if url.pathExtension.lowercased() != Self.fileExtension {
            url = url.appendingPathExtension(Self.fileExtension)
        }

        return saveToURL(url, samples: samples, audioURL: audioURL, tempo: tempo)
    }

    /// Save to specific URL
    private func saveToURL(_ url: URL, samples: [ExtractedSample], audioURL: URL, tempo: Double) -> Bool {
        let projectName = url.deletingPathExtension().lastPathComponent

        let project = LoopLifterProject(
            name: projectName,
            audioURL: audioURL,
            tempo: tempo,
            samples: samples
        )

        do {
            try project.save(to: url)
            currentProject = project
            currentProjectURL = url
            hasUnsavedChanges = false
            print("✅ Project saved: \(url.path)")
            return true
        } catch {
            print("❌ Failed to save project: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Load Operations

    /// Open a project file
    func open() -> (samples: [ExtractedSample], audioURL: URL, tempo: Double)? {
        let panel = NSOpenPanel()
        panel.title = "Open LoopLifter Project"
        panel.allowedContentTypes = []
        panel.allowsOtherFileTypes = true
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }

        return loadFromURL(url)
    }

    /// Load from specific URL
    func loadFromURL(_ url: URL) -> (samples: [ExtractedSample], audioURL: URL, tempo: Double)? {
        do {
            let project = try LoopLifterProject.load(from: url)

            // Restore samples from cache
            let samples = project.restoreSamples()

            if samples.isEmpty {
                print("⚠️ Could not restore samples - stems may need to be re-analyzed")
                // Return the original audio URL so user can re-analyze
                let audioURL = URL(fileURLWithPath: project.originalAudioPath)
                return ([], audioURL, project.tempo)
            }

            currentProject = project
            currentProjectURL = url
            hasUnsavedChanges = false

            let audioURL = URL(fileURLWithPath: project.originalAudioPath)
            return (samples, audioURL, project.tempo)

        } catch {
            print("❌ Failed to load project: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Recent Projects

    /// Get list of recent project URLs (stored in UserDefaults)
    var recentProjects: [URL] {
        get {
            let paths = UserDefaults.standard.stringArray(forKey: "recentProjects") ?? []
            return paths.compactMap { URL(fileURLWithPath: $0) }
        }
        set {
            let paths = newValue.prefix(10).map { $0.path }
            UserDefaults.standard.set(Array(paths), forKey: "recentProjects")
        }
    }

    /// Add URL to recent projects
    func addToRecent(_ url: URL) {
        var recent = recentProjects.filter { $0 != url }
        recent.insert(url, at: 0)
        recentProjects = Array(recent.prefix(10))
    }

    // MARK: - Helpers

    /// Mark project as having unsaved changes
    func markDirty() {
        hasUnsavedChanges = true
    }

    /// Clear current project
    func closeProject() {
        currentProject = nil
        currentProjectURL = nil
        hasUnsavedChanges = false
    }
}
