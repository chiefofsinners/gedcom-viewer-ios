import Foundation
import SwiftUI
import UIKit

struct PersonRowView: View {
    @EnvironmentObject private var themeManager: GVThemeManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    let individual: Individual
    let supportingText: String?
    let onTap: () -> Void

    init(individual: Individual, supportingText: String? = nil, onTap: @escaping () -> Void) {
        self.individual = individual
        self.supportingText = supportingText?.nilIfBlank
        self.onTap = onTap
    }

    var body: some View {
        let colors = themeManager.colors

        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text(individual.displayName)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                if let supportingText {
                    Text(supportingText)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                        .font(.subheadline)
                        .foregroundStyle(colors.supportingText)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(colors.background)
            //.frame(height: 90)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("index.person.\(individual.gedcomId)")
        .listRowBackground(colors.background)
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

    private var isPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    private var isPortraitPhone: Bool {
        isPhone && horizontalSizeClass == .compact && verticalSizeClass == .regular
    }
}

struct PersonCardView: View {
    @EnvironmentObject private var themeManager: GVThemeManager
    let individual: Individual?
    let label: String?
    let onTap: ((String) -> Void)?

    init(individual: Individual?, label: String? = nil, onTap: ((String) -> Void)? = nil) {
        self.individual = individual
        self.label = label
        self.onTap = onTap
    }

    var body: some View {
        let colors = themeManager.colors

        let content = VStack(alignment: .leading, spacing: 10) {
            if let label {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(colors.supportingText.opacity(0.8))
            }
            let unknownName = String(
                localized: "person.unknown_name",
                defaultValue: "Unknown",
                bundle: .main
            )

            Text(individual?.displayName ?? unknownName)
                .font(.headline)
                .foregroundStyle(Color.primary)
            if let birth = individual?.birthSummary {
                let birthSummaryFormat = Bundle.main.localizedString(
                    forKey: "person.birth_summary",
                    value: "Born: %@",
                    table: nil
                )
                Text(
                    String.localizedStringWithFormat(
                        birthSummaryFormat,
                        birth
                    )
                )
                    .font(.subheadline)
                    .foregroundStyle(colors.supportingText)
            }
            if let death = individual?.deathSummary {
                let deathSummaryFormat = Bundle.main.localizedString(
                    forKey: "person.death_summary",
                    value: "Died: %@",
                    table: nil
                )
                Text(
                    String.localizedStringWithFormat(
                        deathSummaryFormat,
                        death
                    )
                )
                    .font(.subheadline)
                    .foregroundStyle(colors.supportingText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(colors.surface)
        )
        //.shadow(color: Color.black.opacity(0.14), radius: 6, y: 3)

        if let individual, let onTap {
            Button(action: { onTap(individual.id) }) {
                content
            }
            .buttonStyle(.plain)
        } else {
            content
        }
    }
}

enum PersonRowLayout {
    static let defaultHorizontalPadding: CGFloat = 0
    static let defaultVerticalPadding: CGFloat = 10
    static let compactPhoneHorizontalPadding: CGFloat = 0
    static let compactPhoneVerticalPadding: CGFloat = 4

    static func horizontalPadding(isPhone: Bool, isPortraitPhone: Bool) -> CGFloat {
        guard isPhone else {
            return defaultHorizontalPadding
        }
        return isPortraitPhone
            ? compactPhoneHorizontalPadding
            : defaultHorizontalPadding
    }

    static func verticalPadding(isPhone: Bool, isPortraitPhone: Bool) -> CGFloat {
        guard isPhone else {
            return defaultVerticalPadding
        }
        return isPortraitPhone
            ? compactPhoneVerticalPadding
            : defaultVerticalPadding
    }
}
