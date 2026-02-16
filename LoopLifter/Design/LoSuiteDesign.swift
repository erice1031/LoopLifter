//
//  LoSuiteDesign.swift
//  LoopLifter
//
//  Lo Suite Design System v1.0
//  Dark studio minimal with subtle AI precision
//

import SwiftUI

// MARK: - Design Tokens

enum LoSuite {

    // MARK: - Colors

    enum Colors {
        // Base Palette
        static let backgroundPrimary = Color(hex: "0E1014")
        static let panelSurface = Color(hex: "151821")
        static let elevatedSurface = Color(hex: "1C202B")
        static let bordersDividers = Color(hex: "272C38")
        static let textPrimary = Color(hex: "E6E8ED")
        static let textSecondary = Color(hex: "9CA3AF")
        static let disabled = Color(hex: "4B5563")

        // LoopLifter Accent
        static let accent = Color(hex: "7C5CFF")
        static let accentGlow = Color(hex: "7C5CFF").opacity(0.25)

        // Stem Colors (consistent with LoOptimizer)
        static let drums = Color(hex: "FF9500")   // Orange
        static let bass = Color(hex: "AF52DE")    // Purple
        static let vocals = Color(hex: "30D158")  // Green
        static let other = Color(hex: "0A84FF")   // Blue

        // Waveform
        static let waveformInactive = Color(hex: "9CA3AF").opacity(0.65)
        static let transientMarker = accent
        static let regionOverlay = accent.opacity(0.12)
        static let regionBorder = accent
    }

    // MARK: - Spacing

    enum Spacing {
        static let grid: CGFloat = 8
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    // MARK: - Corner Radius

    enum Radius {
        static let small: CGFloat = 6
        static let medium: CGFloat = 8
        static let large: CGFloat = 10
        static let xl: CGFloat = 12
    }

    // MARK: - Typography Sizes

    enum Typography {
        static let caption2: CGFloat = 10
        static let caption: CGFloat = 11
        static let body: CGFloat = 13
        static let headline: CGFloat = 15
        static let title3: CGFloat = 17
        static let title2: CGFloat = 20
    }

    // MARK: - Component Sizes

    enum Components {
        // Knobs
        static let knobDiameter: CGFloat = 36
        static let knobTrackWidth: CGFloat = 2
        static let knobIndicatorWidth: CGFloat = 2

        // Asset Tiles
        static let tileWidth: CGFloat = 160
        static let tileHeight: CGFloat = 110
        static let tileGap: CGFloat = 12

        // Buttons
        static let buttonCornerRadius: CGFloat = 10
        static let buttonPaddingH: CGFloat = 18
        static let buttonPaddingV: CGFloat = 10

        // Waveform
        static let waveformHeight: CGFloat = 140
        static let miniWaveformHeight: CGFloat = 32

        // Panels
        static let panelPadding: CGFloat = 16
    }

    // MARK: - Animation

    enum Animation {
        static let quick: Double = 0.12
        static let standard: Double = 0.18
        static let easing = SwiftUI.Animation.easeOut(duration: standard)
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Stem Colors
// Note: To use these with StemType, add an extension in your view file:
// extension StemType {
//     var designColor: Color {
//         switch self {
//         case .drums: return LoSuite.Colors.drums
//         case .bass: return LoSuite.Colors.bass
//         case .vocals: return LoSuite.Colors.vocals
//         case .other: return LoSuite.Colors.other
//         }
//     }
// }

// MARK: - View Modifiers

struct LoSuitePanelStyle: ViewModifier {
    var elevated: Bool = false

    func body(content: Content) -> some View {
        content
            .background(elevated ? LoSuite.Colors.elevatedSurface : LoSuite.Colors.panelSurface)
            .clipShape(RoundedRectangle(cornerRadius: LoSuite.Radius.xl))
    }
}

struct LoSuiteCardStyle: ViewModifier {
    var isSelected: Bool = false
    var accentColor: Color = LoSuite.Colors.accent

    func body(content: Content) -> some View {
        content
            .background(isSelected ? LoSuite.Colors.elevatedSurface : LoSuite.Colors.panelSurface)
            .clipShape(RoundedRectangle(cornerRadius: LoSuite.Radius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: LoSuite.Radius.medium)
                    .stroke(isSelected ? accentColor : LoSuite.Colors.bordersDividers, lineWidth: 1)
            )
    }
}

struct LoSuitePrimaryButtonStyle: ButtonStyle {
    var accentColor: Color = LoSuite.Colors.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: LoSuite.Typography.body, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, LoSuite.Components.buttonPaddingH)
            .padding(.vertical, LoSuite.Components.buttonPaddingV)
            .background(
                RoundedRectangle(cornerRadius: LoSuite.Components.buttonCornerRadius)
                    .fill(accentColor)
                    .brightness(configuration.isPressed ? -0.08 : 0)
            )
            .animation(LoSuite.Animation.easing, value: configuration.isPressed)
    }
}

struct LoSuiteSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: LoSuite.Typography.body, weight: .medium))
            .foregroundColor(LoSuite.Colors.textPrimary)
            .padding(.horizontal, LoSuite.Components.buttonPaddingH)
            .padding(.vertical, LoSuite.Components.buttonPaddingV)
            .background(
                RoundedRectangle(cornerRadius: LoSuite.Components.buttonCornerRadius)
                    .fill(configuration.isPressed ? LoSuite.Colors.panelSurface : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: LoSuite.Components.buttonCornerRadius)
                    .stroke(LoSuite.Colors.bordersDividers, lineWidth: 1)
            )
            .animation(LoSuite.Animation.easing, value: configuration.isPressed)
    }
}

// MARK: - View Extensions

extension View {
    func loSuitePanel(elevated: Bool = false) -> some View {
        modifier(LoSuitePanelStyle(elevated: elevated))
    }

    func loSuiteCard(isSelected: Bool = false, accentColor: Color = LoSuite.Colors.accent) -> some View {
        modifier(LoSuiteCardStyle(isSelected: isSelected, accentColor: accentColor))
    }
}
