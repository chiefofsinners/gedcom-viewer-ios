//
//  IndividualSection.swift
//  GEDCOM Viewer
//

import Foundation

/// A run of individuals sharing an index letter, as displayed by the index list.
struct IndividualSection: Identifiable {
    let title: Character
    let members: [Individual]
    var id: Character { title }

    static func build(from individuals: [Individual]) -> [IndividualSection] {
        guard !individuals.isEmpty else { return [] }

        // Sort keys are derived once per individual rather than inside the
        // comparator: `indexLetter`, `lowercased()` and `displayName` each
        // allocate, and a comparator runs O(n log n) times.
        struct SortKey {
            let letter: Character
            let surname: String
            let given: String
            let display: String
            let individual: Individual
        }

        let keyed = individuals.map { individual -> SortKey in
            let display = individual.displayName.lowercased()
            return SortKey(
                letter: individual.indexLetter,
                surname: individual.surname?.lowercased() ?? display,
                given: individual.givenName?.lowercased() ?? "",
                display: display,
                individual: individual
            )
        }

        let sorted = keyed.sorted { lhs, rhs in
            if lhs.letter != rhs.letter { return lhs.letter < rhs.letter }
            if lhs.surname != rhs.surname { return lhs.surname < rhs.surname }
            if lhs.given != rhs.given { return lhs.given < rhs.given }
            return lhs.display < rhs.display
        }

        var sections: [IndividualSection] = []
        var currentLetter: Character?
        var currentMembers: [Individual] = []
        func flush() {
            guard let letter = currentLetter, !currentMembers.isEmpty else { return }
            sections.append(IndividualSection(title: letter, members: currentMembers))
            currentMembers.removeAll(keepingCapacity: true)
        }
        for key in sorted {
            if key.letter != currentLetter {
                flush()
                currentLetter = key.letter
            }
            currentMembers.append(key.individual)
        }
        flush()
        return sections
    }

    /// Prunes members that fail `predicate`, dropping sections left empty.
    /// Membership depends only on each individual's index letter, so filtering
    /// prebuilt sections yields the same result as rebuilding from the matches.
    static func filter(
        _ sections: [IndividualSection],
        where predicate: (Individual) -> Bool
    ) -> [IndividualSection] {
        sections.compactMap { section in
            let matches = section.members.filter(predicate)
            return matches.isEmpty ? nil : IndividualSection(title: section.title, members: matches)
        }
    }
}
