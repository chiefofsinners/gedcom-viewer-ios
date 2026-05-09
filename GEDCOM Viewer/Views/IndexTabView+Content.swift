import SwiftUI

extension IndexTabView {
    @ViewBuilder
    func contentView(for sections: [IndividualSection], resetToken: UUID) -> some View {
        GeometryReader { geometry in
            let safeAreaInsets = geometry.safeAreaInsets
            let topPadding = LayoutMetrics.letterBarTopPadding
            let bottomSafeArea = safeAreaInsets.bottom
            let bottomInset = bottomSafeArea >= LayoutMetrics.floatingTabBarDetectionThreshold
                ? LayoutMetrics.floatingTabBarBottomPadding
                : max(bottomSafeArea, LayoutMetrics.letterBarMinimumBottomInset)
            let availableHeight = max(geometry.size.height - topPadding - bottomInset, 0)
            let letters = sections.map(\.title)
            let totalRowCount = sections.reduce(into: 0) { result, section in
                result += section.members.count
            }
            
            let shouldShowLetterIndex = {
                // iOS 26 or later → *do not* show custom letter index
                //if #available(iOS 26, *) { return false }

                // iOS 16–25 → use your original logic
                return letters.count > 1 &&
                       availableHeight > 0 &&
                       totalRowCount >= LayoutMetrics.minimumRowsForLetterIndex
            }()

            ScrollViewReader { proxy in
                ZStack(alignment: .topTrailing) {
                    dataContent(for: sections)

                    if shouldShowLetterIndex {
                        let indexHeight = availableHeight
                        let onLetterSelected: (Character) -> Void = { letter in
                            let destination = scrollDestination(for: letter, in: sections)
                            scroll(
                                to: destination.target,
                                in: sections,
                                proxy: proxy,
                                animated: destination.prefersAnimation
                            )
                        }
                        letterIndexBar(letters: letters, targetHeight: indexHeight, onSelect: onLetterSelected)
                            .frame(maxHeight: .infinity, alignment: .top)
                            .padding(.top, topPadding)
                    }
                }
                .onChange(of: resetToken) { _ in
                    scrollToTop(proxy, sections: sections)
                }
            }
        }
    }

    @ViewBuilder
    private func dataContent(for sections: [IndividualSection]) -> some View {
        #if DEBUG
            //lazyStackContent(for: sections)
            listContent(for: sections)
        #else
        if #available(iOS 26.0, *) {
            listContent(for: sections)
        } else {
            lazyStackContent(for: sections)
        }
        #endif
    }

    @ViewBuilder
    private func lazyStackContent(for sections: [IndividualSection]) -> some View {
        let sectionOffsets = sectionRowOffsets(for: sections)
        let sectionData = Array(zip(sectionOffsets, sections))
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                Color.clear
                    .frame(height: 0)
                    .id(ScrollTarget.top)
                ForEach(sectionData, id: \.1.id) { pair in
                    let baseRowOffset = pair.0
                    let section = pair.1
                    let isLastSection = section.id == sectionData.last?.1.id
                    SectionHeader(letter: section.title)
                        .id(ScrollTarget.letter(section.title))
                        .padding(.vertical, layoutVerticalPadding)
                        .padding(.horizontal, layoutHorizontalPadding)
                        .background(colors.background)
                    ForEach(Array(section.members.enumerated()), id: \.element.id) { memberPair in
                        let memberIndex = memberPair.offset
                        let individual = memberPair.element
                        let isLastMemberInSection = memberIndex == section.members.count - 1
                        let isLastMemberOverall = isLastSection && isLastMemberInSection
                        PersonRowView(
                            individual: individual,
                            supportingText: individual.birthSummary
                        ) {
                            selectIndividual(individual.id)
                        }
                        .frame(maxWidth: .infinity,
                               minHeight: LayoutMetrics.personRowHeight,
                               alignment: .topLeading)
                        .padding(.vertical, layoutVerticalPadding)
                        .padding(.horizontal, layoutHorizontalPadding)
                        .id(ScrollTarget.individual(individual.id))
                        .background(rowBackgroundColor(for: baseRowOffset + memberIndex))
                        .overlay(alignment: .bottom) {
                            if !isLastMemberOverall {
                                Rectangle()
                                    .fill(colors.border.opacity(0.25))
                                    .frame(height: 1)
                                    .padding(.horizontal, layoutHorizontalPadding)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 32)
            //.shadow(color: Color.black.opacity(0.05), radius: 16, y: 4)
        }
        .background(colors.background)
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
    }

    @ViewBuilder
    private func listContent(for sections: [IndividualSection]) -> some View {
        let firstSectionID = sections.first?.id
        List {
            ForEach(sections) { section in
                let isFirstSection = section.id == firstSectionID
                Section {
                    ForEach(section.members, id: \.id) { individual in
                        PersonRowView(
                            individual: individual,
                            supportingText: individual.birthSummary
                        ) {
                            selectIndividual(individual.id)
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                } header: {
                    SectionHeader(letter: section.title)
                }
                //.sectionIndexLabelCompat(String(section.title))
                .id(isFirstSection ? ScrollTarget.top : ScrollTarget.letter(section.title))
                .textCase(nil)
                .padding(.horizontal, layoutHorizontalPadding - 16)
            }
        }
        .listStyle(.plain)
        //.listSectionIndexVisibleCompat(.visible)
        .background(colors.background)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.immediately)
    }

    private func letterIndexBar(letters: [Character], targetHeight: CGFloat, onSelect: @escaping (Character) -> Void) -> some View {
        let displayLetters = condensedLetters(
            from: letters,
            targetHeight: targetHeight,
            minimumLetterHeight: LayoutMetrics.minimumLetterHeightThreshold
        )
        let displayLetterCount = displayLetters.count
        let displayDividerHeight = CGFloat(max(displayLetterCount - 1, 0))
        let letterHeight = displayLetterCount > 0 && targetHeight > 0
            ? max((targetHeight - displayDividerHeight) / CGFloat(displayLetterCount), 0)
            : 0

        return VStack(spacing: 0) {
            ForEach(Array(displayLetters.enumerated()), id: \.element) { idx, letter in
                Button {
                    onSelect(letter)
                } label: {
                    Text(String(letter))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.secondary)
                        .frame(width: 36, height: letterHeight)
                }
                .buttonStyle(.plain)

                if idx < displayLetters.count - 1 {
                    Divider()
                }
            }
        }
        .frame(width: 36, height: targetHeight)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(colors.surface.opacity(0.8))
        )
        .frame(width: 36)
        .padding(.trailing, 0)
    }

    private func scrollDestination(for letter: Character, in sections: [IndividualSection]) -> ScrollDestination {
        guard let firstSection = sections.first else {
            return ScrollDestination(target: .top, isFirstSection: true)
        }

        let resolvedSection: IndividualSection
        if let exactMatch = sections.first(where: { $0.title == letter }) {
            resolvedSection = exactMatch
        } else if let nextMatch = sections.first(where: { $0.title > letter }) {
            resolvedSection = nextMatch
        } else if let last = sections.last {
            resolvedSection = last
        } else {
            resolvedSection = firstSection
        }

        let isFirstSection = resolvedSection.id == firstSection.id
        let target: ScrollTarget = isFirstSection ? .top : .letter(resolvedSection.title)
        return ScrollDestination(target: target, isFirstSection: isFirstSection)
    }

    private func scrollToTop(_ proxy: ScrollViewProxy, sections: [IndividualSection]) {
        guard !sections.isEmpty else { return }
        proxy.scrollTo(ScrollTarget.top, anchor: .top)
    }

    private func scroll(
        to target: ScrollTarget,
        in sections: [IndividualSection],
        proxy: ScrollViewProxy,
        animated: Bool
    ) {
        guard !sections.isEmpty else { return }
        let duration = LayoutMetrics.scrollAnimationDuration
                
        // If animated is requested AND duration is greater than zero, use withAnimation.
        if animated && duration > 0.0 {
            withAnimation(.easeInOut(duration: duration)) {
                proxy.scrollTo(target, anchor: .top)
            }
        } else {
            // If animated is disabled or duration is zero, use a non-animated transaction.
            // This is the final and most robust fix for the blank row glitch.
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                proxy.scrollTo(target, anchor: .top)
            }
        }
    }

    private func condensedLetters(
        from letters: [Character],
        targetHeight: CGFloat,
        minimumLetterHeight: CGFloat
    ) -> [Character] {
        guard !letters.isEmpty else { return [] }
        guard targetHeight > 0 else { return letters }

        func letterHeight(for count: Int) -> CGFloat {
            guard count > 0 else { return 0 }
            let dividerHeight = CGFloat(max(count - 1, 0))
            return max((targetHeight - dividerHeight) / CGFloat(count), 0)
        }

        if letterHeight(for: letters.count) >= minimumLetterHeight {
            return letters
        }

        func thinLetters(stride: Int) -> [Character] {
            guard stride > 1 else { return letters }
            var result: [Character] = []
            let lastIndex = letters.count - 1

            for (idx, letter) in letters.enumerated() {
                if idx == 0 || idx == lastIndex {
                    result.append(letter)
                    continue
                }
                if idx % stride == 0 {
                    result.append(letter)
                }
            }

            return result
        }

        var stride = 2
        var bestLetters = letters

        while stride <= letters.count {
            let candidate = thinLetters(stride: stride)
            bestLetters = candidate
            let candidateHeight = letterHeight(for: candidate.count)

            if candidateHeight >= minimumLetterHeight || candidate.count <= 2 {
                break
            }

            stride += 1
        }

        return bestLetters
    }

    private func rowBackgroundColor(for index: Int) -> Color {
        index.isMultiple(of: 2) ? colors.background : colors.background
    }
    
    private func sectionRowOffsets(for sections: [IndividualSection]) -> [Int] {
        var offsets: [Int] = []
        var runningTotal = 0

        for section in sections {
            offsets.append(runningTotal)
            runningTotal += section.members.count
        }

        return offsets
    }
    
}
