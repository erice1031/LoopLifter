//
//  DropZoneView.swift
//  LoopLifter
//
//  Drag and drop zone for audio files
//

import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    @Binding var isTargeted: Bool
    var onDrop: (URL) -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 3, dash: [10])
                    )
                    .foregroundColor(isTargeted ? .accentColor : .secondary.opacity(0.5))

                VStack(spacing: 16) {
                    Image(systemName: "waveform.badge.plus")
                        .font(.system(size: 64))
                        .foregroundColor(isTargeted ? .accentColor : .secondary)

                    Text("Drop any audio file here")
                        .font(.title2)
                        .fontWeight(.medium)

                    Text("WAV, AIFF, MP3, M4A, FLAC")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button("Browse Files...") {
                        browseFiles()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
                }
            }
            .frame(maxWidth: 500, maxHeight: 300)
            .padding(40)
            .onDrop(of: [.audio, .fileURL], isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
                return true
            }

            Spacer()

            // Info footer
            HStack(spacing: 32) {
                InfoItem(icon: "music.note.list", title: "Extract Loops", description: "Find repeating patterns")
                InfoItem(icon: "waveform", title: "Isolate Hits", description: "Kick, snare, hats & more")
                InfoItem(icon: "mic", title: "Vocal Hooks", description: "Phrases & ad-libs")
                InfoItem(icon: "square.and.arrow.up", title: "Export Packs", description: "Ready for any DAW")
            }
            .padding(.bottom, 32)
        }
    }

    private func browseFiles() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            .audio,
            .wav,
            .aiff,
            .mp3,
            UTType(filenameExtension: "flac") ?? .audio,
            UTType(filenameExtension: "m4a") ?? .audio
        ]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            onDrop(url)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }

        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async {
                        onDrop(url)
                    }
                }
            }
        }
    }
}

struct InfoItem: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
            Text(description)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(width: 120)
    }
}

#Preview {
    DropZoneView(isTargeted: .constant(false)) { url in
        print("Dropped: \(url)")
    }
}
