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

    init(
        sourceId: String = UUID().uuidString,
        individuals: [String: Individual] = [:],
        families: [String: Family] = [:]
    ) {
        self.sourceId = sourceId
        self.individuals = individuals
        self.families = families
    }

    var individualsSortedByName: [Individual] {
        individuals.values.sorted {
            let lhsSurname = $0.surname?.lowercased() ?? ""
            let rhsSurname = $1.surname?.lowercased() ?? ""
            if lhsSurname != rhsSurname { return lhsSurname < rhsSurname }

            let lhsGiven = $0.givenName?.lowercased() ?? $0.displayName.lowercased()
            let rhsGiven = $1.givenName?.lowercased() ?? $1.displayName.lowercased()
            return lhsGiven < rhsGiven
        }
    }

    func individual(id: String?) -> Individual? {
        guard let id, !id.isBlank else { return nil }
        return individuals[id]
    }

    func family(id: String?) -> Family? {
        guard let id, !id.isBlank else { return nil }
        return families[id]
    }
}
