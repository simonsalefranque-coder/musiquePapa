import XCTest
@testable import musiquePapa

final class ChordProTests: XCTestCase {
    func testSongBookDirectivesAndPreservedBlankLines() {
        let song = ChordProParser.parse("""
        {t: Titre}
        {st: Sous-titre}
        {artist: Artiste}
        {key: Bb}
        {capo: 3}
        {tempo: 92}
        {c: Lentement}
        {start_of_verse: Premier couplet}
        [Am]Bon[G]jour
        {end_of_verse}

        {soc}
        [F#m]Refrain
        {eoc}
        {sot}
        e|---0  2---|
        {eot}
        {future: valeur}
        Fin
        """)
        XCTAssertEqual(song.title, "Titre"); XCTAssertEqual(song.subtitle, "Sous-titre")
        XCTAssertEqual(song.artist, "Artiste"); XCTAssertEqual(song.key, "Bb"); XCTAssertEqual(song.capo, "3"); XCTAssertEqual(song.tempo, "92")
        XCTAssertTrue(song.lines.contains { $0.kind == .blank })
        XCTAssertTrue(song.lines.contains { $0.kind == .tab && $0.text == "e|---0  2---|" })
        XCTAssertTrue(song.lines.contains { $0.chorus && $0.segments.first?.chord == "F#m" })
        XCTAssertEqual(song.unknownDirectives, ["future: valeur"])
        XCTAssertEqual(song.lines.last?.segments.first?.lyric, "Fin")
    }
    func testSegmentsKeepExactChordPositionsAndEmptyLyrics() {
        let segments = ChordProParser.segments("Un [Am]bon[G]jour [F][C]!")
        XCTAssertEqual(segments, [ChordSegment(chord: nil, lyric: "Un "), ChordSegment(chord: "Am", lyric: "bon"), ChordSegment(chord: "G", lyric: "jour "), ChordSegment(chord: "F", lyric: ""), ChordSegment(chord: "C", lyric: "!")])
        XCTAssertEqual(ChordProParser.segments("[mal formé").first?.lyric, "[mal formé")
    }
    func testTranspositionHandlesAccidentalsAndBassWithoutChangingSuffix() {
        XCTAssertEqual(Transposer.transpose("Am7", by: 2), "Bm7")
        XCTAssertEqual(Transposer.transpose("D/F#", by: 1), "D#/G")
        XCTAssertEqual(Transposer.transpose("Bbmaj7", by: 2), "Cmaj7")
        XCTAssertEqual(Transposer.transpose("C/E", by: -2), "A#/D")
        XCTAssertEqual(Transposer.transpose("F#m", by: -12), "F#m")
        XCTAssertEqual(Transposer.transpose("N.C.", by: 3), "N.C.")
        XCTAssertEqual(Transposer.transpose("C", by: -1, preferFlats: true), "B")
    }
    func testUTF8UTF16AndWindowsEncoding() throws {
        let text = "{title: Été}\n[Am]Déjà là"
        for encoding in [String.Encoding.utf8, .utf16, .windowsCP1252, .isoLatin1] {
            XCTAssertEqual(try ChordProParser.decode(XCTUnwrap(text.data(using: encoding))), text)
        }
        XCTAssertThrowsError(try ChordProParser.decode(Data([0, 0, 0, 0])))
        XCTAssertTrue(ChordProParser.looksLikeChordPro(text))
        XCTAssertFalse(ChordProParser.looksLikeChordPro("Liste des courses"))
    }
}
