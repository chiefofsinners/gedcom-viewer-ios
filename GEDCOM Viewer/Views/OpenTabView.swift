import Foundation
import SwiftUI

struct OpenTabView: View {
    @EnvironmentObject private var themeManager: GVThemeManager
    let state: GedcomUIState
    let onBrowseFiles: () -> Void
    let onLoadSample: () -> Void
    let onRefresh: () -> Void
    let onClear: () -> Void

    private var fileNameDisplay: String {
        guard let name = state.currentFileName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else {
            return String(
                localized: "open.file.none_selected",
                defaultValue: "No file selected",
                bundle: .main
            )
        }
        return name
    }

    private var statusText: String {
        if state.isSampleData {
            return String(
                localized: "open.status.sample_loaded",
                defaultValue: "Sample data loaded from bundle",
                bundle: .main
            )
        }
        if state.data != nil {
            return String(
                localized: "open.status.file_loaded",
                defaultValue: "File loaded from device storage",
                bundle: .main
            )
        }
        return String(
            localized: "open.status.prompt",
            defaultValue: "Select a file to begin",
            bundle: .main
        )
    }

    var body: some View {
        let colors = themeManager.colors

        List {
            Section("open.section.current_selection") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(fileNameDisplay)
                        .font(.headline)
                    Text(statusText)
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                }
            }

            if let error = state.error {
                Section("open.section.status") {
                    MessageCard(text: error, style: .error)
                        .listRowInsets(EdgeInsets())
                }
            }

            Section("open.section.actions") {
                Button(action: onBrowseFiles) {
                    Label("home.action.browse", systemImage: "folder")
                }
                .disabled(state.isLoading)

                Button(action: onLoadSample) {
                    Label("home.action.load_sample", systemImage: "doc.text")
                }
                .disabled(state.isLoading)

                Button(action: onRefresh) {
                    Label("open.action.reload", systemImage: "arrow.clockwise")
                }
                .disabled(state.data == nil || state.isLoading)

                Button(role: .destructive, action: onClear) {
                    Label("open.action.clear", systemImage: "trash")
                }
                .disabled(state.data == nil && !state.isSampleData)
            }
        }
        .listStyle(.insetGrouped)
        .background(colors.background)
    }
}
