//
//  GedcomParser.swift
//  GEDCOM Viewer
//
//  Created by Codex on 13/10/2025.
//

import Foundation

enum GedcomParserError: Error, LocalizedError {
    case invalidEncoding

    var errorDescription: String? {
        switch self {
        case .invalidEncoding:
            return String(
                localized: "parser.error.invalid_encoding",
                defaultValue: "Unable to decode the GEDCOM file using the declared character set.",
                bundle: .main
            )
        }
    }
}

final class GedcomParser {
    private let lineExpression: NSRegularExpression
    private let textDecoder = GedcomTextDecoder()
    private let individualEventTags: Set<String> = [
        "BIRT", "DEAT", "BAPM", "BAPT", "CHR", "CHRA", "RESI", "OCCU", "BURI", "GRAD", "EDUC", "EVEN"
    ]
    private let familyEventTags: Set<String> = ["MARR"]

    init() {
        let pattern = #"^(\d+)\s+(?:(@[^@]+@)\s+)?([A-Z0-9_]+)(?:\s+(.*))?$"#
        lineExpression = try! NSRegularExpression(pattern: pattern, options: [])
    }

    func parse(data: Data, sourceIdentifier: String? = nil) throws -> GedcomData {
        let contents = try textDecoder.decode(data)

        let scope = IdentifierScope(rawSourceIdentifier: sourceIdentifier)

        var individuals: [String: IndividualBuilder] = [:]
        var families: [String: FamilyBuilder] = [:]
        var noteRecords: [String: NoteRecordBuilder] = [:]

        var currentIndividual: IndividualBuilder?
        var currentFamily: FamilyBuilder?
        var currentNoteRecord: NoteRecordBuilder?
        var contexts: [Context] = []

        contents.split(maxSplits: .max, omittingEmptySubsequences: false, whereSeparator: \.isNewline).forEach { rawSubstring in
            let rawLine = String(rawSubstring)
            let trimmedLine = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.isEmpty { return }

            let sanitized = trimmedLine.hasPrefix("\u{feff}") ? String(trimmedLine.dropFirst()) : trimmedLine
            guard let parsed = parseLine(sanitized) else { return }

            while let last = contexts.last, last.level >= parsed.level {
                contexts.removeLast()
            }

            if parsed.level == 0, let pointer = parsed.pointer {
                currentIndividual = nil
                currentFamily = nil
                currentNoteRecord = nil

                switch parsed.tag {
                case "INDI":
                    let builder = individuals[pointer, default: IndividualBuilder(id: pointer)]
                    individuals[pointer] = builder
                    currentIndividual = builder
                case "FAM":
                    let builder = families[pointer, default: FamilyBuilder(id: pointer)]
                    families[pointer] = builder
                    currentFamily = builder
                case "NOTE":
                    let builder = noteRecords[pointer, default: NoteRecordBuilder(id: pointer)]
                    builder.setInitial(parsed.value)
                    noteRecords[pointer] = builder
                    currentNoteRecord = builder
                default:
                    break
                }

                contexts = [Context(level: parsed.level, tag: parsed.tag, eventBuilder: nil)]
                return
            }

            let parentTag = contexts.last?.tag
            let pointerId = parsePointer(parsed.value)
            let currentEventContext = contexts.last(where: { $0.eventBuilder != nil })
            let currentEventBuilder = currentEventContext?.eventBuilder

            var handled = false
            var addedContext = false

            if let note = currentNoteRecord, contexts.last?.tag == "NOTE" {
                switch parsed.tag {
                case "CONC":
                    note.appendConc(parsed.value)
                    handled = true
                case "CONT":
                    note.appendCont(parsed.value)
                    handled = true
                default:
                    break
                }
            }

            if !handled, let individual = currentIndividual, individualEventTags.contains(parsed.tag) {
                let builder = individual.beginEvent(tag: parsed.tag, label: eventLabel(for: parsed.tag), rawValue: parsed.value)
                contexts.append(Context(level: parsed.level, tag: parsed.tag, eventBuilder: builder))
                addedContext = true
                handled = true
            }

            if !handled, let family = currentFamily, familyEventTags.contains(parsed.tag) {
                if let builder = family.beginEvent(tag: parsed.tag, rawValue: parsed.value) {
                    contexts.append(Context(level: parsed.level, tag: parsed.tag, eventBuilder: builder))
                    addedContext = true
                    handled = true
                }
            }

            if !handled, let individual = currentIndividual {
                var consumed = false
                if let eventBuilder = currentEventBuilder, let eventContext = currentEventContext {
                    consumed = eventBuilder.handle(tag: parsed.tag, value: parsed.value, pointer: pointerId, parentTag: parentTag, depth: parsed.level - eventContext.level)
                }
                if !consumed {
                    switch parsed.tag {
                    case "NAME":
                        individual.setName(parsed.value ?? "")
                        handled = true
                    case "GIVN" where parentTag == "NAME":
                        individual.setGivenName(parsed.value)
                        handled = true
                    case "SURN" where parentTag == "NAME":
                        individual.setSurname(parsed.value)
                        handled = true
                    case "TITL":
                        individual.setTitle(parsed.value)
                        handled = true
                    case "SEX":
                        individual.setGender(parsed.value)
                        handled = true
                    case "FAMC":
                        if let pointerId { individual.familiesAsChild.append(pointerId) }
                        handled = true
                    case "FAMS":
                        if let pointerId { individual.familiesAsSpouse.append(pointerId) }
                        handled = true
                    case "OBJE":
                        if individual.primaryObjectId == nil {
                            individual.primaryObjectId = pointerId
                            handled = true
                        }
                    case "NOTE":
                        individual.addNote(parsed.value, pointer: pointerId)
                        handled = true
                    default:
                        if parentTag == "NOTE", parsed.tag == "CONC" || parsed.tag == "CONT" {
                            individual.appendNoteContinuation(tag: parsed.tag, value: parsed.value)
                            handled = true
                        }
                    }
                } else {
                    handled = true
                }
            }

            if !handled, let family = currentFamily {
                var consumed = false
                if let eventBuilder = currentEventBuilder, let eventContext = currentEventContext {
                    consumed = eventBuilder.handle(tag: parsed.tag, value: parsed.value, pointer: pointerId, parentTag: parentTag, depth: parsed.level - eventContext.level)
                }
                if !consumed {
                    switch parsed.tag {
                    case "HUSB":
                        family.husbandId = pointerId
                        handled = true
                    case "WIFE":
                        family.wifeId = pointerId
                        handled = true
                    case "CHIL":
                        if let pointerId { family.children.append(pointerId) }
                        handled = true
                    default:
                        break
                    }
                } else {
                    handled = true
                }
            }

            if !addedContext, (currentIndividual != nil || currentFamily != nil || currentNoteRecord != nil) {
                contexts.append(Context(level: parsed.level, tag: parsed.tag, eventBuilder: nil))
            }
        }

        let resolvedNotes = noteRecords.mapValues { $0.build() }
        let resolvedIndividuals = Dictionary(uniqueKeysWithValues: individuals.map { (_, builder) -> (String, Individual) in
            let individual = builder.build(noteRecords: resolvedNotes, scope: scope)
            return (individual.id, individual)
        })
        let resolvedFamilies = Dictionary(uniqueKeysWithValues: families.map { (_, builder) -> (String, Family) in
            let family = builder.build(noteRecords: resolvedNotes, scope: scope)
            return (family.id, family)
        })

        return GedcomData(sourceId: scope.sourceId, individuals: resolvedIndividuals, families: resolvedFamilies)
    }

    private func parsePointer(_ raw: String?) -> String? {
        guard let raw, raw.hasPrefix("@"), raw.hasSuffix("@") else { return nil }
        return String(raw.dropFirst().dropLast())
    }

    private func parseLine(_ line: String) -> ParsedLine? {
        let range = NSRange(location: 0, length: line.utf16.count)
        guard let match = lineExpression.firstMatch(in: line, options: [], range: range) else { return nil }
        guard let levelRange = Range(match.range(at: 1), in: line),
              let level = Int(line[levelRange])
        else {
            return nil
        }
        let pointerRange = Range(match.range(at: 2), in: line)
        let tagRange = Range(match.range(at: 3), in: line)
        let valueRange = Range(match.range(at: 4), in: line)

        let pointer = pointerRange.map { String(line[$0]).sanitizedPointerIdentifier() }
        let tag = tagRange.map { String(line[$0]) } ?? ""
        let value = valueRange.flatMap { String(line[$0]).nilIfBlank }

        return ParsedLine(level: level, pointer: pointer, tag: tag, value: value)
    }

    private func eventLabel(for tag: String) -> String {
        let resource: (key: String, defaultValue: String)?
        switch tag {
        case "BIRT":
            resource = ("event.birth", "Birth")
        case "DEAT":
            resource = ("event.death", "Death")
        case "BAPM", "BAPT":
            resource = ("event.baptism", "Baptism")
        case "CHR":
            resource = ("event.christening", "Christening")
        case "CHRA":
            resource = ("event.adult_christening", "Adult Christening")
        case "RESI":
            resource = ("event.residence", "Residence")
        case "OCCU":
            resource = ("event.occupation", "Occupation")
        case "BURI":
            resource = ("event.burial", "Burial")
        case "GRAD":
            resource = ("event.graduation", "Graduation")
        case "EDUC":
            resource = ("event.education", "Education")
        case "EVEN":
            resource = ("event.event", "Event")
        case "MARR":
            resource = ("event.marriage", "Marriage")
        default:
            resource = nil
        }
        guard let resource else { return prettify(tag: tag) }
        return Bundle.main.localizedString(
            forKey: resource.key,
            value: resource.defaultValue,
            table: nil
        )
    }

    private func prettify(tag: String) -> String {
        tag.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
            .lowercased()
            .splittingByWhitespacesAndUnderscores()
            .filter { !$0.isBlank }
            .map { part -> String in
                guard let first = part.first else { return part }
                if first.isLowercase {
                    return part.prefix(1).uppercased() + part.dropFirst()
                } else {
                    return String(part)
                }
            }
            .joined(separator: " ")
            .nilIfBlank ?? tag
    }
}

// MARK: - Helpers

private extension String {
    func sanitizedPointerIdentifier() -> String {
        guard hasPrefix("@"), hasSuffix("@") else { return self }
        return String(dropFirst().dropLast())
    }
}

private struct ParsedLine {
    let level: Int
    let pointer: String?
    let tag: String
    let value: String?
}

private struct Context {
    let level: Int
    let tag: String
    let eventBuilder: LifeEventBuilder?
}

// MARK: - Builder types

private final class IndividualBuilder {
    let id: String
    private(set) var fullName: String
    private(set) var givenName: String?
    private(set) var surname: String?
    private var nameSuffix: String?
    private(set) var title: String?
    private(set) var gender: Individual.Gender = .unknown

    private let birthEvent = LifeEventBuilder()
    private let deathEvent = LifeEventBuilder()
    private var timelineEntries: [TimelineEntryContext] = []
    private var notes: [NoteValue] = []
    fileprivate var lastInlineNote: NoteValue.Inline?

    fileprivate var familiesAsSpouse: [String] = []
    fileprivate var familiesAsChild: [String] = []
    fileprivate var primaryObjectId: String?
    private var inPrimaryName = false

    init(id: String) {
        self.id = id
        self.fullName = ""
    }

    func setName(_ raw: String) {
        guard fullName.isEmpty else {
            inPrimaryName = false  // Subsequent NAME record — ignore
            return
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            fullName = ""
            givenName = nil
            surname = nil
            return
        }
        inPrimaryName = true
        let parts = trimmed.split(separator: "/").map { String($0).trimmingCharacters(in: .whitespaces) }
        givenName = parts.first?.nilIfBlank
        surname = parts.count > 1 ? parts[1].nilIfBlank : nil
        nameSuffix = parts.count > 2 ? parts[2].nilIfBlank : nil
        rebuildFullName()
    }

    func setGivenName(_ raw: String?) {
        guard inPrimaryName else { return }
        guard let value = raw?.trimmingCharacters(in: .whitespaces).nilIfBlank else { return }
        givenName = value
        rebuildFullName()
    }

    func setSurname(_ raw: String?) {
        guard inPrimaryName else { return }
        guard let value = raw?.trimmingCharacters(in: .whitespaces).nilIfBlank else { return }
        surname = value
        rebuildFullName()
    }

    private func rebuildFullName() {
        let constructed = [givenName, surname, nameSuffix].compactMap { $0?.nilIfBlank }
        if constructed.isEmpty {
            fullName = ""
        } else {
            fullName = constructed.joined(separator: " ")
        }
    }

    func setTitle(_ raw: String?) {
        title = raw?.nilIfBlank
    }

    func setGender(_ raw: String?) {
        switch raw?.uppercased() {
        case "M":
            gender = .male
        case "F":
            gender = .female
        default:
            gender = .unknown
        }
    }

    func beginEvent(tag: String, label: String, rawValue: String?) -> LifeEventBuilder {
        let builder: LifeEventBuilder
        switch tag {
        case "BIRT":
            builder = birthEvent
        case "DEAT":
            builder = deathEvent
        default:
            builder = LifeEventBuilder()
        }
        if !timelineEntries.contains(where: { $0.builder === builder }) {
            timelineEntries.append(TimelineEntryContext(tag: tag, label: label, builder: builder))
        }
        builder.setValue(rawValue)
        return builder
    }

    func addNote(_ value: String?, pointer: String?) {
        let note: NoteValue
        if let pointer {
            note = .pointer(pointer)
        } else {
            let inline = NoteValue.Inline()
            inline.append(value, newline: false)
            note = .inline(inline)
            lastInlineNote = inline
        }
        notes.append(note)
    }

    func appendNoteContinuation(tag: String, value: String?) {
        guard let inline = lastInlineNote ?? notes.lastInline else { return }
        inline.append(value, newline: tag == "CONT")
        lastInlineNote = inline
    }

    func build(noteRecords: [String: String], scope: IdentifierScope) -> Individual {
        let birth = birthEvent.build(noteRecords: noteRecords)
        let death = deathEvent.build(noteRecords: noteRecords)
        let timeline = timelineEntries.compactMap { entry -> TimelineEntry? in
            guard let event = entry.builder.build(noteRecords: noteRecords) else { return nil }
            return TimelineEntry(tag: entry.tag, label: entry.label, event: event)
        }
        let resolvedNotes = notes.compactMap { $0.resolve(using: noteRecords) }

        let scopedId = scope.scoped(id)
        let scopedFamiliesAsSpouse = familiesAsSpouse.map { scope.scoped($0) }
        let scopedFamiliesAsChild = familiesAsChild.map { scope.scoped($0) }

        return Individual(
            id: scopedId,
            gedcomId: id,
            sourceId: scope.sourceId,
            fullName: fullName,
            givenName: givenName,
            surname: surname,
            title: title,
            gender: gender,
            birth: birth,
            death: death,
            familiesAsSpouse: scopedFamiliesAsSpouse,
            familiesAsChild: scopedFamiliesAsChild,
            timeline: timeline,
            notes: resolvedNotes,
            primaryObjectId: primaryObjectId
        )
    }

    private struct TimelineEntryContext {
        let tag: String
        let label: String
        let builder: LifeEventBuilder
    }
}

private final class FamilyBuilder {
    let id: String
    var husbandId: String?
    var wifeId: String?
    var children: [String] = []
    private let marriageEvent = LifeEventBuilder()

    init(id: String) {
        self.id = id
    }

    func beginEvent(tag: String, rawValue: String?) -> LifeEventBuilder? {
        switch tag {
        case "MARR":
            marriageEvent.setValue(rawValue)
            return marriageEvent
        default:
            return nil
        }
    }

    func build(noteRecords: [String: String], scope: IdentifierScope) -> Family {
        Family(
            id: scope.scoped(id),
            gedcomId: id,
            sourceId: scope.sourceId,
            husbandId: scope.scoped(husbandId),
            wifeId: scope.scoped(wifeId),
            childrenIds: children.map { scope.scoped($0) },
            marriage: marriageEvent.build(noteRecords: noteRecords)
        )
    }
}

private final class LifeEventBuilder {
    private var date: String?
    private var place: String?
    private var addressBuilder: String?
    private var value: String?
    private var details: [String: [String]] = [:]
    private var notes: [NoteValue] = []
    private var lastInlineNote: NoteValue.Inline?

    func setValue(_ raw: String?) {
        value = raw?.nilIfBlank
    }

    /// - Parameter depth: the nesting depth of this line relative to the event tag itself
    ///   (1 = direct child such as the event's own DATE/PLAC, 2 = a continuation of a direct
    ///   child). Lines deeper than this belong to nested substructures such as source
    ///   citations (SOUR > DATA > DATE) and must NOT be treated as the event's own data.
    func handle(tag: String, value: String?, pointer: String?, parentTag: String?, depth: Int) -> Bool {
        if parentTag == "CHAN" {
            return true
        }
        if depth == 2, parentTag == "NOTE", tag == "CONC" || tag == "CONT" {
            appendNoteContinuation(tag: tag, value: value)
            return true
        }
        if depth == 2, parentTag == "ADDR", tag == "CONC" || tag == "CONT" {
            appendAddress(tag: tag, value: value)
            return true
        }
        if depth != 1 {
            // Belongs to a nested substructure (e.g. a source citation); ignore it so its
            // DATE/PLAC/NOTE do not overwrite the event's own fields.
            return false
        }

        switch tag {
        case "DATE":
            date = value
            return true
        case "PLAC":
            place = value
            return true
        case "ADDR":
            setAddress(value)
            return true
        case "NOTE":
            addNote(value, pointer: pointer)
            return true
        case "TYPE", "CAUS", "AGNC", "RELI":
            if let value, !value.isBlank {
                addDetail(tag: tag, value: value.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            return true
        default:
            return false
        }
    }

    private func addDetail(tag: String, value: String) {
        let label = formatLabel(tag: tag)
        var values = details[label, default: []]
        values.append(value)
        details[label] = values
    }

    private func addNote(_ value: String?, pointer: String?) {
        let note: NoteValue
        if let pointer {
            note = .pointer(pointer)
        } else {
            let inline = NoteValue.Inline()
            inline.append(value, newline: false)
            note = .inline(inline)
            lastInlineNote = inline
        }
        notes.append(note)
    }

    private func appendNoteContinuation(tag: String, value: String?) {
        guard let inline = lastInlineNote ?? notes.lastInline else { return }
        inline.append(value, newline: tag == "CONT")
        lastInlineNote = inline
    }

    private func setAddress(_ value: String?) {
        addressBuilder = value
    }

    private func appendAddress(tag: String, value: String?) {
        if addressBuilder == nil {
            addressBuilder = ""
        }
        if tag == "CONT" {
            if let builder = addressBuilder, !builder.isEmpty {
                addressBuilder = builder + "\n"
            } else if value == nil {
                addressBuilder = (addressBuilder ?? "") + "\n"
            }
        }
        if let value, !value.isEmpty {
            addressBuilder = (addressBuilder ?? "") + value
        }
    }

    func build(noteRecords: [String: String]) -> LifeEvent? {
        let address = addressBuilder?.nilIfBlank
        let normalizedValue = value?.nilIfBlank
        let resolvedDetails = details
            .mapValues { $0.compactMap { $0.nilIfBlank } }
            .filter { !$0.value.isEmpty }
        let resolvedNotes = notes.compactMap { $0.resolve(using: noteRecords) }

        let hasCoreData = [
            date?.nilIfBlank,
            place?.nilIfBlank,
            address,
            normalizedValue
        ].compactMap { $0 }.isEmpty == false

        if !hasCoreData, resolvedDetails.isEmpty, resolvedNotes.isEmpty {
            return nil
        }

        return LifeEvent(
            date: date,
            place: place,
            address: address,
            value: normalizedValue,
            details: resolvedDetails,
            notes: resolvedNotes
        )
    }

    private func formatLabel(tag: String) -> String {
        switch tag {
        case "CAUS":
            return String(
                localized: "event.detail.cause",
                defaultValue: "Cause",
                bundle: .main
            )
        case "TYPE":
            return String(
                localized: "event.detail.type",
                defaultValue: "Type",
                bundle: .main
            )
        case "AGNC":
            return String(
                localized: "event.detail.agency",
                defaultValue: "Agency",
                bundle: .main
            )
        case "RELI":
            return String(
                localized: "event.detail.religion",
                defaultValue: "Religion",
                bundle: .main
            )
        default:
            return tag
                .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
                .lowercased()
                .replacingOccurrences(of: "_", with: " ")
                .splittingByWhitespacesAndUnderscores()
                .filter { !$0.isBlank }
                .map { part -> String in
                    guard let first = part.first else { return part }
                    if first.isLowercase {
                        return part.prefix(1).uppercased() + part.dropFirst()
                    } else {
                        return String(part)
                    }
                }
                .joined(separator: " ")
                .nilIfBlank ?? tag
        }
    }
}

private enum NoteValue {
    case inline(NoteValue.Inline)
    case pointer(String)

    final class Inline {
        private(set) var text: String = ""

        func append(_ value: String?, newline: Bool) {
            if newline {
                if !text.isEmpty {
                    text.append("\n")
                } else if value == nil {
                    text.append("\n")
                }
            }
            if let value, !value.isEmpty {
                text.append(value)
            }
        }

        func build() -> String? {
            text.nilIfBlank
        }
    }

    func resolve(using noteRecords: [String: String]) -> String? {
        switch self {
        case .inline(let inline):
            return inline.build()
        case .pointer(let id):
            return noteRecords[id]?.nilIfBlank
        }
    }
}

private extension Array where Element == NoteValue {
    var lastInline: NoteValue.Inline? {
        for element in self.reversed() {
            if case .inline(let inline) = element {
                return inline
            }
        }
        return nil
    }
}

private struct IdentifierScope {
    let sourceId: String

    init(rawSourceIdentifier: String?) {
        if let normalized = IdentifierScope.normalized(rawSourceIdentifier) {
            sourceId = normalized
        } else {
            sourceId = IdentifierScope.fallbackIdentifier()
        }
    }

    func scoped(_ raw: String) -> String {
        "\(sourceId)::\(raw)"
    }

    func scoped(_ raw: String?) -> String? {
        raw.map { scoped($0) }
    }

    private static func normalized(_ raw: String?) -> String? {
        guard let raw, let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank else {
            return nil
        }
        let withoutColons = trimmed.replacingOccurrences(of: "::", with: "__")
        let sanitized = withoutColons.replacingOccurrences(
            of: #"[^A-Za-z0-9._-]"#,
            with: "_",
            options: .regularExpression
        )
        let collapsed = sanitized.replacingOccurrences(
            of: #"_+"#,
            with: "_",
            options: .regularExpression
        )
        return collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "_")).nilIfBlank
    }

    private static func fallbackIdentifier() -> String {
        "src-\(UUID().uuidString)"
    }
}

private final class NoteRecordBuilder {
    private var builder: String = ""

    init(id _: String) {}

    func setInitial(_ value: String?) {
        if let value {
            builder.append(value)
        }
    }

    func appendConc(_ value: String?) {
        if let value {
            builder.append(value)
        }
    }

    func appendCont(_ value: String?) {
        if !builder.isEmpty {
            builder.append("\n")
        }
        if let value {
            builder.append(value)
        }
    }

    func build() -> String {
        builder.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
