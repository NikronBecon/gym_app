import XCTest

final class GymProgressUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testScheduleStartAndFinishWorkout() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()

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
}
