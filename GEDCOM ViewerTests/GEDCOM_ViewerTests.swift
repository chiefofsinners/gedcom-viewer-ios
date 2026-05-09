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
