//
//  Family.swift
//  GEDCOM Viewer
//
//  Created by Codex on 13/10/2025.
//

import Foundation

struct Family: Identifiable, Hashable {
    /// Unique, app-scoped identifier composed of the GEDCOM pointer and source token.
    let id: String
    /// Raw GEDCOM pointer (e.g. "F1").
    let gedcomId: String
    /// Token shared by every record parsed from the same data source.
    let sourceId: String
    let husbandId: String?
    let wifeId: String?
    let childrenIds: [String]
    let marriage: LifeEvent?
}
