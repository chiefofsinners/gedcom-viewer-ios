//
//  GEDCOM_ViewerUITests.swift
//  GEDCOM ViewerUITests
//
//  Created by Alun Lewis on 13/10/2025.
//

import XCTest

final class GEDCOM_ViewerUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSnapshotSampleFlow() throws {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launch()
        ensureHomeTabIsSelected(in: app)

        let loadSampleButton = app.buttons["home.load_sample.button"]
        XCTAssertTrue(loadSampleButton.waitForExistence(timeout: 10), "Load Sample button not found on Home tab")

        snapshot("01-home")

        loadSampleButton.tap()

        let indexSearchField = app.textFields["index.search.field"]
        XCTAssertTrue(indexSearchField.waitForExistence(timeout: 20), "Index search field never appeared")

        snapshot("02-index")

        indexSearchField.clearAndTypeText("anthony")

        let personButtons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "index.person."))
        XCTAssertTrue(personButtons.count > 1, "Expected at least two index entries after filtering")

        snapshot("03-index-filtered")

        let targetRow = personButtons.element(boundBy: 1)
        XCTAssertTrue(targetRow.waitForExistence(timeout: 10), "Second search result did not appear")
        XCTAssertTrue(
            targetRow.staticTexts["Anthony Edward Munro"].waitForExistence(timeout: 1),
            "Expected the second search result to be Anthony Edward Munro"
        )

        targetRow.tap()

        // One pane switches to the Family tab; two panes (iPad, unfolded iPhone Duo) fill
        // the family pane beside the index. Either way the info button appears.
        let familyInfoButton = app.buttons["family.info.button"]
        XCTAssertTrue(familyInfoButton.waitForExistence(timeout: 10), "Family info button missing")

        snapshot("04-family")

        familyInfoButton.tap()

        let detailCloseButton = app.buttons["family.detail.close.button"]
        XCTAssertTrue(detailCloseButton.waitForExistence(timeout: 10), "Individual detail sheet did not present")

        let detailSheet = app.otherElements["family.detail.sheet"]
        if detailSheet.waitForExistence(timeout: 2) {
            detailSheet.swipeUp()
        }

        snapshot("05-family-info")
    }

    private func ensureHomeTabIsSelected(in app: XCUIApplication) {
        // The app may reopen the last file, landing on the index rather than Home.
        if app.buttons["home.load_sample.button"].waitForExistence(timeout: 3) { return }

        // Regular width and height (iPad, iPhone Duo opened out) uses the app's own top bar.
        let customHomeButton = app.buttons["tabbar.home.button"]
        if customHomeButton.exists {
            customHomeButton.tap()
            return
        }

        // The system tab bar: along the bottom, or since iOS 27.1 a vertical bar at the
        // side (folded iPhone Duo), which isn't reported as a tab bar. Home is first in both.
        let tabBar = app.tabBars.firstMatch
        let homeButton = tabBar.exists ? tabBar.buttons.element(boundBy: 0) : app.buttons["house"]
        guard homeButton.waitForExistence(timeout: 2) else { return }
        if !homeButton.isSelected {
            homeButton.tap()
        }
    }
}

private extension XCUIElement {
    func clearAndTypeText(_ text: String) {
        tap()
        if let currentValue = self.value as? String, !currentValue.isEmpty {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
            typeText(deleteString)
        }
        typeText(text)
    }
}
