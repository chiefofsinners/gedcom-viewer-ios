import Combine
import Foundation
import SwiftUI
import UIKit

struct IndexTabView: View {
    @EnvironmentObject private var themeManager: GVThemeManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    let state: GedcomUIState
    @ObservedObject var browseState: IndexBrowseState
    /// The person shown in the family pane beside the index, when there is one.
    let highlightedIndividualId: String?
    let onSelectIndividual: (String) -> Void

    @State private var scrollResetToken = UUID()
    @State private var lastAppliedLoadID: UUID?
    /// Identifies this list to `browseState`, which outlives it.
    @State var browseOwner = UUID()

    init(
        state: GedcomUIState,
        browseState: IndexBrowseState,
        highlightedIndividualId: String? = nil,
        onSelectIndividual: @escaping (String) -> Void
    ) {
        self.state = state
        self.browseState = browseState
        self.highlightedIndividualId = highlightedIndividualId
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

    /// Recomputed on every `body` pass, so it must stay cheap: it reuses the
    /// sections `GedcomData` built once at parse time and only prunes them.
    private var filteredSections: [IndividualSection] {
        guard !state.isLoading, let data = state.data else { return [] }
        let query = browseState.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return data.indexSections }
        return IndividualSection.filter(data.indexSections) { $0.matches(searchQuery: query) }
    }

    var colors: GVThemeColors {
        themeManager.colors
    }

    private var isPortraitPhone: Bool {
        horizontalSizeClass == .compact && verticalSizeClass == .regular
    }

    var layoutHorizontalPadding: CGFloat {
        listHorizontalPadding(isPortraitPhone: isPortraitPhone)
    }

    var layoutVerticalPadding: CGFloat {
        listVerticalPadding(isPortraitPhone: isPortraitPhone)
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
                browseState.searchText = ""
                scrollResetToken = UUID()
            }
        }
        .onChange(of: state.currentFileName) { _ in
            browseState.searchText = ""
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
            TextField("index.search.placeholder", text: $browseState.searchText)
                .font(.title3)
                .autocorrectionDisabled()
                .accessibilityIdentifier("index.search.field")
                .focused($searchFocused)
            if !browseState.searchText.isEmpty {
                Button {
                    browseState.searchText = ""
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

extension IndexTabView: Equatable {
    /// Compares only the state this view's body actually reads. Selecting a person
    /// changes `selectedIndividualId`, which the index does not display; without
    /// this, every selection rebuilt the whole list. Used via `.equatable()`.
    ///
    /// `onSelectIndividual` is deliberately excluded — it is a fresh closure on
    /// every ContentView body pass, so comparing it would never report equality.
    /// Holding the previous closure is safe: it writes through `@State`/`@StateObject`
    /// storage, not through the captured struct copy.
    static func == (lhs: IndexTabView, rhs: IndexTabView) -> Bool {
        lhs.browseState === rhs.browseState
            && lhs.highlightedIndividualId == rhs.highlightedIndividualId
            && lhs.state.isLoading == rhs.state.isLoading
            && lhs.state.needsFileSelection == rhs.state.needsFileSelection
            && lhs.state.currentFileName == rhs.state.currentFileName
            && lhs.state.lastSuccessfulLoadID == rhs.state.lastSuccessfulLoadID
            && lhs.state.data == rhs.state.data
    }
}

/// The index's search text and scroll position. ContentView owns it so that both outlive
/// the `IndexTabView` itself, which is rebuilt whenever the window switches between one
/// pane and two: folding or unfolding an iPhone Duo, or resizing an iPad window.
@MainActor
final class IndexBrowseState: ObservableObject {
    @Published var searchText = ""

    // The scroll position is kept as the rows last on screen, not an offset, so it still
    // means something in a list of a different size. None of it is published: tracking
    // it must not redraw the list.
    private var visibleRows: [UUID: Set<String>] = [:]
    private var lastVisibleRows = Set<String>()
    private var currentOwner: UUID?
    private var isRestoring = false
    private var snapshotScheduled = false

    /// Forgets the search and scroll position, for a newly loaded file.
    func reset() {
        searchText = ""
        visibleRows = [:]
        lastVisibleRows = []
    }

    func rowAppeared(_ id: String, owner: UUID) {
        visibleRows[owner, default: []].insert(id)
        scheduleSnapshot()
    }

    func rowDisappeared(_ id: String, owner: UUID) {
        visibleRows[owner]?.remove(id)
        if visibleRows[owner]?.isEmpty == true {
            visibleRows[owner] = nil
        }
        scheduleSnapshot()
    }

    /// Called when a list comes on screen. Returns the row to scroll a newly built list
    /// to, and nil for one that is merely reappearing, such as on a tab switch.
    func listAppeared(owner: UUID, sections: [IndividualSection]) -> String? {
        guard owner != currentOwner else { return nil }
        currentOwner = owner
        isRestoring = true
        guard !lastVisibleRows.isEmpty else { return nil }
        for section in sections {
            if let member = section.members.first(where: { lastVisibleRows.contains($0.id) }) {
                return member.id
            }
        }
        return nil
    }

    func finishRestoring(owner: UUID) {
        guard owner == currentOwner else { return }
        isRestoring = false
        scheduleSnapshot()
    }

    private func scheduleSnapshot() {
        guard !snapshotScheduled else { return }
        snapshotScheduled = true
        // Coalesced to the end of the run loop turn: a list being torn down drops all of
        // its rows at once, and must not wipe out the position it had.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.snapshotScheduled = false
            guard !self.isRestoring,
                  let owner = self.currentOwner,
                  let rows = self.visibleRows[owner],
                  !rows.isEmpty else { return }
            self.lastVisibleRows = rows
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

private func listHorizontalPadding(isPortraitPhone: Bool) -> CGFloat {
    return isPortraitPhone
        ? LayoutMetrics.compactPhoneListHorizontalPadding
        : LayoutMetrics.defaultListHorizontalPadding
}

private func listVerticalPadding(isPortraitPhone: Bool) -> CGFloat {
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

struct SectionHeader: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    let letter: Character

    private var isPortraitPhone: Bool {
        horizontalSizeClass == .compact && verticalSizeClass == .regular
    }

    private var horizontalPadding: CGFloat {
        PersonRowLayout.horizontalPadding(
            isPortraitPhone: isPortraitPhone
        )
    }

    private var verticalPadding: CGFloat {
        PersonRowLayout.verticalPadding(
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
                    browseState: IndexBrowseState(),
                    onSelectIndividual: { _ in }
                )
            }
            .environmentObject(GVThemeManager(initialTheme: .earth, userDefaults: nil))
            .previewDisplayName("Index View – Light")

            NavigationStack {
                IndexTabView(
                    state: state,
                    browseState: IndexBrowseState(),
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
