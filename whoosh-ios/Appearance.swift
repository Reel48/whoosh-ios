import SwiftUI

/// The user's appearance preference, persisted via `@AppStorage("appearance")`.
/// `system` follows the device; `light`/`dark` force that scheme app-wide.
/// Applied once at the root (`whoosh_iosApp`) via `.preferredColorScheme`.
enum AppearancePref: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    /// nil = follow the device; otherwise force the scheme.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
