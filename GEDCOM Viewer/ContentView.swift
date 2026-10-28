import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @StateObject private var viewModel: GedcomViewModel
    @StateObject private var themeManager = GVThemeManager()
    @State private var selectedTab: AppTab
    @State private var previousTab: AppTab
    @State private var showingFileImporter = false
    @State private var importerError: IdentifiableError?
    @State private var familyScrollResetToken = UUID()
    @State private var pendingErrorClearTask: Task<Void, Never>?
    /// True between a load completing and the destination tab actually being on
    /// screen, so the loading overlay can cover that gap. See `onChange` below.
    @State private var isAwaitingLoadTab = false
    // Held here rather than in the index and family views, which are rebuilt whenever
    // the window switches between one pane and two (folding an iPhone Duo, resizing an
    // iPad window), so that switching keeps the search, scroll position and family history.
    @State private var indexBrowseState = IndexBrowseState()
    @State private var familyPath: [FamilyRoute] = []
    @State private var familyRootId: String?

    /// iPad, and iPhone Duo opened out: regular in both directions gets the tab bar
    /// along the top. Decided by size class, not device, so it follows folding.
    private var usesTopTabBar: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }

    /// With a file loaded, a window that gets the top tab bar shows the index and family
    /// side by side (split on the fold of an iPhone Duo) instead of as separate tabs.
    private var showsPanes: Bool {
        usesTopTabBar && selectedTab != .home && viewModel.state.data != nil
    }

    private var shouldApplyUIKitTabBarAppearance: Bool {
        guard UIDevice.current.userInterfaceIdiom != .pad else { return false }
        let version = ProcessInfo.processInfo.operatingSystemVersion
        if version.majorVersion <= 18 { return true }
        if version.majorVersion > 18 { return false }
        return version.minorVersion <= 5
    }

    /// Reopening the file saved from a previous launch jumps straight back to the
    /// person who was on screen last time; any other load starts at the index.
    private var tabAfterLoad: AppTab {
        viewModel.state.reopensLastViewedIndividual ? .family : .index
    }

    private var allowedContentTypes: [UTType] {
        var types: [UTType] = [.data, .text]
        if let gedType = UTType(filenameExtension: "ged") {
            types.append(gedType)
        }
        return types
    }

    init() {
        let viewModel = GedcomViewModel()
        _viewModel = StateObject(wrappedValue: viewModel)
        let shouldShowIndex = viewModel.state.data != nil || !viewModel.state.needsFileSelection
        let initialTab: AppTab = shouldShowIndex ? .index : .home
        _selectedTab = State(initialValue: initialTab)
        _previousTab = State(initialValue: initialTab)
    }

    var body: some View {
        let colors = themeManager.colors

        ZStack {
            if showsPanes {
                // Index and family side by side. As on Android, the tab bar belongs to the
                // index pane and drops Family, which is already on screen.
                ListDetailPanes {
                    VStack(spacing: 0) {
                        topTabBar(colors: colors)
                        indexTab(highlightedIndividualId: familyRootId)
                    }
                } detailPane: {
                    familyTab
                }
                .background(colors.background)
                .edgesIgnoringSafeArea(.bottom)
            } else if usesTopTabBar {
                // Regular width and height: use custom tab bar at the top
                VStack(spacing: 0) {
                    topTabBar(colors: colors)

                    Group {
                        switch selectedTab {
                        case .home:
                            homeTab
                        case .index:
                            indexTab()
                        case .family:
                            familyTab
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .background(colors.background)
                .edgesIgnoringSafeArea(.bottom)
            } else {
                // Compact width or height: use native TabView with system tab bar
                TabView(selection: $selectedTab) {
                    homeTab
                        .tag(AppTab.home)
                        .tabItem { Label("tab.home.title", systemImage: "house") }

                    indexTab()
                        .tag(AppTab.index)
                        .tabItem { Label("tab.index.title", systemImage: "list.bullet") }

                    familyTab
                        .tag(AppTab.family)
                        .tabItem { Label("tab.family.title", systemImage: "person.2") }
                }
                .tint(colors.accent)
                //.toolbarBackground(colors.tabBackground, for: .tabBar)
                //.toolbarBackground(.visible, for: .tabBar)
            }

            // Mounted only while loading: a ProgressView kept in the hierarchy at
            // zero opacity still animates, which keeps CoreAnimation committing
            // frames for the whole session. Appearance is unanimated either way,
            // so this matches the previous behaviour on screen.
            if viewModel.state.isLoading || isAwaitingLoadTab {
                LoadingOverlay()
                    .zIndex(2)
            }
        }
        .onAppear {
            applyTabBarAppearanceIfNeeded(with: themeManager.colors)
        }
        .onChange(of: colorScheme) { _ in
            applyTabBarAppearanceIfNeeded(with: themeManager.colors)
        }
        .onChange(of: themeManager.theme) { _ in
            applyTabBarAppearanceIfNeeded(with: themeManager.colors)
        }
        .onChange(of: viewModel.state.needsFileSelection) { needsSelection in
            guard needsSelection else { return }
            if viewModel.state.error == nil {
                updateSelectedTab(.home, animated: false)
            }
        }
        .onChange(of: viewModel.state.data) { data in
            guard data != nil else { return }
            if !viewModel.state.needsFileSelection && viewModel.state.error == nil {
                updateSelectedTab(tabAfterLoad, animated: false)
            }
        }
        .onChange(of: selectedTab) { newTab in
            pendingErrorClearTask?.cancel()
            pendingErrorClearTask = nil
            if previousTab == .home, newTab == .index || newTab == .family, viewModel.state.error != nil {
                pendingErrorClearTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    guard !Task.isCancelled else { return }
                    guard self.selectedTab == .index || self.selectedTab == .family else { return }
                    guard self.viewModel.state.error != nil else { return }
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        self.viewModel.clearError()
                    }
                    self.pendingErrorClearTask = nil
                }
            }
            if newTab == .family {
                familyScrollResetToken = UUID()
            }
            isAwaitingLoadTab = false
            previousTab = newTab
        }
        .onChange(of: viewModel.state.lastSuccessfulLoadID) { token in
            guard token != nil else { return }
            // A new file: what these hold belongs to the old one. The index and family
            // views reset themselves only if they are on screen when it loads, which
            // beside each other they may not be (loading from Home).
            familyPath = []
            familyRootId = viewModel.state.selectedIndividualId
            indexBrowseState.reset()
            let tab = tabAfterLoad
            if tab == .family {
                familyScrollResetToken = UUID()
            }
            // The switch below only takes effect on the next render pass, so hold the
            // overlay until it lands rather than trusting a fixed delay to outlast it.
            // Guarded on an actual change: if the tab is already correct nothing will
            // fire `onChange(of: selectedTab)` to clear this again.
            if tab != selectedTab {
                isAwaitingLoadTab = true
            }
            updateSelectedTab(tab, animated: false)
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: allowedContentTypes,
            allowsMultipleSelection: false
        ) { result in
            showingFileImporter = false
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                viewModel.load(url: url)
            case .failure(let error):
                importerError = IdentifiableError(message: error.localizedDescription)
            }
        }
        .alert(item: $importerError) { error in
            Alert(
                title: Text("alert.import_failure.title"),
                message: Text(error.message),
                dismissButton: .default(Text("general.ok"))
            )
        }
        .environmentObject(themeManager)
    }

    private var homeTab: some View {
        HomeTabView(
            state: viewModel.state,
            onBrowseFiles: { showingFileImporter = true },
            onLoadSample: { viewModel.loadSample() },
            onOpenIndex: {
                if viewModel.openSavedIndex() {
                    updateSelectedTab(.index)
                }
            }
        )
        .equatable()
    }

    private func indexTab(highlightedIndividualId: String? = nil) -> some View {
        NavigationStack {
            IndexTabView(
                state: viewModel.state,
                browseState: indexBrowseState,
                highlightedIndividualId: highlightedIndividualId,
                onSelectIndividual: { id in
                    viewModel.selectIndividual(id)
                    // Beside the index the family tab is usually selected already, so the
                    // scroll back to the top that switching to it brings would not happen.
                    if selectedTab == .family {
                        familyScrollResetToken = UUID()
                    }
                    updateSelectedTab(.family)
                }
            )
            .equatable()
        }
    }

    private var familyTab: some View {
        FamilyTabView(
            state: viewModel.state,
            onSelectIndividual: { id in
                viewModel.selectIndividual(id)
            },
            scrollResetToken: familyScrollResetToken,
            path: $familyPath,
            rootIndividualId: $familyRootId
        )
    }

    /// Home and Index only: wherever this bar appears, a file's family view sits beside
    /// the index rather than on a tab of its own.
    private func topTabBar(colors: GVThemeColors) -> some View {
        CustomTabBar(selectedTab: $selectedTab, tabs: [.home, .index], colors: colors)
            .padding(.top, 12)
            .padding(.bottom, 6)
            .background(colors.tabBackground)
            .zIndex(1)
    }

    /// Applies theming to the UITabBar on iPhone.
    @MainActor
    private func applyTabBarAppearanceIfNeeded(with colors: GVThemeColors) {
        guard shouldApplyUIKitTabBarAppearance else { return }
        applyTabBarAppearance(with: colors)
    }

    @MainActor
    private func applyTabBarAppearance(with colors: GVThemeColors) {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = colors.tabBackgroundUIColor
        appearance.shadowColor = colors.tabBackgroundEmphasisUIColor

        let normalColor = colors.tabUnselectedForegroundUIColor
        let selectedColor = colors.tabSelectedForegroundUIColor

        [appearance.inlineLayoutAppearance,
         appearance.stackedLayoutAppearance,
         appearance.compactInlineLayoutAppearance].forEach { layout in
            layout.normal.iconColor = normalColor
            layout.normal.titleTextAttributes = [.foregroundColor: normalColor]
            layout.selected.iconColor = selectedColor
            layout.selected.titleTextAttributes = [.foregroundColor: selectedColor]
        }

        let tabBarProxy = UITabBar.appearance()
        tabBarProxy.tintColor = selectedColor
        tabBarProxy.unselectedItemTintColor = normalColor
        tabBarProxy.standardAppearance = appearance
        tabBarProxy.scrollEdgeAppearance = appearance

        applyAppearanceToRenderedTabBars(
            appearance: appearance,
            selectedColor: selectedColor,
            normalColor: normalColor
        )
    }

    @MainActor
    private func applyAppearanceToRenderedTabBars(
        appearance: UITabBarAppearance,
        selectedColor: UIColor,
        normalColor: UIColor
    ) {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }

        for scene in scenes {
            for window in scene.windows {
                self.update(
                    tabBarAppearanceFor: window.rootViewController,
                    appearance: appearance,
                    selectedColor: selectedColor,
                    normalColor: normalColor
                )
            }
        }
    }

    @MainActor
    private func update(
        tabBarAppearanceFor controller: UIViewController?,
        appearance: UITabBarAppearance,
        selectedColor: UIColor,
        normalColor: UIColor
    ) {
        guard let controller = controller else { return }

        if let tabController = controller as? UITabBarController {
            let tabBar = tabController.tabBar
            tabBar.tintColor = selectedColor
            tabBar.unselectedItemTintColor = normalColor
            tabBar.standardAppearance = appearance
            tabBar.scrollEdgeAppearance = appearance
        }

        for child in controller.children {
            self.update(
                tabBarAppearanceFor: child,
                appearance: appearance,
                selectedColor: selectedColor,
                normalColor: normalColor
            )
        }

        if let presented = controller.presentedViewController {
            self.update(
                tabBarAppearanceFor: presented,
                appearance: appearance,
                selectedColor: selectedColor,
                normalColor: normalColor
            )
        }
    }

    private func updateSelectedTab(_ tab: AppTab, animated: Bool = true) {
        guard animated == false else {
            selectedTab = tab
            return
        }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            selectedTab = tab
        }
    }
}

private enum AppTab: Hashable, CaseIterable {
    case home
    case index
    case family

    var titleKey: LocalizedStringKey {
        switch self {
        case .home: "tab.home.title"
        case .index: "tab.index.title"
        case .family: "tab.family.title"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .index: "list.bullet"
        case .family: "person.2"
        }
    }
}

private struct IdentifiableError: Identifiable {
    let id = UUID()
    let message: String
}

private struct CustomTabBar: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedTab: AppTab
    let tabs: [AppTab]
    let colors: GVThemeColors

    /// A selected tab that is not offered here (Family, beside the index) shows as Index.
    private var displayedTab: AppTab {
        tabs.contains(selectedTab) ? selectedTab : .index
    }

    var body: some View {
        HStack(spacing: 12) {
            ForEach(tabs, id: \.self) { tab in
                let isSelected = displayedTab == tab
                let unselectedColor: Color = colorScheme == .light ? .primary : colors.tabUnselectedForeground
                Button(action: { selectedTab = tab }) {
                    HStack(spacing: 6) {
                        Image(systemName: tab.systemImage)
                        Text(tab.titleKey)
                            .fontWeight(isSelected ? .semibold : .regular)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 18)
                    .background(
                        Group {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(colors.tabBackground)
                                    .shadow(color: colors.tabBackgroundEmphasis.opacity(0.07), radius: 3, y: 2)
                            } else {
                                Color.clear
                            }
                        }
                    )
                }
                .foregroundColor(isSelected ? colors.tabSelectedForeground : unselectedColor)
                .buttonStyle(.plain)
                .accessibilityIdentifier("tabbar.\(tab).button")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(colors.surface)
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
        .frame(maxWidth: .infinity)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView()
                .environment(\.colorScheme, .light)
            ContentView()
                .environment(\.colorScheme, .dark)
        }
    }
}
