//
//  GedcomData.swift
//  GEDCOM Viewer
//
//  Created by Codex on 13/10/2025.
//

import Foundation

struct GedcomData: Hashable {
    /// Unique token identifying the source this data was parsed from.
    let sourceId: String
    let individuals: [String: Individual]
    let families: [String: Family]

    /// Derived once at construction, on whichever queue parsed the file. Both are
    /// pure functions of `individuals`, so they take no part in equality or hashing.
    let individualsSortedByName: [Individual]
    let indexSections: [IndividualSection]

    init(
        sourceId: String = UUID().uuidString,
        individuals: [String: Individual] = [:],
        families: [String: Family] = [:]
    ) {
        self.sourceId = sourceId
        self.individuals = individuals
        self.families = families

        let sorted = Self.sortedByName(individuals.values)
        self.individualsSortedByName = sorted
        self.indexSections = IndividualSection.build(from: sorted)
    }

    private static func sortedByName(_ individuals: Dictionary<String, Individual>.Values) -> [Individual] {
        // Decorated so the comparator never allocates; see IndividualSection.build.
        let keyed = individuals.map { individual -> (surname: String, given: String, individual: Individual) in
            (
                surname: individual.surname?.lowercased() ?? "",
                given: individual.givenName?.lowercased() ?? individual.displayName.lowercased(),
                individual: individual
            )
        }
        return keyed
            .sorted { lhs, rhs in
                if lhs.surname != rhs.surname { return lhs.surname < rhs.surname }
                return lhs.given < rhs.given
            }
            .map(\.individual)
    }

    func individual(id: String?) -> Individual? {
        guard let id, !id.isBlank else { return nil }
        return individuals[id]
    }

    func family(id: String?) -> Family? {
        guard let id, !id.isBlank else { return nil }
        return families[id]
    }

    static func == (lhs: GedcomData, rhs: GedcomData) -> Bool {
        lhs.sourceId == rhs.sourceId
            && lhs.individuals == rhs.individuals
            && lhs.families == rhs.families
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(sourceId)
        hasher.combine(individuals)
        hasher.combine(families)
    }
}
