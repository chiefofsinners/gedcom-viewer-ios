import Foundation
#if DEBUG

enum PreviewContent {
    static let data: GedcomData = {
        if let url = Bundle.main.url(forResource: "Sample-GEDCOM", withExtension: "ged"),
           let raw = try? Data(contentsOf: url),
           let parsed = try? GedcomParser().parse(data: raw, sourceIdentifier: "preview-sample") {
            return parsed
        }
        return fallbackData
    }()

    static var focusIndividual: Individual {
        data.individualsSortedByName.first ?? fallbackFocus
    }

    static var focusFamily: Family? {
        if let spouseFamilyId = focusIndividual.familiesAsSpouse.first,
           let family = data.family(id: spouseFamilyId) {
            return family
        }
        if let childFamilyId = focusIndividual.familiesAsChild.first,
           let family = data.family(id: childFamilyId) {
            return family
        }
        return fallbackData.families.values.first
    }

    static func state(selectedIndividualId: String? = nil) -> GedcomUIState {
        var state = GedcomUIState()
        state.data = data
        state.needsFileSelection = false
        state.currentFileName = "Sample GEDCOM"
        state.isSampleData = true
        state.selectedIndividualId = selectedIndividualId
        return state
    }

    private static let fallbackData: GedcomData = {
        let sourceId = "preview-fallback"
        let familyId = "\(sourceId)::F1"
        let focusId = "\(sourceId)::I1"
        let spouseId = "\(sourceId)::I2"
        let childId = "\(sourceId)::I3"

        let birthEvent = LifeEvent(date: "12 Jan 1984", place: "Cardiff, Wales")
        let focusTimeline: [TimelineEntry] = [
            TimelineEntry(tag: "BIRT", label: "Birth", event: birthEvent),
            TimelineEntry(
                tag: "OCCU",
                label: "Occupation",
                event: LifeEvent(place: "Oxford, England", value: "Research Botanist", details: ["ROLE": ["Team Lead"]])
            )
        ]

        let focus = Individual(
            id: focusId,
            gedcomId: "I1",
            sourceId: sourceId,
            fullName: "Alex Harper",
            givenName: "Alex",
            surname: "Harper",
            title: nil,
            gender: .male,
            birth: birthEvent,
            death: nil,
            familiesAsSpouse: [familyId],
            familiesAsChild: [],
            timeline: focusTimeline,
            notes: ["Enjoys tracing the Harper family roots back to the 18th century."],
            primaryObjectId: nil
        )

        let spouseBirth = LifeEvent(date: "23 Jul 1986", place: "Inverness, Scotland")
        let spouseTimeline: [TimelineEntry] = [
            TimelineEntry(tag: "BIRT", label: "Birth", event: spouseBirth),
            TimelineEntry(
                tag: "EDUC",
                label: "Education",
                event: LifeEvent(place: "University of Edinburgh", value: "MA History")
            )
        ]

        let spouse = Individual(
            id: spouseId,
            gedcomId: "I2",
            sourceId: sourceId,
            fullName: "Morgan Fraser",
            givenName: "Morgan",
            surname: "Fraser",
            title: nil,
            gender: .female,
            birth: spouseBirth,
            death: nil,
            familiesAsSpouse: [familyId],
            familiesAsChild: [],
            timeline: spouseTimeline,
            notes: ["Recorder of family anecdotes and keeper of photo albums."],
            primaryObjectId: nil
        )

        let childBirth = LifeEvent(date: "5 May 2014", place: "Manchester, England")
        let childTimeline: [TimelineEntry] = [
            TimelineEntry(tag: "BIRT", label: "Birth", event: childBirth),
            TimelineEntry(
                tag: "EDUC",
                label: "Education",
                event: LifeEvent(place: "Manchester", value: "Primary School")
            )
        ]

        let child = Individual(
            id: childId,
            gedcomId: "I3",
            sourceId: sourceId,
            fullName: "Jamie Harper",
            givenName: "Jamie",
            surname: "Harper",
            title: nil,
            gender: .unknown,
            birth: childBirth,
            death: nil,
            familiesAsSpouse: [],
            familiesAsChild: [familyId],
            timeline: childTimeline,
            notes: ["First to volunteer for school history projects."],
            primaryObjectId: nil
        )

        let marriage = LifeEvent(
            date: "14 Feb 2009",
            place: "London, England",
            notes: ["Reception held at the old town hall with a ceilidh to finish the evening."]
        )

        let family = Family(
            id: familyId,
            gedcomId: "F1",
            sourceId: sourceId,
            husbandId: focus.id,
            wifeId: spouse.id,
            childrenIds: [child.id],
            marriage: marriage
        )

        return GedcomData(
            sourceId: sourceId,
            individuals: [
                focus.id: focus,
                spouse.id: spouse,
                child.id: child
            ],
            families: [family.id: family]
        )
    }()

    private static var fallbackFocus: Individual {
        fallbackData.individualsSortedByName.first!
    }
}

#endif
