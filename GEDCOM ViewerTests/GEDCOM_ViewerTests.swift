//
//  GEDCOM_ViewerTests.swift
//  GEDCOM ViewerTests
//
//  Created by Alun Lewis on 13/10/2025.
//

import Foundation
import Testing
@testable import GEDCOM_Viewer

struct GedcomParserNameTests {
    private let parser = GedcomParser()

    @Test func usesFirstNameRecordWhenMultiplePresent() throws {
        let gedcom = """
            0 HEAD
            0 @I1@ INDI
            1 NAME John /Smith/
            2 TYPE aka
            1 NAME James /Smyth/
            2 TYPE birth
            2 GIVN James
            2 SURN Smyth
            0 TRLR
            """
        let data = Data(gedcom.utf8)
        let parsed = try parser.parse(data: data)
        let individual = try #require(parsed.individuals.values.first)
        #expect(individual.fullName == "John Smith")
    }
}

struct GedcomParserEventDateTests {
    private let parser = GedcomParser()

    @Test func ignoresSourceCitationRecordingDateForEventDate() throws {
        let gedcom = """
            0 HEAD
            0 @I1@ INDI
            1 NAME Charles /Hafner/
            1 DEAT
            2 DATE 21 Oct 2016
            2 PLAC West Chester, Pa
            2 SOUR @S49@
            3 DATA
            4 TEXT Charles P. Hafner Jr., 56, passed away on Friday, Oct. 21, 2016.
            4 DATE 24 Oct 2016
            0 TRLR
            """
        let parsed = try parser.parse(data: Data(gedcom.utf8))
        let individual = try #require(parsed.individuals.values.first)
        #expect(individual.death?.date == "21 Oct 2016")
    }

    @Test func usesEventDateWhenMultipleSourceCitationsPresent() throws {
        let gedcom = """
            0 HEAD
            0 @I1@ INDI
            1 NAME John /Doe/
            1 DEAT
            2 DATE 21 Jun 1977
            2 SOUR @S1@
            3 DATA
            4 DATE 22 Jun 1977
            2 SOUR @S2@
            3 DATA
            4 DATE 23 Jun 1977
            0 TRLR
            """
        let parsed = try parser.parse(data: Data(gedcom.utf8))
        let individual = try #require(parsed.individuals.values.first)
        #expect(individual.death?.date == "21 Jun 1977")
    }

    @Test func ignoresSourceCitationRecordingDateForMarriageDate() throws {
        let gedcom = """
            0 HEAD
            0 @F1@ FAM
            1 MARR
            2 DATE 1 Mar 1975
            2 SOUR @S1@
            3 DATA
            4 DATE 1 Mar 1975
            2 SOUR @S2@
            3 DATA
            4 DATE 2 Mar 1975
            2 SOUR @S3@
            3 DATA
            4 DATE 2 Mar 1975
            0 TRLR
            """
        let parsed = try parser.parse(data: Data(gedcom.utf8))
        let family = try #require(parsed.families.values.first)
        #expect(family.marriage?.date == "1 Mar 1975")
    }
}

struct GedcomParserEncodingTests {
    private let parser = GedcomParser()

    @Test func parsesReferenceGedcomFiles() throws {
        let directory = try referenceDirectory()
        for fileName in Self.referenceFileNames {
            let fileURL = directory.appendingPathComponent(fileName)
            let data = try Data(contentsOf: fileURL)
            let parsed = try parser.parse(data: data, sourceIdentifier: fileName)
            #expect(!parsed.individuals.isEmpty, "Expected to decode individuals from \(fileName)")
        }
    }

    private static let referenceFileNames = [
        "English+Tudor+Royal+Family.ged",
        "Lord+of+the+Rings+Family+Tree.ged",
        "TGC551.ged",
        "TGC551LF.ged",
        "TGC55C.ged",
        "TGC55CLF.ged"
    ]

    private func referenceDirectory(file: StaticString = #filePath) throws -> URL {
        let fileURL = URL(fileURLWithPath: "\(file)")
        let repositoryRoot = fileURL
            .deletingLastPathComponent() // GEDCOM ViewerTests
            .deletingLastPathComponent() // GEDCOM Viewer
            .deletingLastPathComponent() // Repository root
        let directory = repositoryRoot
            .appendingPathComponent("Reference")
            .appendingPathComponent("GEDCOM Files")

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw NSError(domain: "GedcomParserEncodingTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing Reference/GEDCOM Files directory"])
        }
        return directory
    }
}
