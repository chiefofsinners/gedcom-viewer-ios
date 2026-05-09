import Foundation
import SwiftUI

struct HomeSettingsView: View {
    @EnvironmentObject private var themeManager: GVThemeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = themeManager.colors

        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    SettingsSection(title: "settings.sections.appearance", colors: colors) {
                        ThemeSelector(colors: colors)
                    }
                }
                .padding(20)
            }
            .background(colors.background.ignoresSafeArea())
            .navigationTitle("settings.title")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("general.done") {
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                }
            }
            .toolbarBackground(colors.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
            .tint(colors.accent)
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: LocalizedStringKey
    let colors: GVThemeColors
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.primary)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(colors.border.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 12, y: 4)
    }
}

private struct ThemeSelector: View {
    let colors: GVThemeColors
    @EnvironmentObject private var themeManager: GVThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("settings.theme.label")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.secondary)

            HStack(spacing: 12) {
                ForEach(GVTheme.allCases) { theme in
                    ThemeOptionButton(theme: theme, colors: colors)
                }
            }
        }
    }
}

private struct ThemeOptionButton: View {
    let theme: GVTheme
    let colors: GVThemeColors
    @EnvironmentObject private var themeManager: GVThemeManager

    private var isSelected: Bool {
        themeManager.theme == theme
    }

    var body: some View {
        Button {
            guard !isSelected else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
                themeManager.select(theme)
            }
        } label: {
            Text(theme.displayName)
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14) // slightly taller than default segmented control
                .foregroundStyle(isSelected ? colors.background : Color.primary)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isSelected ? colors.accent : colors.secondaryBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isSelected ? colors.accent : colors.border.opacity(0.4), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            Text(
                String(
                    format: Bundle.main.localizedString(
                        forKey: "settings.theme.option_accessibility",
                        value: "%@ theme",
                        table: nil
                    ),
                    theme.displayName
                )
            )
        )
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#if DEBUG
struct HomeSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            HomeSettingsView()
                .environmentObject(GVThemeManager(initialTheme: .earth, userDefaults: nil))

            HomeSettingsView()
                .environmentObject(GVThemeManager(initialTheme: .silver, userDefaults: nil))
                .preferredColorScheme(.dark)
        }
    }
}
#endif
