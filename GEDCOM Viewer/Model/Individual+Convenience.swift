import Foundation

extension Individual {
    var indexLetter: Character {
        let source = surname?.nilIfBlank ?? displayName
        guard let letter = source.first(where: { $0.isLetter }) else { return "#" }
        return letter.uppercased().first ?? letter
    }

    var birthSummary: String? {
        birth?.description.flatMap { summary in
            summary.isBlank ? nil : summary
        }
    }

    var deathSummary: String? {
        death?.description.flatMap { summary in
            summary.isBlank ? nil : summary
        }
    }

    /// Index search match. `query` is expected to be trimmed and lowercased already.
    func matches(searchQuery query: String) -> Bool {
        if displayName.lowercased().contains(query) { return true }
        if let surname, surname.lowercased().contains(query) { return true }
        if let givenName, givenName.lowercased().contains(query) { return true }
        return false
    }
}
