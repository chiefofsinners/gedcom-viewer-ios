import Foundation
import SwiftUI

struct FamilyView: View {
    @EnvironmentObject private var themeManager: GVThemeManager
    let individualId: String
    let data: GedcomData
    let onSelectIndividual: (String) -> Void
    let scrollResetToken: UUID
    /// Enable a custom right-edge swipe that goes straight back to Index (root only).
    var allowSwipeToIndex: Bool = false
    var onSwipeToIndex: (() -> Void)? = nil
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme


    @State private var showDetails = false
    @State private var navStyleVersion = 0

    private var focus: Individual? {
        data.individual(id: individualId)
    }

    private var spouseFamilies: [Family] {
        guard let focus else { return [] }
        return focus.familiesAsSpouse.compactMap { data.family(id: $0) }
    }

    private var parentFamily: Family? {
        guard let focus else { return nil }
        return findFamily(in: focus.familiesAsChild, data: data)
    }

    var body: some View {
        let colors = themeManager.colors

        let familyExists = focus != nil
        let isRegularWidth = horizontalSizeClass == .regular
        let horizontalPadding: CGFloat = isRegularWidth ? 32 : 16
        let verticalPadding: CGFloat = isRegularWidth ? 32 : 16
        let sheetBinding = Binding(
            get: { showDetails && !isRegularWidth },
            set: { showDetails = $0 }
        )
        let fullScreenBinding = Binding(
            get: { showDetails && isRegularWidth },
            set: { showDetails = $0 }
        )

        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: verticalPadding)
                        .id(FamilyScrollIdentifier.top)

                    VStack(alignment: .leading, spacing: 24) {
                        if let focus {
                            ParentsSection(
                                family: parentFamily,
                                data: data,
                                onSelectIndividual: onSelectIndividual
                            )

                            let families = spouseFamilies
                            let showFamilyNumbers = families.count > 1

                            if families.isEmpty {
                                FamilyCoreSection(
                                    focus: focus,
                                    spouse: nil,
                                    marriage: nil,
                                    onSelectIndividual: onSelectIndividual,
                                    familyNumber: nil
                                )

                                ChildrenSection(
                                    children: [],
                                    onSelectIndividual: onSelectIndividual
                                )
                            } else {
                                ForEach(Array(families.enumerated()), id: \.element.id) { index, family in
                                    let spouse = family.spouse(for: focus, data: data)
                                    let children = family.childrenIds.compactMap { data.individual(id: $0) }

                                    FamilyCoreSection(
                                        focus: focus,
                                        spouse: spouse,
                                        marriage: family.marriage,
                                        onSelectIndividual: onSelectIndividual,
                                        familyNumber: showFamilyNumbers ? index + 1 : nil
                                    )

                                    ChildrenSection(
                                        children: children,
                                        onSelectIndividual: onSelectIndividual,
                                        familyNumber: showFamilyNumbers ? index + 1 : nil
                                    )
                                }
                            }
                        } else {
                            MessageCard(
                                text: String(
                                    localized: "family.error.not_found",
                                    defaultValue: "Individual not found.",
                                    bundle: .main
                                ),
                                style: .error
                            )
                        }
                    }
                    .padding(.bottom, verticalPadding)
                }
                .padding(.horizontal, horizontalPadding)
            }
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .onChange(of: scrollResetToken) { _ in
                proxy.scrollTo(FamilyScrollIdentifier.top, anchor: .top)
            }
        }
        .id(navStyleVersion)
        .background(colors.background)
        .toolbarBackground(colors.surface(for: colorScheme), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(colorScheme, for: .navigationBar)
        .navigationTitle(
            focus?.displayName ?? String(
                localized: "tab.family.title",
                defaultValue: "Family",
                bundle: .main
            )
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if familyExists {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showDetails = true
                    } label: {
                        Image(systemName: "info.circle")
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(Color.primary)
                    }
                    .accessibilityLabel(Text("family.accessibility.individual_details"))
                    .accessibilityIdentifier("family.info.button")
                }
            }
        }
        .onChange(of: colorScheme) { _ in navStyleVersion &+= 1 }
        .onChange(of: themeManager.theme) { _ in navStyleVersion &+= 1 }
        .sheet(isPresented: sheetBinding) {
            if let focus {
                IndividualDetailSheet(individual: focus)
                    .environmentObject(themeManager)
            }
        }
        .fullScreenCover(isPresented: fullScreenBinding) {
            if let focus {
                IndividualDetailSheet(individual: focus)
                    .environmentObject(themeManager)
            }
        }
    }
}

private struct ParentsSection: View {
    let family: Family?
    let data: GedcomData
    let onSelectIndividual: (String) -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var useSingleColumn: Bool {
        guard horizontalSizeClass == .compact else { return false }
        if let verticalSizeClass, verticalSizeClass != .compact {
            return true
        }
        return false
    }
    
    var body: some View {
        SectionContainer(
            title: String(
                localized: "family.section.parents",
                defaultValue: "Parents",
                bundle: .main
            )
        ) {
            if family == nil {
                if useSingleColumn {
                    MessageCardView(
                        message: String(
                            localized: "family.message.no_parents",
                            defaultValue: "No recorded parents.",
                            bundle: .main
                        )
                    )
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(alignment: .top, spacing: FamilyLayout.pairSpacing) {
                        MessageCardView(
                            message: String(
                                localized: "family.message.no_parents",
                                defaultValue: "No recorded parents.",
                                bundle: .main
                            )
                        )
                            .frame(maxWidth: .infinity, alignment: .leading)
                        CardWidthPlaceholder()
                    }
                }
            } else {
                AdaptivePair {
                            PersonCardView(
                                individual: family?.husbandId.flatMap { data.individual(id: $0) },
                                label: String(
                                    localized: "family.label.father",
                                    defaultValue: "Father",
                                    bundle: .main
                                ),
                                onTap: onSelectIndividual
                            )
                } second: {
                    PersonCardView(
                        individual: family?.wifeId.flatMap { data.individual(id: $0) },
                        label: String(
                            localized: "family.label.mother",
                            defaultValue: "Mother",
                            bundle: .main
                        ),
                        onTap: onSelectIndividual
                    )
                }
            }
        }
    }
}

private struct FamilyCoreSection: View {
    @EnvironmentObject private var themeManager: GVThemeManager
    let focus: Individual
    let spouse: Individual?
    let marriage: LifeEvent?
    let onSelectIndividual: (String) -> Void
    var familyNumber: Int? = nil

    private var sectionTitle: String {
        if let n = familyNumber {
            let format = String(
                localized: "family.section.family_numbered",
                defaultValue: "Family %d",
                bundle: .main
            )
            return String(format: format, n)
        }
        return String(
            localized: "family.section.family",
            defaultValue: "Family",
            bundle: .main
        )
    }

    var body: some View {
        let colors = themeManager.colors

        SectionContainer(title: sectionTitle) {
            AdaptivePair {
                PersonCardView(
                    individual: focus,
                    label: String(
                        localized: "family.label.individual",
                        defaultValue: "Individual",
                        bundle: .main
                    ),
                    onTap: onSelectIndividual
                )
            } second: {
                PersonCardView(
                    individual: spouse,
                    label: String(
                        localized: "family.label.spouse",
                        defaultValue: "Spouse",
                        bundle: .main
                    ),
                    onTap: onSelectIndividual
                )
            }

            if let marriage, let description = marriage.description {
                VStack(alignment: .leading, spacing: 8) {
                    Text("family.label.married")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.secondary)
                    Text(description)
                        .font(.body)
                        .foregroundStyle(Color.primary)
                    if !marriage.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(marriage.notes.enumerated()), id: \.offset) { _, note in
                                Text("• \(note)")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(colors.surface)
                )
            }
        }
    }
}

private struct ChildrenSection: View {
    let children: [Individual]
    let onSelectIndividual: (String) -> Void
    var familyNumber: Int? = nil

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var useSingleColumn: Bool {
        guard horizontalSizeClass == .compact else { return false }
        if let verticalSizeClass, verticalSizeClass != .compact {
            return true
        }
        return false
    }

    private var childRows: [(Int, [Individual])] {
        stride(from: 0, to: children.count, by: 2).map { i in
            let end = min(i + 2, children.count)
            return (i, Array(children[i..<end]))
        }
    }

    private var sectionTitle: String {
        if let n = familyNumber {
            let numberedFormat = Bundle.main.localizedString(
                forKey: "family.children.title_numbered",
                value: "Family %d – Children (%d)",
                table: nil
            )
            return String(format: numberedFormat, n, children.count)
        } else {
            let defaultFormat = Bundle.main.localizedString(
                forKey: "family.children.title",
                value: "Children (%d)",
                table: nil
            )
            return String.localizedStringWithFormat(
                defaultFormat,
                children.count
            )
        }
    }

    var body: some View {
        SectionContainer(title: sectionTitle) {
            if children.isEmpty {
                emptyStateView
            } else {
                if useSingleColumn {
                    VStack(spacing: FamilyLayout.gridSpacing) {
                        ForEach(children, id: \.id) { child in
                            PersonCardView(
                                individual: child,
                                onTap: onSelectIndividual
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                } else {
                    VStack(spacing: FamilyLayout.gridSpacing) {
                        ForEach(childRows, id: \.0) { _, pair in
                            HStack(alignment: .top, spacing: FamilyLayout.gridSpacing) {
                                PersonCardView(
                                    individual: pair[0],
                                    onTap: onSelectIndividual
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)

                                if pair.count > 1 {
                                    PersonCardView(
                                        individual: pair[1],
                                        onTap: onSelectIndividual
                                    )
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                } else {
                                    CardWidthPlaceholder()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        Group {
            if useSingleColumn {
                MessageCardView(
                    message: String(
                        localized: "family.message.no_children",
                        defaultValue: "No recorded children.",
                        bundle: .main
                    )
                )
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .top, spacing: FamilyLayout.gridSpacing) {
                    MessageCardView(
                        message: String(
                            localized: "family.message.no_children",
                            defaultValue: "No recorded children.",
                            bundle: .main
                        )
                    )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    CardWidthPlaceholder()
                }
            }
        }
    }
}

private struct SectionContainer<Content: View>: View {
    @EnvironmentObject private var themeManager: GVThemeManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let title: String
    @ViewBuilder var content: Content

    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

    var body: some View {
        let colors = themeManager.colors

        let stack = VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.primary)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        return Group {
            if isRegularWidth {
                stack
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(colors.surfaceEmphasis)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.primary.opacity(0.3), lineWidth: 1)
                    )
            } else {
                stack
            }
        }
    }
}

private struct AdaptivePair<First: View, Second: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    let first: First
    let second: Second

    init(@ViewBuilder first: () -> First, @ViewBuilder second: () -> Second) {
        self.first = first()
        self.second = second()
    }

    var body: some View {
        Group {
            if shouldStackVertically {
                VStack(spacing: FamilyLayout.pairSpacing) {
                    first
                        .frame(maxWidth: .infinity)
                    second
                        .frame(maxWidth: .infinity)
                }
            } else {
                HStack(alignment: .top, spacing: FamilyLayout.pairSpacing) {
                    first
                        .frame(maxWidth: .infinity)
                    second
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var shouldStackVertically: Bool {
        guard horizontalSizeClass == .compact else { return false }
        if let verticalSizeClass, verticalSizeClass != .compact {
            return true
        }
        return false
    }
}

private enum FamilyLayout {
    static let pairSpacing: CGFloat = 16
    static let gridSpacing: CGFloat = 16
}

private enum FamilyScrollIdentifier {
    static let top = "__familyScrollTop__"
}

private func findFamily(in ids: [String], data: GedcomData) -> Family? {
    for id in ids {
        if let family = data.family(id: id) {
            return family
        }
    }
    return nil
}

private struct CardWidthPlaceholder: View {
    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity, minHeight: 0)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }
}

extension Family {
    func spouse(for individual: Individual, data: GedcomData) -> Individual? {
        let spouseId: String?
        switch individual.id {
        case husbandId:
            spouseId = wifeId
        case wifeId:
            spouseId = husbandId
        default:
            spouseId = husbandId ?? wifeId
        }
        return spouseId.flatMap { data.individual(id: $0) }
    }
}

private struct FlickToIndexLayer: UIViewRepresentable {
    var enabled: Bool
    var onFlick: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFlick: onFlick) }

    func makeUIView(context: Context) -> UIView {
        let v = UIView(frame: .zero)
        v.isUserInteractionEnabled = true

        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.cancelsTouchesInView = false            // don't swallow taps/scrolls
        pan.maximumNumberOfTouches = 1
        pan.delegate = context.coordinator
        v.addGestureRecognizer(pan)
        context.coordinator.pan = pan
        context.coordinator.enabled = enabled
        return v
    }

    func updateUIView(_ v: UIView, context: Context) {
        context.coordinator.enabled = enabled
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onFlick: () -> Void
        weak var pan: UIPanGestureRecognizer?
        var enabled = false

        init(onFlick: @escaping () -> Void) { self.onFlick = onFlick }

        // Fire only on decisive rightward flicks
        @objc func handlePan(_ g: UIPanGestureRecognizer) {
            guard enabled else { return }
            if g.state == .ended {
                let v = g.velocity(in: g.view)
                let t = g.translation(in: g.view)
                let horizontal = abs(v.x) > abs(v.y)
                let fastFlick   = v.x > 600 && horizontal
                let shortFirm   = t.x > 36 && abs(t.y) < 30
                if (fastFlick || shortFirm) {
                    onFlick()
                }
            }
        }

        // Start only for predominantly-horizontal rightward gestures
        func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
            guard enabled, let pan = g as? UIPanGestureRecognizer else { return false }
            let v = pan.velocity(in: pan.view)
            // rightward & mostly horizontal
            return v.x > 0 && abs(v.x) > abs(v.y) * 1.3
        }

        // Never block other recognizers (scroll views, buttons, etc.)
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }
    }
}



#if DEBUG
struct FamilyView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleData = PreviewContent.data
        let focus = PreviewContent.focusIndividual
        return Group {
            NavigationStack {
                FamilyView(
                    individualId: focus.id,
                    data: sampleData,
                    onSelectIndividual: { _ in },
                    scrollResetToken: UUID()
                )
            }
            .environmentObject(GVThemeManager(initialTheme: .earth, userDefaults: nil))
            .previewDisplayName("Family View – Light")

            NavigationStack {
                FamilyView(
                    individualId: focus.id,
                    data: sampleData,
                    onSelectIndividual: { _ in },
                    scrollResetToken: UUID()
                )
            }
            .environmentObject(GVThemeManager(initialTheme: .earth, userDefaults: nil))
            .preferredColorScheme(.dark)
            .previewDisplayName("Family View – Dark")
        }
    }
}
#endif
