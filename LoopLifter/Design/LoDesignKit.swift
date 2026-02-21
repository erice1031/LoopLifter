//
//  LoDesignKit.swift
//  LoopLifter
//
//  Lo Suite design tokens — generated from LoDesignKit_v1_swiftui_tokens.json
//  Platform: macOS 14.0+ / SwiftUI
//
//  Single source of truth for colors, spacing, radii, typography, motion, and effects
//  across all Lo Suite apps. Add this file to any target that needs these tokens.
//

import SwiftUI

// MARK: - Color Hex Initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

// MARK: - LoSuite Design Tokens

enum LoSuite {

    // MARK: Colors
    // Source: tokens.color.base + tokens.color.accent.looplifter

    enum Colors {
        // Base palette
        static let backgroundPrimary = Color(hex: "0E1014")   // appBackground
        static let panelSurface      = Color(hex: "151821")   // surfacePanel / panelBackground
        static let elevatedSurface   = Color(hex: "1C202B")   // surfaceElevated / panelElevated
        static let bordersDividers   = Color(hex: "272C38")   // divider / separator
        static let textPrimary       = Color(hex: "E6E8ED")   // primaryText
        static let textSecondary     = Color(hex: "9CA3AF")   // secondaryText
        static let disabled          = Color(hex: "4B5563")   // disabledText

        // LoopLifter accent (tokens.color.accent.looplifter)
        static let accent            = Color(hex: "7C5CFF")
        static let accentGlow        = Color(hex: "7C5CFF").opacity(0.25)  // glowRGBA
    }

    // MARK: Spacing
    // Source: tokens.layout.grid (base = 8pt grid)

    enum Spacing {
        static let xs: CGFloat = 4    // half-step (not in spec, kept for existing usage)
        static let sm: CGFloat = 8    // base grid unit
        static let md: CGFloat = 16   // panelPadding
        static let lg: CGFloat = 24   // sectionGap
        static let controlGap: CGFloat = 12    // controlGap
        static let labelMin:   CGFloat = 8     // labelToControlMin
    }

    // MARK: Radii
    // Source: tokens.layout.radii

    enum Radius {
        // Canonical names (JSON)
        static let sm: CGFloat = 8
        static let md: CGFloat = 10
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16

        // Legacy aliases — map to nearest JSON value
        static let small:  CGFloat = sm   // was 6, updated to 8
        static let medium: CGFloat = md   // was 8, updated to 10
        static let large:  CGFloat = lg   // was 10, updated to 12
    }

    // MARK: Typography
    // Source: tokens.typography.styles
    // All use SF Pro (system font); monospaced variant for numeric readouts.

    enum Typography {
        // Canonical styles (JSON)
        static let h1:         CGFloat = 22   // h1Section — semibold
        static let h2:         CGFloat = 16   // h2PanelTitle — semibold
        static let body:       CGFloat = 13   // body — regular
        static let labelSmall: CGFloat = 12   // labelSmall — medium weight
        static let monoData:   CGFloat = 11   // monoData — regular, monospaced

        // Legacy aliases (kept for existing call sites)
        static let caption:    CGFloat = monoData   // 11pt
        static let caption2:   CGFloat = 10         // sub-caption, not in JSON spec
    }

    // MARK: Motion
    // Source: tokens.motion.durationMs + tokens.motion.curve
    // Rule: easeOut only — no bounce, no exaggerated scaling.

    enum Motion {
        static let fast:   Animation = .easeOut(duration: 0.12)
        static let normal: Animation = .easeOut(duration: 0.15)
        static let slow:   Animation = .easeOut(duration: 0.18)
    }

    // MARK: Shadow
    // Source: tokens.effects.shadow

    enum Shadow {
        // Subtle — default resting state
        static let subtleOpacity: Double  = 0.10
        static let subtleRadius:  CGFloat = 10
        static let subtleY:       CGFloat = 2

        // Lifted — hover / selected state
        static let liftedOpacity: Double  = 0.12
        static let liftedRadius:  CGFloat = 14
        static let liftedY:       CGFloat = 6
    }

    // MARK: Glow
    // Source: tokens.effects.glow

    enum Glow {
        // Inner glow (background ambient)
        static let innerOpacity: Double  = 0.20
        static let innerRadius:  CGFloat = 40

        // Tile selected glow
        static let selectedOpacity: Double  = 0.15
        static let selectedRadius:  CGFloat = 12
    }
}

// MARK: - StemType Design Colors

extension StemType {
    var designColor: Color {
        switch self {
        case .drums:  return Color(hex: "FF9500")
        case .bass:   return Color(hex: "AF52DE")
        case .vocals: return Color(hex: "30D158")
        case .other:  return Color(hex: "0A84FF")
        }
    }
}
