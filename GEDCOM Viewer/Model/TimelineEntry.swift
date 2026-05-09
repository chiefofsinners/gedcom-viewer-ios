//
//  TimelineEntry.swift
//  GEDCOM Viewer
//
//  Created by Codex on 13/10/2025.
//

import Foundation

struct TimelineEntry: Hashable {
    let tag: String
    let label: String
    let event: LifeEvent
}
