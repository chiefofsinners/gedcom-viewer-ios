import SwiftUI

struct HomeTabView: View {
    @EnvironmentObject private var themeManager: GVThemeManager
    @State private var showingSettings = false
    let state: GedcomUIState
    let onBrowseFiles: () -> Void
    let onLoadSample: () -> Void
    let onOpenIndex: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let colors = themeManager.colors
            let isLandscape = geometry.size.width > geometry.size.height
            let bottomPadding = geometry.safeAreaInsets.bottom + HomeLayout.bottomInset

            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text("home.header.title")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.center)
                    Text("home.header.subtitle")
                        .font(.body)
                        .foregroundStyle(Color.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: isLandscape ? 420 : 480)

                if let error = state.error {
                    MessageCard(text: error, style: .error)
                        .frame(maxWidth: isLandscape ? 360 : 420)
                        .frame(maxWidth: .infinity)
                }

                VStack(spacing: 16) {
                    PrimaryButton(
                        title: "home.action.browse",
                        action: onBrowseFiles,
                        isLoading: state.isLoading,
                        accessibilityIdentifier: "home.browse.button"
                    )
                    SecondaryButton(
                        title: "home.action.load_sample",
                        action: onLoadSample,
                        disabled: state.isLoading,
                        accessibilityIdentifier: "home.load_sample.button"
                    )
                    SecondaryButton(
                        title: "home.action.settings",
                        action: { showingSettings = true },
                        accessibilityIdentifier: "home.settings.button"
                    )
                }
                .frame(maxWidth: isLandscape ? 320 : 420)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 32)
            .padding(.top, 24)
            .padding(.bottom, bottomPadding)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: geometry.size.height > 400 ? .center : .top
            )
            .background(colors.background)
            .sheet(isPresented: $showingSettings) {
                HomeSettingsView()
                    .environmentObject(themeManager)
            }
        }
    }
}

private enum HomeLayout {
    static let bottomInset: CGFloat = 24
}

#if DEBUG
struct HomeTabView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            HomeTabView(
                state: previewState(),
                onBrowseFiles: {},
                onLoadSample: {},
                onOpenIndex: {}
            )
            .environmentObject(GVThemeManager(initialTheme: .earth, userDefaults: nil))
            .previewDisplayName("Home – Default")

            HomeTabView(
                state: previewState(isLoading: true),
                onBrowseFiles: {},
                onLoadSample: {},
                onOpenIndex: {}
            )
            .environmentObject(GVThemeManager(initialTheme: .earth, userDefaults: nil))
            .previewDisplayName("Home – Loading")

            HomeTabView(
                state: previewState(error: "Unable to parse GEDCOM file. Please try another file."),
                onBrowseFiles: {},
                onLoadSample: {},
                onOpenIndex: {}
            )
            .environmentObject(GVThemeManager(initialTheme: .earth, userDefaults: nil))
            .previewDisplayName("Home – Error")
        }
    }

    private static func previewState(isLoading: Bool = false, error: String? = nil) -> GedcomUIState {
        var state = GedcomUIState()
        state.isLoading = isLoading
        state.error = error
        return state
    }
}
#endif
