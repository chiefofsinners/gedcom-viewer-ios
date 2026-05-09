//
//  Individual.swift
//  GEDCOM Viewer
//
//  Created by Codex on 13/10/2025.
//

import Foundation

struct Individual: Identifiable, Hashable {
    enum Gender: String {
        case male
        case female
        case unknown
    }

    /// Unique, app-scoped identifier composed of the GEDCOM pointer and source token.
    let id: String
    /// Raw GEDCOM pointer value (e.g. "I1").
    let gedcomId: String
    /// Unique token shared by every record parsed from the same data source.
    let sourceId: String
    let fullName: String
    let givenName: String?
    let surname: String?
    let title: String?
    let gender: Gender
    let birth: LifeEvent?
    let death: LifeEvent?
    let familiesAsSpouse: [String]
    let familiesAsChild: [String]
    let timeline: [TimelineEntry]
    let notes: [String]
    let primaryObjectId: String?

    var displayName: String {
        if let name = fullName.nilIfBlank {
            if let qualifier = title?.nilIfBlank {
                return "\(name) (\(qualifier))"
            }
            return name
        }
        if let qualifier = title?.nilIfBlank {
            return qualifier
        }
        return String(
            localized: "individual.name.unnamed",
            defaultValue: "Unnamed",
            bundle: .main
        )
    }
}
