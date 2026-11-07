import XCTest

final class MusiquePapaUITests: XCTestCase {
    var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication(); app.launchArguments = ["--ui-testing", "--reset-ui-testing", "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]
        app.launch()
        XCUIDevice.shared.orientation = .portrait
    }
    private func demos() {
        let button = app.buttons["Essayer les démonstrations"]
        XCTAssertTrue(button.waitForExistence(timeout: 10)); button.tap()
        let done = app.buttons["Terminé"]; XCTAssertTrue(done.waitForExistence(timeout: 15)); done.tap()
    }
    private func screenshot(_ name: String) {
        Thread.sleep(forTimeInterval: 0.7) // Let native rotation/button transitions settle before visual QA.
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testChordTouchZoomPlaybackAndRelaunch() {
        demos(); app.buttons.containing(.staticText, identifier: "Balade du dimanche").firstMatch.tap()
        let zoom = app.staticTexts["zoomLabel"]; XCTAssertTrue(zoom.waitForExistence(timeout: 10))
        let initial = zoom.label
        app.buttons["zoomIn"].tap(); XCTAssertNotEqual(zoom.label, initial)
        let beforePinch = zoom.label
        app.otherElements["scoreReader"].pinch(withScale: 1.4, velocity: 1)
        XCTAssertNotEqual(zoom.label, beforePinch)
        app.buttons["playPause"].tap()
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 3))
        let progress = app.staticTexts["progressLabel"]
        let progressing = NSPredicate(format: "label != %@", "0 %")
        expectation(for: progressing, evaluatedWith: progress); waitForExpectations(timeout: 15)
        let zoomWhilePlaying = zoom.label
        app.otherElements["scoreReader"].pinch(withScale: 1.15, velocity: 1)
        XCTAssertNotEqual(zoom.label, zoomWhilePlaying)
        XCTAssertTrue(app.buttons["Pause"].exists)
        app.buttons["playPause"].tap(); let paused = progress.label
        let pauseHolds = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", paused), object: progress)
        XCTAssertEqual(XCTWaiter.wait(for: [pauseHolds], timeout: 0.8), .timedOut)
        screenshot("ChordPro-portrait")
        XCUIDevice.shared.orientation = .landscapeLeft
        expectation(for: NSPredicate { _, _ in self.app.frame.width > self.app.frame.height }, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        screenshot("ChordPro-paysage")
        app.buttons["Mode scène"].tap()
        XCTAssertTrue(app.buttons["Quitter le mode scène"].waitForExistence(timeout: 5))
        app.buttons["Afficher ou masquer les commandes"].tap()
        XCTAssertFalse(app.buttons["playPause"].exists)
        screenshot("Mode-scene")
        app.buttons["Afficher ou masquer les commandes"].tap()
        app.buttons["Quitter le mode scène"].tap()
        app.buttons["stop"].tap(); XCTAssertEqual(progress.label, "0 %")
        let savedZoom = zoom.label
        app.terminate(); app.launchArguments.removeAll { $0 == "--reset-ui-testing" }; app.launch()
        app.buttons["Lecteur"].firstMatch.tap()
        XCTAssertTrue(zoom.waitForExistence(timeout: 10)); XCTAssertEqual(zoom.label, savedZoom)
    }
    func testPDFTouchZoomAndPlayback() {
        demos(); app.buttons.containing(.staticText, identifier: "Exercice_10_pages").firstMatch.tap()
        let zoom = app.staticTexts["zoomLabel"]; XCTAssertTrue(zoom.waitForExistence(timeout: 10))
        let initial = zoom.label
        app.otherElements["scoreReader"].pinch(withScale: 1.6, velocity: 1)
        expectation(for: NSPredicate(format: "label != %@", initial), evaluatedWith: zoom); waitForExpectations(timeout: 5)
        app.buttons["playPause"].tap()
        expectation(for: NSPredicate(format: "label != %@", "0 %"), evaluatedWith: app.staticTexts["progressLabel"]); waitForExpectations(timeout: 20)
        let zoomWhilePlaying = zoom.label
        app.otherElements["scoreReader"].pinch(withScale: 1.15, velocity: 1)
        XCTAssertNotEqual(zoom.label, zoomWhilePlaying)
        XCTAssertTrue(app.buttons["Pause"].exists)
        app.buttons["playPause"].tap()
        screenshot("PDF-zoom")
        app.buttons["stop"].tap(); XCTAssertEqual(app.staticTexts["progressLabel"].label, "0 %")
    }
    func testPlaylistCreationAndFilesPicker() {
        demos(); app.buttons["Playlists"].firstMatch.tap(); app.buttons["Créer"].tap()
        app.alerts.textFields.firstMatch.tap(); app.alerts.textFields.firstMatch.typeText("Concert")
        app.alerts.buttons["Créer"].tap(); app.staticTexts["Concert"].firstMatch.tap()
        app.buttons["Ajouter des partitions"].tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Balade du dimanche,")).firstMatch.tap()
        app.buttons["Terminé"].tap()
        XCTAssertTrue(app.staticTexts["Balade du dimanche"].exists)
        screenshot("Playlist")
        app.buttons["Bibliothèque"].firstMatch.tap(); app.buttons["Importer"].tap(); app.buttons["Importer des fichiers"].tap()
        let document = app.staticTexts["Import_depuis_Fichiers"]
        if !document.waitForExistence(timeout: 15) { print(app.debugDescription) }
        XCTAssertTrue(document.exists)
        screenshot("Import-Fichiers")
        document.tap()
        let open = app.buttons["Ouvrir"]
        if open.waitForExistence(timeout: 3) { open.tap() }
        XCTAssertTrue(app.buttons["Terminé"].waitForExistence(timeout: 15)); app.buttons["Terminé"].tap()
        XCTAssertTrue(app.staticTexts["Import depuis Fichiers"].waitForExistence(timeout: 5))
    }
    private func revealKey(_ identifier: String, upwards: Bool) {
        let list = app.descendants(matching: .any)["keyList"].firstMatch
        let key = app.buttons[identifier]
        for _ in 0..<5 {
            if key.exists && key.isHittable { return }
            if upwards { list.swipeUp() } else { list.swipeDown() }
        }
        XCTAssertTrue(key.isHittable, "Option de tonalité inaccessible : \(identifier)")
    }
    func testTonalityScrollBothDirectionsPortraitLandscapeAndColorPersistence() {
        demos(); app.buttons.containing(.staticText, identifier: "Balade du dimanche").firstMatch.tap()
        XCTAssertTrue(app.buttons["tonalityButton"].waitForExistence(timeout: 5)); app.buttons["tonalityButton"].tap()
        XCTAssertTrue(app.buttons["key-C-major"].waitForExistence(timeout: 5))
        revealKey("key-B-major", upwards: true); app.buttons["key-B-major"].tap()
        revealKey("key-C-major", upwards: false); app.buttons["key-C-major"].tap()
        XCTAssertTrue(app.staticTexts["displayKeyLabel"].label.contains("Do (C)"))
        screenshot("Tonalite-portrait")
        XCUIDevice.shared.orientation = .landscapeLeft
        revealKey("key-B-major", upwards: true); app.buttons["key-B-major"].tap()
        revealKey("key-C-major", upwards: false); app.buttons["key-C-major"].tap()
        app.buttons["Mineur"].tap()
        revealKey("key-E-minor", upwards: true); app.buttons["key-E-minor"].tap()
        XCTAssertTrue(app.staticTexts["displayKeyLabel"].label.contains("Em"))
        screenshot("Tonalite-paysage")
        app.buttons["Terminé"].tap()
        XCTAssertEqual(app.buttons["tonalityButton"].label, "Em")
        app.buttons["Couleur des accords"].tap(); app.buttons["chordColor-Rouge"].tap(); app.buttons["Terminé"].tap()
        screenshot("Accords-rouges")
        app.terminate(); app.launchArguments.removeAll { $0 == "--reset-ui-testing" }; app.launch()
        app.buttons["Lecteur"].firstMatch.tap()
        XCTAssertTrue(app.buttons["tonalityButton"].waitForExistence(timeout: 5)); XCTAssertEqual(app.buttons["tonalityButton"].label, "Em")
    }
    func testEditorCreatePreviewSaveReopenAndDiscard() {
        app.buttons["Nouvelle chanson"].tap()
        let source = app.textViews["chordSourceEditor"]
        XCTAssertTrue(source.waitForExistence(timeout: 5))
        app.buttons["Informations"].tap()
        let title = app.textFields["metadata-title"]; XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (title.value as? String ?? "").count))
        title.typeText("Chanson de Papa")
        XCTAssertEqual(title.value as? String, "Chanson de Papa")
        app.buttons["Appliquer"].tap()
        XCTAssertTrue((source.value as? String ?? "").contains("{title: Chanson de Papa}"))
        // Applying metadata leaves the caret at the start of the source.
        source.typeText("{unknown_songbook: conserver}\n[Am7]Bonjour à vélo\n{soc}\n[C/G]Le refrain\n{eoc}\n")
        app.buttons["editorHideKeyboard"].tap()
        app.buttons["Agrandir le texte d’édition"].tap()
        XCTAssertEqual(app.staticTexts["editorFontLabel"].label, "22 pt")
        source.pinch(withScale: 1.2, velocity: 1)
        XCTAssertNotEqual(app.staticTexts["editorFontLabel"].label, "22 pt")
        screenshot("Editeur-portrait")
        app.buttons["toggleEditorPreview"].tap()
        XCTAssertTrue(app.scrollViews["chordPreview"].waitForExistence(timeout: 5))
        screenshot("Editeur-apercu-portrait")
        app.buttons["toggleEditorPreview"].tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        screenshot("Editeur-paysage")
        app.buttons["saveChordSource"].tap()
        XCTAssertTrue(app.staticTexts["Chanson de Papa"].waitForExistence(timeout: 5))
        app.buttons.containing(.staticText, identifier: "Chanson de Papa").firstMatch.tap()
        app.buttons["editChordSong"].tap()
        XCTAssertTrue(source.waitForExistence(timeout: 5))
        XCTAssertTrue((source.value as? String ?? "").contains("{unknown_songbook: conserver}"))
        XCTAssertTrue((source.value as? String ?? "").contains("Bonjour à vélo"))
        source.tap(); source.typeText("Non enregistré")
        app.buttons["Annuler"].firstMatch.tap()
        XCTAssertTrue(app.alerts["Quitter sans enregistrer ?"].waitForExistence(timeout: 5))
        app.alerts.buttons["Abandonner les modifications"].tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: source)
        waitForExpectations(timeout: 5)
        expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: app.buttons["editChordSong"])
        waitForExpectations(timeout: 5)
        app.buttons["editChordSong"].tap(); XCTAssertTrue(source.waitForExistence(timeout: 5))
        XCTAssertFalse((source.value as? String ?? "").contains("Non enregistré"))
        app.buttons["Annuler"].firstMatch.tap()
    }
    func testConversionComparisonCorrectionSaveAndReopen() {
        app.buttons["Importer"].tap(); app.buttons["Importer depuis une URL / un texte"].tap()
        let title = app.textFields["conversionTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap()
        title.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (title.value as? String ?? "").count))
        title.typeText("Conversion de Papa")
        let pasted = app.textViews["conversionPaste"]; pasted.tap(); pasted.typeText("C       G7\nBonjour le soleil\nAm      F\nLa guitare chante")
        app.buttons["convertPasted"].tap()
        XCTAssertTrue(app.buttons["saveChordSource"].waitForExistence(timeout: 10))
        app.segmentedControls["conversionMode"].buttons["Modifier"].tap()
        let source = app.textViews["chordSourceEditor"]; XCTAssertTrue(source.waitForExistence(timeout: 5))
        app.buttons["Informations"].tap()
        let artist = app.textFields["metadata-artist"]; artist.tap(); artist.typeText("Démonstration")
        app.buttons["Appliquer"].tap()
        // Metadata replacement sets the editor caret at the beginning, outside the title directive.
        source.typeText("[Dm]Correction manuelle\n")
        app.buttons["editorHideKeyboard"].tap()
        screenshot("Conversion-correction-portrait")
        app.segmentedControls["conversionMode"].buttons["Résultat"].tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        screenshot("Conversion-comparaison-paysage")
        app.buttons["saveChordSource"].tap()
        XCTAssertTrue(app.buttons["Fermer"].waitForExistence(timeout: 5)); app.buttons["Fermer"].tap()
        XCTAssertTrue(app.staticTexts["Conversion de Papa"].waitForExistence(timeout: 5))
        app.buttons.containing(.staticText, identifier: "Conversion de Papa").firstMatch.tap()
        app.buttons["editChordSong"].tap()
        XCTAssertTrue(app.segmentedControls["conversionMode"].waitForExistence(timeout: 5))
        app.segmentedControls["conversionMode"].buttons["Modifier"].tap()
        XCTAssertTrue((source.value as? String ?? "").contains("Correction manuelle"))
        app.buttons["Annuler"].firstMatch.tap()
    }
    func testWebImportChordDiagnosticsComparisonSaveAndReopen() {
        app.terminate(); app.launchArguments.append("--web-import-fixture"); app.launch()
        app.buttons["Importer"].tap(); app.buttons["internetImport"].tap()
        XCTAssertTrue(app.webViews.staticTexts["Le jardin des accords"].waitForExistence(timeout: 10))
        app.buttons["Utiliser le texte de la page"].tap()
        let diagnostic = app.staticTexts["webChordDiagnostics"]
        XCTAssertTrue(diagnostic.waitForExistence(timeout: 15))
        XCTAssertEqual(diagnostic.label, "6 accords détectés · 6 dans le résultat · 0 à vérifier")
        app.segmentedControls["conversionMode"].buttons["Modifier"].tap()
        let source = app.textViews["chordSourceEditor"]
        XCTAssertTrue((source.value as? String ?? "").contains("Un [C]matin sous le [G7]grand ciel bleu"))
        XCTAssertFalse((source.value as? String ?? "").contains("MENU"))
        app.segmentedControls["conversionMode"].buttons["Résultat"].tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        screenshot("Internet-accords-source-et-resultat")
        app.buttons["saveChordSource"].tap()
        XCTAssertTrue(app.buttons["Fermer"].waitForExistence(timeout: 5)); app.buttons["Fermer"].tap()
        app.terminate(); app.launchArguments.removeAll { $0 == "--reset-ui-testing" }; app.launch()
        XCTAssertTrue(app.staticTexts["Le jardin des accords"].waitForExistence(timeout: 10))
        app.buttons.containing(.staticText, identifier: "Le jardin des accords").firstMatch.tap()
        app.buttons["editChordSong"].tap()
        XCTAssertTrue(diagnostic.waitForExistence(timeout: 5))
        XCTAssertEqual(diagnostic.label, "6 accords détectés · 6 dans le résultat · 0 à vérifier")
        app.segmentedControls["conversionMode"].buttons["Modifier"].tap()
        XCTAssertTrue((source.value as? String ?? "").contains("[Am7/4]"))
        app.buttons["Annuler"].firstMatch.tap()
    }
    func testDiagramPauseZoomRotationAndPDFExportPreview() {
        demos(); app.buttons.containing(.staticText, identifier: "Balade du dimanche").firstMatch.tap()
        XCTAssertTrue(app.buttons["zoomIn"].waitForExistence(timeout: 5)); app.buttons["zoomIn"].tap()
        let zoom = app.staticTexts["zoomLabel"].label
        app.buttons["playPause"].tap()
        let chord = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Accord ")).firstMatch
        XCTAssertTrue(chord.waitForExistence(timeout: 5)); chord.tap()
        XCTAssertTrue(app.staticTexts["diagramChord"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["zoomLabel"].label, zoom)
        screenshot("Diagramme-portrait")
        app.buttons["closeDiagram"].tap()
        XCTAssertTrue(app.buttons["Lecture"].exists)
        XCUIDevice.shared.orientation = .landscapeLeft
        chord.tap(); screenshot("Diagramme-paysage"); app.buttons["closeDiagram"].tap()
        app.buttons["readerTools"].tap(); app.buttons["exportPDF"].tap()
        XCTAssertTrue(app.buttons["savePDF"].waitForExistence(timeout: 10))
        screenshot("Export-PDF-apercu")
        app.buttons["Partager"].tap()
        screenshot("Export-PDF-partage")
    }

    func testPDFConversionComparisonAndNativePrintPreparation() {
        demos(); app.buttons.containing(.staticText, identifier: "Exercice_10_pages").firstMatch.tap()
        app.buttons["readerTools"].tap(); app.buttons["Convertir en ChordPro"].tap()
        XCTAssertTrue(app.buttons["saveChordSource"].waitForExistence(timeout: 45))
        app.segmentedControls["conversionMode"].buttons["Original"].tap()
        screenshot("Conversion-original-PDF")
        XCUIDevice.shared.orientation = .landscapeLeft
        app.segmentedControls["conversionMode"].buttons["Résultat"].tap()
        screenshot("Conversion-PDF-comparaison")
        app.segmentedControls["conversionMode"].buttons["Modifier"].tap()
        XCTAssertTrue((app.textViews["chordSourceEditor"].value as? String ?? "").contains("{title:"))
        app.buttons["Annuler"].firstMatch.tap()
        XCTAssertTrue(app.buttons["readerTools"].waitForExistence(timeout: 5))
        app.buttons["readerTools"].tap(); app.buttons["exportPDF"].tap()
        XCTAssertTrue(app.buttons["printPDF"].waitForExistence(timeout: 5)); app.buttons["printPDF"].tap()
        XCTAssertTrue(app.buttons["Fermer l’impression"].waitForExistence(timeout: 5))
        screenshot("AirPrint-PDF-options")
    }

}
