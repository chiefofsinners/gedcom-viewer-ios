import Foundation

extension Individual {
    var indexLetter: Character {
        let source = surname?.nilIfBlank ?? displayName
        let letter = source.first { $0.isLetter } ?? "#"
        return Character(String(letter).uppercased())
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
}
