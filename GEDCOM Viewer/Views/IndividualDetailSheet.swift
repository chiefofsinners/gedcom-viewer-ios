import Foundation
import SwiftUI

struct IndividualDetailSheet: View {
    @EnvironmentObject private var themeManager: GVThemeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme

    let individual: Individual

    private var genderLabel: String {
        switch individual.gender {
        case .male:
            return String(
                localized: "individual.gender.male",
                defaultValue: "Male",
                bundle: .main
            )
        case .female:
            return String(
                localized: "individual.gender.female",
                defaultValue: "Female",
                bundle: .main
            )
        case .unknown:
            return String(
                localized: "individual.gender.unknown",
                defaultValue: "Unknown",
                bundle: .main
            )
        }
    }

    private var detailRows: [(label: String, value: String)] {
        var rows: [(String, String)] = []
        rows.append((
            String(
                localized: "individual.summary.full_name",
                defaultValue: "Full name",
                bundle: .main
            ),
            individual.displayName
        ))
        if let given = individual.givenName?.nilIfBlank {
            rows.append((
                String(
                    localized: "individual.summary.given_name",
                    defaultValue: "Given name",
                    bundle: .main
                ),
                given
            ))
        }
        if let surname = individual.surname?.nilIfBlank {
            rows.append((
                String(
                    localized: "individual.summary.surname",
                    defaultValue: "Surname",
                    bundle: .main
                ),
                surname
            ))
        }
        rows.append((
            String(
                localized: "individual.summary.gender",
                defaultValue: "Gender",
                bundle: .main
            ),
            genderLabel
        ))
        return rows
    }

    private var additionalNotes: [String] {
        individual.notes.compactMap { $0.nilIfBlank }
    }

    private var sheetDetents: Set<PresentationDetent> {
        if horizontalSizeClass == .regular {
            return [.fraction(0.9), .fraction(1.0)]
        }
        return [.medium, .large]
    }

    private var sheetDragIndicatorVisibility: Visibility {
        sheetDetents.count == 1 ? .hidden : .automatic
    }

    var body: some View {
        let colors = themeManager.colors

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HeaderView()

                    if detailRows.isEmpty && individual.timeline.isEmpty && additionalNotes.isEmpty {
                        Text("individual.info.none")
                            .font(.body)
                            .foregroundStyle(Color.secondary)
                    } else {
                        if !detailRows.isEmpty {
                            DetailSection(rows: detailRows)
                        }

                        if !individual.timeline.isEmpty {
                            TimelineSection(entries: individual.timeline)
                        }

                        if !additionalNotes.isEmpty {
                            NotesSection(
                                title: String(
                                    localized: "individual.notes.additional",
                                    defaultValue: "Additional notes",
                                    bundle: .main
                                ),
                                notes: additionalNotes
                            )
                        }
                    }
                }
                .padding(24)
            }
            .accessibilityIdentifier("family.detail.sheet")
            .background(colors.background)
            .navigationTitle(individual.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .tint(colorScheme == .dark ? Color.primary : colors.accent)
            .toolbarBackground(colors.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(
                colorScheme == .dark ? .dark : .light,
                for: .navigationBar
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("general.close") { dismiss() }
                        .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
                        .accessibilityIdentifier("family.detail.close.button")
                }
            }
        }
        .presentationDetents(sheetDetents)
        .presentationDragIndicator(sheetDragIndicatorVisibility)
    }
}

private struct HeaderView: View {
    @EnvironmentObject private var themeManager: GVThemeManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = themeManager.colors

        HStack(spacing: 12) {
            if colorScheme == .dark {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 28))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.primary, colors.surface)
                    .overlay(
                        Circle()
                            .stroke(Color.primary, lineWidth: 1.5)
                    )
            } else {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 28))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.primary, colors.surface)
                    .overlay(
                        Circle()
                            .stroke(Color.primary, lineWidth: 1.5)
                    )
            }
            Text("individual.header.title")
                .font(.title2.weight(.semibold))
        }
    }
}

private struct DetailSection: View {
    let rows: [(label: String, value: String)]

    var body: some View {
        SectionContainerView(
            title: String(
                localized: "individual.section.summary",
                defaultValue: "Summary",
                bundle: .main
            )
        ) {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    DetailRow(label: row.label, value: row.value)
                }
            }
        }
    }
}

private struct TimelineSection: View {
    let entries: [TimelineEntry]

    var body: some View {
        SectionContainerView(
            title: String(
                localized: "individual.section.timeline",
                defaultValue: "Timeline",
                bundle: .main
            )
        ) {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                    TimelineEntryView(entry: entry)
                }
            }
        }
    }
}

private struct TimelineEntryView: View {
    let entry: TimelineEntry

    private var keyDetails: [(String, String)] {
        var rows: [(String, String)] = []
        if let date = entry.event.date?.nilIfBlank {
            rows.append((
                String(
                    localized: "individual.detail.date",
                    defaultValue: "Date",
                    bundle: .main
                ),
                date
            ))
        }
        if let place = entry.event.place?.nilIfBlank {
            rows.append((
                String(
                    localized: "individual.detail.place",
                    defaultValue: "Place",
                    bundle: .main
                ),
                place
            ))
        }
        if let address = entry.event.address?.nilIfBlank {
            rows.append((
                String(
                    localized: "individual.detail.address",
                    defaultValue: "Address",
                    bundle: .main
                ),
                address
            ))
        }
        return rows
    }

    private var detailKeys: [String] {
        entry.event.details.keys.sorted(by: <)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            let headline = buildHeadline()
            Text(headline)
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(keyDetails.enumerated()), id: \.offset) { _, row in
                    DetailRow(label: row.0, value: row.1)
                }

                ForEach(detailKeys, id: \.self) { detail in
                    if let values = entry.event.details[detail] {
                        ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                            DetailRow(label: detail, value: value)
                        }
                    }
                }

                if !entry.event.notes.isEmpty {
                    NotesSection(
                        title: String(
                            localized: "individual.notes.title",
                            defaultValue: "Notes",
                            bundle: .main
                        ),
                        notes: entry.event.notes
                    )
                }
            }
        }
    }

    private func buildHeadline() -> String {
        if let value = entry.event.value?.nilIfBlank {
            let format = String(
                localized: "individual.timeline.label_with_value",
                defaultValue: "%@: %@",
                bundle: .main
            )
            return String(format: format, locale: Locale.current, entry.label, value)
        }
        return entry.label
    }
}

private struct NotesSection: View {
    let title: String
    let notes: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.secondary)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                    Text("• \(note)")
                        .font(.body)
                }
            }
        }
    }
}

private struct SectionContainerView<Content: View>: View {
    @EnvironmentObject private var themeManager: GVThemeManager
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        let colors = themeManager.colors

        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3.weight(.semibold))
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(colors.surface)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 16, y: 6)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.3), lineWidth: 1)
        )
    }
}

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.secondary)
            Text(value)
                .font(.body)
                .foregroundStyle(Color.primary)
        }
    }
}
