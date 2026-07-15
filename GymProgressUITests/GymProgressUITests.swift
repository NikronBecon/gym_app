import XCTest

final class GymProgressUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testScheduleStartAndFinishWorkout() throws {
        let app = launchApp()

        app.tabBars.buttons["Календарь"].tap()
        app.buttons["calendar.addWorkout"].tap()
        XCTAssertTrue(app.buttons["schedule.save"].waitForExistence(timeout: 2))
        app.buttons["schedule.save"].tap()

        app.tabBars.buttons["Сегодня"].tap()
        XCTAssertTrue(app.buttons["today.startScheduled"].waitForExistence(timeout: 2))
        app.buttons["today.startScheduled"].tap()
        XCTAssertTrue(app.buttons["startWorkout.confirm"].waitForExistence(timeout: 2))
        app.buttons["startWorkout.confirm"].tap()

        XCTAssertTrue(app.buttons["workout.finish"].waitForExistence(timeout: 3))
        app.buttons["workout.finish"].tap()
        XCTAssertTrue(app.buttons["finishWorkout.save"].waitForExistence(timeout: 2))
        app.buttons["finishWorkout.save"].tap()

        app.tabBars.buttons["Прогресс"].tap()
        XCTAssertTrue(app.navigationBars["Прогресс"].waitForExistence(timeout: 2))
    }

    func testTemplateEditorHasOneAddExerciseControl() throws {
        let app = launchApp()

        app.buttons["Шаблоны"].tap()
        XCTAssertTrue(app.navigationBars["Шаблоны"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Править"].exists)

        app.buttons["День 1"].tap()
        XCTAssertTrue(app.navigationBars["День 1"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label == %@", "Добавить упражнение")).count, 1)
    }

    func testStartedScheduleIsNotOfferedAgain() throws {
        let app = launchApp()

        app.tabBars.buttons["Календарь"].tap()
        app.buttons["calendar.addWorkout"].tap()
        XCTAssertTrue(app.buttons["schedule.save"].waitForExistence(timeout: 2))
        app.buttons["schedule.save"].tap()

        app.tabBars.buttons["Сегодня"].tap()
        XCTAssertTrue(app.buttons["today.startScheduled"].waitForExistence(timeout: 2))
        app.buttons["today.startScheduled"].tap()
        app.buttons["startWorkout.confirm"].tap()
        XCTAssertTrue(app.buttons["Выйти"].waitForExistence(timeout: 3))
        app.buttons["Выйти"].tap()

        XCTAssertTrue(app.buttons["today.resumeWorkout"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["today.startScheduled"].waitForNonExistence(timeout: 3))
    }

    func testExerciseDetailOpensWithAnimationResource() throws {
        let app = launchApp()

        app.tabBars.buttons["Упражнения"].tap()
        XCTAssertTrue(app.staticTexts["100 упражнений"].waitForExistence(timeout: 2))
        app.searchFields.firstMatch.tap()
        app.searchFields.firstMatch.typeText("Жим штанги лёжа")
        XCTAssertTrue(app.buttons["Жим штанги лёжа, Грудь"].waitForExistence(timeout: 2))
        app.buttons["Жим штанги лёжа, Грудь"].tap()

        XCTAssertTrue(app.navigationBars["Жим штанги лёжа"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Техника"].exists)
    }

    func testDeletingPlannedSetDoesNotOpenWeightUnitMenu() throws {
        let app = launchApp()

        app.buttons["Шаблоны"].tap()
        app.buttons["День 1"].tap()
        XCTAssertTrue(app.navigationBars["День 1"].waitForExistence(timeout: 2))
        app.buttons["Жим штанги лёжа"].tap()
        XCTAssertTrue(app.navigationBars["Варианты"].waitForExistence(timeout: 2))
        app.buttons["Жим штанги лёжа"].tap()
        XCTAssertTrue(app.buttons["Удалить подход 1"].waitForExistence(timeout: 2))

        app.buttons["Удалить подход 1"].tap()

        XCTAssertTrue(app.buttons["Удалить подход 4"].waitForNonExistence(timeout: 2))
        XCTAssertFalse(app.buttons["lb"].exists)
    }

    func testLaunchPerformance() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        let options = XCTMeasureOptions()
        options.iterationCount = 3

        measure(metrics: [XCTApplicationLaunchMetric()], options: options) {
            app.launch()
        }
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
        return app
    }
}
