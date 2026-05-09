import Foundation
import SwiftUI
import Combine

fileprivate struct GVThemeDynamicColor {
    let light: UIColor
    let dark: UIColor

    func uiColor() -> UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        }
    }

    func color() -> Color {
        Color(uiColor())
    }

    func resolvedColor(for colorScheme: ColorScheme) -> Color {
        Color(uiColor: colorScheme == .dark ? dark : light)
    }
}

fileprivate struct GVThemePalette {
    let background: GVThemeDynamicColor
    let secondaryBackground: GVThemeDynamicColor
    let surface: GVThemeDynamicColor
    let surfaceEmphasis: GVThemeDynamicColor
    let infoBackground: GVThemeDynamicColor
    let alertBackground: GVThemeDynamicColor
    let alertForeground: GVThemeDynamicColor
    let tabBackground: GVThemeDynamicColor
    let tabSelectedForeground: GVThemeDynamicColor
    let tabUnselectedForeground: GVThemeDynamicColor
    let tabBackgroundEmphasis: GVThemeDynamicColor
    let navigationInteractive: GVThemeDynamicColor
    let border: GVThemeDynamicColor
    let accent: GVThemeDynamicColor
    let supportingText: GVThemeDynamicColor
}

struct GVThemeColors {
    private let palette: GVThemePalette

    fileprivate init(palette: GVThemePalette) {
        self.palette = palette
    }

    var background: Color { palette.background.color() }
    var secondaryBackground: Color { palette.secondaryBackground.color() }
    var surface: Color { palette.surface.color() }
    var surfaceEmphasis: Color { palette.surfaceEmphasis.color() }
    var infoBackground: Color { palette.infoBackground.color() }
    var alertBackground: Color { palette.alertBackground.color() }
    var alertForeground: Color { palette.alertForeground.color() }
    var tabBackground: Color { palette.tabBackground.color() }
    var tabSelectedForeground: Color { palette.tabSelectedForeground.color() }
    var tabUnselectedForeground: Color { palette.tabUnselectedForeground.color() }
    var tabBackgroundEmphasis: Color { palette.tabBackgroundEmphasis.color() }
    var navigationInteractive: Color { palette.navigationInteractive.color() }
    var border: Color { palette.border.color() }
    var accent: Color { palette.accent.color() }
    var supportingText: Color { palette.supportingText.color() }

    func surface(for colorScheme: ColorScheme) -> Color { palette.surface.resolvedColor(for: colorScheme) }

    var tabBackgroundUIColor: UIColor { palette.tabBackground.uiColor() }
    var tabSelectedForegroundUIColor: UIColor { palette.tabSelectedForeground.uiColor() }
    var tabUnselectedForegroundUIColor: UIColor { palette.tabUnselectedForeground.uiColor() }
    var tabBackgroundEmphasisUIColor: UIColor { palette.tabBackgroundEmphasis.uiColor() }
}

enum GVTheme: String, CaseIterable, Identifiable, Codable, Hashable {
    case silver
    case earth

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .earth:
            return String(
                localized: "theme.earth",
                defaultValue: "Earth",
                bundle: .main
            )
        case .silver:
            return String(
                localized: "theme.silver",
                defaultValue: "Silver",
                bundle: .main
            )
        }
    }

    fileprivate var palette: GVThemePalette {
        switch self {
        case .earth:
            return GVThemePalette(
                background: .init(light: rgb(0.86, 0.82, 0.63), dark: rgb(0.06, 0.14, 0.10)),
                secondaryBackground: .init(light: rgb(0.87, 0.90, 0.71), dark: rgb(0.09, 0.21, 0.15)),
                surface: .init(light: rgb(0.68, 0.76, 0.47), dark: rgb(0.13, 0.28, 0.20)),
                surfaceEmphasis: .init(light: rgb(0.66, 0.52, 0.40), dark: rgb(0.32, 0.56, 0.44)),
                infoBackground: .init(light: rgb(0.91, 0.93, 0.75), dark: rgb(0.12, 0.30, 0.21)),
                alertBackground: .init(light: rgb(0.82, 0.72, 0.60), dark: rgb(0.16, 0.38, 0.27)),
                alertForeground: .init(light: rgb(0.42, 0.35, 0.30), dark: rgb(0.82, 0.95, 0.83)),
                tabBackground: .init(light: rgb(0.66, 0.52, 0.40), dark: rgb(0.08, 0.20, 0.14)),
                tabSelectedForeground: .init(light: rgb(0.95, 0.97, 0.92), dark: rgb(0.82, 0.95, 0.83)),
                tabUnselectedForeground: .init(light: rgb(0.87, 0.82, 0.72), dark: rgb(0.53, 0.67, 0.58)),
                tabBackgroundEmphasis: .init(light: rgb(0.52, 0.40, 0.31), dark: rgb(0.08, 0.20, 0.14)),
                navigationInteractive: .init(light: rgb(0.33, 0.47, 0.31), dark: rgb(0.60, 0.79, 0.65)),
                border: .init(light: rgb(0.42, 0.34, 0.30), dark: rgb(0.25, 0.47, 0.32)),
                accent: .init(light: rgb(0.24, 0.46, 0.27), dark: rgb(0.33, 0.64, 0.39)),
                supportingText: .init(light: rgb(0.19, 0.28, 0.21), dark: rgb(0.74, 0.89, 0.77))
            )
        case .silver:
            return GVThemePalette(
                background: .init(light: rgb(0.90, 0.91, 0.94), dark: rgb(0.14, 0.15, 0.17)),
                secondaryBackground: .init(light: rgb(0.95, 0.95, 0.97), dark: rgb(0.18, 0.19, 0.21)),
                surface: .init(light: rgb(0.82, 0.84, 0.88), dark: rgb(0.22, 0.23, 0.26)),
                surfaceEmphasis: .init(light: rgb(0.66, 0.68, 0.72), dark: rgb(0.46, 0.48, 0.52)),
                infoBackground: .init(light: rgb(0.88, 0.90, 0.92), dark: rgb(0.24, 0.26, 0.29)),
                alertBackground: .init(light: rgb(0.74, 0.76, 0.80), dark: rgb(0.34, 0.36, 0.40)),
                alertForeground: .init(light: rgb(0.35, 0.36, 0.38), dark: rgb(0.88, 0.90, 0.94)),
                tabBackground: .init(light: rgb(0.32, 0.34, 0.38), dark: rgb(0.20, 0.22, 0.25)),
                tabSelectedForeground: .init(light: rgb(0.96, 0.97, 0.99), dark: rgb(0.88, 0.90, 0.94)),
                tabUnselectedForeground: .init(light: rgb(0.72, 0.74, 0.78), dark: rgb(0.65, 0.67, 0.70)),
                tabBackgroundEmphasis: .init(light: rgb(0.24, 0.26, 0.29), dark: rgb(0.16, 0.17, 0.20)),
                navigationInteractive: .init(light: rgb(0.34, 0.44, 0.68), dark: rgb(0.62, 0.71, 0.85)),
                border: .init(light: rgb(0.55, 0.56, 0.60), dark: rgb(0.40, 0.42, 0.46)),
                accent: .init(light: rgb(0.45, 0.47, 0.52), dark: rgb(0.70, 0.72, 0.78)),
                supportingText: .init(light: rgb(0.33, 0.34, 0.38), dark: rgb(0.78, 0.80, 0.84))
            )
        }
    }
}

final class GVThemeManager: ObservableObject {
    private static let storageKey = "GVThemeSelection"

    private let userDefaults: UserDefaults?

    @Published var theme: GVTheme {
        didSet {
            guard oldValue != theme else { return }
            persist(theme)
        }
    }

    init(initialTheme: GVTheme = .silver, userDefaults: UserDefaults? = .standard) {
        self.userDefaults = userDefaults
        if let raw = userDefaults?.string(forKey: Self.storageKey),
           let stored = GVTheme(rawValue: raw) {
            theme = stored
        } else {
            theme = initialTheme
        }
    }

    var colors: GVThemeColors {
        GVThemeColors(palette: theme.palette)
    }

    func select(_ theme: GVTheme) {
        guard self.theme != theme else { return }
        self.theme = theme
    }

    private func persist(_ theme: GVTheme) {
        userDefaults?.set(theme.rawValue, forKey: Self.storageKey)
    }
}

private func rgb(_ red: Double, _ green: Double, _ blue: Double) -> UIColor {
    UIColor(red: red, green: green, blue: blue, alpha: 1.0)
}
