//
//  ExportSheet.swift
//  LoopLifter
//
//  Modal sheet for choosing export format before running the export.
//

import SwiftUI

struct ExportSheet: View {
    let samples: [ExtractedSample]
    let songName: String
    let tempo: Double
    var onExport: (ExportFormat) async -> ExportResult?
    var onCancel: () -> Void

    @State private var selectedFormat: ExportFormat = .appleLoops
    @State private var isExporting = false
    @State private var exportResult: ExportResult? = nil
    @State private var showResult = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ────────────────────────────────────────────────────
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Export Sample Pack")
                        .font(.system(size: LoSuite.Typography.h2, weight: .semibold))
                        .foregroundColor(LoSuite.Colors.textPrimary)
                    Text("\(samples.count) sample\(samples.count == 1 ? "" : "s") · \(songName) · \(Int(tempo.rounded())) BPM")
                        .font(.system(size: LoSuite.Typography.monoData, design: .monospaced))
                        .foregroundColor(LoSuite.Colors.textSecondary)
                }
                Spacer()
                Button { onCancel(); dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(LoSuite.Colors.textSecondary)
                        .frame(width: 24, height: 24)
                        .background(LoSuite.Colors.elevatedSurface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, LoSuite.Spacing.lg)
            .padding(.top, LoSuite.Spacing.lg)
            .padding(.bottom, LoSuite.Spacing.md)

            Divider()
                .background(LoSuite.Colors.bordersDividers)

            // ── Format cards ──────────────────────────────────────────────
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: LoSuite.Spacing.sm) {
                    ForEach(ExportFormat.allCases) { format in
                        formatCard(format)
                    }
                }
                .padding(.horizontal, LoSuite.Spacing.lg)
                .padding(.vertical, LoSuite.Spacing.md)
            }

            Divider()
                .background(LoSuite.Colors.bordersDividers)

            // ── Footer: pack folder preview + actions ─────────────────────
            VStack(spacing: LoSuite.Spacing.sm) {
                // Folder preview
                let exporter = SamplePackExporter(samples: samples,
                                                   songName: songName,
                                                   tempo: tempo,
                                                   format: selectedFormat)
                HStack(spacing: LoSuite.Spacing.xs) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 11))
                        .foregroundColor(LoSuite.Colors.accent)
                    Text("Will create: ")
                        .font(.system(size: 10))
                        .foregroundColor(LoSuite.Colors.textSecondary)
                    Text(exporter.packFolderName + "/")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(LoSuite.Colors.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, LoSuite.Spacing.lg)

                // Action buttons
                HStack(spacing: LoSuite.Spacing.sm) {
                    Button("Cancel") { onCancel(); dismiss() }
                        .buttonStyle(.plain)
                        .font(.system(size: LoSuite.Typography.body))
                        .foregroundColor(LoSuite.Colors.textSecondary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(LoSuite.Colors.elevatedSurface)
                        .clipShape(RoundedRectangle(cornerRadius: LoSuite.Radius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: LoSuite.Radius.md)
                                .stroke(LoSuite.Colors.bordersDividers, lineWidth: 1)
                        )
                        .disabled(isExporting)

                    Spacer()

                    Button {
                        Task { await runExport() }
                    } label: {
                        HStack(spacing: 7) {
                            if isExporting {
                                ProgressView()
                                    .scaleEffect(0.75)
                                    .tint(.white)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            Text(isExporting ? "Exporting…" : "Export \(selectedFormat.rawValue)")
                                .font(.system(size: LoSuite.Typography.body, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 9)
                        .background(isExporting
                            ? LoSuite.Colors.accent.opacity(0.7)
                            : LoSuite.Colors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: LoSuite.Radius.md))
                    }
                    .buttonStyle(.plain)
                    .disabled(isExporting)
                }
                .padding(.horizontal, LoSuite.Spacing.lg)
            }
            .padding(.top, LoSuite.Spacing.sm)
            .padding(.bottom, LoSuite.Spacing.lg)
        }
        .frame(width: 500)
        .background(LoSuite.Colors.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: LoSuite.Radius.xl))
    }

    // MARK: - Format Card

    @ViewBuilder
    private func formatCard(_ format: ExportFormat) -> some View {
        let isSelected = selectedFormat == format
        Button { selectedFormat = format } label: {
            HStack(alignment: .top, spacing: LoSuite.Spacing.md) {
                // Icon
                Image(systemName: format.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isSelected ? LoSuite.Colors.accent : LoSuite.Colors.textSecondary)
                    .frame(width: 32, height: 32)

                // Text
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(format.rawValue)
                            .font(.system(size: LoSuite.Typography.body, weight: .semibold))
                            .foregroundColor(LoSuite.Colors.textPrimary)
                        Text(format.subtitle)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(isSelected ? LoSuite.Colors.accent : LoSuite.Colors.disabled)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background((isSelected ? LoSuite.Colors.accent : LoSuite.Colors.bordersDividers).opacity(0.15))
                            .clipShape(Capsule())
                    }
                    Text(format.detail)
                        .font(.system(size: 11))
                        .foregroundColor(LoSuite.Colors.textSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17))
                    .foregroundColor(isSelected ? LoSuite.Colors.accent : LoSuite.Colors.disabled)
                    .padding(.top, 2)
            }
            .padding(LoSuite.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: LoSuite.Radius.md)
                    .fill(isSelected ? LoSuite.Colors.accent.opacity(0.05) : LoSuite.Colors.panelSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: LoSuite.Radius.md)
                    .stroke(
                        isSelected ? LoSuite.Colors.accent.opacity(0.7) : LoSuite.Colors.bordersDividers,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .shadow(
                color: isSelected ? LoSuite.Colors.accent.opacity(0.12) : .clear,
                radius: 8, y: 2
            )
        }
        .buttonStyle(.plain)
        .animation(LoSuite.Motion.fast, value: isSelected)
    }

    // MARK: - Export action

    private func runExport() async {
        isExporting = true
        let result = await onExport(selectedFormat)
        isExporting = false
        if result != nil {
            dismiss()
        }
    }
}
