import Foundation
import SwiftUI

struct FamilyTabView: View {
    @EnvironmentObject private var themeManager: GVThemeManager
    let state: GedcomUIState
    let onSelectIndividual: (String?) -> Void
    let scrollResetToken: UUID

    @Environment(\.colorScheme) private var colorScheme
    @State private var path: [FamilyRoute] = []
    @State private var suppressSelectionReset = false
    @State private var suppressPathChange = false
    @State private var pendingPathRestoration = false
    @State private var suppressingRootPlaceholder = false
    @State private var placeholderSuppressionTask: Task<Void, Never>?
    @State private var rootIndividualId: String?
    private var stackContent: some View {
        Group {
            if state.isLoading && state.data == nil {
                PlaceholderView(
                    message: String(
                        localized: "family.placeholder.loading",
                        defaultValue: "Loading GEDCOM data…",
                        bundle: .main
                    )
                )
            } else if let error = state.error, state.data == nil {
                PlaceholderView(message: error)
            } else if state.needsFileSelection {
                PlaceholderView(
                    message: String(
                        localized: "family.placeholder.select_from_home",
                        defaultValue: "Choose a GEDCOM file from the Home tab to explore family details.",
                        bundle: .main
                    )
                )
            } else if let data = state.data {
                if data.individualsSortedByName.isEmpty {
                    PlaceholderView(
                        message: String(
                            localized: "family.placeholder.no_individuals",
                            defaultValue: "No individuals available in this GEDCOM data.",
                            bundle: .main
                        )
                    )
                } else if let rootId = rootIndividualId ?? state.selectedIndividualId {
                    // 👉 Family is the true root now
                    FamilyView(
                        individualId: rootId,
                        data: data,
                        onSelectIndividual: handleSelection,
                        scrollResetToken: scrollResetToken,
                        allowSwipeToIndex: false,     // keep off for now; we’ll revisit the “final flick” later
                        onSwipeToIndex: nil
                    )
                } else {
                    PlaceholderView(
                        message: String(
                            localized: "family.placeholder.select_from_index",
                            defaultValue: "Please select an individual from the index to view their connections.",
                            bundle: .main
                        )
                    )
                }
            } else {
                PlaceholderView(
                    message: String(
                        localized: "placeholder.no_data",
                        defaultValue: "No GEDCOM data available.",
                        bundle: .main
                    )
                )
            }
        }
    }

    var body: some View {
        let colors = themeManager.colors
        let navigationTint = colors.navigationInteractive

        NavigationStack(path: $path) {
            stackContent
                .navigationBarTitleDisplayMode(.inline)
                .background(colors.background)
                .tint(colors.navigationInteractive)
                .navigationDestination(for: FamilyRoute.self) { route in
                    if let data = state.data {
                        FamilyView(
                            individualId: route.individualId,
                            data: data,
                            onSelectIndividual: handleSelection,
                            scrollResetToken: scrollResetToken,
                            allowSwipeToIndex: false,
                            onSwipeToIndex: nil
                        )
                    } else {
                        PlaceholderView(
                            message: String(
                                localized: "placeholder.no_data",
                                defaultValue: "No GEDCOM data available.",
                                bundle: .main
                            )
                        )
                    }
                }
        }
        //.id(colorScheme)
        .background(colors.background)
        .tint(navigationTint)
        .onAppear {
            // Capture the initial selection as the navigation root.
            if rootIndividualId == nil {
                rootIndividualId = state.selectedIndividualId
            }
        }
        .onChange(of: themeManager.theme) { _ in
            // No path manipulation needed anymore.
        }
        .onChange(of: state.selectedIndividualId) { newSelection in
            if suppressSelectionReset {
                suppressSelectionReset = false
                return
            }
            rootIndividualId = newSelection
            suppressPathChange = true
            path = []
        }
        .onChange(of: path) { newPath in
            if suppressPathChange {
                suppressPathChange = false
                pendingPathRestoration = false
                return
            }
            DispatchQueue.main.async {
                if let lastId = newPath.last?.individualId {
                    pendingPathRestoration = false
                    if state.selectedIndividualId != lastId {
                        suppressSelectionReset = true
                        onSelectIndividual(lastId)
                    }
                } else {
                    pendingPathRestoration = false
                    if let rootId = rootIndividualId, state.selectedIndividualId != rootId {
                        suppressSelectionReset = true
                        onSelectIndividual(rootId)
                    }
                }
            }            
        }
    }

    private func handleSelection(_ id: String) {
        guard let rootId = rootIndividualId ?? state.selectedIndividualId else {
            return
        }

        if id == rootId {
            // Ignore reselection if already at root.
            if path.isEmpty {
                return
            }

            // Collapse navigation stack back to root.
            suppressPathChange = true
            path = []

            if state.selectedIndividualId != rootId {
                suppressSelectionReset = true
                onSelectIndividual(rootId)
            }
            return
        }

        if path.last?.individualId == id {
            return
        }

        if let existingIndex = path.lastIndex(where: { $0.individualId == id }) {
            suppressPathChange = true
            path = Array(path.prefix(existingIndex + 1))

            suppressSelectionReset = true
            onSelectIndividual(id)
            return
        }

        suppressPathChange = true
        path.append(.family(id))

        suppressSelectionReset = true
        onSelectIndividual(id)
    }


}

private enum FamilyRoute: Hashable {
    case family(String)

    var individualId: String {
        switch self {
        case .family(let id):
            return id
        }
    }
}
