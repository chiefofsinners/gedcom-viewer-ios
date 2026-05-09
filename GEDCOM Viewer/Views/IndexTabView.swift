import Foundation
import SwiftUI
import UIKit

struct IndexTabView: View {
    @EnvironmentObject private var themeManager: GVThemeManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    let state: GedcomUIState
    let onSelectIndividual: (String) -> Void

    @State private var searchText: String = ""
    @State private var scrollResetToken = UUID()
    @State private var lastAppliedLoadID: UUID?

    init(state: GedcomUIState, onSelectIndividual: @escaping (String) -> Void) {
        self.state = state
        self.onSelectIndividual = onSelectIndividual
    }

    private var displayTitle: String {
        guard let name = state.currentFileName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return String(
                localized: "tab.index.title",
                defaultValue: "Index",
                bundle: .main
            )
        }
        if name.lowercased().hasSuffix(".ged") {
            return String(name.dropLast(4))
        }
        return name
    }

    private var filteredSections: [IndividualSection] {
        guard !state.isLoading, let data = state.data else { return [] }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let individuals: [Individual]
        if query.isEmpty {
            individuals = data.individualsSortedByName
        } else {
            individuals = data.individualsSortedByName.filter { individual in
                let displayName = individual.displayName.lowercased()
                let surname = individual.surname?.lowercased()
                let givenName = individual.givenName?.lowercased()
                return displayName.contains(query) ||
                    (surname?.contains(query) ?? false) ||
                    (givenName?.contains(query) ?? false)
            }
        }
        return IndividualSection.build(from: individuals)
    }

    var colors: GVThemeColors {
        themeManager.colors
    }

    private var isPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    private var isPortraitPhone: Bool {
        isPhone && horizontalSizeClass == .compact && verticalSizeClass == .regular
    }

    var layoutHorizontalPadding: CGFloat {
        listHorizontalPadding(isPhone: isPhone, isPortraitPhone: isPortraitPhone)
    }

    var layoutVerticalPadding: CGFloat {
        listVerticalPadding(isPhone: isPhone, isPortraitPhone: isPortraitPhone)
    }

    // Forces List to rebuild when the displayed dataset changes.
    private var listIdentityKey: Int {
        var hasher = Hasher()
        hasher.combine(searchText)
        if let data = state.data {
            for section in IndividualSection.build(from: data.individualsSortedByName) {
                hasher.combine(section.title)
                for member in section.members {
                    hasher.combine(member.id)
                }
            }
        } else {
            hasher.combine(0)
        }
        return hasher.finalize()
    }

    var body: some View {
        let sections = filteredSections
        let viewState = displayState(for: sections)

        return ZStack {
            colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                fixedSearchContent
                    .opacity(viewState.showsSearch ? 1 : 0)
                    .allowsHitTesting(viewState.showsSearch)
                    .accessibilityHidden(!viewState.showsSearch)

                ZStack(alignment: .top) {
                    contentView(for: sections, resetToken: scrollResetToken)
                        .opacity(viewState.showsContent ? 1 : 0)

                    if state.data != nil && sections.isEmpty {
                        emptyResultsPlaceholder
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            stateOverlay(for: viewState)
                .allowsHitTesting(viewState != .content)
                .zIndex(1)
        }
        .ignoresSafeArea(.keyboard)
        .navigationTitle(displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: state.lastSuccessfulLoadID) { token in
            guard let token, token != lastAppliedLoadID else { return }
            lastAppliedLoadID = token
            withAnimation(.none) {
                searchText = ""
                scrollResetToken = UUID()
            }
        }
        .onChange(of: state.currentFileName) { _ in
            searchText = ""
            lastAppliedLoadID = nil
        }
        .onAppear {
            if #available(iOS 15.0, *) {
                UITableView.appearance().sectionHeaderTopPadding = 0
            }
        }
    }
    
    @FocusState private var searchFocused: Bool
    
    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(colors.supportingText.opacity(0.9))
            TextField("index.search.placeholder", text: $searchText)
                .font(.title3)
                .autocorrectionDisabled()
                .accessibilityIdentifier("index.search.field")
                .focused($searchFocused)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(colors.supportingText.opacity(0.9))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("index.search.clear_accessibility"))
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(colors.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(colors.border.opacity(0.4), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private var fixedSearchContent: some View {
        VStack(spacing: 8) {
            searchField
                .padding(.horizontal, layoutHorizontalPadding)
        }
        .padding(.vertical, layoutVerticalPadding)
        .background(colors.surface.ignoresSafeArea(edges: .horizontal))
    }

    private var emptyResultsPlaceholder: some View {
        PlaceholderView(
            message: String(
                localized: "index.placeholder.empty_results",
                defaultValue: "No individuals found.",
                bundle: .main
            )
        )
            .padding(.top, 24)
            .background(Color.clear)
    }

    private func displayState(for sections: [IndividualSection]) -> DisplayState {
        if state.isLoading {
            return .loading
        }
        if state.data == nil {
            if state.needsFileSelection {
                return .needsSelection
            }
            return .noData
        }
        return .content
    }

    @ViewBuilder
    private func stateOverlay(for state: DisplayState) -> some View {
        switch state {
        case .content:
            EmptyView()
        case .loading:
            EmptyView()
        case .needsSelection:
            overlayPlaceholder(
                String(
                    localized: "placeholder.no_selection",
                    defaultValue: "No GEDCOM data loaded. Choose a file from Home.",
                    bundle: .main
                )
            )
                .transition(.opacity)
        case .noData:
            overlayPlaceholder(
                String(
                    localized: "placeholder.no_data",
                    defaultValue: "No GEDCOM data available.",
                    bundle: .main
                )
            )
                .transition(.opacity)
        }
    }

    private func overlayPlaceholder(_ message: String) -> some View {
        PlaceholderView(message: message)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(colors.background)
            .ignoresSafeArea()
    }

    func selectIndividual(_ id: String) {
        // Drop focus/keyboard before navigating away.
        searchFocused = false
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif

        // Defer to next runloop tick so the list can settle before navigating.
        DispatchQueue.main.async {
            onSelectIndividual(id)
        }
    }

}

enum LayoutMetrics {
    static let sectionHeaderHeight: CGFloat = 44
    static let defaultListHorizontalPadding: CGFloat = 32
    static let defaultListVerticalPadding: CGFloat = 16
    static let compactPhoneListHorizontalPadding: CGFloat = 12
    static let compactPhoneListVerticalPadding: CGFloat = 8
    static let minimumRowsForLetterIndex: Int = 8
    static let minimumLetterHeightThreshold: CGFloat = 26
    static let letterBarTopPadding: CGFloat = 12
    static let letterBarMinimumBottomInset: CGFloat = 8
    static let floatingTabBarDetectionThreshold: CGFloat = 60
    static let floatingTabBarBottomPadding: CGFloat = 12
    static let scrollAnimationDuration: Double = 0.4
    static let personRowHeight: CGFloat = 52
}

private func listHorizontalPadding(isPhone: Bool, isPortraitPhone: Bool) -> CGFloat {
    guard isPhone else {
        return LayoutMetrics.defaultListHorizontalPadding
    }
    return isPortraitPhone
        ? LayoutMetrics.compactPhoneListHorizontalPadding
        : LayoutMetrics.defaultListHorizontalPadding
}

private func listVerticalPadding(isPhone: Bool, isPortraitPhone: Bool) -> CGFloat {
    guard isPhone else {
        return LayoutMetrics.defaultListVerticalPadding
    }
    return isPortraitPhone
        ? LayoutMetrics.compactPhoneListVerticalPadding
        : LayoutMetrics.defaultListVerticalPadding
}

enum ScrollTarget: Hashable {
    case top
    case letter(Character)
    case individual(String)
}

struct ScrollDestination {
    let target: ScrollTarget
    let isFirstSection: Bool

    var prefersAnimation: Bool {
        //!isFirstSection
        true
    }
}

struct IndividualSection: Identifiable {
    let title: Character
    let members: [Individual]
    var id: Character { title }

    static func build(from individuals: [Individual]) -> [IndividualSection] {
        guard !individuals.isEmpty else { return [] }
        var sections: [IndividualSection] = []
        let sorted = individuals.sorted { lhs, rhs in
            let lhsLetter = lhs.indexLetter
            let rhsLetter = rhs.indexLetter
            if lhsLetter != rhsLetter { return lhsLetter < rhsLetter }
            let lhsSurname = lhs.surname?.lowercased() ?? lhs.displayName.lowercased()
            let rhsSurname = rhs.surname?.lowercased() ?? rhs.displayName.lowercased()
            if lhsSurname != rhsSurname { return lhsSurname < rhsSurname }
            let lhsGiven = lhs.givenName?.lowercased() ?? ""
            let rhsGiven = rhs.givenName?.lowercased() ?? ""
            if lhsGiven != rhsGiven { return lhsGiven < rhsGiven }
            return lhs.displayName.lowercased() < rhs.displayName.lowercased()
        }
        var currentLetter: Character?
        var currentMembers: [Individual] = []
        func flush() {
            guard let letter = currentLetter, !currentMembers.isEmpty else { return }
            sections.append(IndividualSection(title: letter, members: currentMembers))
            currentMembers.removeAll(keepingCapacity: true)
        }
        for individual in sorted {
            let letter = individual.indexLetter
            if letter != currentLetter {
                flush()
                currentLetter = letter
            }
            currentMembers.append(individual)
        }
        flush()
        return sections
    }
}

struct SectionHeader: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    let letter: Character

    private var isPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    private var isPortraitPhone: Bool {
        isPhone && horizontalSizeClass == .compact && verticalSizeClass == .regular
    }

    private var horizontalPadding: CGFloat {
        PersonRowLayout.horizontalPadding(
            isPhone: isPhone,
            isPortraitPhone: isPortraitPhone
        )
    }

    private var verticalPadding: CGFloat {
        PersonRowLayout.verticalPadding(
            isPhone: isPhone,
            isPortraitPhone: isPortraitPhone
        )
    }

    private var contentHeight: CGFloat {
        max(LayoutMetrics.sectionHeaderHeight - (verticalPadding * 2), 0)
    }

    var body: some View {
        Text(String(letter))
            .font(.title.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: contentHeight, alignment: .leading)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
    }
}

private enum DisplayState: Equatable {
    case needsSelection
    case noData
    case loading
    case content
}

private extension DisplayState {
    var showsSearch: Bool {
        switch self {
        case .content:
            return true
        default:
            return false
        }
    }
    var showsContent: Bool {
        self == .content
    }
}

fileprivate extension View {
    // Forces a full view rebuild by keying the content on a dynamic value.
    func contentKey<T: Hashable>(_ key: T) -> some View {
        self.id(key)
    }
}

#if os(iOS)
fileprivate extension View {
    @ViewBuilder
    func sectionIndexLabelCompat<S: StringProtocol>(_ label: S) -> some View {
        if #available(iOS 26.0, *) {
            self.sectionIndexLabel(label)
        } else {
            self
        }
    }

    @ViewBuilder
    func listSectionIndexVisibleCompat(_ visibility: Visibility = .visible) -> some View {
        if #available(iOS 26.0, *) {
            self.listSectionIndexVisibility(visibility)
        } else {
            self
        }
    }
}
#else
fileprivate extension View {
    // No-ops on non-iOS platforms so previews/mac builds compile cleanly
    @inline(__always)
    func sectionIndexLabelCompat<S: StringProtocol>(_ label: S) -> some View { self }

    @inline(__always)
    func listSectionIndexVisibleCompat(_ visibility: Visibility = .automatic) -> some View { self }
}
#endif

#if DEBUG
struct IndexTabView_Previews: PreviewProvider {
    static var previews: some View {
        let focus = PreviewContent.focusIndividual
        let state = PreviewContent.state(selectedIndividualId: focus.id)
        return Group {
            NavigationStack {
                IndexTabView(
                    state: state,
                    onSelectIndividual: { _ in }
                )
            }
            .environmentObject(GVThemeManager(initialTheme: .earth, userDefaults: nil))
            .previewDisplayName("Index View – Light")

            NavigationStack {
                IndexTabView(
                    state: state,
                    onSelectIndividual: { _ in }
                )
            }
            .environmentObject(GVThemeManager(initialTheme: .earth, userDefaults: nil))
            .preferredColorScheme(.dark)
            .previewDisplayName("Index View – Dark")
        }
    }
}
#endif
