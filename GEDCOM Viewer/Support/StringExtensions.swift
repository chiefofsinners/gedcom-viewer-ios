//
//  StringExtensions.swift
//  GEDCOM Viewer
//
//  Created by Codex on 13/10/2025.
//

import Foundation

extension String {
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func splittingByWhitespacesAndUnderscores() -> [String] {
        split { $0 == " " || $0 == "_" }.map(String.init)
    }
}
