//
//  SamplePackExporter.swift
//  LoopLifter
//
//  Exports sample packs as Apple Loops, Ableton Drum Rack, EXS24, or plain AIFF.
//  Creates a named subfolder "{SongName}_LoopLifter" inside the user-chosen destination.
//

import Foundation
import AVFoundation
import AppKit

// MARK: - Export Format

enum ExportFormat: String, CaseIterable, Identifiable {
    case appleLoops      = "Apple Loops"
    case abletonDrumRack = "Ableton Drum Rack"
    case exs24           = "EXS24 / Logic Sampler"
    case plainAIFF       = "Plain AIFF"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .appleLoops:      return "waveform.badge.plus"
        case .abletonDrumRack: return "square.grid.3x3.fill"
        case .exs24:           return "pianokeys"
        case .plainAIFF:       return "doc.waveform"
        }
    }

    var subtitle: String {
        switch self {
        case .appleLoops:      return "Logic Pro · GarageBand"
        case .abletonDrumRack: return "Ableton Live 10, 11, 12"
        case .exs24:           return "Logic Pro (Sampler)"
        case .plainAIFF:       return "Universal · Any DAW"
        }
    }

    var detail: String {
        switch self {
        case .appleLoops:
            return "AIFF files organized for Logic Pro's Loop Browser. Includes a README with one-click import instructions and tempo/key metadata."
        case .abletonDrumRack:
            return "Drum Rack preset (.adg) with all samples mapped to pads starting at C1. Drag into Live's Session or Arrangement view."
        case .exs24:
            return "Logic Sampler instrument (.exs) with each sample mapped chromatically from C3. Open directly in Logic's built-in Sampler."
        case .plainAIFF:
            return "Standard AIFF files in a named project folder. Compatible with any DAW, sampler, or sample manager."
        }
    }
}

// MARK: - Sample Pack Exporter

struct SamplePackExporter {

    let samples: [ExtractedSample]
    let songName: String
    let tempo: Double
    let format: ExportFormat

    // MARK: - Public entry point

    func export() async -> ExportResult? {
        guard !samples.isEmpty else {
            return ExportResult(successCount: 0, failCount: 0, folder: nil)
        }

        guard let parentFolder = await pickFolder() else { return nil }

        do {
            let packFolder = try createPackFolder(in: parentFolder)
            let exportedFiles = await exportAudioFiles(to: packFolder)
            let successCount = exportedFiles.count
            let failCount    = samples.count - successCount

            if successCount > 0 {
                switch format {
                case .appleLoops:
                    try generateAppleLoopsReadme(in: packFolder)
                case .abletonDrumRack:
                    try generateAbletonDrumRack(in: packFolder, files: exportedFiles)
                case .exs24:
                    try generateEXS24(in: packFolder, files: exportedFiles)
                case .plainAIFF:
                    break
                }
            }

            return ExportResult(successCount: successCount, failCount: failCount, folder: packFolder)
        } catch {
            print("❌ Export error: \(error)")
            return ExportResult(successCount: 0, failCount: samples.count, folder: nil)
        }
    }

    // MARK: - Folder picking (main thread)

    @MainActor
    private func pickFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.canChooseFiles       = false
        panel.prompt  = "Export Here"
        panel.title   = "Choose Export Location"
        panel.message = "A \"\(packFolderName)\" folder will be created here."
        return panel.runModal() == .OK ? panel.url : nil
    }

    // MARK: - Pack folder

    private var safeSongName: String {
        let s = songName
            .replacingOccurrences(of: "/",  with: "-")
            .replacingOccurrences(of: ":",  with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .trimmingCharacters(in: .whitespaces)
        return s.isEmpty ? "Untitled" : s
    }

    var packFolderName: String { "\(safeSongName)_LoopLifter" }

    private func createPackFolder(in parent: URL) throws -> URL {
        let folder = parent.appendingPathComponent(packFolderName)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    // MARK: - Audio file export (shared by all formats)

    private func exportAudioFiles(to folder: URL) async -> [(ExtractedSample, URL)] {
        var results: [(ExtractedSample, URL)] = []
        for sample in samples {
            guard let audioURL = sample.audioURL else { continue }
            let safeName = sample.name
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
            let outputURL = folder.appendingPathComponent("\(safeName).aiff")
            try? FileManager.default.removeItem(at: outputURL)

            let asset = AVAsset(url: audioURL)
            guard let session = AVAssetExportSession(asset: asset,
                                                      presetName: AVAssetExportPresetPassthrough)
            else { continue }

            let start = CMTime(seconds: sample.effectiveStartTime, preferredTimescale: 44100)
            let end   = CMTime(seconds: sample.effectiveEndTime,   preferredTimescale: 44100)
            session.timeRange      = CMTimeRange(start: start, end: end)
            session.outputURL      = outputURL
            session.outputFileType = .aiff
            await session.export()
            if session.status == .completed {
                results.append((sample, outputURL))
            }
        }
        return results
    }

    // MARK: - Apple Loops

    private func generateAppleLoopsReadme(in folder: URL) throws {
        let bpm = Int(tempo.rounded())
        let date = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
        let text = """
        ── \(safeSongName) · LoopLifter Sample Pack ──────────────────────────
        Tempo: \(bpm) BPM
        Exported: \(date)
        Files: \(samples.count) sample\(samples.count == 1 ? "" : "s") (AIFF)

        ── ADD TO LOGIC PRO LOOP BROWSER ───────────────────────────────────
        1.  Open Logic Pro.
        2.  Press ⌘⎇L (or View → Show Loop Browser).
        3.  Click the ⚙ gear icon at top-right of the Loop Browser.
        4.  Choose "Add Folder to Loop Library…"
        5.  Select THIS folder (\(folder.lastPathComponent)).
        6.  Your samples appear under User → \(safeSongName) in the Loop Browser.

        ── ADD TO GARAGEBAND ───────────────────────────────────────────────
        Drag the .aiff files directly onto any GarageBand audio track.

        ── USE IN ANY OTHER DAW ────────────────────────────────────────────
        The AIFF files are standard audio and work in any DAW or sampler.
        All samples are at \(bpm) BPM.

        Generated by LoopLifter · Lo Suite
        """
        let readmeURL = folder.appendingPathComponent("README – Logic Import.txt")
        try text.write(to: readmeURL, atomically: true, encoding: .utf8)
    }

    // MARK: - Ableton Drum Rack (.adg)

    private func generateAbletonDrumRack(in folder: URL,
                                          files: [(ExtractedSample, URL)]) throws {
        let padSamples = Array(files.prefix(32))
        var pads = ""
        var atomId = 10

        for (index, (sample, fileURL)) in padSamples.enumerated() {
            let midiNote = 36 + index   // C1 = 36
            let name     = xe(sample.name)
            let filename = xe(fileURL.lastPathComponent)
            let n = atomId; atomId += 8

            pads += pad(
                id: index, midiNote: midiNote,
                name: name, filename: filename,
                atomBase: n
            )
        }

        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <Ableton MajorVersion="5" MinorVersion="11.0.12.1" SchemaChangeCount="3" Creator="LoopLifter" Revision="">
          <DrumGroupDevice Id="0">
            <LomId Value="0" />
            <LomIdView Value="0" />
            <IsExpanded Value="true" />
            <On>
              <LomId Value="0" />
              <Manual Value="true" />
              <AutomationTarget Id="1"><LockEnvelope Value="0" /></AutomationTarget>
              <ModulationTarget Id="2"><LockEnvelope Value="0" /></ModulationTarget>
            </On>
            <ParameterList />
            <Preset />
            <BranchSelectorRange><Min Value="0" /><Max Value="0" /></BranchSelectorRange>
            <IsSendPreFader Value="false" />
            <ReceivingNote Value="60" />
            <PlayingNote Value="255" />
            <SelectionNote Value="36" />
            <ShowAsStereo Value="false" />
            <PlaybackMode Value="0" />
            <DrumBranchPresets>
        \(pads)
            </DrumBranchPresets>
          </DrumGroupDevice>
        </Ableton>
        """

        let xmlData  = Data(xml.utf8)
        let gzipped  = try gzipCompress(xmlData)
        let adgURL   = folder.appendingPathComponent("\(safeSongName)_LoopLifter.adg")
        try gzipped.write(to: adgURL)
    }

    // One pad's XML
    private func pad(id: Int, midiNote: Int, name: String, filename: String, atomBase n: Int) -> String {
        """
              <DrumBranchPreset Id="\(id)">
                <LomId Value="0" />
                <Name Value="\(name)" />
                <IsExpanded Value="false" />
                <On>
                  <LomId Value="0" />
                  <Manual Value="true" />
                  <AutomationTarget Id="\(n)"><LockEnvelope Value="0" /></AutomationTarget>
                  <ModulationTarget Id="\(n+1)"><LockEnvelope Value="0" /></ModulationTarget>
                </On>
                <ParameterList />
                <Preset />
                <SourceContext />
                <ZoneSettings>
                  <ReceivingNote Value="\(midiNote)" />
                  <SendingNote Value="\(midiNote)" />
                  <ChokeGroup Value="0" />
                  <VelocityRange><Min Value="1" /><Max Value="127" /></VelocityRange>
                  <FollowActionId Value="0" />
                  <IsRooted Value="true" />
                </ZoneSettings>
                <FollowAction>
                  <IsLinked Value="false" />
                  <FollowTime Value="4" />
                  <Jump><Min Value="0.1" /><Max Value="0.1" /></Jump>
                  <FollowActionA Value="4" />
                  <FollowActionB Value="0" />
                  <Probability Value="1" />
                  <LoopIterations Value="1" />
                  <Random Value="false" />
                </FollowAction>
                <Chain Name="\(name)" Color="0">
                  <Devices>
                    <OriginalSimpler Id="\(id)">
                      <LomId Value="0" />
                      <LomIdView Value="0" />
                      <IsExpanded Value="true" />
                      <On>
                        <LomId Value="0" />
                        <Manual Value="true" />
                        <AutomationTarget Id="\(n+2)"><LockEnvelope Value="0" /></AutomationTarget>
                        <ModulationTarget Id="\(n+3)"><LockEnvelope Value="0" /></ModulationTarget>
                      </On>
                      <ParameterList />
                      <Preset />
                      <Player>
                        <MultiSampleMap>
                          <UserSampleData>
                            <IsActive Value="true" />
                            <SampleRef>
                              <FileRef>
                                <HasRelativePath Value="true" />
                                <RelativePathType Value="3" />
                                <RelativePath Value="\(filename)" />
                                <Name Value="\(filename)" />
                                <Type Value="1" />
                                <LivePackName Value="" />
                                <LivePackId Value="" />
                                <OriginalFileSize Value="0" />
                                <Checksum Value="0" />
                              </FileRef>
                              <LastModDate Value="0" />
                              <SourceContext><SourceContext /></SourceContext>
                              <SampleUsageHint Value="0" />
                              <DefaultDuration Value="1" />
                              <DefaultSampleRate Value="44100" />
                            </SampleRef>
                            <SlicePoints />
                            <ManualSlicePoints />
                            <BeatGrid>
                              <Resolution Value="-1" />
                              <Offset Value="0" />
                              <Adherence Value="0" />
                              <HiddenSlices />
                            </BeatGrid>
                            <RegionLockContentPosition Value="0" />
                            <SampleStart Value="0" />
                            <SampleEnd Value="1" />
                          </UserSampleData>
                        </MultiSampleMap>
                      </Player>
                    </OriginalSimpler>
                  </Devices>
                  <MixerDevice Id="\(n+4)">
                    <LomId Value="0" />
                    <LomIdView Value="0" />
                    <IsExpanded Value="true" />
                    <On>
                      <LomId Value="0" />
                      <Manual Value="true" />
                      <AutomationTarget Id="\(n+5)"><LockEnvelope Value="0" /></AutomationTarget>
                      <ModulationTarget Id="\(n+6)"><LockEnvelope Value="0" /></ModulationTarget>
                    </On>
                    <ParameterList />
                    <Sends />
                    <Speaker>
                      <LomId Value="0" />
                      <Manual Value="true" />
                      <AutomationTarget Id="\(n+7)"><LockEnvelope Value="0" /></AutomationTarget>
                      <ModulationTarget Id="\(n+7)"><LockEnvelope Value="0" /></ModulationTarget>
                    </Speaker>
                    <SoloSink Value="false" />
                    <PanMode Value="0" />
                    <Pan>
                      <LomId Value="0" /><Manual Value="0" />
                      <AutomationTarget Id="\(n+7)"><LockEnvelope Value="0" /></AutomationTarget>
                      <ModulationTarget Id="\(n+7)"><LockEnvelope Value="0" /></ModulationTarget>
                    </Pan>
                    <SpeakerSize Value="1" />
                    <VuMeter Value="0" />
                    <Crossfader Value="0" />
                    <CrossfadeAssign Value="0" />
                    <Height Value="0" />
                  </MixerDevice>
                </Chain>
              </DrumBranchPreset>

        """
    }

    // MARK: - EXS24 / Logic Sampler (.exs)

    private func generateEXS24(in folder: URL, files: [(ExtractedSample, URL)]) throws {
        var zones = ""
        let rootNote = 60  // C3 — map each sample to its own key

        for (index, (sample, fileURL)) in files.enumerated() {
            let note     = rootNote + index
            let name     = xe(sample.name)
            let path     = xe(fileURL.path)
            let filename = xe(fileURL.lastPathComponent)
            let isLoop   = sample.category == .loop

            zones += """
                    <dict>
                        <key>ID</key>
                        <integer>\(index)</integer>
                        <key>ZoneName</key>
                        <string>\(name)</string>
                        <key>AudioFile</key>
                        <string>\(filename)</string>
                        <key>AudioFilePath</key>
                        <string>\(path)</string>
                        <key>RootKey</key>
                        <integer>\(note)</integer>
                        <key>LowKey</key>
                        <integer>\(note)</integer>
                        <key>HighKey</key>
                        <integer>\(note)</integer>
                        <key>LowVelocity</key>
                        <integer>1</integer>
                        <key>HighVelocity</key>
                        <integer>127</integer>
                        <key>Volume</key>
                        <real>0.0</real>
                        <key>Pan</key>
                        <real>0.0</real>
                        <key>SampleStart</key>
                        <integer>0</integer>
                        <key>SampleEnd</key>
                        <integer>-1</integer>
                        <key>LoopEnabled</key>
                        <\(isLoop ? "true" : "false")/>
                        <key>OneShot</key>
                        <\(isLoop ? "false" : "true")/>
                        <key>GroupIndex</key>
                        <integer>0</integer>
                    </dict>

            """
        }

        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Zones</key>
            <array>
        \(zones)    </array>
            <key>Groups</key>
            <array>
                <dict>
                    <key>ID</key>
                    <integer>0</integer>
                    <key>Name</key>
                    <string>All Samples</string>
                </dict>
            </array>
        </dict>
        </plist>
        """

        let exsURL = folder.appendingPathComponent("\(safeSongName)_LoopLifter.exs")
        try plist.write(to: exsURL, atomically: true, encoding: .utf8)
    }

    // MARK: - Gzip (pure Swift — strips zlib header, wraps in gzip container)

    private func gzipCompress(_ data: Data) throws -> Data {
        // NSData.compressed(.zlib) = 2-byte zlib header + DEFLATE bitstream + 4-byte Adler-32
        let zlibWrapped = try (data as NSData).compressed(using: .zlib) as Data
        let rawDeflate  = zlibWrapped.dropFirst(2).dropLast(4)

        var out = Data(capacity: 10 + rawDeflate.count + 8)
        // Gzip header (RFC 1952)
        out.append(contentsOf: [0x1F, 0x8B,  // Magic
                                 0x08,         // Deflate
                                 0x00,         // Flags (no name)
                                 0x00, 0x00, 0x00, 0x00,  // mtime
                                 0x00,         // xfl
                                 0xFF])        // OS: unknown
        out.append(contentsOf: rawDeflate)

        // CRC-32 of original data (little-endian)
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB8_8320 : crc >> 1
            }
        }
        crc = ~crc
        withUnsafeBytes(of: crc.littleEndian) { out.append(contentsOf: $0) }

        // ISIZE: original size mod 2^32 (little-endian)
        let isize = UInt32(truncatingIfNeeded: data.count)
        withUnsafeBytes(of: isize.littleEndian) { out.append(contentsOf: $0) }

        return out
    }

    // MARK: - XML helpers

    private func xe(_ s: String) -> String {
        s.replacingOccurrences(of: "&",  with: "&amp;")
         .replacingOccurrences(of: "<",  with: "&lt;")
         .replacingOccurrences(of: ">",  with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
