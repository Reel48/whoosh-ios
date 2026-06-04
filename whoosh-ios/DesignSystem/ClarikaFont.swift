import SwiftUI
import CoreText
import UIKit

/// Clarika Pro typography for the app: Geometric for titles/display, Grotesque
/// for body/UI. Fonts are bundled (whoosh-ios/Fonts) and registered at launch
/// via CTFontManager (the target uses a generated Info.plist, so there's no
/// UIAppFonts list). Use `Font.ck(_:_:)` everywhere; numerals stay on the
/// system font (`.monospacedDigit()`) until licensed Clarika with tabular
/// figures lands.
///
/// LICENSE: the bundled files are Fontspring DEMO (evaluation only, ~96 glyphs).
/// Swap in licensed Clarika Pro before release — update the PostScript names in
/// `PSName` below and replace whoosh-ios/Fonts/*.otf (same filenames). This enum
/// is the ONE place the app references the font names.
enum ClarikaFont {
    /// PostScript names of the bundled weights — the single source of truth.
    enum PSName {
        static let geoMedium = "FONTSPRINGDEMO-ClarikaProGeometricMediumRegular"
        static let geoBold   = "FONTSPRINGDEMO-ClarikaProGeometricBold"
        static let geoHeavy  = "FONTSPRINGDEMO-ClarikaProGeometricHeavyRegular"
        static let geoBlack  = "FONTSPRINGDEMO-ClarikaProGeometricBlackRegular"
        static let grotRegular  = "FONTSPRINGDEMO-ClarikaProGrotesqueRegular"
        static let grotMedium   = "FONTSPRINGDEMO-ClarikaProGrotesqueMediumRegular"
        static let grotDemibold = "FONTSPRINGDEMO-ClarikaProGrotesqueDemiRegular"
        static let grotBold     = "FONTSPRINGDEMO-ClarikaProGrotesqueBold"
    }

    enum Family { case geometric, grotesque }

    /// Register the bundled OTFs once at launch. Idempotent + best-effort.
    static func registerAll() {
        let names = [
            "ClarikaProGrotesque-Regular", "ClarikaProGrotesque-Medium",
            "ClarikaProGrotesque-Demibold", "ClarikaProGrotesque-Bold",
            "ClarikaProGeometric-Medium", "ClarikaProGeometric-Bold",
            "ClarikaProGeometric-Heavy", "ClarikaProGeometric-Black",
        ]
        for name in names {
            guard let url = Bundle.main.url(forResource: name, withExtension: "otf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    // MARK: Style → metrics

    /// Title styles render in Geometric; everything else in Grotesque.
    private static func family(for style: Font.TextStyle) -> Family {
        switch style {
        case .largeTitle, .title, .title2, .title3: return .geometric
        default: return .grotesque
        }
    }

    /// Default (Large content size) point size per text style — UIFontMetrics
    /// scales from here to the user's accessibility size.
    private static func baseSize(_ style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: return 34
        case .title: return 28
        case .title2: return 22
        case .title3: return 20
        case .headline, .body: return 17
        case .callout: return 16
        case .subheadline: return 15
        case .footnote: return 13
        case .caption: return 12
        case .caption2: return 11
        @unknown default: return 17
        }
    }

    private static func uiStyle(_ style: Font.TextStyle) -> UIFont.TextStyle {
        switch style {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .body: return .body
        case .callout: return .callout
        case .subheadline: return .subheadline
        case .footnote: return .footnote
        case .caption: return .caption1
        case .caption2: return .caption2
        @unknown default: return .body
        }
    }

    /// Default weight when a call site doesn't specify one.
    private static func defaultWeight(_ style: Font.TextStyle) -> Font.Weight {
        switch style {
        case .largeTitle, .title, .title2: return .black
        case .title3: return .bold
        case .headline: return .semibold
        default: return .regular
        }
    }

    /// Pick the nearest bundled PostScript name for a family + weight.
    private static func psName(_ family: Family, _ weight: Font.Weight) -> String {
        switch family {
        case .geometric:
            switch weight {
            case .ultraLight, .thin, .light, .regular, .medium: return PSName.geoMedium
            case .semibold, .bold: return PSName.geoBold
            case .heavy: return PSName.geoHeavy
            case .black: return PSName.geoBlack
            default: return PSName.geoBold
            }
        case .grotesque:
            switch weight {
            case .ultraLight, .thin, .light, .regular: return PSName.grotRegular
            case .medium: return PSName.grotMedium
            case .semibold: return PSName.grotDemibold
            case .bold, .heavy, .black: return PSName.grotBold
            default: return PSName.grotRegular
            }
        }
    }

    /// Clarika font for a text style (+ optional weight), Dynamic-Type-scaled.
    static func font(_ style: Font.TextStyle, weight: Font.Weight? = nil) -> Font {
        let fam = family(for: style)
        let w = weight ?? defaultWeight(style)
        let size = baseSize(style)
        guard let base = UIFont(name: psName(fam, w), size: size) else {
            // Fonts not registered yet / missing — fall back to the system style.
            return weight.map { Font.system(style).weight($0) } ?? Font.system(style)
        }
        let scaled = UIFontMetrics(forTextStyle: uiStyle(style)).scaledFont(for: base)
        return Font(scaled)
    }
}

extension Font {
    /// Clarika, Dynamic-Type-scaled. Geometric for title styles, Grotesque
    /// otherwise. Drop-in for `.font(.body)` → `.font(.ck(.body))`.
    static func ck(_ style: Font.TextStyle, _ weight: Font.Weight? = nil) -> Font {
        ClarikaFont.font(style, weight: weight)
    }
}
