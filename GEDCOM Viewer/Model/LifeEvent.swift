//
//  LifeEvent.swift
//  GEDCOM Viewer
//
//  Created by Codex on 13/10/2025.
//

import Foundation

struct LifeEvent: Hashable {
    let date: String?
    let place: String?
    let address: String?
    let value: String?
    let details: [String: [String]]
    let notes: [String]

    init(
        date: String? = nil,
        place: String? = nil,
        address: String? = nil,
        value: String? = nil,
        details: [String: [String]] = [:],
        notes: [String] = []
    ) {
        self.date = date?.nilIfBlank
        self.place = place?.nilIfBlank
        self.address = address?.nilIfBlank
        self.value = value?.nilIfBlank
        self.details = details.mapValues { $0.filter { !$0.isBlank } }.filter { !$0.value.isEmpty }
        self.notes = notes.filter { !$0.isBlank }
    }

    var description: String? {
        let segments = [
            date?.nilIfBlank,
            place?.nilIfBlank,
            address?.nilIfBlank
        ].compactMap { $0 }
        guard !segments.isEmpty else { return nil }
        return segments.joined(separator: " • ")
    }
}
