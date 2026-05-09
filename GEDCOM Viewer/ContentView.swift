import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var viewModel: GedcomViewModel
    @StateObject private var themeManager = GVThemeManager()
    @State private var selectedTab: AppTab
    @State private var previousTab: AppTab
    @State private var showingFileImporter = false
    @State private var importerError: IdentifiableError?
    @State private var familyScrollResetToken = UUID()
    @State private var pendingErrorClearTask: Task<Void, Never>?

    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    private var shouldApplyUIKitTabBarAppearance: Bool {
        guard !isPad else { return false }
        let version = ProcessInfo.processInfo.operatingSystemVersion
        if version.majorVersion <= 18 { return true }
        if version.majorVersion > 18 { return false }
        return version.minorVersion <= 5
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
            if isPad {
                // iPad: Use custom tab bar at the top
                VStack(spacing: 0) {
                    CustomTabBar(selectedTab: $selectedTab, colors: colors)
                        .padding(.top, 12)
                        .padding(.bottom, 6)
                        .background(colors.tabBackground)
                        .zIndex(1)

                    Group {
                        switch selectedTab {
                        case .home:
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
                        case .index:
                            NavigationStack {
                                IndexTabView(
                                    state: viewModel.state,
                                    onSelectIndividual: { id in
                                        familyScrollResetToken = UUID()
                                        viewModel.selectIndividual(id)
                                        updateSelectedTab(.family)
                                    }
                                )
                            }
                        case .family:
                            FamilyTabView(
                                state: viewModel.state,
                                onSelectIndividual: { id in
                                    viewModel.selectIndividual(id)
                                },
                                scrollResetToken: familyScrollResetToken
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .background(colors.background)
                .edgesIgnoringSafeArea(.bottom)
            } else {
                // iPhone: Use native TabView with system tab bar
                TabView(selection: $selectedTab) {
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
                    .tag(AppTab.home)
                    .tabItem { Label("tab.home.title", systemImage: "house") }

                    NavigationStack {
                        IndexTabView(
                            state: viewModel.state,
                            onSelectIndividual: { id in
                                familyScrollResetToken = UUID()
                                viewModel.selectIndividual(id)
                                updateSelectedTab(.family)
                            }
                        )
                    }
                    .tag(AppTab.index)
                    .tabItem { Label("tab.index.title", systemImage: "list.bullet") }

                    FamilyTabView(
                        state: viewModel.state,
                        onSelectIndividual: { id in
                            viewModel.selectIndividual(id)
                        },
                        scrollResetToken: familyScrollResetToken
                    )
                    .tag(AppTab.family)
                    .tabItem { Label("tab.family.title", systemImage: "person.2") }
                }
                .tint(colors.accent)
                //.toolbarBackground(colors.tabBackground, for: .tabBar)
                //.toolbarBackground(.visible, for: .tabBar)
            }

            LoadingOverlay()
                .opacity(viewModel.state.isLoading ? 1 : 0)
                .allowsHitTesting(viewModel.state.isLoading)
                .zIndex(2)
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
                updateSelectedTab(.index, animated: false)
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
            previousTab = newTab
        }
        .onChange(of: viewModel.state.lastSuccessfulLoadID) { token in
            guard token != nil else { return }
            updateSelectedTab(.index, animated: false)
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
    let colors: GVThemeColors

    var body: some View {
        HStack(spacing: 12) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                let isSelected = selectedTab == tab
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
