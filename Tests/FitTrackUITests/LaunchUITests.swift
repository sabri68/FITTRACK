import XCTest

/// End-to-end tests of the core workflows on the iPhone simulator.
/// Screenshots are attached (kept) so they can be reviewed and published in docs/screenshots.
final class FitTrackUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ arguments: [String] = ["-uiTesting", "-skipOnboarding"]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments + ["-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]
        app.launch()
        return app
    }

    private func screenshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func tapTab(_ app: XCUIApplication, _ label: String) {
        let button = app.tabBars.buttons[label]
        XCTAssertTrue(button.waitForExistence(timeout: 10), "Onglet \(label) introuvable")
        button.tap()
    }

    // MARK: Onboarding

    func testOnboardingFlowInFrench() {
        let app = launch(["-uiTesting"])
        XCTAssertTrue(app.staticTexts["Bienvenue sur FitTrack"].waitForExistence(timeout: 15))
        screenshot(app, "01-Bienvenue")
        let next = app.buttons["onboarding.next"]
        next.tap() // Commencer → profil
        XCTAssertTrue(app.staticTexts["Votre profil"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Taille : 177 cm"].exists || app.steppers["Taille : 177 cm"].exists,
                      "Le profil initial (177 cm) doit être prérempli")
        screenshot(app, "02-Profil")
        next.tap() // → objectif
        XCTAssertTrue(app.staticTexts["Votre objectif"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["5 séances par semaine"].exists || app.steppers["5 séances par semaine"].exists)
        next.tap() // → objectifs nutritionnels
        XCTAssertTrue(app.staticTexts["Vos objectifs quotidiens"].waitForExistence(timeout: 5))
        screenshot(app, "03-Objectifs")
        next.tap() // → Santé
        XCTAssertTrue(app.staticTexts["Apple Santé"].waitForExistence(timeout: 5))
        next.tap() // Terminer
        XCTAssertTrue(app.tabBars.buttons["Accueil"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["dashboard.startWorkout"].waitForExistence(timeout: 5))
    }

    // MARK: Navigation

    func testAllTabsAndScreensOpen() {
        let app = launch()
        XCTAssertTrue(app.buttons["dashboard.startWorkout"].waitForExistence(timeout: 15))
        screenshot(app, "04-Accueil")

        tapTab(app, "Entraînement")
        XCTAssertTrue(app.navigationBars["Entraînement"].waitForExistence(timeout: 5))
        screenshot(app, "05-Entrainement")
        app.buttons["template.0"].tap()
        XCTAssertTrue(app.staticTexts["Développé couché barre"].firstMatch.waitForExistence(timeout: 5))
        screenshot(app, "06-Programme-Jour1")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.buttons["workout.library"].tap()
        XCTAssertTrue(app.navigationBars["Bibliothèque"].waitForExistence(timeout: 5))
        let librarySearch = app.searchFields.firstMatch
        XCTAssertTrue(librarySearch.waitForExistence(timeout: 5))
        librarySearch.tap()
        librarySearch.typeText("Squat")
        let squat = app.staticTexts["Squat barre"].firstMatch
        XCTAssertTrue(squat.waitForExistence(timeout: 5))
        squat.tap()
        XCTAssertTrue(app.staticTexts["Exécution"].waitForExistence(timeout: 5))
        screenshot(app, "07-Fiche-exercice")

        tapTab(app, "Nutrition")
        XCTAssertTrue(app.staticTexts["Aujourd'hui"].waitForExistence(timeout: 5))
        screenshot(app, "08-Nutrition")

        tapTab(app, "Progrès")
        XCTAssertTrue(app.navigationBars["Progrès"].waitForExistence(timeout: 5))
        screenshot(app, "09-Progres")

        tapTab(app, "Profil")
        XCTAssertTrue(app.navigationBars["Profil"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches["profile.halal"].exists)
        screenshot(app, "10-Profil")

        tapTab(app, "Accueil")
        XCTAssertTrue(app.buttons["dashboard.startWorkout"].waitForExistence(timeout: 5))
    }

    // MARK: Workout

    func testCompleteWorkoutFlow() {
        let app = launch()
        let start = app.buttons["dashboard.startWorkout"]
        XCTAssertTrue(start.waitForExistence(timeout: 15))
        start.tap()

        XCTAssertTrue(app.staticTexts["active.timer"].waitForExistence(timeout: 5))
        let completeButtons = app.buttons.matching(identifier: "set.complete")
        XCTAssertGreaterThan(completeButtons.count, 0)
        completeButtons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["rest.remaining"].waitForExistence(timeout: 5), "Le minuteur de repos doit démarrer")
        screenshot(app, "11-Seance-en-cours")
        app.buttons["rest.skip"].tap()
        completeButtons.element(boundBy: 1).tap()
        app.buttons["rest.skip"].tap()

        // Pause and resume.
        app.buttons["active.pause"].tap()
        XCTAssertTrue(app.staticTexts["En pause"].waitForExistence(timeout: 3))
        app.buttons["active.pause"].tap()
        XCTAssertTrue(app.staticTexts["Durée"].waitForExistence(timeout: 3))

        // Add an exercise.
        app.buttons["active.addExercise"].tap()
        let pick = app.buttons["pick.skull_crusher"]
        XCTAssertTrue(pick.waitForExistence(timeout: 5))
        pick.tap()

        app.buttons["active.finish"].tap()
        let confirm = app.buttons["Terminer et enregistrer"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(app.staticTexts["Séance terminée !"].waitForExistence(timeout: 10))
        screenshot(app, "12-Seance-terminee")
        app.buttons["summary.close"].tap()

        tapTab(app, "Entraînement")
        XCTAssertTrue(app.buttons["workout.history"].waitForExistence(timeout: 5), "La séance doit apparaître dans l'historique")
        app.buttons["workout.history"].tap()
        XCTAssertTrue(app.staticTexts["Jour 1 · Haut du corps"].firstMatch.waitForExistence(timeout: 5))
    }

    // MARK: Nutrition

    func testAddGenericFoodBySearch() {
        let app = launch()
        tapTab(app, "Nutrition")
        app.buttons["nutrition.add.lunch"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("poulet")
        let chicken = app.staticTexts["Blanc de poulet cuit"].firstMatch
        XCTAssertTrue(chicken.waitForExistence(timeout: 5))
        screenshot(app, "13-Recherche-aliment")
        chicken.tap()
        XCTAssertTrue(app.buttons["food.add"].waitForExistence(timeout: 5))
        screenshot(app, "14-Detail-aliment")
        app.buttons["food.add"].tap()
        XCTAssertTrue(app.staticTexts["Blanc de poulet cuit"].firstMatch.waitForExistence(timeout: 5), "L'aliment doit apparaître dans le journal")
        screenshot(app, "15-Journal")
    }

    func testAddFoodManually() {
        let app = launch()
        tapTab(app, "Nutrition")
        app.buttons["nutrition.add"].tap()
        app.segmentedControls["addFood.mode"].buttons["Manuel"].tap()
        let name = app.textFields["manual.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Galette maison")
        for (id, value) in [("manual.kcal", "250"), ("manual.protein", "10"), ("manual.carbs", "30"), ("manual.fat", "9")] {
            let field = app.textFields[id].firstMatch
            XCTAssertTrue(field.waitForExistence(timeout: 3), "Champ \(id) introuvable")
            field.tap()
            field.typeText(value)
            // Close the keyboard so the next field is not hidden behind it.
            let ok = app.toolbars.buttons["OK"].firstMatch
            if ok.waitForExistence(timeout: 2) { ok.tap() }
        }
        app.swipeUp()
        app.buttons["manual.continue"].tap()
        XCTAssertTrue(app.buttons["food.add"].waitForExistence(timeout: 5))
        app.buttons["food.add"].tap()
        XCTAssertTrue(app.staticTexts["Galette maison"].firstMatch.waitForExistence(timeout: 5))
    }

    // MARK: Persistence

    /// Kills the app in the middle of a workout and checks that everything is restored.
    func testDataSurvivesRestartAndUnexpectedTermination() {
        var app = launch(["-uiTestingDisk", "-resetStore", "-skipOnboarding"])
        // Log a food.
        tapTab(app, "Nutrition")
        app.buttons["nutrition.add.breakfast"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("banane")
        XCTAssertTrue(app.staticTexts["Banane"].firstMatch.waitForExistence(timeout: 5))
        app.staticTexts["Banane"].firstMatch.tap()
        app.buttons["food.add"].tap()
        XCTAssertTrue(app.staticTexts["Banane"].firstMatch.waitForExistence(timeout: 5))

        // Start a workout and validate one set, then kill the app.
        tapTab(app, "Accueil")
        app.buttons["dashboard.startWorkout"].tap()
        let complete = app.buttons.matching(identifier: "set.complete").element(boundBy: 0)
        XCTAssertTrue(complete.waitForExistence(timeout: 5))
        complete.tap()
        XCTAssertEqual(complete.label, "Série validée")
        app.terminate()

        // Relaunch on the same store: the workout is offered again with its validated set.
        app = launch(["-uiTestingDisk", "-skipOnboarding"])
        XCTAssertTrue(app.staticTexts["active.timer"].waitForExistence(timeout: 15), "La séance interrompue doit être restaurée")
        XCTAssertEqual(app.buttons.matching(identifier: "set.complete").element(boundBy: 0).label, "Série validée")
        app.buttons["active.minimize"].tap()
        XCTAssertTrue(app.buttons["dashboard.resume"].waitForExistence(timeout: 5))
        tapTab(app, "Nutrition")
        XCTAssertTrue(app.staticTexts["Banane"].firstMatch.waitForExistence(timeout: 5), "Le repas doit être conservé après redémarrage")
    }
}
