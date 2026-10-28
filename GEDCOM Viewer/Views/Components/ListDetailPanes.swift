import SwiftUI

/// Lays out the index (list) and family (detail) panes side by side for a window that is
/// regular in both directions, splitting along the fold when there is one so that neither
/// pane's content runs across the crease.
///
/// - An iPhone Duo opened out like a book: index on the leading side, family on the
///   trailing side, divided on the fold.
/// - An iPhone Duo half-folded in tabletop posture: family above the fold, facing the user,
///   and the index below it, resting on the table where it is easy to tap.
/// - Anything else, such as an iPad: index on the leading side at 40% of the width.
///
/// The panes keep their identity across all three, so moving between book and tabletop
/// postures keeps their state.
struct ListDetailPanes<ListPane: View, DetailPane: View>: View {
    @EnvironmentObject private var themeManager: GVThemeManager
    private let listPane: ListPane
    private let detailPane: DetailPane

    init(@ViewBuilder listPane: () -> ListPane, @ViewBuilder detailPane: () -> DetailPane) {
        self.listPane = listPane()
        self.detailPane = detailPane()
    }

    var body: some View {
        GeometryReader { proxy in
            let split = PaneSplit(size: proxy.size, fold: PaneFold(in: proxy))

            PaneSplitLayout(split: split) {
                listPane
                    .environment(\.horizontalSizeClass, split.listSizeClass)
                detailPane
                    .environment(\.horizontalSizeClass, split.detailSizeClass)
                Rectangle()
                    .fill(themeManager.colors.border.opacity(0.5))
                    .accessibilityHidden(true)
            }
        }
    }
}

/// The fold of an iPhone Duo, in the coordinate space of the panes' container.
private struct PaneFold: Equatable {
    /// The fold line plus the margin to keep clear either side of it.
    let frame: CGRect
    /// True only while the device is partly folded.
    let isActive: Bool

    init?(in proxy: GeometryProxy) {
        guard #available(iOS 27.1, *) else { return nil }
        // Inactive regions are included so a flat, open device still splits on its fold.
        guard let region = proxy.reservedRegions(kind: .division, options: [.includeInactive]).first else {
            return nil
        }
        frame = region.frame
        isActive = region.isActive
    }

    var isHorizontal: Bool {
        frame.width > frame.height
    }
}

/// Where the two panes meet, along the axis they are split on.
private struct PaneSplit: Equatable {
    /// Width of the leading pane, or height of the top pane when stacked.
    let firstEnd: CGFloat
    /// Where the second pane starts. Past `firstEnd` when the panes leave a partly folded
    /// fold clear.
    let secondStart: CGFloat
    let extent: CGSize
    /// True for tabletop posture: family on top, index below.
    let isStacked: Bool

    /// Narrower than this, a pane lays itself out as on a phone, as Android does below 600dp.
    private static let compactPaneWidth: CGFloat = 600
    private static let listShare: CGFloat = 0.4
    private static let minimumListWidth: CGFloat = 320

    init(size: CGSize, fold: PaneFold?) {
        extent = size
        if let fold, fold.isHorizontal, fold.isActive {
            isStacked = true
            firstEnd = min(max(fold.frame.minY, 0), size.height)
            secondStart = min(max(fold.frame.maxY, firstEnd), size.height)
        } else if let fold, !fold.isHorizontal {
            isStacked = false
            if fold.isActive {
                firstEnd = min(max(fold.frame.minX, 0), size.width)
                secondStart = min(max(fold.frame.maxX, firstEnd), size.width)
            } else {
                // Flat, so there is no crease to keep clear: meet on the fold line itself.
                firstEnd = min(max(fold.frame.midX.rounded(), 0), size.width)
                secondStart = firstEnd
            }
        } else {
            // No fold, or a flat one running across an open device turned on its side,
            // which is no reason to stack the panes.
            isStacked = false
            let split = max(size.width * Self.listShare, min(Self.minimumListWidth, size.width / 2)).rounded()
            firstEnd = split
            secondStart = split
        }
    }

    var listFrame: CGRect {
        isStacked
            ? CGRect(x: 0, y: secondStart, width: extent.width, height: extent.height - secondStart)
            : CGRect(x: 0, y: 0, width: firstEnd, height: extent.height)
    }

    var detailFrame: CGRect {
        isStacked
            ? CGRect(x: 0, y: 0, width: extent.width, height: firstEnd)
            : CGRect(x: secondStart, y: 0, width: extent.width - secondStart, height: extent.height)
    }

    /// A hairline where the panes meet. A partly folded fold leaves a gap instead.
    var dividerFrame: CGRect {
        let thickness: CGFloat = secondStart > firstEnd ? 0 : 1
        return isStacked
            ? CGRect(x: 0, y: firstEnd, width: extent.width, height: thickness)
            : CGRect(x: firstEnd, y: 0, width: thickness, height: extent.height)
    }

    var listSizeClass: UserInterfaceSizeClass {
        listFrame.width < Self.compactPaneWidth ? .compact : .regular
    }

    var detailSizeClass: UserInterfaceSizeClass {
        detailFrame.width < Self.compactPaneWidth ? .compact : .regular
    }
}

/// Places its three subviews (list, detail, divider) in the frames a `PaneSplit` gives.
/// A layout rather than nested stacks, so the panes keep their identity when the split
/// changes axis.
private struct PaneSplitLayout: Layout {
    let split: PaneSplit

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = [split.listFrame, split.detailFrame, split.dividerFrame]
        for (subview, frame) in zip(subviews, frames) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: max(frame.width, 0), height: max(frame.height, 0))
            )
        }
    }
}
