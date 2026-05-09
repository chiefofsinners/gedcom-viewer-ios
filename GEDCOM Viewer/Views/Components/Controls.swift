import SwiftUI

struct PrimaryButton: View {
    @EnvironmentObject private var themeManager: GVThemeManager
    let title: LocalizedStringKey
    let action: () -> Void
    var isLoading: Bool = false
    var accessibilityIdentifier: String? = nil

    var body: some View {
        let colors = themeManager.colors

        Button(action: action) {
            ZStack {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(colors.background)
                    .opacity(isLoading ? 0 : 1)

                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(colors.surfaceEmphasis)
        .disabled(isLoading)
        .applyAccessibilityIdentifier(accessibilityIdentifier)
    }
}

struct SecondaryButton: View {
    @EnvironmentObject private var themeManager: GVThemeManager
    let title: LocalizedStringKey
    let action: () -> Void
    var disabled: Bool = false
    var accessibilityIdentifier: String? = nil

    var body: some View {
        let colors = themeManager.colors

        Button(action: action) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(colors.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .tint(colors.accent)
        .disabled(disabled)
        .applyAccessibilityIdentifier(accessibilityIdentifier)
    }
}

struct MessageCard: View {
    @EnvironmentObject private var themeManager: GVThemeManager

    enum Style {
        case info
        case error

        func background(using colors: GVThemeColors) -> Color {
            switch self {
            case .info:
                return colors.infoBackground
            case .error:
                return colors.alertBackground
            }
        }

        func foreground(using colors: GVThemeColors) -> Color {
            switch self {
            case .info:
                return Color.primary
            case .error:
                return colors.alertForeground
            }
        }
    }

    let text: String
    var style: Style = .info

    var body: some View {
        let colors = themeManager.colors

        Text(text)
            .font(.callout)
            .foregroundStyle(style.foreground(using: colors))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(style.background(using: colors))
            )
    }
}

private extension View {
    @ViewBuilder
    func applyAccessibilityIdentifier(_ identifier: String?) -> some View {
        if let identifier {
            self.accessibilityIdentifier(identifier)
        } else {
            self
        }
    }
}
