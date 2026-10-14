import XCTest
@testable import MidiDSL

final class NoteTests: XCTestCase {
    func testNoteCarriesItsWrittenFields() {
        let note = Note(
            pitch: .C,
            velocity: 100,
            startTime: 0,
            duration: .quarter
        )
        XCTAssertEqual(note.pitch, .C as UInt32)
        XCTAssertEqual(note.startTime, 0)
        XCTAssertEqual(note.duration, .quarter)
        XCTAssertEqual(note.velocity, 100)
    }
}

class ChordTest: XCTestCase {
    func testChordFromDescription() {
        let cMajor = Chord("Cmaj")!
        let dMajor = Chord("Dmaj")!
        let eMajor = Chord("Emaj")!
        let fMajor = Chord("Fmaj")!
        let gMajor = Chord("Gmaj")!
        let aMajor = Chord("Amaj")!
        let bMajor = Chord("B", .major)
            .durations(2,2,4)
            .velocities(10,50,100)
        XCTAssertEqual(cMajor.noteNotations, ["C5", "E5", "G5"])
        XCTAssertEqual(dMajor.noteNotations, ["D5", "F#5", "A5"])
        XCTAssertEqual(eMajor.noteNotations, ["E5", "G#5", "B5"])
        XCTAssertEqual(fMajor.noteNotations, ["F5", "A5", "C6"])
        XCTAssertEqual(gMajor.noteNotations, ["G5", "B5", "D6"])
        XCTAssertEqual(aMajor.noteNotations, ["A5", "C#6", "E6"])
        XCTAssertEqual(bMajor.noteNotations, ["B5", "D#6", "F#6"])
        XCTAssertEqual(bMajor.duration, 4)
        XCTAssertEqual(bMajor.notes.map{$0.velocity}, [10,50,100])
    }

    func testChordWithUnknownRootIsNil() {
        XCTAssertNil(Chord("Xmaj"))
        XCTAssertNil(Chord("garbage"))
    }

    func testChordWithGarbageQualityFallsBackToMajor() {
        let chord = Chord("C@#!")
        XCTAssertNotNil(chord)
        XCTAssertEqual(chord?.noteNotations, ["C5", "E5", "G5"])
    }

    func testShortVelocityListKeepsRemainingNotes() {
        let original = Chord("Cmaj7")!
        XCTAssertEqual(original.notes.count, 4)
        let originalVelocities = original.notes.map { $0.velocity }

        let modified = Chord("Cmaj7")!.velocities(90, 80)

        XCTAssertEqual(modified.notes.count, 4)
        XCTAssertEqual(modified.notes[0].velocity, 90)
        XCTAssertEqual(modified.notes[1].velocity, 80)
        XCTAssertEqual(modified.notes[2].velocity, originalVelocities[2])
        XCTAssertEqual(modified.notes[3].velocity, originalVelocities[3])
    }

    func testShortDurationListKeepsRemainingNotes() {
        let original = Chord("Cmaj7")!
        XCTAssertEqual(original.notes.count, 4)
        let originalDurations = original.notes.map { $0.duration }

        let modified = Chord("Cmaj7")!.durations(2, 2)

        XCTAssertEqual(modified.notes.count, 4)
        XCTAssertEqual(modified.notes[0].duration, 2)
        XCTAssertEqual(modified.notes[1].duration, 2)
        XCTAssertEqual(modified.notes[2].duration, originalDurations[2])
        XCTAssertEqual(modified.notes[3].duration, originalDurations[3])
    }
}

class ScaleTests: XCTestCase {
    func testMajorScaleSharpRoot() {
        XCTAssertEqual(Scale.majorScale(for: "F#"), ["F#", "G#", "A#", "B", "C#", "D#", "F"])
    }

    func testMajorScaleFlatRoot() {
        XCTAssertEqual(Scale.majorScale(for: "Bb"), ["A#", "C", "D", "D#", "F", "G", "A"])
    }

    func testMajorScaleNaturalRootUnchanged() {
        XCTAssertEqual(Scale.majorScale(for: "C"), ["C", "D", "E", "F", "G", "A", "B"])
    }

    func testMinorScale() {
        XCTAssertEqual(Scale.minorScale(for: "A"), ["A", "B", "C", "D", "E", "F", "G"])
        XCTAssertEqual(Scale.minorScale(for: "Eb"), ["D#", "F", "F#", "G#", "A#", "B", "C#"])
    }

    func testDorianScale() {
        XCTAssertEqual(Scale.dorianScale(for: "D"), ["D", "E", "F", "G", "A", "B", "C"])
    }

    func testScaleNoteCount() {
        XCTAssertEqual(Scale.majorScale(for: "G#").count, 7)
        XCTAssertEqual(Scale.minorScale(for: "Bb").count, 7)
    }

    func testInvalidRootReturnsEmpty() {
        XCTAssertEqual(Scale.majorScale(for: "H"), [])
        XCTAssertEqual(Scale.majorScale(for: ""), [])
    }
}

class ScaleDegreeTests: XCTestCase {
    private func pitches(_ notes: [Note]) -> [Pitch?] { notes.map { $0.pitch } }

    // MARK: The key value itself

    func testDegreesOfAMajorScale() {
        let key = Scale(.C5, .major)
        XCTAssertEqual(key.pitches, [60, 62, 64, 65, 67, 69, 71])
    }

    func testDegreeWrapsByOctaveBothWays() {
        let key = Scale(.C5, .major)
        XCTAssertEqual(key.pitch(ScaleDegree(degree: 8)), 72)
        XCTAssertEqual(key.pitch(ScaleDegree(degree: 1, octave: -1)), 48)
        XCTAssertEqual(key.pitch(ScaleDegree(degree: 0)), 59)
    }

    func testPentatonicWrapsAtItsOwnSize() {
        let key = Scale(.C5, .minorPentatonic)
        XCTAssertEqual(key.pitches, [60, 63, 65, 67, 70])
        XCTAssertEqual(key.pitch(ScaleDegree(degree: 6)), 72)
    }

    func testKeyFromANoteName() {
        XCTAssertEqual(Scale("Eb5", .major).root, Scale(63, .major).root)
    }

    // MARK: Writing degrees

    func testDegreesInBarNotation() {
        let section = Section { "1 2 3 4 | 5 6 7 1'" }.key(.C5, .major)
        XCTAssertEqual(pitches(section.notes), [60, 62, 64, 65, 67, 69, 71, 72])
    }

    func testOctaveMarksAndAlterations() {
        let section = Section { "1 1' 1, b3 | #4 b7 #1 7" }.key(.C5, .major)
        XCTAssertEqual(pitches(section.notes), [60, 72, 48, 63, 66, 70, 61, 71])
    }

    func testCountingPastTheOctaveMatchesTheOctaveMark() {
        let section = Section { "8 9 | 1' 2'" }.key(.C5, .major)
        XCTAssertEqual(pitches(section.notes), [72, 74, 72, 74])
    }

    func testDegreeChordStacks() {
        let section = Section { "[1 3 5] | [4 6 1']" }.key(.C5, .major)
        XCTAssertEqual(pitches(section.notes), [60, 64, 67, 65, 69, 72])
    }

    func testNoteSetVariantsFollowTheKey() {
        let section = Section { "(1 3) 5 1' 5" }.key(.A5, .minor)
        XCTAssertEqual(section.notes[0].pitchVariants, [69, 72])
    }

    func testModesReadTheSameDegreesDifferently() {
        let dorian = Section { "1 2 3 4 | 5 6 7 1'" }.key(.D5, .dorian)
        XCTAssertEqual(pitches(dorian.notes), [62, 64, 65, 67, 69, 71, 72, 74])
    }

    func testHoldsAndRestsBetweenDegrees() {
        let section = Section { "1 - 5 R | 3 - - -" }.key(.C5, .major)
        XCTAssertEqual(pitches(section.notes), [60, 67, nil, 64])
        XCTAssertEqual(section.duration, 2.0)
    }

    func testUnbarredSpaceIsARestForDegreesAsForNames() {
        XCTAssertEqual(pitches(SectionBuilder.parseNotation("1 2")), [60, nil, 62])
        XCTAssertEqual(pitches(SectionBuilder.parseNotation("C5 D5")), [60, nil, 62])
    }

    // MARK: Which key wins

    func testDegreesSoundBeforeAnyKeyArrives() {
        let section = Section { "1 3 | 5 8" }
        XCTAssertEqual(pitches(section.notes), [60, 64, 67, 72])
        XCTAssertTrue(section.notes.allSatisfy { $0.isUnkeyed })
    }

    func testSectionKeyReadsItsDegrees() {
        let section = Section { "1 3 | 5 8" }.key(.A5, .minor)
        XCTAssertEqual(pitches(section.notes), [69, 72, 76, 81])
        XCTAssertFalse(section.notes.contains { $0.isUnkeyed })
    }

    func testStringKeyBeatsSectionKey() {
        let section = Section {
            "1 3 | 5 8"
            "1 3 | 5 8".key(.A5, .minor)
        }.key(.C5, .major)
        XCTAssertEqual(pitches(section.notes), [60, 64, 67, 72, 69, 72, 76, 81])
    }

    func testTrackKeyReachesItsSections() {
        let track = Track(name: "Lead") {
            Section { "1 3 | 5 8" }
            Section { "8 5 | 3 1" }
        }.key(.C5, .major)
        XCTAssertEqual(pitches(track.sections.flatMap { $0.notes }),
                       [60, 64, 67, 72, 72, 67, 64, 60])
    }

    func testSessionKeyReachesEverythingButInnerKeysStillWin() {
        let session = Session {
            Track(name: "A") { Section { "1 3 | 5 8" } }
            Track(name: "B") { Section { "1 3 | 5 8" }.key(.A5, .minor) }
        }.key(.C5, .major)
        XCTAssertEqual(pitches(session.tracks.flatMap { $0.sections.flatMap { $0.notes } }),
                       [60, 64, 67, 72, 69, 72, 76, 81])
    }

    func testAnOuterKeyCannotRereadAClaimedDegree() {
        let section = Section { "1 3 | 5 8".key(.C5, .major) }
            .key(.A5, .minor)
            .key(.D5, .dorian)
        XCTAssertEqual(pitches(section.notes), [60, 64, 67, 72])
    }

    func testAbsoluteNamesIgnoreTheKey() {
        let section = Section { "C5 E5 | 1 3" }.key(.A5, .minor)
        XCTAssertEqual(pitches(section.notes), [60, 64, 69, 72])
    }

    func testKeyAppliesBeforeTransposeOnTheSameChain() {
        let section = Section { "1 3 | 5 8".key(.C5, .major).transpose(12) }
        XCTAssertEqual(pitches(section.notes), [72, 76, 79, 84])
    }

    func testKeySurvivesTheJSONBoundary() throws {
        let section = Section { "1 3 | 5 8" }.key(.C5, .major)
        let decoded = try JSONDecoder().decode(Section.self, from: JSONEncoder().encode(section))
        XCTAssertEqual(pitches(decoded.notes), pitches(section.notes))
        XCTAssertEqual(decoded.notes.first?.scale, Scale(.C5, .major))
    }

    // MARK: Degrees wherever notation takes a pitch

    func testSlideTargetCanBeADegree() {
        let section = Section { "1 >5 - - | 1 >3' - -" }.key(.A5, .minor)
        XCTAssertEqual(pitches(section.notes), [76, 84])
        XCTAssertEqual(section.notes[0].slides?.first?.from, 69)
        XCTAssertEqual(section.notes[1].slides?.first?.from, 69)
    }

    func testGlideLengthStillReadsAsASpec() {
        let section = Section { "1 >0.25C6 - - |" }.key(.A5, .minor)
        XCTAssertEqual(pitches(section.notes), [72])
        XCTAssertEqual(section.notes[0].slides?.first?.from, 69)
        XCTAssertEqual(section.notes[0].slides?.first?.over, 0.25)
    }

    func testLegatoTargetCanBeADegree() {
        let section = Section { "1 ^3 - - |" }.key(.A5, .minor)
        XCTAssertEqual(pitches(section.notes), [72])
        XCTAssertEqual(section.notes[0].slides?.first?.from, 69)
        XCTAssertNotNil(section.notes[0].slides?.first?.carry)
    }

    func testFusedSlideStagesCanBeDegrees() {
        let melody = Section { "1>3 - - - |" }.key(.A5, .minor)
        XCTAssertEqual(pitches(melody.notes), [72])
        XCTAssertEqual(melody.notes[0].slides?.first?.from, 69)

        let chords = Section { "[1 3 5]>[4 6 1'] - |" }.key(.A5, .minor)
        XCTAssertEqual(pitches(chords.notes), [74, 77, 81])
        XCTAssertEqual(chords.notes.compactMap { $0.slides?.first?.from }, [69, 72, 76])
    }

    func testAScoopIntoADegreeMovesWithIt() {
        let section = Section { ">-3b3 - - - |" }.key(.A5, .minor)
        XCTAssertEqual(pitches(section.notes), [71])
        XCTAssertEqual(section.notes[0].slides?.first?.from, 68)
    }

    func testPortamentoAcrossARestRemembersTheDegree() {
        let section = Section { "1 R >5 - |" }.key(.A5, .minor)
        XCTAssertEqual(pitches(section.notes), [69, nil, 76])
        XCTAssertEqual(section.notes[2].slides?.first?.from, 69)
    }

    func testASlideOntoAnAbsoluteNameKeepsItsPitch() {
        let section = Section { "C5 >5 - - | 1 >C6 - -" }.key(.A5, .minor)
        XCTAssertEqual(pitches(section.notes), [76, 72])
        XCTAssertEqual(section.notes[0].slides?.first?.from, 60)
        XCTAssertEqual(section.notes[1].slides?.first?.from, 69)
    }

    func testStacksMixDegreesAndNames() {
        let section = Section { "[1 3 C5] - - - |" }.key(.A5, .minor)
        XCTAssertEqual(pitches(section.notes), [69, 72, 60])
    }

    func testChordOnADegree() {
        let section = Section { "6m - - - | 5dom7 - - -" }.key(.A5, .minor)
        XCTAssertEqual(pitches(section.notes), [77, 80, 84, 76, 80, 83, 86])
    }

    func testADegreeChordKeepsItsQualityInEveryKey() {
        for key in [Scale(.C5, .major), Scale(.A5, .minor), Scale(.D5, .dorian)] {
            let notes = Section { "6m - - - |" }.key(key).notes
            let intervals = notes.compactMap { $0.pitch }.map { Int($0) - Int(notes[0].pitch!) }
            XCTAssertEqual(intervals, [0, 3, 7], "\(key) re-read the quality")
        }
    }

    func testDegreeChordExtensions() {
        let section = Section { "[2m7 9] - - - |" }.key(.A5, .minor)
        XCTAssertEqual(pitches(section.notes), [71, 74, 78, 81, 85])
    }

    func testADegreeChordNeedsALetteredQuality() {
        XCTAssertNil(SectionBuilder.parseDegreeChord("17"))
        XCTAssertNil(SectionBuilder.parseDegreeChord("5"))
        XCTAssertEqual(SectionBuilder.parseDegreeChord("6m")?.quality, .minor)
        XCTAssertEqual(SectionBuilder.parseDegreeChord("5dom7")?.quality, .dominant7)
        XCTAssertEqual(SectionBuilder.parseDegreeChord("b3maj7")?.root,
                       ScaleDegree(degree: 3, alteration: -1))
    }

    func testAdditiveTokensTakeDegrees() {
        let single = Section { "1 +3 - - |" }.key(.A5, .minor)
        XCTAssertEqual(pitches(single.notes), [69, 72])
        let chord = Section { "1 +6m - - |" }.key(.A5, .minor)
        XCTAssertEqual(pitches(chord.notes), [69, 77, 80, 84])
    }

    func testChordExtensionsStillWinOverTheDegreeReading() {
        let section = Section { "| Am7 +9 - - |" }
        XCTAssertEqual(pitches(section.notes), [69, 72, 76, 79, 83])
    }

    // MARK: The accidental on either side of the number

    func testAnAccidentalAfterTheNumberReadsAsTheSameDegree() {
        XCTAssertEqual(SectionBuilder.parseDegreeToken("4#"), ScaleDegree(degree: 4, alteration: 1))
        XCTAssertEqual(SectionBuilder.parseDegreeToken("3b"), ScaleDegree(degree: 3, alteration: -1))
        XCTAssertEqual(SectionBuilder.parseDegreeToken("4##"), ScaleDegree(degree: 4, alteration: 2))
        XCTAssertEqual(SectionBuilder.parseDegreeToken("4#"), SectionBuilder.parseDegreeToken("#4"))
        XCTAssertEqual(SectionBuilder.parseDegreeToken("4#'"), ScaleDegree(degree: 4, octave: 1, alteration: 1))
        XCTAssertEqual(SectionBuilder.parseDegreeToken("4'#"), ScaleDegree(degree: 4, octave: 1, alteration: 1))
        XCTAssertEqual(SectionBuilder.parseDegreeToken("3,b"), ScaleDegree(degree: 3, octave: -1, alteration: -1))
    }

    func testADegreeChordTakesTheAccidentalOnEitherSideToo() {
        XCTAssertEqual(SectionBuilder.parseDegreeChord("2#m7")?.root, ScaleDegree(degree: 2, alteration: 1))
        XCTAssertEqual(SectionBuilder.parseDegreeChord("2#m7")?.quality, .minor7)
        XCTAssertEqual(SectionBuilder.parseDegreeChord("3bmaj7")?.root,
                       SectionBuilder.parseDegreeChord("b3maj7")?.root)
    }

    func testASuffixedAccidentalSoundsEverywhereAPrefixedOneDoes() {
        let spellings: [(suffix: String, prefix: String)] = [
            ("| 4# 5 6 7 |",            "| #4 5 6 7 |"),
            ("4# 5",                    "#4 5"),
            ("| 3b 2 1 7 |",            "| b3 2 1 7 |"),
            ("| [1 3# 5] - - - |",      "| [1 #3 5] - - - |"),
            ("| {4# 5} 1 - - |",        "| {#4 5} 1 - - |"),
            ("| ?(4# 5) - - - |",       "| ?(#4 5) - - - |"),
            ("| 1 >4# - - |",           "| 1 >#4 - - |"),
            ("| 1 ^4# - - |",           "| 1 ^#4 - - |"),
            ("| 1>4# - - - |",          "| 1>#4 - - - |"),
            ("| 1 +4# - - |",           "| 1 +#4 - - |"),
            ("| [1 3 5]>[4# 6 1'] - |", "| [1 3 5]>[#4 6 1'] - |"),
            ("| 2#m7 5 - - |",          "| #2m7 5 - - |"),
            ("| 4#maj7 - - - |",        "| #4maj7 - - - |"),
            ("| 4#' 5 - - |",           "| #4' 5 - - |"),
        ]
        for (suffix, prefix) in spellings {
            let parsed = SectionBuilder.parseNotationWithWarnings(suffix)
            XCTAssertEqual(parsed.warnings.map { $0.token }, [], "\"\(suffix)\" warned")
            let written = Section { suffix }.key(.A5, .minor).notes
            let expected = Section { prefix }.key(.A5, .minor).notes
            XCTAssertEqual(pitches(written), pitches(expected), "\"\(suffix)\" ≠ \"\(prefix)\"")
            XCTAssertFalse(written.compactMap { $0.pitch }.isEmpty, "\"\(suffix)\" sounded nothing")
        }
    }

    func testAChordAlterationIsNotASuffixedAccidental() {
        for token in ["1b9", "1b5", "1#11", "5b13", "1#5"] {
            XCTAssertNil(SectionBuilder.parseDegreeToken(token), "\"\(token)\" names a chord, not a degree")
        }
        XCTAssertEqual(pitches(Section { "| 1b9 - - - |" }.notes), [60, 64, 67, 73])
        XCTAssertEqual(pitches(Section { "| 1#5 - - - |" }.notes), [60, 64, 68])
    }

    // MARK: Token parsing

    func testDegreeTokenParsing() {
        XCTAssertEqual(SectionBuilder.parseDegreeToken("1"), ScaleDegree(degree: 1))
        XCTAssertEqual(SectionBuilder.parseDegreeToken("5'"), ScaleDegree(degree: 5, octave: 1))
        XCTAssertEqual(SectionBuilder.parseDegreeToken("1,,"), ScaleDegree(degree: 1, octave: -2))
        XCTAssertEqual(SectionBuilder.parseDegreeToken("b3"), ScaleDegree(degree: 3, alteration: -1))
        XCTAssertEqual(SectionBuilder.parseDegreeToken("#4'"), ScaleDegree(degree: 4, octave: 1, alteration: 1))
    }

    func testNonDegreeTokensAreNotDegrees() {
        for token in ["C5", "Am", "R", "", "1x", "3#4", "'C7", "-"] {
            XCTAssertNil(SectionBuilder.parseDegreeToken(token), "\"\(token)\" is not a degree")
        }
    }
}

class EnharmonicNoteNameTests: XCTestCase {
    private func pitches(_ notes: [Note]) -> [Pitch?] { notes.map { $0.pitch } }

    func testANameIsReadNotLookedUp() {
        XCTAssertEqual(pitchForNoteName("E#"), pitchForNoteName("F"))
        XCTAssertEqual(pitchForNoteName("B#"), pitchForNoteName("C6"))
        XCTAssertEqual(pitchForNoteName("Fb"), pitchForNoteName("E"))
        XCTAssertEqual(pitchForNoteName("Cb"), pitchForNoteName("B4"))
        XCTAssertEqual(pitchForNoteName("F##"), pitchForNoteName("G"))
        XCTAssertEqual(pitchForNoteName("Bbb"), pitchForNoteName("A"))
        XCTAssertEqual(pitchForNoteName("E#4"), 53)
        XCTAssertEqual(pitchForNoteName("C"), 60)
    }

    func testEveryNameTheTableHoldsReadsTheSame() {
        for (name, pitch) in pitchForNote {
            XCTAssertEqual(pitchForNoteName(name), pitch, "\"\(name)\"")
        }
    }

    func testWhatIsNotANameIsStillNotAName() {
        for token in ["H", "b", "c", "R", "", "Cx", "C4.5", "1", "#4", "-", "Cb0", "G#10"] {
            XCTAssertNil(pitchForNoteName(token), "\"\(token)\" is not a note name")
        }
    }

    func testTheReportedExampleSoundsItsSharp() {
        let written = "A - - - E# A B Eb | "
        XCTAssertEqual(pitches(Section { written }.notes), [69, 65, 69, 71, 63, nil])
        XCTAssertEqual(SectionBuilder.parseNotationWithWarnings(written).warnings.map { $0.token }, [])
    }

    func testAnEnharmonicNameSoundsEverywhereACommonOneDoes() {
        let spellings: [(rare: String, common: String)] = [
            ("| E# G5 - - |",            "| F5 G5 - - |"),
            ("E# G5",                    "F5 G5"),
            ("| Cb - - - |",             "| B4 - - - |"),
            ("| B# - - - |",             "| C6 - - - |"),
            ("| Fb - - - |",             "| E5 - - - |"),
            ("| [C5 E# G5] - - - |",     "| [C5 F5 G5] - - - |"),
            ("| {E# G5} C5 - - |",       "| {F5 G5} C5 - - |"),
            ("| ?(E# G5) - - - |",       "| ?(F5 G5) - - - |"),
            ("| C5 >E# - - |",           "| C5 >F5 - - |"),
            ("| C5 ^E# - - |",           "| C5 ^F5 - - |"),
            ("| C5>E# - - - |",          "| C5>F5 - - - |"),
            ("| AE#B - - - |",           "| AFB - - - |"),
            ("| E#maj7 - - - |",         "| Fmaj7 - - - |"),
            ("| 'E#7 - - - |",           "| 'F7 - - - |"),
        ]
        for (rare, common) in spellings {
            let parsed = SectionBuilder.parseNotationWithWarnings(rare)
            XCTAssertEqual(parsed.warnings.map { $0.token }, [], "\"\(rare)\" warned")
            let written = Section { rare }.notes
            XCTAssertEqual(pitches(written), pitches(Section { common }.notes),
                           "\"\(rare)\" ≠ \"\(common)\"")
            XCTAssertFalse(written.compactMap { $0.pitch }.isEmpty, "\"\(rare)\" sounded nothing")
        }
    }

    func testAChordCanBeSpelledOnAnyRoot() {
        XCTAssertEqual(pitches(Section { "| Cbm7 - - - |" }.notes), [59, 62, 66, 69])
        XCTAssertEqual(pitches(Section { "| B#5 - - - |" }.notes), [72])
    }

    func testAKeyCanBeNamedWithAnEnharmonicRoot() {
        XCTAssertEqual(Scale("E#", .major).root, Scale("F", .major).root)
        XCTAssertEqual(pitches(Section { "| 1 2 3 |" }.key(Scale("Cb", .major)).notes),
                       pitches(Section { "| 1 2 3 |" }.key(Scale("B4", .major)).notes))
    }
}

class RunGroupTests: XCTestCase {
    private func times(_ notes: [Note]) -> [(Double, Double)] {
        notes.map { ($0.startTime, $0.duration) }
    }
    private func assertSpan(_ notes: [Note], startsAt start: Double, endsAt end: Double,
                            file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(notes.first?.startTime ?? -1, start, accuracy: 1e-9, file: file, line: line)
        let last = notes.map { $0.startTime + $0.duration }.max() ?? -1
        XCTAssertEqual(last, end, accuracy: 1e-9, file: file, line: line)
    }

    func testAGroupDividesOneSlotAmongItsNotes() {
        let notes = SectionBuilder.parseNotation("| 1 - - {1 2 3 4} |")
        XCTAssertEqual(notes.count, 5)
        XCTAssertEqual(times(notes)[0].1, 0.75, accuracy: 1e-9)
        assertSpan(Array(notes.dropFirst()), startsAt: 0.75, endsAt: 1.0)
        for n in notes.dropFirst() { XCTAssertEqual(n.duration, 0.0625, accuracy: 1e-9) }
    }

    func testAGroupIsHowATupletIsWritten() {
        let notes = SectionBuilder.parseNotation("| 1 - - {1 2 3} |")
        for n in notes.dropFirst() { XCTAssertEqual(n.duration, 0.25 / 3, accuracy: 1e-9) }
        assertSpan(Array(notes.dropFirst()), startsAt: 0.75, endsAt: 1.0)
    }

    func testAGroupHoldsWhateverABarHolds() {
        XCTAssertEqual(SectionBuilder.parseNotation("| C5 - - {C5 D5 E5} |").compactMap { $0.pitch },
                       [60, 60, 62, 64])
        XCTAssertEqual(SectionBuilder.parseNotation("| 1 - - {[1 3 5] [4 6 1']} |").compactMap { $0.pitch },
                       [60, 60, 64, 67, 65, 69, 72])
        XCTAssertEqual(SectionBuilder.parseNotation("| 1 - - {6m 5dom7} |").compactMap { $0.pitch },
                       [60, 69, 72, 76, 67, 71, 74, 77])
        let slid = SectionBuilder.parseNotation("| 1 - - {1 >5 2} |")
        XCTAssertEqual(slid.compactMap { $0.pitch }, [60, 67, 62])
        XCTAssertEqual(slid[1].slides?.first?.from, 60)
    }

    func testATieInsideAndAfterAGroup() {
        let inside = SectionBuilder.parseNotation("| 1 {2 - 3} - - |")
        XCTAssertEqual(inside[1].duration, 0.25 * 2 / 3, accuracy: 1e-9)
        let after = SectionBuilder.parseNotation("| {1 2} - - - |")
        XCTAssertEqual(after.last?.duration ?? 0, 0.875, accuracy: 1e-9)
    }

    func testARestInsideAGroupKeepsTheSlotsLength() {
        let notes = SectionBuilder.parseNotation("| 1 - - {1 2 R} |")
        XCTAssertEqual(notes.count, 4)
        XCTAssertEqual(notes.compactMap { $0.pitch }, [60, 60, 62])
        for n in notes.dropFirst() { XCTAssertEqual(n.duration, 0.25 / 3, accuracy: 1e-9) }
    }

    func testGroupsNest() {
        let notes = SectionBuilder.parseNotation("| 1 - - {1 {2 3}} |")
        XCTAssertEqual(notes.compactMap { $0.pitch }, [60, 60, 62, 64])
        XCTAssertEqual(notes[1].duration, 0.125, accuracy: 1e-9)
        XCTAssertEqual(notes[2].duration, 0.0625, accuracy: 1e-9)
        assertSpan(Array(notes.dropFirst()), startsAt: 0.75, endsAt: 1.0)
    }

    func testAGroupTakesOneBeatUnbarred() {
        let notes = SectionBuilder.parseNotation("1 {1 2 3}")
        XCTAssertEqual(notes.compactMap { $0.pitch }, [60, 60, 62, 64])
        assertSpan(Array(notes.dropFirst(2)), startsAt: 2.0, endsAt: 3.0)
    }

    func testDegreesInsideAGroupFollowTheKey() {
        let section = Section { "| 1 - - {1 2 3 4} |" }.key(.A5, .minor)
        XCTAssertEqual(section.notes.compactMap { $0.pitch }, [69, 69, 71, 72, 74])
    }

    func testGroupNotesAreStampedInTheOuterString() {
        let source = "| 1 - - {1 2 3} |"
        let notes = SectionBuilder.parseNotation(source)
        XCTAssertEqual(notes.compactMap { $0.sourceOffset }, [2, 9, 11, 13])
        XCTAssertEqual(notes.compactMap { $0.sourceLength }, [1, 1, 1, 1])
        for note in notes {
            let start = source.index(source.startIndex, offsetBy: note.sourceOffset!)
            XCTAssertTrue(source[start].isNumber, "stamp \(note.sourceOffset!) misses its token")
        }
    }

    func testAWarningInsideAGroupPointsAtTheOuterString() {
        let (notes, warnings) = SectionBuilder.parseNotationWithWarnings("| 1 - - {1 1x 3} |")
        XCTAssertEqual(notes.count, 4)
        XCTAssertEqual(notes.compactMap { $0.pitch }, [60, 60, 64])
        XCTAssertEqual(warnings.count, 1)
        XCTAssertEqual(warnings.first?.offset, 11)
    }

    func testAnEmptyGroupWarnsAndKeepsItsSlot() {
        let (notes, warnings) = SectionBuilder.parseNotationWithWarnings("| 1 - - {} |")
        XCTAssertEqual(notes.compactMap { $0.pitch }, [60])
        XCTAssertEqual(warnings.count, 1)
        XCTAssertEqual(notes[0].duration, 0.75, accuracy: 1e-9)
        XCTAssertEqual(notes.count, 2)
        XCTAssertEqual(notes[1].startTime, 0.75, accuracy: 1e-9)
        XCTAssertEqual(notes[1].duration, 0.25, accuracy: 1e-9)
    }
}

class ProgressionTests: XCTestCase {
    func testProgression() {
        let progressionA = Progression("I - V - vi - IV", for: .C)
        let progressionB = Progression("I - V - vi - IV", for: "C".pitch!)
        let progressionC = Progression("i - ii - I - IV", for: .C)
            .velocities(60, 70, 50, 100)
            .durations(1.0, 1.0, 1.0, 2.0)

        XCTAssertEqual(progressionA.chords.map{$0.notation}, ["Cmaj", "Gmaj", "Amin", "Fmaj"])
        XCTAssertEqual(progressionB.chords.map{$0.notation}, ["Cmaj", "Gmaj", "Amin", "Fmaj"])
        XCTAssertEqual(progressionC.chords.count, 4)
    }

    func testProgressionSkipsUnparseableSteps() {
        let progression = Progression("I - garbage - V", for: .C)
        XCTAssertEqual(progression.chords.count, 2)
        XCTAssertEqual(progression.chords.map{$0.notation}, ["Cmaj", "Gmaj"])
    }

    func testMinorKeyProgression() {
        let diatonic = Progression("i - ii - III - iv - v - VI - VII", for: .A, minor: true)
        XCTAssertEqual(diatonic.chords.map { $0.notation },
                       ["Amin", "Bdim", "Cmaj", "Dmin", "Emin", "Fmaj", "Gmaj"])

        let cadence = Progression("i - iv - V", for: .A, minor: true)
        XCTAssertEqual(cadence.chords.map { $0.notation }, ["Amin", "Dmin", "Emaj"])
    }

    func testMajorKeyCaseDrivenQuality() {
        let borrowed = Progression("I - II - V", for: .C)
        XCTAssertEqual(borrowed.chords.map { $0.notation }, ["Cmaj", "Dmaj", "Gmaj"])
        XCTAssertEqual(borrowed.chords[1].noteNotations, ["D5", "F#5", "A5"])

        let modal = Progression("i - IV", for: .C)
        XCTAssertEqual(modal.chords.map { $0.notation }, ["Cmin", "Fmaj"])
    }

    func testNumeralQualitySuffixes() {
        let jazz = Progression("iim7 - V7 - Imaj7", for: .C)
        XCTAssertEqual(jazz.chords.map { $0.notation }, ["Dmin7", "Gdom7", "Cmaj7"])

        let minorJazz = Progression("i - Vdom9", for: .A, minor: true)
        XCTAssertEqual(minorJazz.chords.map { $0.notation }, ["Amin", "Edom9"])
    }
}

class SectionTests: XCTestCase {
    func testProgressionExpandsToItsChordTones() {
        let byDegreeKey = Section {
            Progression("I - V - vi - IV", for: .C)
        }
        XCTAssertEqual(byDegreeKey.notes.count, 12)

        let byPitchKey = Section {
            Progression("I - V - vi - IV", for: "C".pitch!)
        }
        XCTAssertEqual(byPitchKey.notes.count, 12)
    }

    func testCompactRunTreatsASpaceAsARest() {
        let section = Section {
            "ABCD EFG"
        }
        XCTAssertEqual(section.notes.count, 8)
        XCTAssertEqual(section.notes[0].pitch, .A)
        XCTAssertEqual(section.notes[7].pitch, .G)
    }

    func testStacksStrikeTogether() {
        let section = Section {
            "[ABC] [BEF]"
        }
        XCTAssertEqual(section.notes.count, 7)
        XCTAssertEqual(section.notes[0].pitch, .A)
        XCTAssertEqual(section.notes[1].pitch, .B)
        XCTAssertEqual(section.notes[2].pitch, .C)
        XCTAssertEqual(section.notes[4].pitch, .B)
        XCTAssertEqual(section.notes[5].pitch, .E)
        XCTAssertEqual(section.notes[6].pitch, .F)
    }
}

class TrackTests: XCTestCase {
    func testTrackCollectsSectionsAndTheirNotes() {
        let progression1 = Progression("I - II - I - IV", for: .C)
            .startTimes(0,1,2,3)
        let progression2 = Progression("i - ii - I - IV", for: .C)
            .startTimes(0,2,4,6)
        let section1 = Section {
            progression1
                .velocities(60, 70, 50, 100)
                .durations(1.0, 1.0, 1.0, 1.0)
            progression2
                .velocities(60, 70, 50, 100)
                .durations(1.0, 1.0, 1.0, 2.0)
        }
        let section2 = Section {
            "ABCDEF"
        }
        let track = Track(name: "Test") {
            section1
            section2
        }

        XCTAssertEqual(section1.duration, 8)
        XCTAssertEqual(section2.duration, 6)

        XCTAssertEqual(track.sections.count, 2)
        XCTAssertEqual(track.sections[0].notes.count, 24)
        XCTAssertEqual(track.sections[1].notes.count, 6)
    }

    func testSectionLayersAreParallelAndSectionsSerial() {
        let track = Track(name: "Test") {
            Section {
                "CD"
                "EEE"
            }
            Section {
                "G"
            }
        }
        let layered = track.sections[0]
        XCTAssertEqual(layered.duration, 3)
        XCTAssertEqual(layered.notes.filter { $0.startTime == 0 }.count, 2)
        XCTAssertEqual(track.sections[1].notes.first?.startTime, 3)
    }
}

class EffectiveLoopCountTests: XCTestCase {
    func testExplicitLoopsWins() {
        let s = Session {
            Track(name: "A") { Section { "C" } }.active(loops: [0, 7])
        }.loops(3)
        XCTAssertEqual(s.effectiveLoopCount, 3)
    }

    func testNoArrangementPlaysOnce() {
        let s = Session { Track(name: "A") { Section { "C" } } }
        XCTAssertEqual(s.effectiveLoopCount, 1)
    }

    func testSetActivityIncludesLastNamedLoop() {
        let s = Session {
            Track(name: "A") { Section { "C" } }.active(loops: [0, 4])
        }
        XCTAssertEqual(s.effectiveLoopCount, 5)
    }

    func testClosedRangeActivity() {
        let s = Session {
            Track(name: "A") { Section { "C" } }.active(loops: 1...3)
        }
        XCTAssertEqual(s.effectiveLoopCount, 4)
    }

    func testOpenEndedRangeUsesLowerBound() {
        let s = Session {
            Track(name: "A") { Section { "C" } }.active(loops: 2...)
        }
        XCTAssertEqual(s.effectiveLoopCount, 3)
    }

    func testEveryAsksForOneFullCycle() {
        let s = Session {
            Track(name: "A") { Section { "C" } }.active(every: 4)
        }
        XCTAssertEqual(s.effectiveLoopCount, 4)
    }

    func testSectionActivityCounts() {
        let s = Session {
            Track(name: "A") {
                Section { "C" }.active(loops: [5])
            }
        }
        XCTAssertEqual(s.effectiveLoopCount, 6)
    }

    func testLoopsClampedToAtLeastOne() {
        let s = Session { Track(name: "A") { Section { "C" } } }.loops(0)
        XCTAssertEqual(s.effectiveLoopCount, 1)
    }
}

class DrumLaneTests: XCTestCase {
    func testLaneGridExpandsToGMKeys() {
        let section = Section {
            Kick( "x...x...")
            Snare("....x...")
        }
        let kicks = section.notes.filter { $0.pitch == DrumPiece.kick.midiKey }
        let snares = section.notes.filter { $0.pitch == DrumPiece.snare.midiKey }
        XCTAssertEqual(kicks.count, 2)
        XCTAssertEqual(snares.count, 1)
        XCTAssertEqual(kicks.map { $0.startTime }, [0, 0.5])
        XCTAssertEqual(snares.first?.startTime, 0.5)
        XCTAssertEqual(kicks.first?.duration ?? 0, 0.125, accuracy: 1e-9)
    }

    func testAccentGhostAndSpacesAndBars() {
        let lane = DrumLane(.closedHat, "X.x. o... | x...")
        let all = lane.notes(barDuration: 1.0)
        let hits = all.filter { $0.pitch != nil }
        XCTAssertEqual(hits.map { $0.velocity },
                       [DrumLane.accentVelocity, DrumLane.hitVelocity,
                        DrumLane.ghostVelocity, DrumLane.hitVelocity])
        XCTAssertEqual(hits.map { $0.startTime }, [0, 0.25, 0.5, 1.0])
        XCTAssertEqual(hits.compactMap { $0.sourceOffset }, [0, 2, 5, 12])
        XCTAssertEqual(all.map { $0.startTime + $0.duration }.max(), 2.0)
    }

    func testLanesLayerInParallelWithMelody() {
        let section = Section {
            Kick("x.x.")
            "C2C2"
        }
        let starts = section.notes.filter { $0.pitch != nil }.map { $0.startTime }.sorted()
        XCTAssertEqual(starts, [0, 0, 0.5, 1.0])
        XCTAssertEqual(section.duration, 2.0)
    }

    func testLaneVolumeScalesVelocitiesOnly() {
        let plain  = DrumLane(.closedHat, "X.x. o...")
        let quiet  = plain.volume(0.5)
        let hits   = quiet.notes(barDuration: 1.0).filter { $0.pitch != nil }
        let asWritten = plain.notes(barDuration: 1.0).filter { $0.pitch != nil }

        XCTAssertEqual(hits.map { $0.velocity }, [60, 50, 28])
        XCTAssertEqual(hits.map { $0.startTime }, asWritten.map { $0.startTime })
        XCTAssertEqual(hits.compactMap { $0.sourceOffset }, asWritten.compactMap { $0.sourceOffset })
    }

    func testLaneVolumeComposesWithSectionVelocity() {
        let scaled = Section { Kick("x...").volume(0.5) }.velocity(scale: 0.5)
        XCTAssertEqual(scaled.notes.filter { $0.pitch != nil }.map { $0.velocity }, [25])

        let flattened = Section { Kick("x...").volume(0.5) }.velocity(80)
        XCTAssertEqual(flattened.notes.filter { $0.pitch != nil }.map { $0.velocity }, [80])
    }

    func testLaneVolumeClampsAndKeepsBarExtent() {
        let silent = DrumLane(.kick, "x...").volume(0)
        XCTAssertEqual(silent.notes(barDuration: 1.0).filter { $0.pitch != nil }.map { $0.velocity }, [0])

        let loud = DrumLane(.closedHat, "X...").volume(3)
        XCTAssertEqual(loud.notes(barDuration: 1.0).filter { $0.pitch != nil }.map { $0.velocity }, [127])

        XCTAssertEqual(DrumLane(.kick, "x...").volume(-2).volumeScale, 0)

        let notes = loud.notes(barDuration: 1.0)
        XCTAssertEqual(notes.last?.pitch, nil)
        XCTAssertEqual(notes.map { $0.startTime + $0.duration }.max(), 1.0)
    }

    func testDrumsPatchIsPercussion() {
        let patch = Synth.drums(.tr808).build()
        XCTAssertEqual(patch.sampler?.percussion, true)
        XCTAssertEqual(patch.sampler?.program, DrumKit.tr808.rawValue)
    }
}

// MARK: - A kit piece written into notation

class DrumPieceSpellingTests: XCTestCase {

    func testEveryPercussionKeySpellsBackToItself() {
        for key in UInt32(35)...UInt32(81) {
            let spelling = DrumPiece(key: key).spelling
            XCTAssertEqual(pitchForNoteName(spelling), key,
                           "key \(key) spells as \(spelling), which reads back as something else")
        }
    }

    func testTheNamedPiecesSpellTheirOwnKeys() {
        XCTAssertEqual(DrumPiece.kick.spelling, "C3")
        XCTAssertEqual(DrumPiece.snare.spelling, "D3")
        XCTAssertEqual(DrumPiece.closedHat.spelling, "F#3")
        XCTAssertEqual(DrumPiece.slot(3).spelling, "D#3")
    }

    func testAPieceInterpolatesIntoNotationAsItsOwnKey() {
        let line = "| \(.kick) \(.closedHat) [\(.snare) \(.closedHat)] \(.closedHat) |"
        XCTAssertEqual(line, "| C3 F#3 [D3 F#3] F#3 |")
        let sounding = Section { line }.notes.filter { $0.pitch != nil }
        XCTAssertEqual(sounding.compactMap { $0.pitch },
                       [DrumPiece.kick.midiKey, DrumPiece.closedHat.midiKey,
                        DrumPiece.snare.midiKey, DrumPiece.closedHat.midiKey,
                        DrumPiece.closedHat.midiKey])
    }

    // A name is read absolutely, which is why a piece is written as one: the
    // number 36 would be the thirty-sixth degree of whatever key is in force.
    func testNoKeyMovesAnInterpolatedPiece() {
        let keyed = Section { "| \(.kick) \(.snare) |" }.key(.C4, .chromatic)
        XCTAssertEqual(keyed.notes.compactMap { $0.pitch },
                       [DrumPiece.kick.midiKey, DrumPiece.snare.midiKey])
    }
}

// MARK: - Comprehensive chord correctness tests (derived from Wikipedia: Chord notation)

class ChordIntervalTests: XCTestCase {

    func testIntervals() {
        let cases: [(ChordQuality, [UInt32], String)] = [
            (.major,          [0, 4, 7],         "major triad"),
            (.minor,          [0, 3, 7],         "minor triad"),
            (.diminished,     [0, 3, 6],         "diminished triad"),
            (.augmented,      [0, 4, 8],         "augmented triad"),
            (.dominant7,      [0, 4, 7, 10],     "dominant 7th"),
            (.major7,         [0, 4, 7, 11],     "major 7th"),
            (.minor7,         [0, 3, 7, 10],     "minor 7th"),
            (.add9,           [0, 4, 7, 14],     "add9"),
            (.sus4,           [0, 5, 7],         "sus4"),
            (.halfDiminished, [0, 3, 6, 10],     "half-diminished 7th"),
            (.diminished7,    [0, 3, 6, 9],      "diminished 7th"),
            (.sus2,           [0, 2, 7],         "sus2"),
            (.majorSixth,     [0, 4, 7, 9],      "major sixth"),
            (.minorSixth,     [0, 3, 7, 9],      "minor sixth"),
            (.dominant7sus4,  [0, 5, 7, 10],     "dominant 7 sus4"),
            (.add11,          [0, 4, 7, 17],     "add11"),
            (.power,          [0, 7],            "power chord"),
        ]
        for (quality, expected, label) in cases {
            XCTAssertEqual(quality.intervals, expected, label)
        }
    }

    func testCustomIntervals() {
        XCTAssertEqual(ChordQuality.custom("0,3,6,10").intervals, [0, 3, 6, 10], "half-diminished 7th via custom")
        XCTAssertEqual(ChordQuality.custom("0,3,6,9").intervals,  [0, 3, 6, 9],  "diminished 7th via custom")
    }

    func testBuildNotesOnC() {
        let cases: [(ChordQuality, [String])] = [
            (.major,          ["C5", "E5", "G5"]),
            (.minor,          ["C5", "D#5", "G5"]),
            (.diminished,     ["C5", "D#5", "F#5"]),
            (.augmented,      ["C5", "E5", "G#5"]),
            (.dominant7,      ["C5", "E5", "G5", "A#5"]),
            (.major7,         ["C5", "E5", "G5", "B5"]),
            (.minor7,         ["C5", "D#5", "G5", "A#5"]),
            (.add9,           ["C5", "E5", "G5", "D6"]),
            (.sus4,           ["C5", "F5", "G5"]),
            (.halfDiminished, ["C5", "D#5", "F#5", "A#5"]),
            (.diminished7,    ["C5", "D#5", "F#5", "A5"]),
        ]
        for (quality, expected) in cases {
            let notes = Chord.buildNotes(root: "C", quality: quality)
            XCTAssertEqual(notes.map { NoteNotation(pitch: $0.pitch) }, expected, "C \(quality)")
        }
    }

    func testBuildNotesMultipleRoots() {
        let cases: [(String, ChordQuality, [String])] = [
            ("G",  .major,      ["G5", "B5", "D6"]),
            ("D",  .major,      ["D5", "F#5", "A5"]),
            ("F",  .major,      ["F5", "A5", "C6"]),
            ("A",  .minor,      ["A5", "C6", "E6"]),
            ("E",  .minor,      ["E5", "G5", "B5"]),
            ("B",  .minor7,     ["B5", "D6", "F#6", "A6"]),
            ("F#", .major,      ["F#5", "A#5", "C#6"]),
            ("Bb", .major,      ["A#5", "D6", "F6"]),
            ("Ab", .minor,      ["G#5", "B5", "D#6"]),
            ("C",  .dominant7,  ["C5", "E5", "G5", "A#5"]),
            ("G",  .major7,     ["G5", "B5", "D6", "F#6"]),
            ("D",  .minor7,     ["D5", "F5", "A5", "C6"]),
        ]
        for (root, quality, expected) in cases {
            let notes = Chord.buildNotes(root: root, quality: quality)
            XCTAssertEqual(notes.map { NoteNotation(pitch: $0.pitch) }, expected, "\(root) \(quality)")
        }
    }

    func testNotationStringParsing() {
        let cases: [(String, [String])] = [
            ("Cmaj",  ["C5", "E5", "G5"]),
            ("Cmin",  ["C5", "D#5", "G5"]),
            ("Cdim",  ["C5", "D#5", "F#5"]),
            ("Caug",  ["C5", "E5", "G#5"]),
            ("Gmaj",  ["G5", "B5", "D6"]),
            ("F#min", ["F#5", "A5", "C#6"]),
            ("Abmaj", ["G#5", "C6", "D#6"]),
            ("Bbmin", ["A#5", "C#6", "F6"]),
        ]
        for (notation, expected) in cases {
            guard let chord = Chord(notation) else {
                XCTFail("Chord('\(notation)') returned nil")
                continue
            }
            XCTAssertEqual(chord.noteNotations, expected, "notes for '\(notation)'")
        }
    }

    func testNoteCount() {
        let triadQualities: [ChordQuality] = [.major, .minor, .diminished, .augmented, .sus4]
        let seventhQualities: [ChordQuality] = [.dominant7, .major7, .minor7, .add9, .halfDiminished, .diminished7]

        for q in triadQualities {
            XCTAssertEqual(Chord.buildNotes(root: "C", quality: q).count, 3, "\(q) should be a triad")
        }
        for q in seventhQualities {
            XCTAssertEqual(Chord.buildNotes(root: "C", quality: q).count, 4, "\(q) should have 4 notes")
        }
    }

    func testRootIsLowest() {
        let qualities: [ChordQuality] = [.major, .minor, .diminished, .augmented,
                                          .dominant7, .major7, .minor7, .add9, .sus4,
                                          .halfDiminished, .diminished7]
        for q in qualities {
            let notes = Chord.buildNotes(root: "C", quality: q)
            let pitches = notes.compactMap { $0.pitch }
            XCTAssertEqual(pitches.first, pitches.min(), "root should be lowest in C \(q)")
        }
    }
}

// MARK: - Jazz chord notation aliases

class JazzNotationTests: XCTestCase {

    func testJazzAliases() {
        let cases: [(String, [String])] = [
            ("Cm",    ["C5", "D#5", "G5"]),
            ("Cm7",   ["C5", "D#5", "G5", "A#5"]),
            ("C7",    ["C5", "E5", "G5", "A#5"]),
            ("Cmaj7", ["C5", "E5", "G5", "B5"]),
            ("Cdim7", ["C5", "D#5", "F#5", "A5"]),
            ("Fm7",   ["F5", "G#5", "C6", "D#6"]),
            ("Bbm7",  ["A#5", "C#6", "F6", "G#6"]),
        ]
        for (notation, expected) in cases {
            guard let chord = Chord(notation) else {
                XCTFail("Chord('\(notation)') returned nil")
                continue
            }
            XCTAssertEqual(chord.noteNotations, expected, "notes for '\(notation)'")
        }
    }

    func testHalfDiminishedNotation() {
        let chord = Chord("Cø7")!
        XCTAssertEqual(chord.noteNotations, ["C5", "D#5", "F#5", "A#5"])
        XCTAssertEqual(Chord("Cm7b5")!.noteNotations, ["C5", "D#5", "F#5", "A#5"])
        XCTAssertEqual(ChordQuality(from: "m7b5")?.notation, "ø7")
    }

    func testNewQualityAliases() {
        let cases: [(String, [String])] = [
            ("Csus2",     ["C5", "D5", "G5"]),
            ("Cmaj6",     ["C5", "E5", "G5", "A5"]),
            ("CM6",       ["C5", "E5", "G5", "A5"]),
            ("C6th",      ["C5", "E5", "G5", "A5"]),
            ("Cm6",       ["C5", "D#5", "G5", "A5"]),
            ("Cmin6",     ["C5", "D#5", "G5", "A5"]),
            ("C7sus4",    ["C5", "F5", "G5", "A#5"]),
            ("Cdom7sus4", ["C5", "F5", "G5", "A#5"]),
            ("Cadd11",    ["C5", "E5", "G5", "F6"]),
            ("Cpow",      ["C5", "G5"]),
            ("Cno3",      ["C5", "G5"]),
        ]
        for (notation, expected) in cases {
            guard let chord = Chord(notation) else {
                XCTFail("Chord('\(notation)') returned nil")
                continue
            }
            XCTAssertEqual(chord.noteNotations, expected, "notes for '\(notation)'")
        }
    }

    func testSingleTokenAlterations() {
        XCTAssertEqual(Chord("G7b9")!.notes.compactMap { $0.pitch }.sorted(), [67, 71, 74, 77, 80])
        XCTAssertEqual(Chord("Cmaj7#11")!.notes.compactMap { $0.pitch }.sorted(), [60, 64, 67, 71, 78])
        XCTAssertEqual(Chord("Am7b13")!.notes.compactMap { $0.pitch }.sorted(), [69, 72, 76, 79, 89])
    }

    func testAlteredFifthReplacesNaturalFifth() {
        XCTAssertEqual(Chord("C7b5")!.notes.compactMap { $0.pitch }.sorted(), [60, 64, 66, 70])
        XCTAssertEqual(Chord("C7#5")!.notes.compactMap { $0.pitch }.sorted(), [60, 64, 68, 70])
        XCTAssertEqual(Chord("Cdom7")!.ext("b5").notes.compactMap { $0.pitch }.sorted(), [60, 64, 66, 70])
    }

    func testStackedAlterations() {
        XCTAssertEqual(ChordQuality(from: "m7b5b9")?.intervals, [0, 3, 6, 10, 13])
        XCTAssertEqual(ChordQuality(from: "7b9b13")?.intervals, [0, 4, 7, 10, 13, 20])
    }

    func testAlterationOnNewQuality() {
        XCTAssertEqual(Chord("C7sus4b9")!.notes.compactMap { $0.pitch }.sorted(), [60, 65, 67, 70, 73])
    }

    func testRomanNumeralWithAlterationSuffix() {
        guard let notation = Chord.transformRomanNumeral("V7b9", inKey: "C") else {
            XCTFail("V7b9 did not resolve")
            return
        }
        XCTAssertEqual(Chord(notation)!.notes.compactMap { $0.pitch }.sorted(), [67, 71, 74, 77, 80])
    }

    func testUnknownAlterationRejected() {
        XCTAssertNil(ChordQuality(from: "7b12"))
        XCTAssertNil(ChordQuality(from: "b8"))
        XCTAssertNil(ChordQuality(from: "6"))
        XCTAssertNil(ChordQuality(from: "5"))
    }
}

// MARK: - F14 — new qualities and alterations in string notation

class ChordQualityNotationTests: XCTestCase {

    private func pitches(at time: MusicTimeStamp, in notes: [Note]) -> [UInt32] {
        notes.filter { $0.startTime == time }.compactMap { $0.pitch }.sorted()
    }

    func testBarModeC6StaysPitch() {
        let notes = SectionBuilder.parseNotation("C6 | G")
        XCTAssertEqual(pitches(at: 0.0, in: notes), [72])
    }

    func testBarModeC5StaysPitch() {
        let notes = SectionBuilder.parseNotation("C5 | G")
        XCTAssertEqual(pitches(at: 0.0, in: notes), [60])
    }

    func testInlineC6StaysPitch() {
        let notes = SectionBuilder.parseNotation("C6")
        XCTAssertEqual(notes.compactMap { $0.pitch }, [72])
    }

    func testAccidentalPitchesUnaffectedByAlterationParsing() {
        let notes = SectionBuilder.parseNotation("Ab5 | Gb9")
        XCTAssertEqual(pitches(at: 0.0, in: notes), [68])
        XCTAssertEqual(pitches(at: 1.0, in: notes), [114])
    }

    func testBarModeSusChords() {
        let notes = SectionBuilder.parseNotation("Csus2 | C7sus4")
        XCTAssertEqual(pitches(at: 0.0, in: notes), [60, 62, 67])
        XCTAssertEqual(pitches(at: 1.0, in: notes), [60, 65, 67, 70])
    }

    func testBarModeAlteredToken() {
        let notes = SectionBuilder.parseNotation("G7b9 | Cmaj7")
        XCTAssertEqual(pitches(at: 0.0, in: notes), [67, 71, 74, 77, 80])
    }

    func testBarModePowerAndSixthChords() {
        let notes = SectionBuilder.parseNotation("Cpow | Gno3 | Cmaj6 | Cm6")
        XCTAssertEqual(pitches(at: 0.0, in: notes), [60, 67])
        XCTAssertEqual(pitches(at: 1.0, in: notes), [67, 74])
        XCTAssertEqual(pitches(at: 2.0, in: notes), [60, 64, 67, 69])
        XCTAssertEqual(pitches(at: 3.0, in: notes), [60, 63, 67, 69])
    }

    func testInlineAlteredToken() {
        let notes = SectionBuilder.parseNotation("C G7b9")
        XCTAssertEqual(pitches(at: 2.0, in: notes), [67, 71, 74, 77, 80])
    }

    func testLoneInlineRunCharTokenStaysCompactRun() {
        let notes = SectionBuilder.parseNotation("G7b9")
        XCTAssertEqual(notes.compactMap { $0.pitch }, [91])
    }
}

// MARK: - Bar notation

class BarNotationTests: XCTestCase {

    func testBarDuration() {
        let section = Section { "Cm7 | Fm7 | Bbmaj7 | Cm7" }
        XCTAssertEqual(section.notes.count, 16)
        XCTAssertEqual(section.duration, 4.0)
        let sortedTimes = Set(section.notes.map { $0.startTime }).sorted()
        XCTAssertEqual(sortedTimes[0], 0.0)
        XCTAssertEqual(sortedTimes[1], 1.0)
        XCTAssertEqual(sortedTimes[2], 2.0)
        XCTAssertEqual(sortedTimes[3], 3.0)
    }

    func testTwoChordsPerBar() {
        let section = Section { "Cm7 Fm7 | Bbmaj7" }
        XCTAssertEqual(section.notes.count, 12)
        let bar1Times = Set(section.notes.filter { $0.startTime < 1.0 }.map { $0.startTime }).sorted()
        XCTAssertEqual(bar1Times[0], 0.0)
        XCTAssertEqual(bar1Times[1], 0.5)
    }

    func testBarNotationChordQuality() {
        let section = Section { "Dm7 | G7 | Cmaj7" }
        XCTAssertEqual(section.notes.count, 12)
        let bar2Notes = section.notes.filter { $0.startTime == 1.0 }.compactMap { $0.pitch }.sorted()
        XCTAssertEqual(bar2Notes, [67, 71, 74, 77])
    }

    // MARK: F03 — compact melody runs inside bars

    func testCompactRunSubdividesSlot() {
        let notes = SectionBuilder.parseNotation("CDEF | G")
        XCTAssertEqual(notes.count, 5)
        XCTAssertEqual(notes[0..<4].map { $0.startTime }, [0.0, 0.25, 0.5, 0.75])
        XCTAssertEqual(notes[0..<4].map { $0.duration }, [0.25, 0.25, 0.25, 0.25])
        XCTAssertEqual(notes[0..<4].compactMap { $0.pitch },
                       [pitchForNote["C"]!, pitchForNote["D"]!, pitchForNote["E"]!, pitchForNote["F"]!])
        XCTAssertEqual(notes[4].pitch, pitchForNote["G"])
        XCTAssertEqual(notes[4].startTime, 1.0)
        XCTAssertEqual(notes[4].duration, 1.0)
    }

    func testCompactRunSharesBarWithChord() {
        let notes = SectionBuilder.parseNotation("CDEF Cmaj | G")
        XCTAssertEqual(notes.count, 8)
        XCTAssertEqual(notes[0..<4].map { $0.startTime }, [0.0, 0.125, 0.25, 0.375])
        XCTAssertEqual(notes[0..<4].map { $0.duration }, [0.125, 0.125, 0.125, 0.125])
        let chord = notes[4..<7]
        XCTAssertTrue(chord.allSatisfy { $0.startTime == 0.5 && $0.duration == 0.5 })
        XCTAssertEqual(notes[7].startTime, 1.0)
    }

    func testCompactRunWithTie() {
        let notes = SectionBuilder.parseNotation("C-DE | G")
        XCTAssertEqual(notes.count, 4)
        XCTAssertEqual(notes[0].pitch, pitchForNote["C"])
        XCTAssertEqual(notes[0].startTime, 0.0)
        XCTAssertEqual(notes[0].duration, 0.5)
        XCTAssertEqual(notes[1].pitch, pitchForNote["D"])
        XCTAssertEqual(notes[1].startTime, 0.5)
        XCTAssertEqual(notes[1].duration, 0.25)
        XCTAssertEqual(notes[2].pitch, pitchForNote["E"])
        XCTAssertEqual(notes[2].startTime, 0.75)
        XCTAssertEqual(notes[2].duration, 0.25)
        XCTAssertEqual(notes[3].startTime, 1.0)
    }

    func testCompactRunWithSlide() {
        let notes = SectionBuilder.parseNotation("CD>EF | G")
        XCTAssertEqual(notes.count, 4)
        XCTAssertEqual(notes[0].pitch, pitchForNote["C"])
        XCTAssertEqual(notes[0].startTime, 0.0)
        XCTAssertEqual(notes[0].duration, 1.0 / 3, accuracy: 1e-9)
        XCTAssertEqual(notes[1].pitch, pitchForNote["E"])
        XCTAssertEqual(notes[1].startTime, 1.0 / 3, accuracy: 1e-9)
        XCTAssertEqual(notes[1].duration, 1.0 / 3, accuracy: 1e-9)
        XCTAssertEqual(notes[1].slides?.count, 1)
        XCTAssertEqual(notes[1].slides?[0].from, pitchForNote["D"])
        XCTAssertEqual(notes[1].slides?[0].at ?? -1, 0.0, accuracy: 1e-9)
        XCTAssertEqual(notes[1].slides?[0].over, 0)
        XCTAssertEqual(notes[2].pitch, pitchForNote["F"])
        XCTAssertEqual(notes[2].startTime, 2.0 / 3, accuracy: 1e-9)
        XCTAssertEqual(notes[3].startTime, 1.0)
    }

    func testCompactRunFillSlideScalesIntoSlot() {
        let notes = SectionBuilder.parseNotation("CD>=EF | G")
        XCTAssertEqual(notes.count, 4)
        XCTAssertEqual(notes[1].slides?.count, 1)
        XCTAssertEqual(notes[1].slides?[0].over ?? -1, 1.0 / 3, accuracy: 1e-9)
    }

    func testCompactRunSourceOffsets() {
        let notes = SectionBuilder.parseNotation("CDEF | G")
        XCTAssertEqual(notes.map { $0.sourceOffset }, [0, 1, 2, 3, 7])
        XCTAssertTrue(notes.allSatisfy { $0.sourceLength == 1 })
    }

    func testCompactRunTailOnlySuspends() {
        let notes = SectionBuilder.parseNotation("CDEF - | G")
        XCTAssertEqual(notes.count, 5)
        XCTAssertEqual(notes[0..<4].map { $0.startTime }, [0.0, 0.125, 0.25, 0.375])
        XCTAssertEqual(notes[0].duration, 0.125)
        XCTAssertEqual(notes[1].duration, 0.125)
        XCTAssertEqual(notes[2].duration, 0.125)
        XCTAssertEqual(notes[3].duration, 0.625)
        XCTAssertEqual(notes[4].startTime, 1.0)
    }

    // MARK: Rests hold their slots

    func testTrailingRestsKeepTheBarsLength() {
        let notes = SectionBuilder.parseNotation("| 1 r r r |")
        XCTAssertEqual(notes.compactMap { $0.pitch }, [60])
        XCTAssertEqual(notes.count, 4)
        XCTAssertEqual(notes.map { $0.startTime }, [0.0, 0.25, 0.5, 0.75])
        XCTAssertTrue(notes.allSatisfy { $0.duration == 0.25 })
        XCTAssertEqual(Section(notes: notes).duration, 1.0)
    }

    func testEverySilentSlotKeepsItsTime() {
        XCTAssertEqual(Section { "| 1 - - - | |" }.duration, 2.0)
        XCTAssertEqual(Section { "| r r r r |" }.duration, 1.0)
        XCTAssertEqual(Section { "| 1 r r - |" }.duration, 1.0)
        XCTAssertEqual(Section { "| 1 r r >5 |" }.duration, 1.0)
    }

    func testASectionAfterTrailingRestsStartsOnTheBarline() {
        let track = Track(name: "t") {
            Section { "| 1 r r r |" }
            Section { "| 5 r r r |" }
        }
        XCTAssertEqual(track.sections[1].notes.first?.startTime, 1.0)
    }

    func testCompactRunsProduceNoWarnings() {
        XCTAssertTrue(SectionBuilder.parseNotationWithWarnings("CDEF | G").warnings.isEmpty)
        XCTAssertTrue(SectionBuilder.parseNotationWithWarnings("C-DE | G").warnings.isEmpty)
        XCTAssertTrue(SectionBuilder.parseNotationWithWarnings("CD>EF | G").warnings.isEmpty)
        XCTAssertTrue(SectionBuilder.parseNotationWithWarnings("CDEF Cmaj | G").warnings.isEmpty)
    }
}

// MARK: - Arpeggio tilde notation

class ArpeggioNotationTests: XCTestCase {

    func testPrefixTildeAscending() {
        let section = Section { "~Cmaj | Fmaj" }
        XCTAssertEqual(section.notes.count, 6)
        let bar1 = section.notes.filter { $0.startTime < 1.0 }.sorted { $0.startTime < $1.startTime }
        XCTAssertEqual(bar1.count, 3)
        XCTAssertTrue(bar1[0].startTime < bar1[1].startTime)
        XCTAssertTrue(bar1[1].startTime < bar1[2].startTime)
        XCTAssertTrue(bar1[0].pitch ?? 0 < bar1[1].pitch ?? 0)
        XCTAssertTrue(bar1[1].pitch ?? 0 < bar1[2].pitch ?? 0)
    }

    func testPostfixDoubleTildeDescending() {
        let section = Section { "Cmaj~~ | Fmaj" }
        XCTAssertEqual(section.notes.count, 6)
        let bar1 = section.notes.filter { $0.startTime < 1.0 }.sorted { $0.startTime < $1.startTime }
        XCTAssertEqual(bar1.count, 3)
        XCTAssertTrue(bar1[0].pitch ?? 0 > bar1[1].pitch ?? 0)
        XCTAssertTrue(bar1[1].pitch ?? 0 > bar1[2].pitch ?? 0)
    }

    func testNoArpeggioPlaysSimultaneously() {
        let section = Section { "Cmaj | Fmaj" }
        let bar1 = section.notes.filter { $0.startTime < 1.0 }
        XCTAssertEqual(Set(bar1.map { $0.startTime }).count, 1)
    }

    func testStackArpeggioFillPlaysListedOrder() {
        let written = Section { "[D3 A3 E4 F#4] | C" }.notes.filter { $0.startTime < 1.0 }.map { $0.pitch }
        let section = Section { "~=[D3 A3 E4 F#4] | C" }
        let bar1 = section.notes.filter { $0.startTime < 1.0 }.sorted { $0.startTime < $1.startTime }
        XCTAssertEqual(bar1.count, 4)
        XCTAssertEqual(bar1.map { $0.pitch }, written)
        for (i, note) in bar1.enumerated() {
            XCTAssertEqual(note.startTime, 0.25 * Double(i), accuracy: 0.001)
        }
    }

    func testStackArpeggioDoubleTildeReversesListedOrder() {
        let written = Section { "[D3 A3 E4 F#4] | C" }.notes.filter { $0.startTime < 1.0 }.map { $0.pitch }
        let section = Section { "[D3 A3 E4 F#4]~~= | C" }
        let bar1 = section.notes.filter { $0.startTime < 1.0 }.sorted { $0.startTime < $1.startTime }
        XCTAssertEqual(bar1.map { $0.pitch }, written.reversed())
    }

    func testStackArpeggioKeepsRepeatedPitchesAndNonMonotonicOrder() {
        let written = Section { "[C#5 E5 C#5 A4] | C" }.notes.filter { $0.startTime < 1.0 }.map { $0.pitch }
        let section = Section { "~=[C#5 E5 C#5 A4] | C" }
        let bar1 = section.notes.filter { $0.startTime < 1.0 }.sorted { $0.startTime < $1.startTime }
        XCTAssertEqual(bar1.count, 4)
        XCTAssertEqual(bar1.map { $0.pitch }, written)
    }

    func testStackArpeggioTightDefaultsToStrumDelay() {
        let section = Section { "~[D3 A3 E4] | C" }
        let bar1 = section.notes.filter { $0.startTime < 1.0 }.sorted { $0.startTime < $1.startTime }
        XCTAssertEqual(bar1.count, 3)
        for (i, note) in bar1.enumerated() {
            XCTAssertEqual(note.startTime, 0.05 * Double(i), accuracy: 0.001)
        }
    }

    func testStackArpeggioNotesRingThroughSlot() {
        let section = Section { "~=[D3 A3 E4 F#4] | C" }
        let bar1 = section.notes.filter { $0.startTime < 1.0 }
        for note in bar1 {
            XCTAssertEqual(note.duration, 1.0, accuracy: 0.001)
        }
    }

    func testStackArpeggioInlineNotation() {
        let written = Section { "[D3 A3 E4 F#4] C4" }.notes.filter { $0.startTime < 1.0 }.map { $0.pitch }
        let section = Section { "~=[D3 A3 E4 F#4] C4" }
        let slot1 = section.notes.filter { $0.startTime < 1.0 }.sorted { $0.startTime < $1.startTime }
        XCTAssertEqual(slot1.count, 4)
        XCTAssertEqual(slot1.map { $0.pitch }, written)
        for (i, note) in slot1.enumerated() {
            XCTAssertEqual(note.startTime, 0.25 * Double(i), accuracy: 0.001)
        }
    }
}

// MARK: - Velocity scaling & gated shuffle plumbing

class VelocityScaleTests: XCTestCase {

    func testVelocityScaleKeepsRatios() {
        let section = Section {
            Kick( "x.X.")
            Snare("..o.")
        }
        let scaled = section.velocity(scale: 0.5)
        let original = section.notes.filter { $0.pitch != nil }.sorted { $0.startTime < $1.startTime }
        let result = scaled.notes.filter { $0.pitch != nil }.sorted { $0.startTime < $1.startTime }
        XCTAssertEqual(result.count, original.count)
        for (o, r) in zip(original, result) {
            XCTAssertEqual(r.velocity, UInt32((Double(o.velocity) * 0.5).rounded()))
        }
        let velocities = result.map { $0.velocity }
        XCTAssertEqual(velocities.sorted(by: >).first, velocities.max())
    }

    func testVelocityScaleClampsTo127() {
        let section = Section { "C4" }.velocity(120).velocity(scale: 2.0)
        XCTAssertEqual(section.notes.first?.velocity, 127)
    }

    func testVelocityScalePreservesActivity() {
        let section = Section { "C4" }.active(loops: [3]).velocity(scale: 0.8)
        XCTAssertNotNil(section.activity, "copy-and-mutate must keep the arrangement gate")
    }
}

class ShuffleLoopsPlumbingTests: XCTestCase {

    func testShuffleSectionsLoopsSetsOrderAndGate() {
        let track = Track(name: "t") { Section { "C" } }.shuffleSections(loops: [1, 2, 4, 5])
        XCTAssertEqual(track.sectionOrder, .shuffled)
        XCTAssertEqual(track.shuffleLoops, .set([1, 2, 4, 5]))
        XCTAssertNil(Track(name: "t") { Section { "C" } }.shuffleSections().shuffleLoops,
                     "no-argument form keeps the every-pass behavior")
    }

    func testModifiersPreserveShuffleLoops() {
        let track = Track(name: "t") { Section { "C" } }
            .shuffleSections(loops: [1, 2])
            .volume(0.7)
            .active(loops: 1...)
        XCTAssertEqual(track.shuffleLoops, .set([1, 2]))
        XCTAssertEqual(track.sectionOrder, .shuffled)
    }

    func testMuteFlagSurvivesModifiersAndCodable() throws {
        let track = Track(name: "t") { Section { "C" } }
            .mute()
            .volume(0.7)
            .active(loops: 1...)
        XCTAssertTrue(track.isMuted)
        XCTAssertEqual(track.volume, 0.7)
        XCTAssertFalse(track.mute(false).isMuted)
        XCTAssertFalse(Track(name: "t") { Section { "C" } }.isMuted)

        let data = try JSONEncoder().encode(Session { track })
        XCTAssertTrue(try JSONDecoder().decode(Session.self, from: data).tracks[0].isMuted)
    }

    func testShuffleLoopsSurvivesCodableRoundTrip() throws {
        let session = Session {
            Track(name: "t") { Section { "C" } }.shuffleSections(loops: [1, 3])
        }
        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(Session.self, from: data)
        XCTAssertEqual(decoded.tracks[0].shuffleLoops, .set([1, 3]))
        XCTAssertEqual(decoded.tracks[0].sectionOrder, .shuffled)
    }
}

// MARK: - Progression syncopation

class ProgressionSyncopateTests: XCTestCase {

    func testFirstChordUnchanged() {
        let prog = Progression("I - IV - V - I", for: .C).syncopate(by: .n16)
        let times = prog.chords.map { $0.notes[0].startTime }
        XCTAssertEqual(times[0], 0.0, accuracy: 0.001)
    }

    func testSubsequentChordsShiftedEarlier() {
        let amount = MusicTimeStamp.n16
        let prog = Progression("I - IV - V - I", for: .C).syncopate(by: amount)
        let times = prog.chords.map { $0.notes[0].startTime }
        XCTAssertEqual(times[1], 1.0 - amount, accuracy: 0.001)
        XCTAssertEqual(times[2], 2.0 - amount, accuracy: 0.001)
        XCTAssertEqual(times[3], 3.0 - amount, accuracy: 0.001)
    }

    func testZeroAmountMatchesNaturalTimes() {
        let prog = Progression("I - IV - V - I", for: .C).syncopate(by: 0)
        let times = prog.chords.map { $0.notes[0].startTime }
        XCTAssertEqual(times[0], 0.0, accuracy: 0.001)
        XCTAssertEqual(times[1], 1.0, accuracy: 0.001)
        XCTAssertEqual(times[2], 2.0, accuracy: 0.001)
        XCTAssertEqual(times[3], 3.0, accuracy: 0.001)
    }
}

// MARK: - Section syncopation

class SectionSyncopateTests: XCTestCase {

    private func quarterNoteSection() -> Section {
        let notes = (0..<4).map { i in
            Note(pitch: 60, velocity: 80, startTime: Double(i) * .n4, duration: .n4)
        }
        return Section(notes: notes)
    }

    func testBeatOneUnchanged() {
        let section = quarterNoteSection().syncopate(by: .n16)
        XCTAssertEqual(section.notes[0].startTime, 0.0, accuracy: 0.001)
    }

    func testOnBeatNotesShiftedEarlier() {
        let amount = MusicTimeStamp.n16
        let section = quarterNoteSection().syncopate(by: amount)
        XCTAssertEqual(section.notes[1].startTime, 0.25 - amount, accuracy: 0.001)
        XCTAssertEqual(section.notes[2].startTime, 0.50 - amount, accuracy: 0.001)
        XCTAssertEqual(section.notes[3].startTime, 0.75 - amount, accuracy: 0.001)
    }

    func testOffBeatNotesUntouched() {
        let offBeat = Note(pitch: 62, velocity: 80, startTime: 0.125, duration: .n8)
        let section = Section(notes: [offBeat]).syncopate(by: .n16)
        XCTAssertEqual(section.notes[0].startTime, 0.125, accuracy: 0.001)
    }
}

// MARK: - Section swing

class SectionSwingTests: XCTestCase {

    private func eighthNoteSection() -> Section {
        let notes = (0..<8).map { i in
            Note(pitch: 60, velocity: 80, startTime: Double(i) * .n8, duration: .n8)
        }
        return Section(notes: notes)
    }

    func testOnBeatNotesUnchanged() {
        let section = eighthNoteSection().swing(0.67)
        XCTAssertEqual(section.notes[0].startTime, 0.0,  accuracy: 0.001)
        XCTAssertEqual(section.notes[2].startTime, 0.25, accuracy: 0.001)
        XCTAssertEqual(section.notes[4].startTime, 0.5,  accuracy: 0.001)
    }

    func testOffBeatNotesSwungLater() {
        let ratio = 0.67
        let section = eighthNoteSection().swing(ratio)
        XCTAssertEqual(section.notes[1].startTime, ratio * 0.25, accuracy: 0.001)
        XCTAssertEqual(section.notes[3].startTime, 0.25 + ratio * 0.25, accuracy: 0.001)
        XCTAssertEqual(section.notes[5].startTime, 0.50 + ratio * 0.25, accuracy: 0.001)
        XCTAssertEqual(section.notes[7].startTime, 0.75 + ratio * 0.25, accuracy: 0.001)
    }

    func testStraightRatioNoChange() {
        let section = eighthNoteSection().swing(0.5)
        for (i, note) in section.notes.enumerated() {
            XCTAssertEqual(note.startTime, Double(i) * 0.125, accuracy: 0.001)
        }
    }
}

class SourceStampTests: XCTestCase {

    func testStatementsStampLineAndColumn() {
        let section = Section {
            Note(pitch: 60, velocity: 100, duration: .n4)
            Note(pitch: 62, velocity: 100, duration: .n4)
        }
        XCTAssertEqual(section.notes.count, 2)
        let first = section.notes[0]
        let second = section.notes[1]
        XCTAssertNotNil(first.sourceLine)
        XCTAssertNotNil(first.sourceColumn)
        XCTAssertEqual((second.sourceLine ?? 0) - (first.sourceLine ?? 0), 1)
        XCTAssertEqual(first.sourceColumn, second.sourceColumn)
        XCTAssertNil(first.sourceOffset)
    }

    func testChordStatementSharesOneStamp() {
        let section = Section {
            Chord("C", .major).duration(.n2)
        }
        XCTAssertEqual(section.notes.count, 3)
        XCTAssertTrue(section.notes.allSatisfy { $0.sourceLine != nil })
        XCTAssertEqual(Set(section.notes.compactMap { $0.sourceLine }).count, 1)
    }

    func testSpacedNotationTokenOffsets() {
        let notes = SectionBuilder.parseNotation("C E G")
        let pitched = notes.filter { $0.pitch != nil }
        XCTAssertEqual(pitched.compactMap { $0.sourceOffset }, [0, 2, 4])
        XCTAssertEqual(pitched.compactMap { $0.sourceLength }, [1, 1, 1])
    }

    func testCompactNotationTokenOffsets() {
        let notes = SectionBuilder.parseNotation("CDbE5")
        XCTAssertEqual(notes.compactMap { $0.sourceOffset }, [0, 1, 3])
        XCTAssertEqual(notes.compactMap { $0.sourceLength }, [1, 2, 2])
    }

    func testBarNotationTokenOffsets() {
        let notes = SectionBuilder.parseNotation("Cm7 | F | Am")

        let cm7 = notes.filter { $0.sourceOffset == 0 }
        XCTAssertEqual(cm7.count, 4)
        XCTAssertTrue(cm7.allSatisfy { $0.sourceLength == 3 })

        let f = notes.filter { $0.sourceOffset == 6 }
        XCTAssertEqual(f.count, 1)
        XCTAssertEqual(f.first?.sourceLength, 1)

        let am = notes.filter { $0.sourceOffset == 10 }
        XCTAssertEqual(am.count, 3)
        XCTAssertTrue(am.allSatisfy { $0.sourceLength == 2 })
    }

    func testSectionModifiersPreserveStamps() {
        let section = Section {
            "C E G"
        }.velocities(90, 80, 70).swing()
        let pitched = section.notes.filter { $0.pitch != nil }
        XCTAssertFalse(pitched.isEmpty)
        XCTAssertTrue(pitched.allSatisfy { $0.sourceLine != nil && $0.sourceOffset != nil })
    }

    func testNotationExpressionPreservesTokenOffsets() {
        let section = Section {
            "Cm7 | F".velocity(70)
        }
        XCTAssertTrue(section.notes.allSatisfy { $0.sourceLine != nil })
        XCTAssertEqual(Set(section.notes.compactMap { $0.sourceOffset }), Set([0, 6]))
        XCTAssertTrue(section.notes.allSatisfy { $0.velocity == 70 })
    }

    func testArpeggioKeepsTokenOffsets() {
        let section = Section {
            "Cm7 | F".arpeggio()
        }
        let cm7 = section.notes.filter { $0.sourceOffset == 0 }
        XCTAssertEqual(cm7.count, 4)
        XCTAssertTrue(cm7.allSatisfy { $0.sourceLength == 3 })
    }
}

class LoopActivityTests: XCTestCase {

    func testRangeActivity() {
        let fromTwo = LoopActivity.range(from: 2, through: nil)
        XCTAssertFalse(fromTwo.isActive(loopIndex: 0))
        XCTAssertFalse(fromTwo.isActive(loopIndex: 1))
        XCTAssertTrue(fromTwo.isActive(loopIndex: 2))
        XCTAssertTrue(fromTwo.isActive(loopIndex: 100))

        let window = LoopActivity.range(from: 1, through: 3)
        XCTAssertFalse(window.isActive(loopIndex: 0))
        XCTAssertTrue(window.isActive(loopIndex: 1))
        XCTAssertTrue(window.isActive(loopIndex: 3))
        XCTAssertFalse(window.isActive(loopIndex: 4))

        let upToTwo = LoopActivity.range(from: nil, through: 2)
        XCTAssertTrue(upToTwo.isActive(loopIndex: 0))
        XCTAssertTrue(upToTwo.isActive(loopIndex: 2))
        XCTAssertFalse(upToTwo.isActive(loopIndex: 3))
    }

    func testSetActivity() {
        let set = LoopActivity.set([0, 1, 4])
        XCTAssertTrue(set.isActive(loopIndex: 0))
        XCTAssertTrue(set.isActive(loopIndex: 4))
        XCTAssertFalse(set.isActive(loopIndex: 2))
        XCTAssertFalse(set.isActive(loopIndex: 5))
    }

    func testEveryActivity() {
        let even = LoopActivity.every(2, offset: 0)
        XCTAssertTrue(even.isActive(loopIndex: 0))
        XCTAssertFalse(even.isActive(loopIndex: 1))
        XCTAssertTrue(even.isActive(loopIndex: 2))

        let odd = LoopActivity.every(2, offset: 1)
        XCTAssertFalse(odd.isActive(loopIndex: 0))
        XCTAssertTrue(odd.isActive(loopIndex: 1))

        let everyFourth = LoopActivity.every(4, offset: 3)
        XCTAssertTrue(everyFourth.isActive(loopIndex: 3))
        XCTAssertTrue(everyFourth.isActive(loopIndex: 7))
        XCTAssertFalse(everyFourth.isActive(loopIndex: 4))
    }

    func testTrackActiveModifiers() {
        let base = Track(name: "t") { Section { Note(pitch: 60) } }
        XCTAssertNil(base.activity)

        XCTAssertEqual(base.active(loops: 2...).activity, .range(from: 2, through: nil))
        XCTAssertEqual(base.active(loops: 1...3).activity, .range(from: 1, through: 3))
        XCTAssertEqual(base.active(loops: 1..<3).activity, .range(from: 1, through: 2))
        XCTAssertEqual(base.active(loops: ...2).activity, .range(from: nil, through: 2))
        XCTAssertEqual(base.active(loops: ..<4).activity, .range(from: nil, through: 3))
        XCTAssertEqual(base.active(loops: [0, 4]).activity, .set([0, 4]))
        XCTAssertEqual(base.active(every: 2, offset: 1).activity, .every(2, offset: 1))
    }

    func testSectionActiveHalfOpenUpperBound() {
        let base = Section { Note(pitch: 60) }
        XCTAssertEqual(base.active(loops: ..<4).activity, .range(from: nil, through: 3))
    }

    func testActivitySurvivesOtherTrackModifiers() {
        let track = Track(name: "t") { Section { Note(pitch: 60) } }
            .active(loops: 2...)
            .volume(0.5)
            .tempo(120)
        XCTAssertEqual(track.activity, .range(from: 2, through: nil))
    }

    func testActivitySurvivesSectionTransforms() {
        let section = Section {
            Note(pitch: 60, velocity: 90, duration: .n4)
            Note(pitch: 64, velocity: 90, duration: .n4)
        }
        .active(every: 2)
        .velocity(70)
        .tempo(100)
        .swing()
        XCTAssertEqual(section.activity, .every(2, offset: 0))
    }

    func testActivityRoundTripsThroughJSON() throws {
        let session = Session {
            Track(name: "drums") { Section { Note(pitch: 36) }.active(loops: [0, 2]) }
                .active(loops: 1...)
        }
        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(Session.self, from: data)
        XCTAssertEqual(decoded.tracks[0].activity, .range(from: 1, through: nil))
        XCTAssertEqual(decoded.tracks[0].sections[0].activity, .set([0, 2]))
    }
}

class VariantSectionTests: XCTestCase {

    func testNestedSectionIsAParallelLayer() {
        let section = Section {
            Section {
                Note(pitch: 60, velocity: 90, startTime: 0, duration: 1.0)
                Note(pitch: 64, velocity: 90, startTime: 1.0, duration: 1.0)
            }
            Note(pitch: 40, velocity: 90, startTime: 0, duration: 0.5)
        }
        XCTAssertEqual(section.notes.count, 3)
        XCTAssertEqual(section.notes.filter { $0.startTime == 0 }.count, 2)
        XCTAssertEqual(section.duration, 2.0)
    }

    func testNestedSectionActivityStampsNotes() {
        let section = Section {
            Section { Note(pitch: 60, velocity: 90, startTime: 0, duration: 1.0) }
                .active(loops: [0, 1])
            Section { Note(pitch: 72, velocity: 90, startTime: 0, duration: 1.0) }
                .active(loops: 2...)
            Note(pitch: 40, velocity: 90, startTime: 0, duration: 1.0)
        }
        let gates = Dictionary(uniqueKeysWithValues: section.notes.map { ($0.pitch!, $0.activity) })
        XCTAssertEqual(gates[60], .set([0, 1]))
        XCTAssertEqual(gates[72], .range(from: 2, through: nil))
        XCTAssertNil(gates[40]!)
    }

    func testVariantsShareOneWindowInTrackLayout() {
        let track = Track(name: "t") {
            Section {
                Section { Note(pitch: 60, velocity: 90, startTime: 0, duration: 1.0) }
                    .active(loops: [0])
                Section { Note(pitch: 72, velocity: 90, startTime: 0, duration: 2.0) }
                    .active(loops: [1])
            }
            Section { Note(pitch: 67, velocity: 90, startTime: 0, duration: 1.0) }
        }
        let follower = track.sections[1].notes[0]
        XCTAssertEqual(follower.startTime, 2.0)
    }

    func testNestedSectionKeepsInnerTransformsAndStamps() {
        let section = Section {
            Section { "C4D4".duration(.n4) }.velocity(70).active(every: 2)
        }
        XCTAssertEqual(section.notes.map { $0.velocity }, [70, 70])
        XCTAssertEqual(section.notes.map { $0.activity }, [.every(2, offset: 0), .every(2, offset: 0)])
        XCTAssertNotNil(section.notes[0].sourceLine)
    }

    func testNoteActivityRoundTripsThroughJSON() throws {
        let session = Session {
            Track(name: "t") {
                Section {
                    Section { Note(pitch: 60, velocity: 90, startTime: 0, duration: 1.0) }
                        .active(loops: [3])
                }
            }
        }
        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(Session.self, from: data)
        XCTAssertEqual(decoded.tracks[0].sections[0].notes[0].activity, .set([3]))
    }

    func testSectionEqualityDetectsGateChange() {
        func build(_ loops: [Int]) -> Section {
            Section {
                Section { Note(pitch: 60, velocity: 90, startTime: 0, duration: 1.0) }
                    .active(loops: loops)
            }
        }
        XCTAssertEqual(build([0, 1]), build([0, 1]))
        XCTAssertNotEqual(build([0, 1]), build([0, 2]))
    }
}

class DominantNotationTests: XCTestCase {
    func testDomAliasParsesInBarNotation() {
        let section = Section { "Dm7 | Gdom7 | Cmaj7" }
        let g7 = section.notes.filter { $0.startTime == 1.0 }
        XCTAssertEqual(Set(g7.compactMap { $0.pitch.map { Int($0) % 12 } }), Set([7, 11, 2, 5]),
                       "Gdom7 should sound G B D F in the second bar")
    }

    func testUnprefixedG7DivergenceUnchanged() {
        let inline = SectionBuilder.parseNotation("G7 E")
        XCTAssertEqual(inline.first?.pitch, 91, "inline G7 stays the pitch G octave 7")

        let bar = SectionBuilder.parseNotation("G7 | Cmaj7")
        let bar1 = bar.filter { $0.startTime < 1.0 }
        XCTAssertEqual(Set(bar1.compactMap { $0.pitch.map { Int($0) % 12 } }), Set([7, 11, 2, 5]),
                       "bar-mode G7 stays G dominant 7")
    }

    func testApostropheForcesPitchInBarMode() {
        let notes = SectionBuilder.parseNotation("'G7 | Cmaj7")
        let bar1 = notes.filter { $0.startTime < 1.0 }
        XCTAssertEqual(bar1.compactMap { $0.pitch }, [91], "'G7 in a bar is the pitch G7, not a chord")
        XCTAssertEqual(bar1.first?.duration, 1.0)
    }

    func testBare13SuffixIsDominant13() {
        let expected = Set([4, 8, 11, 2, 6, 1])

        let inline = SectionBuilder.parseNotation("E13")
        XCTAssertEqual(Set(inline.compactMap { $0.pitch.map { Int($0) % 12 } }), expected,
                       "inline E13 should sound the dominant 13 chord")

        let bar = SectionBuilder.parseNotation("E13 | Cmaj7")
        let bar1 = bar.filter { $0.startTime < 1.0 }
        XCTAssertEqual(Set(bar1.compactMap { $0.pitch.map { Int($0) % 12 } }), expected,
                       "bar-mode E13 should sound the dominant 13 chord")
    }

    func testApostrophePitchInlineMatchesUnprefixed() {
        XCTAssertEqual(SectionBuilder.parseNotation("'C7 E").first?.pitch, 84)
        XCTAssertEqual(SectionBuilder.parseNotation("C7 E").first?.pitch, 84)
    }

    func testApostropheTokenStampCoversPrefix() {
        let notes = SectionBuilder.parseNotation("'G7 | Cmaj7")
        XCTAssertEqual(notes.first?.sourceOffset, 0, "stamp starts at the apostrophe")
        XCTAssertEqual(notes.first?.sourceLength, 3, "stamp includes the apostrophe")
    }

    func testBracketStackApostropheGivesPitches() {
        for expr in ["['C7 E]", "['C7 E] | Cmaj7"] {
            let notes = SectionBuilder.parseNotation(expr)
            let stack = notes.filter { $0.startTime == 0.0 }
            XCTAssertEqual(Set(stack.compactMap { $0.pitch }), Set([84, 64]), "for '\(expr)'")
        }
    }

    func testSingleElementBracketApostropheGivesPitch() {
        let notes = SectionBuilder.parseNotation("['C7] | Cmaj7")
        let bar1 = notes.filter { $0.startTime < 1.0 }
        XCTAssertEqual(bar1.compactMap { $0.pitch }, [84])
    }

    func testChordBracketWithForcedPitchElement() {
        let notes = SectionBuilder.parseNotation("[C7 'G8] | Cmaj7")
        let bar1 = notes.filter { $0.startTime < 1.0 }
        XCTAssertEqual(Set(bar1.compactMap { $0.pitch }), Set([60, 64, 67, 70, 103]))
    }

    func testApostropheSlideFusionStages() {
        let notes = SectionBuilder.parseNotation("'C7>'C8 E")
        XCTAssertEqual(notes.first?.pitch, 96, "fused note lands on C8")
        XCTAssertEqual(notes.first?.slides?.first?.from, 84, "attacks at C7")
    }

    func testApostrophePrefixSlideTarget() {
        let notes = SectionBuilder.parseNotation("G >'G7")
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes.first?.pitch, 91)
        XCTAssertEqual(notes.first?.slides?.first?.from, 67)
    }

    func testApostropheInNoteSetAndAdditive() {
        let set = SectionBuilder.parseNotation("('C7 E)")
        XCTAssertEqual(set.first?.pitchVariants, [84, 64])

        let add = SectionBuilder.parseNotation("Cm +'C7")
        let added = add.filter { $0.startTime == 1.0 }
        XCTAssertEqual(added.compactMap { $0.pitch }, [84])
    }

    func testApostropheUnknownWarnsAndRests() {
        let (notes, warnings) = SectionBuilder.parseNotationWithWarnings("'Xy")
        XCTAssertEqual(notes.count, 1)
        XCTAssertNil(notes.first?.pitch)
        XCTAssertEqual(warnings.count, 1)

        let (barNotes, barWarnings) = SectionBuilder.parseNotationWithWarnings("'Xy Cmaj7 | Fm7")
        XCTAssertEqual(barWarnings.count, 1)
        XCTAssertEqual(barNotes.filter { $0.startTime == 0.5 }.count, 4, "Cmaj7 keeps the second half-bar slot")
    }

    func testApostropheMidRunRejected() {
        for expr in ["CD'E7F", "CD'E7F | G"] {
            let (notes, warnings) = SectionBuilder.parseNotationWithWarnings(expr)
            XCTAssertEqual(warnings.count, 1, "for '\(expr)'")
            XCTAssertTrue(notes.filter { $0.startTime == 0.0 }.compactMap { $0.pitch }.isEmpty,
                          "no notes from the malformed run in '\(expr)'")
        }
    }
}

class ExtendedChordQualityTests: XCTestCase {
    func testNinthAndEleventhQualities() {
        XCTAssertEqual(Chord("C", .minor9).notes.compactMap { $0.pitch }, [60, 63, 67, 70, 74])
        XCTAssertEqual(Chord("C", .major9).notes.compactMap { $0.pitch }, [60, 64, 67, 71, 74])
        XCTAssertEqual(Chord("C", .dominant9).notes.compactMap { $0.pitch }, [60, 64, 67, 70, 74])
        XCTAssertEqual(Chord("C", .minor11).notes.compactMap { $0.pitch }, [60, 63, 67, 70, 74, 77])
        XCTAssertEqual(Chord("C", .dominant13).notes.compactMap { $0.pitch }, [60, 64, 67, 70, 74, 81])
    }

    func testNinthAliasesParse() {
        XCTAssertEqual(Chord("Cm9")?.notes.compactMap { $0.pitch }, [60, 63, 67, 70, 74])
        XCTAssertEqual(Chord("Cmaj9")?.notes.compactMap { $0.pitch }, [60, 64, 67, 71, 74])
        XCTAssertEqual(Chord("Cdom9")?.notes.compactMap { $0.pitch }, [60, 64, 67, 70, 74])
    }

    func testC9RemainsAPitchInNotation() {
        let notes = SectionBuilder.parseNotation("C9 E")
        XCTAssertEqual(notes.first?.pitch, 108)
    }

    func testExtendedQualityVoicings() {
        XCTAssertEqual(Chord("C", .sixNine).notes.compactMap { $0.pitch }, [60, 64, 67, 69, 74])
        XCTAssertEqual(Chord("C", .minorMajor7).notes.compactMap { $0.pitch }, [60, 63, 67, 71])
        XCTAssertEqual(Chord("C", .augmented7).notes.compactMap { $0.pitch }, [60, 64, 68, 70])
        XCTAssertEqual(Chord("C", .augmentedMajor7).notes.compactMap { $0.pitch }, [60, 64, 68, 71])
        XCTAssertEqual(Chord("C", .minorAdd9).notes.compactMap { $0.pitch }, [60, 63, 67, 74])
        XCTAssertEqual(Chord("C", .dominant11).notes.compactMap { $0.pitch }, [60, 67, 70, 74, 77])
        XCTAssertEqual(Chord("C", .major11).notes.compactMap { $0.pitch }, [60, 67, 71, 74, 77])
        XCTAssertEqual(Chord("C", .major13).notes.compactMap { $0.pitch }, [60, 64, 67, 71, 74, 81])
        XCTAssertEqual(Chord("C", .minor13).notes.compactMap { $0.pitch }, [60, 63, 67, 70, 74, 81])
        XCTAssertEqual(Chord("C", .dominant9sus4).notes.compactMap { $0.pitch }, [60, 65, 67, 70, 74])
    }

    func testExtendedQualityAliasesParse() {
        for spelling in ["C69", "C6/9", "C6add9"] {
            XCTAssertEqual(Chord(spelling)?.quality, .sixNine, spelling)
        }
        for spelling in ["CmMaj7", "CmM7", "CminMaj7"] {
            XCTAssertEqual(Chord(spelling)?.quality, .minorMajor7, spelling)
        }
        for spelling in ["Caug7", "C+7"] {
            XCTAssertEqual(Chord(spelling)?.quality, .augmented7, spelling)
        }
        for spelling in ["CaugMaj7", "CaugM7", "C+M7"] {
            XCTAssertEqual(Chord(spelling)?.quality, .augmentedMajor7, spelling)
        }
        for spelling in ["Cmadd9", "Cminadd9"] {
            XCTAssertEqual(Chord(spelling)?.quality, .minorAdd9, spelling)
        }
        for spelling in ["C11", "Cdom11"] {
            XCTAssertEqual(Chord(spelling)?.quality, .dominant11, spelling)
        }
        for spelling in ["Cmaj11", "CM11"] {
            XCTAssertEqual(Chord(spelling)?.quality, .major11, spelling)
        }
        for spelling in ["Cmaj13", "CM13"] {
            XCTAssertEqual(Chord(spelling)?.quality, .major13, spelling)
        }
        for spelling in ["Cm13", "Cmi13", "Cmin13"] {
            XCTAssertEqual(Chord(spelling)?.quality, .minor13, spelling)
        }
        for spelling in ["C9sus4", "Cdom9sus4"] {
            XCTAssertEqual(Chord(spelling)?.quality, .dominant9sus4, spelling)
        }
        XCTAssertEqual(Chord("Csus")?.quality, .sus4)
    }

    func testExtendedQualityNotationRoundTrips() {
        let qualities: [ChordQuality] = [.sixNine, .minorMajor7, .augmented7, .augmentedMajor7,
                                         .minorAdd9, .dominant11, .major11, .major13, .minor13,
                                         .dominant9sus4]
        for quality in qualities {
            XCTAssertEqual(ChordQuality(from: quality.notation), quality, quality.notation)
        }
    }

    func testExtendedQualitiesSoundInBarNotation() {
        let notes = SectionBuilder.parseNotation("C69 | CmMaj7 | C11 | Cmaj13")
        let bars = [0.0, 1.0, 2.0, 3.0].map { start in
            Set(notes.filter { $0.startTime >= start && $0.startTime < start + 1.0 }
                    .compactMap { $0.pitch.map { Int($0) % 12 } })
        }
        XCTAssertEqual(bars[0], Set([0, 4, 7, 9, 2]), "C69")
        XCTAssertEqual(bars[1], Set([0, 3, 7, 11]), "CmMaj7")
        XCTAssertEqual(bars[2], Set([0, 7, 10, 2, 5]), "C11")
        XCTAssertEqual(bars[3], Set([0, 4, 7, 11, 2, 9]), "Cmaj13")
    }
}

class SuspensionNotationTests: XCTestCase {
    func testHoldExtendsChord() {
        let notes = SectionBuilder.parseNotation("Cm - - -")
        XCTAssertEqual(notes.count, 3)
        XCTAssertTrue(notes.allSatisfy { $0.startTime == 0.0 && $0.duration == 4.0 })
    }

    func testAdditivePitchKeepsChordRinging() {
        let notes = SectionBuilder.parseNotation("Cm +D5")
        let chord = notes.filter { $0.startTime == 0.0 }
        XCTAssertEqual(chord.count, 3)
        XCTAssertTrue(chord.allSatisfy { $0.duration == 2.0 })
        let added = notes.filter { $0.startTime == 1.0 }
        XCTAssertEqual(added.compactMap { $0.pitch }, [62])
    }

    func testAdditiveExtensionResolvesAgainstHeldChord() {
        for expr in ["Cm +[9]", "Cm +9"] {
            let notes = SectionBuilder.parseNotation(expr)
            let added = notes.filter { $0.startTime == 1.0 }
            XCTAssertEqual(added.compactMap { $0.pitch }, [74], "ninth of held Cm for '\(expr)'")
        }
    }

    func testAdditiveChordAttacksOnlyNewPitches() {
        let notes = SectionBuilder.parseNotation("Cm +Cm9")
        let held = notes.filter { $0.startTime == 0.0 }
        XCTAssertEqual(Set(held.compactMap { $0.pitch }), Set([60, 63, 67]))
        XCTAssertTrue(held.allSatisfy { $0.duration == 2.0 })
        let added = notes.filter { $0.startTime >= 1.0 }
        XCTAssertEqual(Set(added.compactMap { $0.pitch }), Set([70, 74]),
                       "only the 7th and 9th re-attack when Cm resolves to Cm9")
    }

    func testAdditiveChordArpeggioStaggersOnlyAttackedNotes() {
        let notes = SectionBuilder.parseNotation("Cm +Cm9~0.15")
        let added = notes.filter { $0.startTime >= 1.0 }.sorted { $0.startTime < $1.startTime }
        XCTAssertEqual(added.compactMap { $0.pitch }, [70, 74])
        XCTAssertEqual(added[0].startTime, 1.0, accuracy: 1e-9)
        XCTAssertEqual(added[1].startTime, 1.075, accuracy: 1e-9)
    }

    func testCompactTies() {
        let notes = SectionBuilder.parseNotation("C-D-E")
        XCTAssertEqual(notes.map { $0.duration }, [2.0, 2.0, 1.0])
        XCTAssertEqual(notes.map { $0.startTime }, [0.0, 2.0, 4.0])
    }

    func testBarNotationRise() {
        let notes = SectionBuilder.parseNotation("Cm - +Cm7 +Cm9 |")
        let cm = notes.filter { $0.startTime == 0.0 }
        XCTAssertTrue(cm.allSatisfy { $0.duration == 1.0 })
        let seventh = notes.first { $0.pitch == 70 }
        XCTAssertEqual(seventh?.startTime, 0.5)
        XCTAssertEqual(seventh?.duration, 0.5)
        let ninth = notes.first { $0.pitch == 74 }
        XCTAssertEqual(ninth?.startTime, 0.75)
        XCTAssertEqual(ninth?.duration, 0.25)
    }

    func testTieSpansBarline() {
        let notes = SectionBuilder.parseNotation("Cm - - - | - - +[9] -")
        let cm = notes.filter { $0.startTime == 0.0 }
        XCTAssertTrue(cm.allSatisfy { $0.duration == 2.0 }, "held chord rings through both bars")
        let ninth = notes.first { $0.pitch == 74 }
        XCTAssertEqual(ninth?.startTime, 1.5)
        XCTAssertEqual(ninth?.duration, 0.5)
    }

    func testSpacesStillInsertRestsAroundPlainTokens() {
        let notes = SectionBuilder.parseNotation("C E")
        XCTAssertEqual(notes.map { $0.pitch }, [60, nil, 64])
    }

    func testAdditiveTokenCarriesSourceStamp() {
        let notes = SectionBuilder.parseNotation("Cm +[9]")
        let added = notes.first { $0.pitch == 74 }
        XCTAssertEqual(added?.sourceOffset, 3)
        XCTAssertEqual(added?.sourceLength, 4)
    }

    func testExplicitRestDoesNotDoubleWithSpaceRests() {
        let notes = SectionBuilder.parseNotation("C R E")
        XCTAssertEqual(notes.map { $0.pitch }, [60, nil, 64])
        XCTAssertEqual(notes.map { $0.startTime }, [0.0, 1.0, 2.0])
    }
}

class SlideNotationTests: XCTestCase {
    func testInfixSlideIsOneBentNote() {
        let notes = SectionBuilder.parseNotation("C>E")
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes[0].pitch, 64)
        XCTAssertEqual(notes[0].duration, 1.0)
        XCTAssertEqual(notes[0].slides, [SlideStep(from: 60, at: 0, over: 0)])
    }

    func testInfixSlideInsideCompactRun() {
        let notes = SectionBuilder.parseNotation("CD>EF")
        XCTAssertEqual(notes.map { $0.pitch }, [60, 64, 65])
        XCTAssertEqual(notes.map { $0.startTime }, [0.0, 1.0, 2.0])
        XCTAssertEqual(notes[1].slides, [SlideStep(from: 62, at: 0, over: 0)])
        XCTAssertNil(notes[0].slides)
    }

    func testMultiStageSlideDividesTheSlot() {
        let notes = SectionBuilder.parseNotation("C>D>E")
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes[0].pitch, 64)
        XCTAssertEqual(notes[0].slides, [SlideStep(from: 60, at: 0, over: 0),
                                         SlideStep(from: 62, at: 0.5, over: 0)])
    }

    func testFillAndTimedGlideSpecs() {
        XCTAssertEqual(SectionBuilder.parseNotation("C>=E")[0].slides,
                       [SlideStep(from: 60, at: 0, over: 1.0)])
        XCTAssertEqual(SectionBuilder.parseNotation("C>0.25E")[0].slides,
                       [SlideStep(from: 60, at: 0, over: 0.25)])
    }

    func testTieExtendsBentNote() {
        let notes = SectionBuilder.parseNotation("C>E-")
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes[0].duration, 2.0)
    }

    func testPrefixSlideContinuesPreviousNote() {
        let notes = SectionBuilder.parseNotation("C >E")
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes[0].pitch, 64)
        XCTAssertEqual(notes[0].startTime, 0.0)
        XCTAssertEqual(notes[0].duration, 2.0)
        XCTAssertEqual(notes[0].slides, [SlideStep(from: 60, at: 1.0, over: 0)])
    }

    func testPrefixSlideFillSpansTargetSlot() {
        let notes = SectionBuilder.parseNotation("C >=E")
        XCTAssertEqual(notes[0].slides, [SlideStep(from: 60, at: 1.0, over: 1.0)])
    }

    func testChainedPrefixSlides() {
        let notes = SectionBuilder.parseNotation("C >D >E")
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes[0].duration, 3.0)
        XCTAssertEqual(notes[0].slides, [SlideStep(from: 60, at: 1.0, over: 0),
                                         SlideStep(from: 62, at: 2.0, over: 0)])
    }

    func testChordSlideFusionPairsVoicesLowToHigh() {
        let notes = SectionBuilder.parseNotation("Am>Gmaj")
        XCTAssertEqual(notes.count, 3)
        let pairs = notes.map { ($0.slides![0].from, $0.pitch!) }.sorted { $0.0 < $1.0 }
        XCTAssertEqual(pairs.map { $0.0 }, [69, 72, 76])
        XCTAssertEqual(pairs.map { $0.1 }, [67, 71, 74])
        XCTAssertTrue(notes.allSatisfy { $0.duration == 1.0 })
    }

    func testChordPrefixSlideAttacksUnpairedVoices() {
        let notes = SectionBuilder.parseNotation("Am >Fmaj7")
        let sliding = notes.filter { $0.slides != nil }
        XCTAssertEqual(sliding.count, 3)
        XCTAssertTrue(sliding.allSatisfy { $0.startTime == 0.0 && $0.duration == 2.0 })
        let attacked = notes.filter { $0.slides == nil }
        XCTAssertEqual(attacked.map { $0.pitch }, [76])
        XCTAssertEqual(attacked[0].startTime, 1.0)
    }

    func testSlideAcrossBarline() {
        let notes = SectionBuilder.parseNotation("Cmaj | >Fmaj")
        XCTAssertEqual(notes.count, 3)
        XCTAssertTrue(notes.allSatisfy { $0.duration == 2.0 })
        XCTAssertTrue(notes.allSatisfy { $0.slides?.first?.at == 1.0 })
        XCTAssertEqual(Set(notes.compactMap { $0.pitch }), Set([65, 69, 72]))
    }

    func testInfixSlideInBarSlot() {
        let notes = SectionBuilder.parseNotation("C>E G | Cmaj")
        let bent = notes[0]
        XCTAssertEqual(bent.pitch, 64)
        XCTAssertEqual(bent.duration, 0.5)
        XCTAssertEqual(bent.slides, [SlideStep(from: 60, at: 0, over: 0)])
    }

    func testTransposeShiftsSlideSources() {
        let section = Section { "C>E".transpose(12) }
        XCTAssertEqual(section.notes[0].pitch, 76)
        XCTAssertEqual(section.notes[0].slides?.first?.from, 72)
    }

    func testSlidesRoundTripThroughJSON() throws {
        let session = Session {
            Track(name: "lead") { Section { "C >=E" } }
        }
        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(Session.self, from: data)
        XCTAssertEqual(decoded.tracks[0].sections[0].notes[0].slides,
                       [SlideStep(from: 60, at: 1.0, over: 1.0)])
    }

    func testSectionEqualityDistinguishesSlides() {
        let bent = SectionBuilder.parseNotation("C>E")
        var plain = bent
        plain[0].slides = nil
        XCTAssertNotEqual(Section(notes: bent), Section(notes: plain))
    }

    func testSectionTempoWarpsSlideTimes() {
        let section = Section { "C >0.5E" }.tempo(120)
        XCTAssertEqual(section.notes[0].slides?.first?.at, 2.0)
        XCTAssertEqual(section.notes[0].slides?.first?.over, 1.0)
    }

    func testDurationModifierScalesSlideTimes() {
        let section = Section { "C >E".duration(.n4) }
        XCTAssertEqual(section.notes.count, 1)
        XCTAssertEqual(section.notes[0].duration, 0.25)
        XCTAssertEqual(section.notes[0].slides, [SlideStep(from: 60, at: 0.125, over: 0)])
    }

    func testDurationModifierKeepsSlidesInsideCompactRunNotes() {
        let section = Section { "CD>EF".duration(.n8) }
        XCTAssertEqual(section.notes.map { $0.startTime }, [0.0, 0.125, 0.25])
        let bent = section.notes[1]
        XCTAssertEqual(bent.slides, [SlideStep(from: 62, at: 0, over: 0)])
        XCTAssertTrue(bent.slides!.allSatisfy { $0.at + $0.over <= bent.duration })
    }

    func testDurationModifierScalesMultiStageSlide() {
        let section = Section { "C>D>E".duration(.n4) }
        XCTAssertEqual(section.notes[0].slides, [SlideStep(from: 60, at: 0, over: 0),
                                                 SlideStep(from: 62, at: 0.125, over: 0)])
    }

    func testNoteDurationScalesSlideTimes() {
        let section = Section { "C >E" }.noteDuration(.n2)
        XCTAssertEqual(section.notes[0].duration, 0.5)
        XCTAssertEqual(section.notes[0].slides, [SlideStep(from: 60, at: 0.25, over: 0)])
    }

    func testSectionDurationsScalesSlideOver() {
        let section = Section { "C>0.5E G" }.durations(.n2)
        XCTAssertEqual(section.notes[0].duration, 0.5)
        XCTAssertEqual(section.notes[0].slides, [SlideStep(from: 60, at: 0, over: 0.25)])
        XCTAssertEqual(section.notes[1].duration, 1.0)
    }

    func testDurationRescaleKeepsDefaultGlideSentinel() {
        let section = Section { "C >E".duration(.n4) }.noteDuration(.n8)
        XCTAssertEqual(section.notes[0].slides?.first?.over, 0)
    }

    func testDurationModifierScalesFillGlide() {
        let section = Section { "C >=E".duration(.n4) }
        let step = section.notes[0].slides!.first!
        XCTAssertEqual(step.at, 0.125)
        XCTAssertEqual(step.over, 0.125)
        XCTAssertEqual(step.at + step.over, section.notes[0].duration)
    }

    // MARK: - Bracket slide targets (F20)

    func testPrefixSlideIntoExtensionBracket() {
        let (notes, warnings) = SectionBuilder.parseNotationWithWarnings("Cm >[Fm7 9]")
        XCTAssertTrue(warnings.isEmpty)
        let sliding = notes.filter { $0.slides != nil }.sorted { $0.slides![0].from < $1.slides![0].from }
        XCTAssertEqual(sliding.map { $0.slides![0].from }, [60, 63, 67])
        XCTAssertEqual(sliding.compactMap { $0.pitch }, [65, 68, 72])
        XCTAssertTrue(sliding.allSatisfy { $0.startTime == 0.0 && $0.duration == 2.0 })
        let attacked = notes.filter { $0.slides == nil }
        XCTAssertEqual(attacked.compactMap { $0.pitch }.sorted(), [75, 79])
        XCTAssertTrue(attacked.allSatisfy { $0.startTime == 1.0 && $0.duration == 1.0 })
    }

    func testPrefixSlideIntoCustomStack() {
        let notes = SectionBuilder.parseNotation("C >[E G]")
        XCTAssertEqual(notes.count, 2)
        let bent = notes.first { $0.slides != nil }!
        XCTAssertEqual(bent.pitch, 64)
        XCTAssertEqual(bent.duration, 2.0)
        XCTAssertEqual(bent.slides, [SlideStep(from: 60, at: 1.0, over: 0)])
        let attacked = notes.first { $0.slides == nil }!
        XCTAssertEqual(attacked.pitch, 67)
        XCTAssertEqual(attacked.startTime, 1.0)
    }

    func testCustomStackTargetWithPitchEscape() {
        let (notes, warnings) = SectionBuilder.parseNotationWithWarnings("C >[E G 'C7]")
        XCTAssertTrue(warnings.isEmpty)
        XCTAssertEqual(notes.compactMap { $0.pitch }.sorted(), [64, 67, 84])
        XCTAssertEqual(notes.filter { $0.slides != nil }.count, 1)
    }

    func testBracketSlideTargetInBarMode() {
        let notes = SectionBuilder.parseNotation("Cm | >[Fm7 9]")
        let sliding = notes.filter { $0.slides != nil }
        XCTAssertEqual(sliding.count, 3)
        XCTAssertTrue(sliding.allSatisfy { $0.duration == 2.0 && $0.slides![0].at == 1.0 })
        let attacked = notes.filter { $0.slides == nil }
        XCTAssertEqual(attacked.compactMap { $0.pitch }.sorted(), [75, 79])
        XCTAssertTrue(attacked.allSatisfy { $0.startTime == 1.0 })
    }

    func testInfixBracketFusionStaysOneToken() {
        let (notes, warnings) = SectionBuilder.parseNotationWithWarnings("[C E]>[D F]")
        XCTAssertTrue(warnings.isEmpty)
        XCTAssertEqual(notes.count, 2)
        let pairs = notes.map { ($0.slides![0].from, $0.pitch!) }.sorted { $0.0 < $1.0 }
        XCTAssertEqual(pairs.map { $0.0 }, [60, 64])
        XCTAssertEqual(pairs.map { $0.1 }, [62, 65])
        XCTAssertTrue(notes.allSatisfy { $0.startTime == 0.0 && $0.duration == 1.0 })
    }

    func testInfixBracketFusionInBarSlot() {
        let notes = SectionBuilder.parseNotation("[C E]>[D F] G | Cmaj")
        let bent = notes.filter { $0.slides != nil }
        XCTAssertEqual(bent.count, 2)
        XCTAssertTrue(bent.allSatisfy { $0.duration == 0.5 && $0.startTime == 0.0 })
        XCTAssertEqual(Set(bent.compactMap { $0.pitch }), Set([62, 65]))
    }

    func testNoteSetSlideTargetWarnsAndHolds() {
        let (notes, warnings) = SectionBuilder.parseNotationWithWarnings("Cm >(C Eb)")
        XCTAssertEqual(warnings.count, 1)
        XCTAssertTrue(warnings[0].message.contains("held instead"))
        XCTAssertEqual(warnings[0].offset, 3)
        XCTAssertEqual(notes.count, 3)
        XCTAssertTrue(notes.allSatisfy { $0.duration == 2.0 && $0.slides == nil })
    }

    func testArpeggiatedSlideTargetWarnsAndHolds() {
        let (notes, warnings) = SectionBuilder.parseNotationWithWarnings("Cm >~Fm")
        XCTAssertEqual(warnings.count, 1)
        XCTAssertTrue(warnings[0].message.contains("held instead"))
        XCTAssertEqual(notes.count, 3)
        XCTAssertTrue(notes.allSatisfy { $0.duration == 2.0 && $0.slides == nil })
    }

    func testBracketSlideTargetStampsAttackedNotes() {
        let notes = SectionBuilder.parseNotation("Cm >[Fm7 9]")
        let attacked = notes.filter { $0.slides == nil }
        XCTAssertEqual(attacked.count, 2)
        XCTAssertTrue(attacked.allSatisfy { $0.sourceOffset == 3 && $0.sourceLength == 8 })
    }
}

class ScoopAndFallNotationTests: XCTestCase {

    // MARK: - Scoops (signed interval names the source)

    func testSignedScoopFromBelow() {
        let (notes, warnings) = SectionBuilder.parseNotationWithWarnings(">-3E")
        XCTAssertTrue(warnings.isEmpty)
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes[0].pitch, 64)
        XCTAssertEqual(notes[0].duration, 1.0)
        XCTAssertEqual(notes[0].slides, [SlideStep(from: 61, at: 0, over: 0)])
    }

    func testSignedScoopFromAbove() {
        let notes = SectionBuilder.parseNotation(">+5E")
        XCTAssertEqual(notes[0].slides, [SlideStep(from: 69, at: 0, over: 0)])
    }

    func testScoopGlideSpecComesBeforeInterval() {
        XCTAssertEqual(SectionBuilder.parseNotation(">0.1-3E")[0].slides,
                       [SlideStep(from: 61, at: 0, over: 0.1)])
        XCTAssertEqual(SectionBuilder.parseNotation(">=-3E")[0].slides,
                       [SlideStep(from: 61, at: 0, over: 1.0)])
    }

    func testSignedChordScoopOffsetsEveryVoice() {
        let (notes, warnings) = SectionBuilder.parseNotationWithWarnings(">-3Am")
        XCTAssertTrue(warnings.isEmpty)
        XCTAssertEqual(notes.compactMap { $0.pitch }.sorted(), [69, 72, 76])
        for note in notes {
            XCTAssertEqual(note.slides, [SlideStep(from: note.pitch! - 3, at: 0, over: 0)])
        }
    }

    func testSignedScoopIgnoresHeldNotes() {
        let notes = SectionBuilder.parseNotation("C >-3E")
        XCTAssertEqual(notes.count, 2)
        XCTAssertEqual(notes[0].pitch, 60)
        XCTAssertEqual(notes[0].duration, 1.0, "held note must end at the slot, not glide")
        XCTAssertEqual(notes[1].slides, [SlideStep(from: 61, at: 0, over: 0)])
    }

    func testBareScoopAfterRestUsesLastSoundedPitch() {
        let (notes, warnings) = SectionBuilder.parseNotationWithWarnings("C R >E")
        XCTAssertTrue(warnings.isEmpty)
        let e = notes.last!
        XCTAssertEqual(e.pitch, 64)
        XCTAssertEqual(e.startTime, 2.0)
        XCTAssertEqual(e.slides, [SlideStep(from: 60, at: 0, over: 0)])
    }

    func testBareScoopInBarModeUsesLastSoundedPitch() {
        let notes = SectionBuilder.parseNotation("'C R | >E")
        let e = notes.last!
        XCTAssertEqual(e.pitch, 64)
        XCTAssertEqual(e.slides, [SlideStep(from: 60, at: 0, over: 0)])
    }

    func testBareScoopAtStringStartWarnsAndAttacksPlain() {
        let (notes, warnings) = SectionBuilder.parseNotationWithWarnings(">E")
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes[0].pitch, 64)
        XCTAssertNil(notes[0].slides)
        XCTAssertEqual(warnings.count, 1)
        XCTAssertEqual(warnings[0].offset, 0)
        XCTAssertEqual(warnings[0].length, 2)
        XCTAssertTrue(warnings[0].message.contains(">-3E"))
    }

    func testBareChordScoopWarnsAndAttacksPlain() {
        let (notes, warnings) = SectionBuilder.parseNotationWithWarnings("C R >Am")
        XCTAssertEqual(warnings.count, 1)
        XCTAssertTrue(warnings[0].message.contains("signed interval"))
        let chord = notes.filter { $0.startTime == 2.0 }
        XCTAssertEqual(chord.compactMap { $0.pitch }.sorted(), [69, 72, 76])
        XCTAssertTrue(chord.allSatisfy { $0.slides == nil })
    }

    // MARK: - Falls

    func testFallOnPitch() {
        let (notes, warnings) = SectionBuilder.parseNotationWithWarnings("C>-3")
        XCTAssertTrue(warnings.isEmpty)
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes[0].pitch, 60)
        XCTAssertEqual(notes[0].duration, 1.0)
        XCTAssertNil(notes[0].slides)
        XCTAssertEqual(notes[0].fall, Fall(semitones: -3, over: 0))
    }

    func testDefaultFallUnderscore() {
        XCTAssertEqual(SectionBuilder.parseNotation("C>_")[0].fall,
                       Fall(semitones: -5, over: 0))
    }

    func testDoitFallsUpward() {
        XCTAssertEqual(SectionBuilder.parseNotation("C>+2")[0].fall,
                       Fall(semitones: 2, over: 0))
    }

    func testFallWithExplicitLength() {
        XCTAssertEqual(SectionBuilder.parseNotation("C>0.25-3")[0].fall,
                       Fall(semitones: -3, over: 0.25))
    }

    func testChordFallHitsEveryVoice() {
        let notes = SectionBuilder.parseNotation("Am>-3")
        XCTAssertEqual(notes.count, 3)
        XCTAssertTrue(notes.allSatisfy { $0.fall == Fall(semitones: -3, over: 0) })
    }

    func testCompactRunFallLandsOnLastNote() {
        let notes = SectionBuilder.parseNotation("CDE>-3")
        XCTAssertEqual(notes.count, 3)
        XCTAssertNil(notes[0].fall)
        XCTAssertNil(notes[1].fall)
        XCTAssertEqual(notes[2].fall, Fall(semitones: -3, over: 0))
    }

    func testTieCarriesFallToHeldNote() {
        let notes = SectionBuilder.parseNotation("C ->-3")
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes[0].duration, 2.0)
        XCTAssertEqual(notes[0].fall, Fall(semitones: -3, over: 0))
    }

    func testSlideThenFall() {
        let notes = SectionBuilder.parseNotation("C>E>-3")
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes[0].pitch, 64)
        XCTAssertEqual(notes[0].slides, [SlideStep(from: 60, at: 0, over: 0)])
        XCTAssertEqual(notes[0].fall, Fall(semitones: -3, over: 0))
    }

    func testPrefixSlideWithFall() {
        let notes = SectionBuilder.parseNotation("C >E>-3")
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes[0].duration, 2.0)
        XCTAssertEqual(notes[0].slides, [SlideStep(from: 60, at: 1.0, over: 0)])
        XCTAssertEqual(notes[0].fall, Fall(semitones: -3, over: 0))
    }

    func testScoopComposesWithFall() {
        let notes = SectionBuilder.parseNotation(">-3E>_")
        XCTAssertEqual(notes[0].slides, [SlideStep(from: 61, at: 0, over: 0)])
        XCTAssertEqual(notes[0].fall, Fall(semitones: -5, over: 0))
    }

    func testFallInBarModeKeepsSlot() {
        let notes = SectionBuilder.parseNotation("C>-3 G | F")
        XCTAssertEqual(notes[0].pitch, 60)
        XCTAssertEqual(notes[0].duration, 0.5)
        XCTAssertEqual(notes[0].fall, Fall(semitones: -3, over: 0))
        XCTAssertNil(notes[1].fall)
    }

    func testTimedGlideTargetIsNotAFall() {
        let notes = SectionBuilder.parseNotation("C>3E")
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes[0].pitch, 64)
        XCTAssertNil(notes[0].fall)
    }

    // MARK: - Fall model plumbing

    func testFallRoundTripsThroughJSON() throws {
        let session = Session {
            Track(name: "lead") { Section { "C>0.25-3" } }
        }
        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(Session.self, from: data)
        XCTAssertEqual(decoded.tracks[0].sections[0].notes[0].fall,
                       Fall(semitones: -3, over: 0.25))
    }

    func testSectionEqualityDistinguishesFalls() {
        let falling = SectionBuilder.parseNotation("C>-3")
        var plain = falling
        plain[0].fall = nil
        XCTAssertNotEqual(Section(notes: falling), Section(notes: plain))
    }

    func testSectionTempoWarpsFallLength() {
        let section = Section { "C>0.25-3" }.tempo(120)
        XCTAssertEqual(section.notes[0].fall, Fall(semitones: -3, over: 0.5))
        let quick = Section { "C>_" }.tempo(120)
        XCTAssertEqual(quick.notes[0].fall, Fall(semitones: -5, over: 0))
    }

    func testDurationRescaleScalesFallLength() {
        let section = Section { "C>0.5-3".duration(.n2) }
        XCTAssertEqual(section.notes[0].duration, 0.5)
        XCTAssertEqual(section.notes[0].fall, Fall(semitones: -3, over: 0.25))
        let quick = Section { "C>_".duration(.n4) }.noteDuration(.n8)
        XCTAssertEqual(quick.notes[0].fall, Fall(semitones: -5, over: 0))
    }

    func testTransposeLeavesFallIntervalAlone() {
        let section = Section { "C>-3".transpose(12) }
        XCTAssertEqual(section.notes[0].pitch, 72)
        XCTAssertEqual(section.notes[0].fall, Fall(semitones: -3, over: 0))
    }
}

class SessionEqualityTests: XCTestCase {
    private func makeSession() -> Session {
        Session {
            Track(name: "piano") {
                Section { "CDEG" }
            }
        }
    }

    func testIdenticalSessionsAreEqual() {
        XCTAssertEqual(makeSession(), makeSession())
        XCTAssertEqual(makeSession().tempo(90), makeSession().tempo(90))
    }

    func testTempoChangeBreaksEquality() {
        XCTAssertNotEqual(makeSession().tempo(120), makeSession().tempo(90))
        XCTAssertNotEqual(makeSession(), makeSession().tempo(90))
    }

    func testTimeSignatureChangeBreaksEquality() {
        XCTAssertNotEqual(makeSession().timeSignature(3, 4), makeSession().timeSignature(4, 4))
        XCTAssertNotEqual(makeSession(), makeSession().timeSignature(3, 4))
    }

    func testLoopBarsAndVolumeBreakEquality() {
        XCTAssertNotEqual(makeSession().loopBars(2), makeSession().loopBars(4))
        XCTAssertNotEqual(makeSession().volume(0.5), makeSession().volume(1.0))
    }

    func testTrackNameChangeBreaksEquality() {
        let a = Session { Track(name: "piano") { Section { "C" } } }
        let b = Session { Track(name: "organ") { Section { "C" } } }
        XCTAssertNotEqual(a, b)
    }
}

class SamplerPatchTests: XCTestCase {
    func testSampledBuilderSetsConfig() {
        let patch = Synth.sampled("strings", soundFont: "Orchestra.sf2", program: 48, bank: 2).build()
        XCTAssertEqual(patch.name, "strings")
        XCTAssertEqual(patch.sampler, SamplerConfig(soundFont: "Orchestra.sf2", program: 48, bank: 2))
    }

    func testPianoAndGuitarPresetsAreSampled() {
        let piano = Synth.piano().build()
        XCTAssertEqual(piano.sampler?.program, 0)
        XCTAssertNil(piano.sampler?.soundFont)
        XCTAssertTrue(piano.reverb.enabled)

        let guitar = Synth.acousticGuitar().build()
        XCTAssertEqual(guitar.sampler?.program, 25)
    }

    func testOscillatorPresetsHaveNoSampler() {
        XCTAssertNil(Synth.guitar().build().sampler)
        XCTAssertNil(Synth.named("plain").build().sampler)
    }

    func testProgramIsClampedToMIDIRange() {
        XCTAssertEqual(SamplerConfig(program: 300).program, 127)
        XCTAssertEqual(SamplerConfig(program: -3).program, 0)
    }

    func testSamplerConfigSurvivesCodableRoundtrip() throws {
        let patch = Synth.sampled("piano", program: 0).reverb(enabled: true, mix: 0.2).build()
        let data = try JSONEncoder().encode(patch)
        let decoded = try JSONDecoder().decode(SynthPatch.self, from: data)
        XCTAssertEqual(decoded, patch)
        XCTAssertEqual(decoded.sampler, patch.sampler)
    }

    func testPatchWithoutSamplerKeyStillDecodes() throws {
        let legacy = Synth.named("old").build()
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as! [String: Any]
        json.removeValue(forKey: "sampler")
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(SynthPatch.self, from: data)
        XCTAssertNil(decoded.sampler)
    }

    func testSamplerChangeBreaksPatchEquality() {
        XCTAssertNotEqual(Synth.piano().build(), Synth.named("piano").reverb(enabled: true, mix: 0.2).volume(0.85).build())
        XCTAssertNotEqual(Synth.sampled("x", program: 0).build(), Synth.sampled("x", program: 25).build())
        XCTAssertEqual(Synth.piano().build(), Synth.piano().build())
    }
}

class AudioUnitPatchTests: XCTestCase {
    func testAudioUnitBuilderSetsConfig() {
        let patch = Synth.audioUnit("BBC Symphony Orchestra", preset: "Strings").build()
        XCTAssertEqual(patch.name, "BBC Symphony Orchestra")
        XCTAssertEqual(patch.audioUnit, AudioUnitConfig(name: "BBC Symphony Orchestra", preset: "Strings"))
        XCTAssertNil(patch.sampler)
    }

    func testOscillatorAndSampledPresetsHaveNoAudioUnit() {
        XCTAssertNil(Synth.guitar().build().audioUnit)
        XCTAssertNil(Synth.piano().build().audioUnit)
    }

    func testAudioUnitConfigSurvivesCodableRoundtrip() throws {
        let patch = Synth.audioUnit("Cardinal Synth").volume(0.7).build()
        let data = try JSONEncoder().encode(patch)
        let decoded = try JSONDecoder().decode(SynthPatch.self, from: data)
        XCTAssertEqual(decoded, patch)
        XCTAssertEqual(decoded.audioUnit, patch.audioUnit)
    }

    func testPatchWithoutAudioUnitKeyStillDecodes() throws {
        let legacy = Synth.named("old").build()
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as! [String: Any]
        json.removeValue(forKey: "audioUnit")
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(SynthPatch.self, from: data)
        XCTAssertNil(decoded.audioUnit)
    }

    func testAudioUnitChangeBreaksPatchEquality() {
        XCTAssertNotEqual(Synth.audioUnit("a").build(), Synth.audioUnit("b").build())
        XCTAssertNotEqual(Synth.audioUnit("a").build(), Synth.audioUnit("a", preset: "p").build())
        XCTAssertNotEqual(Synth.audioUnit("a").build(), Synth.named("a").build())
        XCTAssertEqual(Synth.audioUnit("a").build(), Synth.audioUnit("a").build())
    }
}

// MARK: - Parse warnings & rest substitution (F04)

class ParseWarningTests: XCTestCase {

    func testUnknownInlineTokenKeepsSubsequentNoteTimes() {
        let (notes, warnings) = SectionBuilder.parseNotationWithWarnings("C Gsus3 E")
        let pitched = notes.filter { $0.pitch != nil }
        XCTAssertEqual(pitched.count, 2)
        XCTAssertEqual(pitched[0].startTime, 0.0)
        XCTAssertEqual(pitched[1].startTime, 4.0)
        XCTAssertTrue(notes.contains { $0.pitch == nil && $0.startTime == 2.0 && $0.duration == 1.0 })
        XCTAssertEqual(warnings.count, 1)
    }

    func testWarningCarriesTokenOffsetAndLength() {
        let (_, warnings) = SectionBuilder.parseNotationWithWarnings("C Gsus3 E")
        XCTAssertEqual(warnings.count, 1)
        XCTAssertEqual(warnings[0].token, "Gsus3")
        XCTAssertEqual(warnings[0].offset, 2)
        XCTAssertEqual(warnings[0].length, 5)
        XCTAssertFalse(warnings[0].message.isEmpty)
    }

    func testUnknownBarTokenKeepsItsSlot() {
        let (notes, warnings) = SectionBuilder.parseNotationWithWarnings("Gsus3 C | E")
        let pitched = notes.filter { $0.pitch != nil }
        XCTAssertEqual(pitched.count, 2)
        XCTAssertEqual(pitched[0].pitch, pitchForNote["C"])
        XCTAssertEqual(pitched[0].startTime, 0.5)
        XCTAssertEqual(pitched[1].pitch, pitchForNote["E"])
        XCTAssertEqual(pitched[1].startTime, 1.0)
        XCTAssertTrue(notes.contains { $0.pitch == nil && $0.startTime == 0.0 && $0.duration == 0.5 })
        XCTAssertEqual(warnings.count, 1)
        XCTAssertEqual(warnings[0].token, "Gsus3")
        XCTAssertEqual(warnings[0].offset, 0)
        XCTAssertEqual(warnings[0].length, 5)
    }

    func testLegacyParseNotationMatchesWarningOverload() {
        let plain = SectionBuilder.parseNotation("C Gsus3 E")
        let (withWarnings, _) = SectionBuilder.parseNotationWithWarnings("C Gsus3 E")
        XCTAssertEqual(Section(notes: plain), Section(notes: withWarnings))
    }

    func testCleanParseYieldsNoWarnings() {
        XCTAssertTrue(SectionBuilder.parseNotationWithWarnings("C E G").warnings.isEmpty)
        XCTAssertTrue(SectionBuilder.parseNotationWithWarnings("Cm7 Fm7 | Bbmaj7").warnings.isEmpty)
        XCTAssertTrue(SectionBuilder.parseNotationWithWarnings("C>E G | >Fmaj").warnings.isEmpty)
    }

    func testFailedSlideTargetWarnsAndKeepsTiming() {
        let (notes, warnings) = SectionBuilder.parseNotationWithWarnings("C >Xy E")
        let pitched = notes.filter { $0.pitch != nil }
        XCTAssertEqual(pitched.count, 2)
        XCTAssertEqual(pitched[0].startTime, 0.0)
        XCTAssertEqual(pitched[0].duration, 1.0)
        XCTAssertNil(pitched[0].slides)
        XCTAssertEqual(pitched[1].startTime, 3.0)
        XCTAssertEqual(warnings.count, 1)
        XCTAssertEqual(warnings[0].token, ">Xy")
        XCTAssertEqual(warnings[0].offset, 2)
        XCTAssertEqual(warnings[0].length, 3)
    }

    func testSubstitutedRestCarriesSourceStamp() {
        let (notes, _) = SectionBuilder.parseNotationWithWarnings("Gsus3 C")
        let rest = notes.first { $0.pitch == nil }
        XCTAssertEqual(rest?.sourceOffset, 0)
        XCTAssertEqual(rest?.sourceLength, 5)
    }
}

class BarTimeSignatureTests: XCTestCase {

    override func tearDown() {
        SectionBuilder.timeSignature = .fourFour
        super.tearDown()
    }

    func testThreeFourBarSpansThreeQuarters() {
        SectionBuilder.timeSignature = .threeFour
        let section = Section { "Cm7 | Fm7" }
        XCTAssertEqual(section.notes.count, 8)
        let starts = Set(section.notes.map { $0.startTime }).sorted()
        XCTAssertEqual(starts, [0.0, 0.75])
        XCTAssertTrue(section.notes.allSatisfy { $0.duration == 0.75 })
        XCTAssertEqual(section.duration, 1.5)
    }

    func testSlotSubdivisionScalesWithMeter() {
        SectionBuilder.timeSignature = .threeFour
        let notes = SectionBuilder.parseNotation("Cm Fm | G")
        let starts = Set(notes.map { $0.startTime }).sorted()
        XCTAssertEqual(starts, [0.0, 0.375, 0.75])
        XCTAssertTrue(notes.filter { $0.startTime < 0.75 }.allSatisfy { $0.duration == 0.375 })
    }

    func testSixEightBarDuration() {
        SectionBuilder.timeSignature = .sixEight
        let notes = SectionBuilder.parseNotation("C | G")
        XCTAssertEqual(notes.count, 2)
        XCTAssertEqual(notes[0].duration, 0.75)
        XCTAssertEqual(notes[1].startTime, 0.75)
        XCTAssertEqual(notes[1].duration, 0.75)
    }

    func testFiveFourBarDuration() {
        SectionBuilder.timeSignature = .fiveFour
        let notes = SectionBuilder.parseNotation("C | G")
        XCTAssertEqual(notes[1].startTime, 1.25)
    }

    func testInlineNotationUnaffectedByMeter() {
        let baseline = SectionBuilder.parseNotation("C D E CDEF Am7")
        SectionBuilder.timeSignature = .threeFour
        let metered = SectionBuilder.parseNotation("C D E CDEF Am7")
        XCTAssertEqual(metered.map { $0.pitch }, baseline.map { $0.pitch })
        XCTAssertEqual(metered.map { $0.startTime }, baseline.map { $0.startTime })
        XCTAssertEqual(metered.map { $0.duration }, baseline.map { $0.duration })
    }
}

class NoteSetSourceSpanTests: XCTestCase {
    func testInlineNoteSetVariantSpans() {
        let notes = SectionBuilder.parseNotation("E (A C) G")
        guard let set = notes.first(where: { $0.pitchVariants != nil }) else {
            return XCTFail("no NoteSet note parsed")
        }
        XCTAssertEqual(set.pitchVariants, [69, 60])
        XCTAssertEqual(set.sourceOffset, 2)
        XCTAssertEqual(set.sourceLength, 5)
        XCTAssertEqual(set.variantSourceOffsets, [3, 5])
        XCTAssertEqual(set.variantSourceLengths, [1, 1])
    }

    func testMultiCharacterNamesInBarMode() {
        let notes = SectionBuilder.parseNotation("(A4 C#4) G | Am")
        let set = notes[0]
        XCTAssertEqual(set.pitchVariants, [57, 49])
        XCTAssertEqual(set.variantSourceOffsets, [1, 4])
        XCTAssertEqual(set.variantSourceLengths, [2, 3])
    }

    func testApostropheElementSpansIncludePrefix() {
        let set = SectionBuilder.parseNotation("('C7 E)")[0]
        XCTAssertEqual(set.pitchVariants, [84, 64])
        XCTAssertEqual(set.variantSourceOffsets, [1, 5])
        XCTAssertEqual(set.variantSourceLengths, [3, 1])
    }

    func testArpeggioPrefixShiftsVariantSpans() {
        let set = SectionBuilder.parseNotation("~~(A C)")[0]
        XCTAssertEqual(set.variantMode, .down)
        XCTAssertEqual(set.variantSourceOffsets, [3, 5])
        XCTAssertEqual(set.variantSourceLengths, [1, 1])
    }

    func testPlainNoteCarriesNoVariantSpans() {
        let note = SectionBuilder.parseNotation("E")[0]
        XCTAssertNil(note.variantSourceOffsets)
        XCTAssertNil(note.variantSourceLengths)
    }
}

class SlideSourceSpanTests: XCTestCase {
    func testExtendedSlideStampsContinuationSpans() {
        let notes = SectionBuilder.parseNotation("C >E >G")
        XCTAssertEqual(notes.count, 1)
        let note = notes[0]
        XCTAssertEqual(note.pitch, 67)
        XCTAssertEqual(note.slides?.map { $0.at }, [1.0, 2.0])
        XCTAssertEqual(note.sourceOffset, 0, "base span stays on the first token")
        XCTAssertEqual(note.sourceLength, 1)
        XCTAssertEqual(note.slideSourceOffsets, [2, 5])
        XCTAssertEqual(note.slideSourceLengths, [2, 2])
    }

    func testScoopStepsPadWithBaseSpanWhenExtended() {
        let notes = SectionBuilder.parseNotation("C R >E >G")
        guard let note = notes.first(where: { $0.pitch == 67 }) else {
            return XCTFail("no slide note parsed")
        }
        XCTAssertEqual(note.slides?.count, 2)
        XCTAssertEqual(note.sourceOffset, 4)
        XCTAssertEqual(note.slideSourceOffsets, [4, 7])
        XCTAssertEqual(note.slideSourceLengths, [2, 2])
    }

    func testFusedSlideTokenKeepsWholeTokenSpan() {
        let note = SectionBuilder.parseNotation("C>E")[0]
        XCTAssertEqual(note.sourceOffset, 0)
        XCTAssertEqual(note.sourceLength, 3)
        XCTAssertNil(note.slideSourceOffsets)
    }
}

class LegatoNotationTests: XCTestCase {
    func testSpacedHammerOnExtendsHeldNote() {
        let notes = SectionBuilder.parseNotation("C ^E")
        XCTAssertEqual(notes.count, 1)
        let note = notes[0]
        XCTAssertEqual(note.pitch, 64)
        XCTAssertEqual(note.duration, 2.0)
        XCTAssertEqual(note.slides?.count, 1)
        XCTAssertEqual(note.slides?.first?.from, 60)
        XCTAssertEqual(note.slides?.first?.at, 1.0)
        XCTAssertEqual(note.slides?.first?.carry, SectionBuilder.defaultLegatoCarry)
        XCTAssertEqual(note.slideSourceOffsets, [2], "highlight follows into the ^E token")
        XCTAssertEqual(note.slideSourceLengths, [2])
    }

    func testPullOffIsJustDownward() {
        let notes = SectionBuilder.parseNotation("E ^C")
        XCTAssertEqual(notes.first?.pitch, 60)
        XCTAssertEqual(notes.first?.slides?.first?.from, 64)
        XCTAssertNotNil(notes.first?.slides?.first?.carry)
    }

    func testCarrySpecClampedToUnit() {
        XCTAssertEqual(SectionBuilder.parseNotation("C ^0.7E").first?.slides?.first?.carry, 0.7)
        XCTAssertEqual(SectionBuilder.parseNotation("C ^7E").first?.slides?.first?.carry, 1.0)
    }

    func testFusedGraceHammerInOneSlot() {
        let notes = SectionBuilder.parseNotation("C^E G")
        let note = notes[0]
        XCTAssertEqual(note.pitch, 64)
        XCTAssertEqual(note.duration, 1.0)
        XCTAssertEqual(note.slides?.first?.from, 60)
        XCTAssertNotNil(note.slides?.first?.carry)
        XCTAssertEqual(note.slides?.first?.over, 0, "legato steps never glide")
    }

    func testCompactRunLegato() {
        let notes = SectionBuilder.parseNotation("CD^EF")
        XCTAssertEqual(notes.count, 3)
        XCTAssertEqual(notes[1].pitch, 64)
        XCTAssertEqual(notes[1].slides?.first?.from, 62)
        XCTAssertNotNil(notes[1].slides?.first?.carry)
        XCTAssertNil(notes[0].slides)
        XCTAssertNil(notes[2].slides)
    }

    func testChordLegatoPairsVoices() {
        let notes = SectionBuilder.parseNotation("Am^Gmaj")
        XCTAssertEqual(notes.count, 3)
        XCTAssertEqual(Set(notes.compactMap { $0.pitch }), Set([67, 71, 74]), "lands on G major")
        for note in notes {
            XCTAssertEqual(note.slides?.count, 1)
            XCTAssertNotNil(note.slides?.first?.carry)
        }
    }

    func testChainAppendsOneStepPerHammer() {
        let notes = SectionBuilder.parseNotation("C ^D ^E")
        XCTAssertEqual(notes.count, 1)
        let steps = notes[0].slides ?? []
        XCTAssertEqual(steps.map { $0.at }, [1.0, 2.0])
        XCTAssertEqual(steps.map { $0.from }, [60, 62])
        XCTAssertTrue(steps.allSatisfy { $0.carry != nil })
        XCTAssertEqual(notes[0].pitch, 64)
    }

    func testBarModeHammerAcrossBarline() {
        let notes = SectionBuilder.parseNotation("Cmaj | ^Fmaj")
        XCTAssertEqual(notes.count, 3)
        for note in notes {
            XCTAssertEqual(note.duration, 2.0, "held across both bars")
            XCTAssertEqual(note.slides?.first?.at, 1.0)
            XCTAssertNotNil(note.slides?.first?.carry)
        }
        XCTAssertEqual(Set(notes.compactMap { $0.pitch }), Set([65, 69, 72]), "lands on F major")
    }

    func testNoteSetTargetWarnsAndHolds() {
        let (notes, warnings) = SectionBuilder.parseNotationWithWarnings("C ^(D F)")
        XCTAssertEqual(warnings.count, 1)
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes[0].pitch, 60, "C held, not hammered")
        XCTAssertEqual(notes[0].duration, 2.0)
    }

    func testScoopIntervalNotSupportedForLegato() {
        let (notes, warnings) = SectionBuilder.parseNotationWithWarnings("C ^-3E")
        XCTAssertEqual(warnings.count, 1)
        XCTAssertTrue(warnings[0].message.contains("legato"))
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes[0].pitch, 60, "held note just ends")
    }
}

// MARK: - Section order (Componium mode)

class SectionOrderTests: XCTestCase {
    private var track: Track {
        Track(name: "t") {
            Section { "C D" }
            Section { "E F" }
        }
    }

    func testShuffleSectionsSetsTheOrder() {
        XCTAssertNil(track.sectionOrder, "as written by default")
        XCTAssertEqual(track.shuffleSections().sectionOrder, .shuffled)
    }

    func testModifiersPreserveTheOrder() {
        let shuffled = track.shuffleSections()
        XCTAssertEqual(shuffled.volume(0.5).sectionOrder, .shuffled)
        XCTAssertEqual(shuffled.tempo(90).sectionOrder, .shuffled)
        XCTAssertEqual(shuffled.active(every: 2).sectionOrder, .shuffled)
        XCTAssertEqual(shuffled.replacingSections(shuffled.sections).sectionOrder, .shuffled)
    }

    func testOrderAffectsEqualityAndSurvivesJSON() throws {
        let plain = track
        let shuffled = plain.shuffleSections()
        XCTAssertNotEqual(plain, shuffled, "switchSession must see the change")

        let decoded = try JSONDecoder().decode(
            Track.self, from: JSONEncoder().encode(shuffled))
        XCTAssertEqual(decoded.sectionOrder, .shuffled,
                       "the order rides the compile pipeline's JSON")
    }
}

class DiceTests: XCTestCase {

    // MARK: - The primitive

    func testRollIsStableAcrossCallsAndSpreadsAcrossPasses() {
        let salt = Dice.salt([1, 2, 3])
        for pass in 0..<8 {
            XCTAssertEqual(Dice.roll(salt: salt, loopIndex: pass, count: 6),
                           Dice.roll(salt: salt, loopIndex: pass, count: 6))
        }
        let rolls = (0..<60).map { Dice.roll(salt: salt, loopIndex: $0, count: 6) }
        XCTAssertTrue(rolls.allSatisfy { (0..<6).contains($0) })
        XCTAssertTrue(Set(rolls).count >= 5, "a six-sided die should reach most of its faces")
    }

    func testDifferentSaltsRollDifferently() {
        let a = Dice.salt([1]), b = Dice.salt([2])
        let rollsA = (0..<40).map { Dice.roll(salt: a, loopIndex: $0, count: 8) }
        let rollsB = (0..<40).map { Dice.roll(salt: b, loopIndex: $0, count: 8) }
        XCTAssertNotEqual(rollsA, rollsB, "two notes must not roll in lockstep")
    }

    func testPurposesDoNotRollInLockstep() {
        let base = Dice.salt([7, 7])
        let vel = (0..<40).map { Dice.roll(salt: Dice.salt(base, for: .velocity), loopIndex: $0, count: 8) }
        let dur = (0..<40).map { Dice.roll(salt: Dice.salt(base, for: .duration), loopIndex: $0, count: 8) }
        XCTAssertNotEqual(vel, dur, "a note's loudness and its length must roll independently")
    }

    func testRangeRollStaysInsideTheRange() {
        let salt = Dice.salt([42])
        let values = (0..<100).map { Dice.roll(salt: salt, loopIndex: $0, in: 70...110) }
        XCTAssertTrue(values.allSatisfy { (70...110).contains($0) })
        XCTAssertTrue(Set(values).count > 10, "a wide range should actually spread")
    }

    // MARK: - Rolled velocity

    func testVelocityRandomDrawsInsideTheRangeAndVaries() {
        let section = Section { "C D E F" }.velocity(random: 70...110)
        let notes = section.notes.filter { $0.pitch != nil }
        XCTAssertEqual(notes.first?.velocityChoices, 70...110)
        XCTAssertEqual(notes.first?.velocity, 90)

        var seen = Set<UInt32>()
        for pass in 0..<24 {
            for note in notes {
                let v = note.resolvedVelocity(loopIndex: pass)
                XCTAssertTrue((70...110).contains(v))
                seen.insert(v)
            }
        }
        XCTAssertTrue(seen.count > 5, "the part should breathe, not repeat one value")
    }

    func testVelocityRandomIsClampedToMIDIRange() {
        let section = Section { "C" }.velocity(random: 0...200)
        XCTAssertEqual(section.notes.first?.velocityChoices, 0...127)
    }

    func testANoteWithoutDiceKeepsItsWrittenVelocity() {
        let note = Section { "C" }.velocity(90).notes.first!
        XCTAssertEqual(note.resolvedVelocity(loopIndex: 5), 90)
    }

    // MARK: - Rolled durations

    func testDurationsRandomPicksFromTheChoicesWithoutMovingStarts() {
        let plain = Section { "C D E F" }
        let rolled = Section { "C D E F" }.durations(random: [.n8, .n4, .n2])
        XCTAssertEqual(rolled.notes.map(\.startTime), plain.notes.map(\.startTime),
                       "a rolled length must never shift the notes after it")

        let note = rolled.notes.first!
        var seen = Set<Double>()
        for pass in 0..<24 { seen.insert(note.resolvedDuration(loopIndex: pass)) }
        XCTAssertTrue(seen.isSubset(of: [.n8, .n4, .n2]))
        XCTAssertTrue(seen.count > 1, "the feel should change from pass to pass")
        XCTAssertEqual(note.longestDuration, .n2)
    }

    func testTempoTransformScalesTheDurationChoices() {
        let section = Section { "C" }.durations(random: [.n4, .n2]).tempo(120)
        let warp = 240.0 / 120.0
        XCTAssertEqual(section.notes.first?.durationChoices ?? [],
                       [Double.n4 * warp, Double.n2 * warp])
    }

    // MARK: - Rolled drum steps

    func testQuestionMarkStepSoundsOnSomePassesOnly() {
        let lane = DrumLane(.kick, "x..?")
        let notes = lane.notes(barDuration: 1.0).filter { $0.pitch != nil }
        XCTAssertEqual(notes.count, 2, "both the sure hit and the rolled one are written")

        let sure = notes[0], rolled = notes[1]
        XCTAssertNil(sure.dice)
        XCTAssertEqual(rolled.dice, .chance(0.5), "\"?\" is an even coin")
        XCTAssertTrue((0..<40).allSatisfy { sure.rolledOn(loopIndex: $0) }, "a plain hit always sounds")

        let passes = (0..<40).filter { rolled.rolledOn(loopIndex: $0) }
        XCTAssertFalse(passes.isEmpty, "the step must sound sometimes")
        XCTAssertTrue(passes.count < 40, "and sit out sometimes")
    }

    func testTwoRolledStepsInDifferentLanesAreIndependent() {
        let section = Section {
            Kick("?...")
            Snare("?...")
        }
        let kick  = section.notes.first { $0.pitch == DrumPiece.kick.midiKey }!
        let snare = section.notes.first { $0.pitch == DrumPiece.snare.midiKey }!
        let kickPasses  = (0..<40).map { kick.rolledOn(loopIndex: $0) }
        let snarePasses = (0..<40).map { snare.rolledOn(loopIndex: $0) }
        XCTAssertNotEqual(kickPasses, snarePasses)
    }

    func testRolledStepKeepsItsSourceStampAndVelocity() {
        let notes = DrumLane(.closedHat, "x.?.").notes(barDuration: 1.0).filter { $0.pitch != nil }
        XCTAssertEqual(notes.map { $0.sourceOffset }, [0, 2])
        XCTAssertEqual(notes.map { $0.velocity }, [DrumLane.hitVelocity, DrumLane.hitVelocity])
    }

    func testRolledStepObeysLaneVolume() {
        let note = DrumLane(.kick, "?").volume(0.5).notes(barDuration: 1.0).first { $0.pitch != nil }!
        XCTAssertEqual(note.velocity, 50)
        XCTAssertNotNil(note.dice)
    }

    // MARK: - Rolled section choice

    func testPickOnePlaysExactlyOneLayerPerPass() {
        let section = Section {
            "C4 C4"
            "E4 E4"
            "G4 G4"
        }.pickOne()

        for pass in 0..<24 {
            let sounding = Set(section.notes
                .filter { $0.pitch != nil && $0.rolledOn(loopIndex: pass) }
                .compactMap { $0.pitch })
            XCTAssertEqual(sounding.count, 1, "exactly one layer sounds on pass \(pass)")
        }
        var chosen = Set<UInt32>()
        for pass in 0..<40 {
            chosen.formUnion(section.notes.filter { $0.rolledOn(loopIndex: pass) }.compactMap { $0.pitch })
        }
        XCTAssertEqual(chosen, Set(section.notes.compactMap { $0.pitch }),
                       "every layer should come up over enough passes")
    }

    func testPickOneOnASingleLayerChangesNothing() {
        let section = Section { "C4" }.pickOne()
        XCTAssertNil(section.notes.first?.dice, "nothing to choose between")
    }

    func testTwoPickOneSectionsChooseIndependently() {
        let a = Section { "C4"; "D4" }.pickOne()
        let b = Section { "E4"; "F4" }.pickOne()
        let choiceA = (0..<40).map { pass in a.notes.firstIndex { $0.rolledOn(loopIndex: pass) } }
        let choiceB = (0..<40).map { pass in b.notes.firstIndex { $0.rolledOn(loopIndex: pass) } }
        XCTAssertNotEqual(choiceA, choiceB)
    }
}

class DiceInteractionTests: XCTestCase {

    func testStatedVelocityStopsTheRolling() {
        let section = Section { "C E G" }.velocity(random: 40...120).velocity(90)
        for note in section.notes where note.pitch != nil {
            XCTAssertNil(note.velocityChoices)
            XCTAssertEqual(note.resolvedVelocity(loopIndex: 7), 90)
        }
    }

    func testStatedDurationStopsTheRolling() {
        let section = Section { "C E" }.durations(random: [.n8, .n2]).noteDuration(.n4)
        for note in section.notes where note.pitch != nil {
            XCTAssertNil(note.durationChoices)
            XCTAssertEqual(note.resolvedDuration(loopIndex: 3), .n4)
        }
    }

    func testScalingMovesTheRolledRange() {
        let section = Section { "C" }.velocity(random: 40...120).velocity(scale: 0.5)
        XCTAssertEqual(section.notes.first?.velocityChoices, 20...60)
        for pass in 0..<20 {
            XCTAssertTrue((20...60).contains(section.notes[0].resolvedVelocity(loopIndex: pass)))
        }
    }

    func testChangingARolledStepCountsAsNewMusic() {
        XCTAssertNotEqual(Section { Kick("x..?") }, Section { Kick("x..x") })
        XCTAssertNotEqual(Section { "C E" }.velocity(random: 40...120),
                          Section { "C E" }.velocity(random: 41...120))
        XCTAssertEqual(Section { Kick("x..?") }, Section { Kick("x..?") })
    }
}

class GenerativeDiceTests: XCTestCase {

    func testSameSeedSameNumbersForever() {
        let a = Dice(seed: 7), b = Dice(seed: 7)
        for bar in 0..<4 {
            for step in 0..<12 {
                XCTAssertEqual(a(1, bar, step), b(1, bar, step))
            }
        }
    }

    func testAnotherSeedIsAnotherTake() {
        let a = Dice(seed: 7), b = Dice(seed: 8)
        let rollsA = (0..<48).map { a(1, $0 / 12, $0 % 12) }
        let rollsB = (0..<48).map { b(1, $0 / 12, $0 % 12) }
        XCTAssertNotEqual(rollsA, rollsB)
    }

    func testStreamsAndCoordinateOrderMatter() {
        let d = Dice(seed: 3)
        XCTAssertNotEqual((0..<32).map { d(1, 0, $0) }, (0..<32).map { d(2, 0, $0) })
        XCTAssertNotEqual(d(1, 2, 3), d(3, 2, 1), "coordinates are a position, not a bag")
    }

    func testValuesAreUniformEnoughToComposeWith() {
        let d = Dice(seed: 42)
        let values = (0..<2000).map { d(1, $0 / 16, $0 % 16) }
        XCTAssertTrue(values.allSatisfy { $0 >= 0 && $0 < 1 })
        let below = values.filter { $0 < 0.5 }.count
        XCTAssertTrue((850...1150).contains(below), "got \(below)/2000 below 0.5")
        let hits = (0..<2000).filter { d.chance(0.3, 2, $0 / 16, $0 % 16) }.count
        XCTAssertTrue((480...720).contains(hits), "got \(hits)/2000 hits")
    }

    func testPickAndIntStayInBounds() {
        let d = Dice(seed: 11)
        let options = ["x", "o", "."]
        for i in 0..<200 {
            XCTAssertTrue(options.contains(d.pick(options, 1, i) ?? ""))
            XCTAssertTrue((60...72).contains(d.int(in: 60...72, 2, i)))
        }
        XCTAssertNil(d.pick([Int](), 1))
        XCTAssertEqual(d.int(in: 5...5, 1), 5)
    }

    // MARK: - Grid

    func testGridShapeAndCoordinates() {
        let grid = Grid(bars: 2, beats: 4, subdivisions: 3) { $0.isDownbeat ? "x" : "." }
        XCTAssertEqual(grid, "x..x..x..x.. | x..x..x..x..")

        var seen: [(Int, Int, Int, Int, Int)] = []
        _ = Grid(bars: 2, beats: 2, subdivisions: 2) { s in
            seen.append((s.bar, s.beat, s.sub, s.step, s.index)); return "."
        }
        XCTAssertEqual(seen.count, 8)
        XCTAssertEqual(seen[0].0, 0); XCTAssertEqual(seen[0].3, 0); XCTAssertEqual(seen[0].4, 0)
        XCTAssertEqual(seen[3].1, 1, "step 3 of a 2×2 bar is beat 1")
        XCTAssertEqual(seen[3].2, 1, "…its second subdivision")
        XCTAssertEqual(seen[4].0, 1, "step 4 starts the next bar")
        XCTAssertEqual(seen[4].3, 0, "…back at step 0 within it")
        XCTAssertEqual(seen[4].4, 4, "…but index keeps counting")
    }

    func testGeneratedGridBecomesRealNotes() {
        let d = Dice(seed: 7)
        let ride = Grid(bars: 4, subdivisions: 3) { s in
            if s.isDownbeat { return s.beat % 2 == 0 ? "X" : "x" }
            if s.sub == 2 && s.beat % 2 == 1 { return "x" }
            return d.chance(0.3, 1, s.bar, s.step) ? "x" : "."
        }
        let section = Section { Lane(.ride, ride) }
        let notes = section.notes.filter { $0.pitch != nil }

        XCTAssertTrue(notes.allSatisfy { $0.pitch == DrumPiece.ride.midiKey })
        XCTAssertTrue(notes.count >= 24, "got \(notes.count)")
        XCTAssertEqual(section.duration, 4.0, "four bars, whatever the dice did")
        for note in notes {
            let within = (note.startTime * 12).rounded()
            XCTAssertEqual(note.startTime * 12, within, accuracy: 1e-9)
        }
    }

    func testRegeneratingWritesTheIdenticalPart() {
        func groove(seed: Int) -> String {
            let d = Dice(seed: seed)
            return Grid(bars: 8, subdivisions: 3) { s in
                d.chance(0.25, 2, s.bar, s.step) ? "x" : "."
            }
        }
        XCTAssertEqual(groove(seed: 7), groove(seed: 7))
        XCTAssertNotEqual(groove(seed: 7), groove(seed: 8))
    }

    func testGridEdgeCases() {
        XCTAssertEqual(Grid(bars: 0) { _ in "x" }, "")
        XCTAssertEqual(Grid(bars: 1, beats: 1, subdivisions: 1) { _ in "x" }, "x")
    }
}

class EvolvingPassTests: XCTestCase {

    private func kickPasses(_ grid: String, seed: UInt64 = 0, passes: Int = 40) -> [Bool] {
        let notes = Section { Kick(grid) }.notes.filter { $0.pitch != nil }
        return (0..<passes).flatMap { pass in
            notes.map { $0.rolledOn(loopIndex: pass, seed: seed) }
        }
    }

    // MARK: - Odds

    func testDigitStepsSoundAtTheirWrittenOdds() {
        for (character, expected) in [("1", 0.1), ("3", 0.3), ("5", 0.5), ("9", 0.9)] {
            let note = Section { Kick(character) }.notes.first { $0.pitch != nil }!
            let hits = (0..<2000).filter { note.rolledOn(loopIndex: $0) }.count
            let rate = Double(hits) / 2000
            XCTAssertEqual(rate, expected, accuracy: 0.05, "\"\(character)\" landed at \(rate)")
        }
    }

    func testQuestionMarkIsAnEvenCoin() {
        let hits = kickPasses("?", passes: 2000).filter { $0 }.count
        XCTAssertEqual(Double(hits) / 2000, 0.5, accuracy: 0.05)
    }

    func testZeroAndRestNeverSound() {
        XCTAssertTrue(Section { Kick("0") }.notes.filter { $0.pitch != nil }.isEmpty,
                      "0 is a rest, not a never-sounding note")
        XCTAssertTrue(Section { Kick(".") }.notes.filter { $0.pitch != nil }.isEmpty)
    }

    func testWrittenHitsAreNeverRolled() {
        XCTAssertTrue(kickPasses("x").allSatisfy { $0 })
        XCTAssertTrue(kickPasses("X").allSatisfy { $0 })
    }

    // MARK: - Evolving

    func testTheGrooveActuallyChangesFromPassToPass() {
        let lane = Section { Kick("x.3? 5.x2 | ?.5x 3?.x") }
        let notes = lane.notes.filter { $0.pitch != nil }
        let shapes = (0..<8).map { pass in
            notes.map { $0.rolledOn(loopIndex: pass) ? "x" : "." }.joined()
        }
        XCTAssertTrue(Set(shapes).count >= 5, "eight passes gave only \(Set(shapes).count) shapes")
    }

    func testEachPassIsTheSameEveryTimeItComesAround() {
        let a = kickPasses("x.3? 5.x2")
        let b = kickPasses("x.3? 5.x2")
        XCTAssertEqual(a, b)
    }

    // MARK: - The seed

    func testTheSeedChangesTheWholePerformance() {
        let take7 = kickPasses("x.3? 5.x2", seed: 7)
        let take8 = kickPasses("x.3? 5.x2", seed: 8)
        XCTAssertNotEqual(take7, take8, "another seed must be another performance")
        XCTAssertEqual(take7, kickPasses("x.3? 5.x2", seed: 7), "…and the same one every time")
    }

    func testNoSeedIsItsOwnTake() {
        XCTAssertEqual(kickPasses("x.3? 5.x2", seed: 0), kickPasses("x.3? 5.x2"))
    }

    func testSessionCarriesItsSeedThroughEveryModifier() {
        let session = Session { Track(name: "t") { Section { "C" } } }
            .seed(7).tempo(120).loopBars(2).loops(4).volume(0.8).timeSignature(3, 4)
        XCTAssertEqual(session.diceSeed, 7)
        XCTAssertEqual(session.diceSeedValue, 7)
        XCTAssertEqual(Session { Track(name: "t") { Section { "C" } } }.diceSeedValue, 0)
    }

    func testChangingTheSeedIsANewSession() {
        let base = Session { Track(name: "t") { Section { Kick("x..?") } } }
        XCTAssertNotEqual(base.seed(7), base.seed(8))
        XCTAssertEqual(base.seed(7), base.seed(7))
    }

    func testTheSeedReachesVelocityDurationAndPitch() {
        let note = Section { "C" }.velocity(random: 40...120).durations(random: [.n8, .n4, .n2]).notes[0]
        XCTAssertNotEqual((0..<24).map { note.resolvedVelocity(loopIndex: $0, seed: 7) },
                          (0..<24).map { note.resolvedVelocity(loopIndex: $0, seed: 8) })
        XCTAssertNotEqual((0..<24).map { note.resolvedDuration(loopIndex: $0, seed: 7) },
                          (0..<24).map { note.resolvedDuration(loopIndex: $0, seed: 8) })
    }

    // MARK: - Generated fields

    func testGeneratedFieldOfMaybesEvolves() {
        let d = Dice(seed: 7)
        let grid = Grid(bars: 4, subdivisions: 3) { s in
            if s.isDownbeat { return "x" }
            return d.chance(0.4, 1, s.bar, s.step) ? "4" : "."
        }
        let notes = Section { Lane(.ride, grid) }.notes.filter { $0.pitch != nil }
        let sure = notes.filter { $0.dice == nil }
        let maybes = notes.filter { $0.dice != nil }

        XCTAssertEqual(sure.count, 16, "four bars of four downbeats always sound")
        XCTAssertFalse(maybes.isEmpty, "the dice wrote no maybes at all")

        let counts = (0..<12).map { pass in notes.filter { $0.rolledOn(loopIndex: pass) }.count }
        XCTAssertTrue(Set(counts).count > 1, "every pass had the same number of hits")
        XCTAssertTrue(counts.allSatisfy { $0 >= sure.count }, "the spine never drops out")
    }
}

// MARK: - Mute

class MuteModifierTests: XCTestCase {

    private func lane(_ l: DrumLane) -> [Note] {
        SectionBuilder.buildExpression(l)
    }

    func testMutedLaneHasNoHits() {
        let sounding = lane(Kick("x... x... x... x..."))
        let silent   = lane(Kick("x... x... x... x...").mute())
        XCTAssertEqual(sounding.filter { $0.pitch != nil }.count, 4)
        XCTAssertTrue(silent.allSatisfy { $0.pitch == nil }, "a muted lane sounds nothing")
    }

    func testMutedLaneKeepsItsBars() {
        let written = Section { Kick("x... | .... | .... | ....") }
        let muted   = Section { Kick("x... | .... | .... | ....").mute() }
        XCTAssertEqual(muted.duration, written.duration, accuracy: 1e-9)
        XCTAssertGreaterThan(muted.duration, 0)
    }

    func testMuteIsAValueModifierLikeVolume() {
        let l = Kick("x...").volume(0.5).mute()
        XCTAssertTrue(l.muted)
        XCTAssertEqual(l.volumeScale, 0.5, accuracy: 1e-9, "mute doesn't drop the lane's level")
        XCTAssertFalse(Kick("x...").mute().mute(false).muted)
    }

    func testMutedSectionKeepsItsNotesAndSlot() {
        let written = Section { "C4 D4 E4 F4" }
        let section = Section { "C4 D4 E4 F4" }.mute()
        XCTAssertTrue(section.isMuted)
        XCTAssertEqual(section.notes.count, written.notes.count)
        XCTAssertEqual(section.duration, written.duration, accuracy: 1e-9)
    }

    func testMuteSurvivesSectionTransforms() {
        XCTAssertTrue(Section { "C4 D4" }.mute().velocity(90).isMuted)
        XCTAssertTrue(Section { "C4 D4" }.mute().tempo(90).isMuted)
        XCTAssertTrue(Section { "C4 D4" }.mute().active(loops: 1...2).isMuted)
    }

    func testMuteIsPartOfSectionEquality() {
        XCTAssertNotEqual(Section { "C4 D4" }, Section { "C4 D4" }.mute())
        XCTAssertEqual(Section { "C4 D4" }.mute(), Section { "C4 D4" }.mute())
    }

    func testMutedNestedLayerIsSilentOnEveryPass() {
        let section = Section {
            "C4 C4"
            Section { "G5 G5" }.mute()
        }
        let muted = section.notes.filter { $0.pitch == .G5 }
        XCTAssertFalse(muted.isEmpty, "the layer's notes are still there")
        for pass in 0..<8 {
            XCTAssertTrue(muted.allSatisfy { $0.activity?.isActive(loopIndex: pass) == false },
                          "the muted layer sounded on pass \(pass)")
        }
        XCTAssertTrue(section.notes.filter { $0.pitch == .C4 }
            .allSatisfy { $0.activity == nil }, "its sibling is untouched")
    }
}

// MARK: - Cleanup-audit regressions (C06, C08, C10, C13)

class ArpeggioRootPatternTests: XCTestCase {
    private func strumOrder(_ chord: Chord) -> [Pitch?] {
        chord.notes.sorted { $0.startTime < $1.startTime }.map { $0.pitch }
    }

    func testRootFirstLeadsWithTheRootOnAnInversion() {
        let chord = Chord("C", .major)
        chord.notes = [Note(pitch: .E4, duration: 1), Note(pitch: .G4, duration: 1),
                       Note(pitch: .C5, duration: 1)]
        XCTAssertEqual(strumOrder(chord.arpeggio(.rootFirst, delay: 0.1)), [.C5, .E4, .G4])
    }

    func testRootLastClosesWithTheRootOnAnInversion() {
        let chord = Chord("C", .major)
        chord.notes = [Note(pitch: .G4, duration: 1), Note(pitch: .C5, duration: 1),
                       Note(pitch: .E5, duration: 1)]
        XCTAssertEqual(strumOrder(chord.arpeggio(.rootLast, delay: 0.1)), [.G4, .E5, .C5])
    }

    func testRootPatternsMatchUpOnARootPositionChord() {
        XCTAssertEqual(strumOrder(Chord("C", .major).arpeggio(.rootFirst, delay: 0.1)),
                       strumOrder(Chord("C", .major).arpeggio(.up, delay: 0.1)))
    }

    func testEmptyChordSurvivesEveryArpeggioPattern() {
        let patterns: [ArpeggioPattern] = [.up, .down, .random, .alternating,
                                           .rootFirst, .rootLast, .custom([0, 1])]
        for pattern in patterns {
            let chord = Chord("C", .major)
            chord.notes = []
            XCTAssertTrue(chord.arpeggio(pattern).notes.isEmpty)
        }
    }

    func testRandomArpeggioIsDeterministic() {
        let a = strumOrder(Chord("C", .major7).arpeggio(.random, delay: 0.1))
        let b = strumOrder(Chord("C", .major7).arpeggio(.random, delay: 0.1))
        XCTAssertEqual(a, b)
    }
}

class DeterministicGenerationTests: XCTestCase {
    func testSectionRandomWritesTheSameMelodyEveryBuild() {
        let pool: [UInt32] = [60, 62, 64, 65, 67, 69, 71]
        let a = Section.random(from: pool, count: 16)
        let b = Section.random(from: pool, count: 16)
        XCTAssertEqual(a.notes.map { $0.pitch }, b.notes.map { $0.pitch })
        XCTAssertTrue(a.notes.allSatisfy { note in note.pitch.map(pool.contains) == true })
    }

    func testSectionRandomFromAnEmptyPoolFallsBackToMiddleC() {
        XCTAssertEqual(Section.random(from: [UInt32](), count: 2).notes.map { $0.pitch }, [60, 60])
    }

    func testNaturalHumanizationIsTheSameEveryBuild() {
        let a = Chord("C", .major7).natural().notes.map { $0.velocity }
        let b = Chord("C", .major7).natural().notes.map { $0.velocity }
        XCTAssertEqual(a, b)
        XCTAssertTrue(a.allSatisfy { $0 >= 80 && $0 <= 127 })
    }

    func testRandomStackArpeggioIsTheSameEveryParse() {
        let a = SectionBuilder.parseNotation("?[C E G]").map { ($0.pitch, $0.startTime) }
        let b = SectionBuilder.parseNotation("?[C E G]").map { ($0.pitch, $0.startTime) }
        XCTAssertEqual(a.count, 3)
        for (x, y) in zip(a, b) {
            XCTAssertEqual(x.0, y.0)
            XCTAssertEqual(x.1, y.1, accuracy: 1e-12)
        }
    }
}

class ProgressionValueSemanticsTests: XCTestCase {
    func testVelocitiesLeavesTheReceiverIntact() {
        let p = Progression("I - IV", for: .C)
        let modified = p.velocities(90)
        XCTAssertTrue(modified.chords[0].notes.allSatisfy { $0.velocity == 90 })
        XCTAssertTrue(p.chords[0].notes.allSatisfy { $0.velocity == 100 },
                      "the receiver's chords were mutated through the copy")
    }

    func testDurationsLeavesTheReceiverIntact() {
        let p = Progression("I - IV", for: .C)
        _ = p.durations(2.0)
        XCTAssertTrue(p.chords[0].notes.allSatisfy { $0.duration == 1.0 })
    }

    func testQualitiesLeavesTheReceiverIntact() {
        let p = Progression("I - IV", for: .C)
        _ = p.qualities(.minor)
        XCTAssertEqual(p.chords[0].quality, .major)
        XCTAssertEqual(p.chords[0].notes.compactMap { $0.pitch }, [60, 64, 67])
    }
}

class EffectiveLoopCountVariantTests: XCTestCase {
    func testNestedVariantGatesDriveTheLoopCount() {
        let session = Session {
            Track(name: "Lead") {
                Section {
                    Section { "C D E F" }.active(loops: [0])
                    Section { "G A B C6" }.active(loops: [3])
                }
            }
        }
        XCTAssertEqual(session.effectiveLoopCount, 4)
    }

    func testNestedVariantEveryGateAsksForOneFullCycle() {
        let session = Session {
            Track(name: "Lead") {
                Section {
                    Section { "C D" }.active(every: 3)
                }
            }
        }
        XCTAssertEqual(session.effectiveLoopCount, 3)
    }
}

class ArpeggioOnRunGroupTests: XCTestCase {

    func testTheMarkIsReportedRatherThanDropped() {
        for notation in ["| ~{Cm7 Fm7} - - |", "| ~~{1 2 3} - |", "| ?{Cm Fm} - |"] {
            let parsed = SectionBuilder.parseNotationWithWarnings(notation)
            XCTAssertTrue(parsed.warnings.contains { $0.message.contains("run group has no effect") },
                          "\(notation) warned \(parsed.warnings.map(\.message))")
        }
    }

    func testAnUnmarkedGroupIsSilent() {
        XCTAssertEqual(SectionBuilder.parseNotationWithWarnings("| {Cm7 Fm7} - - |").warnings.count, 0)
        XCTAssertEqual(SectionBuilder.parseNotationWithWarnings("{1 2 3}").warnings.count, 0)
    }

    func testTheGroupStillSoundsTheSame() {
        let marked = SectionBuilder.parseNotation("| ~{Cm7 Fm7} - - |")
        let plain = SectionBuilder.parseNotation("| {Cm7 Fm7} - - |")
        XCTAssertEqual(marked.map(\.startTime), plain.map(\.startTime))
        XCTAssertEqual(marked.compactMap(\.pitch), plain.compactMap(\.pitch))
    }

    func testInlineNotationReportsTheMarkItsOwnWay() {
        for notation in ["~{C E G}", "{C E G}~", "C {D E}~ G"] {
            let parsed = SectionBuilder.parseNotationWithWarnings(notation)
            XCTAssertFalse(parsed.warnings.isEmpty, "\(notation) said nothing")
        }
    }
}

// MARK: - Chord note sets

class ChordNoteSetTests: XCTestCase {

    private func members(of notation: String, pass: Int) -> [Pitch] {
        SectionBuilder.parseNotation(notation)
            .filter { $0.pitch != nil && $0.rolledOn(loopIndex: pass) }
            .compactMap(\.pitch).sorted()
    }

    func testAStackedMemberStaysWhole() {
        let notes = SectionBuilder.parseNotationWithWarnings("| ?([1 3 5] [4 6 1']) - |")
        XCTAssertEqual(notes.warnings.map(\.message), [])
        XCTAssertEqual(notes.notes.compactMap(\.pitch).sorted(), [60, 64, 65, 67, 69, 72])
        for note in notes.notes {
            guard case .noteSet(_, let count, let mode) = note.dice else {
                return XCTFail("a chord set member is not gated: \(note.dice as Any)")
            }
            XCTAssertEqual(count, 2)
            XCTAssertEqual(mode, .random)
        }
    }

    func testExactlyOneChordSoundsOnAnyPass() {
        for pass in 0..<12 {
            let sounding = members(of: "| ?([1 3 5] [4 6 1']) - |", pass: pass)
            XCTAssertTrue(sounding == [60, 64, 67] || sounding == [65, 69, 72],
                          "pass \(pass) sounded \(sounding)")
        }
    }

    func testChordsOnDegreesWorkAsMembers() {
        for pass in 0..<8 {
            let sounding = members(of: "| ?(1maj 6m) - |", pass: pass)
            XCTAssertTrue(sounding == [60, 64, 67] || sounding == [69, 72, 76],
                          "pass \(pass) sounded \(sounding)")
        }
    }

    func testTheCyclingModesWalkChordsToo() {
        let up = (0..<4).map { members(of: "| ([1 3 5] [4 6 1']) - |", pass: $0) }
        XCTAssertEqual(up, [[60, 64, 67], [65, 69, 72], [60, 64, 67], [65, 69, 72]])
        let down = (0..<4).map { members(of: "| ~~([1 3 5] [4 6 1']) - |", pass: $0) }
        XCTAssertEqual(down, [[65, 69, 72], [60, 64, 67], [65, 69, 72], [60, 64, 67]])
    }

    func testAChordSetAndAPitchSetChooseTheSameMember() {
        for pass in 0..<8 {
            let pitch = SectionBuilder.parseNotation("| ?(1 4) - |")[0]
            let chose = (pitch.variantMode ?? .up).variantIndex(
                loopIndex: pass, count: 2,
                salt: Dice.salt(pitch.diceSalt, for: .pitch))
            let chord = members(of: "| ?(1 4) - |", pass: pass)
            _ = chord
            XCTAssertTrue(chose == 0 || chose == 1)
        }
    }

    func testASingleMemberSoundsAsItself() {
        let notes = SectionBuilder.parseNotation("| ?([1 3 5]) - |")
        XCTAssertEqual(notes.compactMap(\.pitch).sorted(), [60, 64, 67])
        XCTAssertNil(notes.first?.dice)
    }

    func testAMemberThatIsNotANoteIsReportedOnce() {
        let parsed = SectionBuilder.parseNotationWithWarnings("| ?(1maj nonsense) - |")
        XCTAssertEqual(parsed.warnings.count, 1, parsed.warnings.map(\.message).joined(separator: " / "))
        XCTAssertTrue(parsed.warnings[0].message.contains("dropped from the set"))
        XCTAssertEqual(parsed.notes.compactMap(\.pitch).sorted(), [60, 64, 67])
    }

    func testEveryToneOfAChordSetSharesOneDie() {
        let notes = SectionBuilder.parseNotation("| ?(1maj 6m) - |").filter { $0.pitch != nil }
        XCTAssertEqual(Set(notes.map(\.diceSalt)).count, 1)
        XCTAssertTrue(notes.allSatisfy { $0.pitchVariants == nil })
    }

    func testTwoChordSetsInOneBarRollSeparately() {
        let notation = "| ?(1maj 6m) ?(1maj 6m) |"
        let salts = Set(SectionBuilder.parseNotation(notation).filter { $0.pitch != nil }.map(\.diceSalt))
        XCTAssertEqual(salts.count, 2, "both tokens roll one die")
    }

    func testAPlainPitchSetIsUnchanged() {
        let note = SectionBuilder.parseNotation("| ?(1 3 5) - |")[0]
        XCTAssertEqual(note.pitchVariants, [60, 64, 67])
        XCTAssertEqual(note.variantMode, .random)
        XCTAssertNil(note.dice)
    }

    func testChordSetsWorkInInlineNotationToo() {
        let notes = SectionBuilder.parseNotationWithWarnings("?([1 3 5] [4 6 1'])")
        XCTAssertEqual(notes.warnings.map(\.message), [])
        XCTAssertEqual(notes.notes.compactMap(\.pitch).sorted(), [60, 64, 65, 67, 69, 72])
    }
}

// MARK: - Generators (Phrase, Markov)

class PhraseTests: XCTestCase {

    func testPhraseLaysOutOneTokenPerSlot() {
        let phrase = Phrase(bars: 2, beats: 4, subdivisions: 1) { s in
            s.isDownbeat ? String(s.beat + 1) : "-"
        }
        XCTAssertEqual(phrase, "| 1 2 3 4 | 1 2 3 4 |")
    }

    func testSubdivisionsSplitTheBeat() {
        let phrase = Phrase(bars: 1, subdivisions: 2) { s in s.sub == 0 ? "1" : "5" }
        XCTAssertEqual(phrase, "| 1 5 1 5 1 5 1 5 |")
    }

    func testStepCoordinatesMatchGrid() {
        var seen: [(Int, Int, Int, Int, Int)] = []
        _ = Phrase(bars: 2, beats: 2, subdivisions: 3) { s in
            seen.append((s.bar, s.beat, s.sub, s.step, s.index)); return "1"
        }
        XCTAssertEqual(seen.count, 12)
        XCTAssertEqual(seen[0].0, 0); XCTAssertEqual(seen[0].1, 0); XCTAssertEqual(seen[0].2, 0)
        XCTAssertEqual(seen[11].0, 1); XCTAssertEqual(seen[11].1, 1); XCTAssertEqual(seen[11].2, 2)
        XCTAssertEqual(seen[11].3, 5); XCTAssertEqual(seen[11].4, 11)
    }

    func testEmptyAnswerIsARestSoTheSlotKeepsItsTime() {
        let phrase = Phrase(bars: 1) { s in s.beat == 0 ? "1" : "" }
        XCTAssertEqual(phrase, "| 1 R R R |")
        let notes = SectionBuilder.parseNotation(phrase)
        XCTAssertEqual(notes.count, 4)
        XCTAssertEqual(notes.filter { $0.pitch == nil }.count, 3)
    }

    func testSeveralTokensInOneSlotBecomeARunGroup() {
        let phrase = Phrase(bars: 1) { s in s.beat == 1 ? "1 2 3" : "5" }
        XCTAssertEqual(phrase, "| 5 {1 2 3} 5 5 |")
        let notes = SectionBuilder.parseNotation(phrase)
        XCTAssertEqual(notes.count, 6)
        XCTAssertEqual(notes[1].duration, 0.25 / 3, accuracy: 1e-9)
        XCTAssertEqual(notes[4].startTime, 0.5, accuracy: 1e-9)
    }

    func testAGroupedTokenIsNotWrappedAgain() {
        XCTAssertEqual(Phrase(bars: 1) { _ in "[1 3 5]" }, "| [1 3 5] [1 3 5] [1 3 5] [1 3 5] |")
        XCTAssertEqual(Phrase(bars: 1) { _ in "{1 2}" }, "| {1 2} {1 2} {1 2} {1 2} |")
    }

    func testOneBarStillReadsAsABar() {
        let notes = SectionBuilder.parseNotation(Phrase(bars: 1) { _ in "1" })
        XCTAssertEqual(notes.count, 4)
        XCTAssertEqual(notes.map(\.startTime), [0, 0.25, 0.5, 0.75])
    }

    func testNoBarsIsEmpty() {
        XCTAssertEqual(Phrase(bars: 0) { _ in "1" }, "")
    }
}

class MarkovTests: XCTestCase {

    let source = "1 2 3 5 | 5 3 2 1 | 1 3 5 3 - - | 5 6 5 3 | 3 2 1 - | 1 5 3 2"

    func testTheSameSeedWritesTheSameMelody() {
        let m = Markov(from: source, order: 2)
        XCTAssertEqual(m.melody(bars: 4, seed: 7), m.melody(bars: 4, seed: 7))
    }

    func testADifferentSeedIsADifferentTake() {
        let m = Markov(from: source, order: 1)
        XCTAssertNotEqual(m.melody(bars: 4, seed: 7), m.melody(bars: 4, seed: 8))
    }

    func testItLaysOutTheBarsItIsAskedFor() {
        let m = Markov(from: source, order: 1)
        let melody = m.melody(bars: 4, seed: 3)
        XCTAssertEqual(melody.filter { $0 == "|" }.count, 5)
        for bar in Markov.bars(of: melody) where !bar.isEmpty {
            XCTAssertEqual(bar.count, 4)
        }
    }

    func testSlotsOverrideTheLearnedBarLength() {
        let m = Markov(from: source, order: 1)
        XCTAssertEqual(m.slots, 4)
        for bar in Markov.bars(of: m.melody(bars: 2, slots: 8, seed: 3)) where !bar.isEmpty {
            XCTAssertEqual(bar.count, 8)
        }
    }

    func testWhatItWritesAlwaysParses() {
        for order in 1...3 {
            let m = Markov(from: source, order: order)
            for seed in 0...5 {
                let melody = m.melody(bars: 4, seed: seed, open: 0.4)
                let parsed = SectionBuilder.parseNotationWithWarnings(melody)
                XCTAssertEqual(parsed.warnings.map(\.message), [], "order \(order) seed \(seed): \(melody)")
                XCTAssertFalse(parsed.notes.isEmpty)
            }
        }
    }

    func testOnlyTokensSeenInTheSourceAreWritten() {
        let m = Markov(from: source, order: 1)
        let vocabulary = Set(Markov.bars(of: source).flatMap { $0 })
        for bar in Markov.bars(of: m.melody(bars: 8, seed: 4)) {
            for token in bar { XCTAssertTrue(vocabulary.contains(token), token) }
        }
    }

    func testItDoesNotGetStuckOnTheLastTokenOfTheSource() {
        let m = Markov(from: "1 2 3 5 | 5 3 2 1 | 1 3 5 3 - -", order: 2)
        let melody = m.melody(bars: 8, seed: 7)
        let tail = Markov.bars(of: melody).suffix(4).flatMap { $0 }
        XCTAssertFalse(tail.allSatisfy { $0 == "-" }, melody)
    }

    // The source is read straight through and its ending opens another phrase,
    // so the last token leaves for each distinct way a bar of the source opened
    // — not, as the circular reading had it, for the first token and nothing
    // else. Here "2" ends the source and 5 opens the second bar.
    func testAnEndingOpensAnyBarTheSourceOpened() {
        let m = Markov(from: "1 2 3 | 5 4 2", order: 1)
        XCTAssertTrue(m.chart.contains("2: [3, 1, 5]"), m.chart)
        let written = (0..<40).map { m.melody(bars: 4, slots: 3, seed: $0) }
        XCTAssertTrue(written.contains { $0.contains("2 5") },
                      "the ending never opened the bar that begins on 5")
    }

    // The other half of that rule: a source whose bars all open the same way
    // has exactly one way to begin again, so it reads as it always did.
    func testOneWayOfOpeningLeavesTheChainAsItWas() {
        XCTAssertTrue(Markov(from: "1 2 1 2 | 1 2 1 3", order: 1).chart.contains("3: [1]"))
    }

    func testHigherOrderStaysCloserToTheSource() {
        let vocabulary = Markov.bars(of: source).flatMap { $0 }
        let written = Markov.bars(of: Markov(from: source, order: 3).melody(bars: 3, seed: 1)).flatMap { $0 }
        let doubled = vocabulary + vocabulary
        let run = written.prefix(8)
        XCTAssertTrue((0..<vocabulary.count).contains { start in
            Array(doubled[start..<(start + run.count)]) == Array(run)
        }, "\(run)")
    }

    func testAStatedTableIsWeightedByRepeats() {
        let m = Markov([1: [2, 2, 2, 3], 2: [1], 3: [1]], start: 1)
        let tokens = Markov.bars(of: m.melody(bars: 16, seed: 5)).flatMap { $0 }
        let after1 = zip(tokens, tokens.dropFirst()).filter { $0.0 == "1" }.map(\.1)
        XCTAssertGreaterThan(after1.filter { $0 == "2" }.count, after1.filter { $0 == "3" }.count)
    }

    func testAStateWithNoSuccessorsIsDropped() {
        let m = Markov([1: [2], 2: [], 3: [1]])
        let openings = Set((0..<40).map { seed in
            Markov.bars(of: m.melody(bars: 1, seed: seed)).flatMap { $0 }.first
        })
        XCTAssertEqual(openings, ["1", "3"])
    }

    func testSlotsChangesTheBarringNotTheTokens() {
        let m = Markov(from: source, order: 2)
        XCTAssertEqual(Markov.bars(of: m.melody(bars: 4, slots: 4, seed: 7)).flatMap { $0 },
                       Markov.bars(of: m.melody(bars: 2, slots: 8, seed: 7)).flatMap { $0 })
        XCTAssertEqual(SectionBuilder.parseNotation(m.melody(bars: 1, slots: 4, seed: 7))[0].duration, 0.25)
        XCTAssertEqual(SectionBuilder.parseNotation(m.melody(bars: 1, slots: 8, seed: 7))[0].duration, 0.125)
    }

    func testAMelodyOpensWhereABarOfTheSourceOpens() {
        let m = Markov(from: source, order: 2)
        let sourceOpenings = Set(Markov.bars(of: source).filter { $0.count >= 2 }
                                                        .map { Array($0.prefix(2)) })
        for seed in 0..<20 {
            let opening = Array(Markov.bars(of: m.melody(bars: 2, seed: seed)).flatMap { $0 }.prefix(2))
            XCTAssertTrue(sourceOpenings.contains(opening), "\(opening)")
        }
    }

    func testTheQuotedOpeningNeverOpens() {
        for order in 1...3 {
            let m = Markov(from: source, order: order)
            for seed in 0..<20 {
                let head = Markov.bars(of: m.melody(bars: 4, seed: seed, open: 1.0)).flatMap { $0 }.prefix(order)
                XCTAssertFalse(head.contains { $0.hasPrefix("?(") }, "order \(order) seed \(seed)")
            }
        }
    }

    func testAnOpenSetHoldsTwoOrThreeNotes() {
        let m = Markov(from: source, order: 1)
        for seed in 0..<20 {
            for token in Markov.bars(of: m.melody(bars: 4, seed: seed, open: 1.0)).flatMap({ $0 })
            where token.hasPrefix("?(") {
                let members = token.dropFirst(2).dropLast().split(separator: " ")
                XCTAssertTrue((2...3).contains(members.count), token)
                XCTAssertEqual(Set(members).count, members.count, "a set repeats a note: \(token)")
            }
        }
    }

    func testStatedWeightsAreTheProportions() {
        let m = Markov([1: [2, 2, 2, 3], 2: [1], 3: [1]], start: 1)
        var twos = 0, threes = 0
        for seed in 0..<50 {
            let tokens = Markov.bars(of: m.melody(bars: 8, seed: seed)).flatMap { $0 }
            for (from, to) in zip(tokens, tokens.dropFirst()) where from == "1" {
                if to == "2" { twos += 1 } else if to == "3" { threes += 1 }
            }
        }
        XCTAssertEqual(Double(twos) / Double(twos + threes), 0.75, accuracy: 0.06)
    }

    func testAStatedTableCanUseAnyToken() {
        let m = Markov(["[1 3 5]": ["2m7"], "2m7": ["-"], "-": ["[1 3 5]"]], start: "[1 3 5]")
        XCTAssertEqual(m.melody(bars: 2, seed: 0), "| [1 3 5] 2m7 - [1 3 5] | 2m7 - [1 3 5] 2m7 |")
    }

    func testOpenSlotsBecomeRandomNoteSets() {
        let m = Markov(from: source, order: 1)
        let melody = m.melody(bars: 4, seed: 2, open: 1.0)
        XCTAssertTrue(melody.contains("?("), melody)
        let notes = SectionBuilder.parseNotation(melody)
        let sets = notes.filter { $0.pitchVariants != nil }
        XCTAssertFalse(sets.isEmpty)
        for note in sets {
            XCTAssertEqual(note.variantMode, .random)
            XCTAssertGreaterThan(note.pitchVariants?.count ?? 0, 1)
        }
    }

    func testOpenIsARisingCeilingNotAProportion() {
        let m = Markov(from: source, order: 1)
        func share(_ open: Double) -> Double {
            var sets = 0, total = 0
            for seed in 0..<40 {
                let tokens = Markov.bars(of: m.melody(bars: 4, seed: seed, open: open)).flatMap { $0 }
                sets += tokens.filter { $0.hasPrefix("?(") }.count
                total += tokens.count
            }
            return Double(sets) / Double(total)
        }
        let (quarter, half, all) = (share(0.25), share(0.5), share(1.0))
        XCTAssertEqual(share(0), 0)
        XCTAssertLessThan(quarter, 0.25)
        XCTAssertLessThan(half, 0.5)
        XCTAssertLessThan(all, 1.0)
        XCTAssertLessThan(quarter, half)
        XCTAssertLessThan(half, all)
        XCTAssertGreaterThan(all, 0.5, "this source should branch at most slots")
    }

    func testAClosedMelodyHasNoSets() {
        let m = Markov(from: source, order: 1)
        XCTAssertFalse(m.melody(bars: 4, seed: 2).contains("?("))
    }

    func testOnlySoundingTokensGoIntoASet() {
        let m = Markov(from: "1 - R 1 [1 3 5] 1 2m7 1 3 1 >5", order: 1)
        let melody = m.melody(bars: 8, seed: 1, open: 1.0)
        var sawAChord = false
        for token in Markov.bars(of: melody).flatMap({ $0 }) where token.hasPrefix("?(") {
            for member in SectionBuilder.barTokens(String(token.dropFirst(2).dropLast())) {
                XCTAssertTrue(NotationToken.canJoinSet(member), "\(member) in \(token)")
                if member.hasPrefix("[") || member == "2m7" { sawAChord = true }
            }
        }
        XCTAssertTrue(sawAChord, "chords should be eligible now")
        XCTAssertFalse(NotationToken.canJoinSet("-"))
        XCTAssertFalse(NotationToken.canJoinSet("R"))
        XCTAssertFalse(NotationToken.canJoinSet(">5"))
        XCTAssertTrue(NotationToken.canJoinSet("[1 3 5]"))
        XCTAssertTrue(NotationToken.canJoinSet("2m7"))
        XCTAssertTrue(NotationToken.canJoinSet("Cmaj7"))
        XCTAssertTrue(NotationToken.canJoinSet("1'"))
    }

    func testTheChainStillWalksThroughAnOpenSlot() {
        let m = Markov(from: source, order: 2)
        XCTAssertEqual(m.melody(bars: 4, seed: 6, open: 1.0).contains("?("), true)
        let open = Markov.bars(of: m.melody(bars: 4, seed: 6, open: 1.0)).flatMap { $0 }
        let closed = Markov.bars(of: m.melody(bars: 4, seed: 6)).flatMap { $0 }
        XCTAssertEqual(open.count, closed.count)
        for (o, c) in zip(open, closed) {
            XCTAssertEqual(o.hasPrefix("?(") ? String(o.dropFirst(2).prefix(while: { $0 != " " && $0 != ")" })) : o, c)
        }
    }

    func testAnEmptySourceStillWritesBars() {
        let m = Markov(from: "", order: 2)
        XCTAssertEqual(m.melody(bars: 2, seed: 1), "| R R R R | R R R R |")
    }

    func testNoBarsIsEmpty() {
        XCTAssertEqual(Markov(from: source).melody(bars: 0, seed: 1), "")
    }

    func testItLearnsTheSourcesBarLength() {
        XCTAssertEqual(Markov(from: "1 2 | 3 5 | 1 2").slots, 2)
        XCTAssertEqual(Markov(from: "1 2 3 5 6 7").slots, 6)
    }

    // MARK: The chart a phrase derives

    private func tableLines(_ chart: String) -> String {
        chart.split(separator: "\n").filter { !$0.hasPrefix("//") }.joined(separator: "\n")
    }

    private var pastedSource: Markov {
        Markov(["-": ["-", "5", "1"],
                "1": ["2", "1", "3", "-", "5"],
                "2": ["3", "1", "1", "1", "5", "3"],
                "3": ["5", "2", "5", "-", "3", "2", "2"],
                "5": ["5", "3", "3", "6", "3", "3"],
                "6": ["5"]], start: "1", slots: 4)
    }

    func testAPhrasePrintsTheChartItCounted() {
        XCTAssertEqual(Markov(from: "1 2 1 2 | 1 2 1 3", order: 1).chart,
                       "Markov([1: [2, 2, 2, 3],\n"
                       + "        2: [1, 1, 1],\n"
                       + "        3: [1]], start: 1, slots: 4)")
    }

    func testPastingTheChartGivesTheSameChain() {
        XCTAssertEqual(tableLines(pastedSource.chart),
                       tableLines(Markov(from: source, order: 1).chart))
    }

    func testOnlyTheOpeningIsLostInAChart() {
        let learned = Markov(from: source, order: 1)
        XCTAssertTrue(learned.chart.split(separator: "\n")
            .contains { $0.hasPrefix("// the phrase also opened on") },
                      "several openings should be disclosed")
        var compared = 0
        for seed in 0..<200 {
            let a = learned.melody(bars: 4, seed: seed)
            let b = pastedSource.melody(bars: 4, seed: seed)
            guard Markov.bars(of: a).flatMap({ $0 }).first
                    == Markov.bars(of: b).flatMap({ $0 }).first else { continue }
            compared += 1
            XCTAssertEqual(a, b, "seed \(seed)")
        }
        XCTAssertGreaterThan(compared, 20, "no seeds shared an opening — the check proved nothing")
    }

    func testAHigherOrderChainSaysWhatThePrintLoses() {
        let chart = Markov(from: "1 2 3 | 3 2 1", order: 2).chart
        XCTAssertTrue(chart.contains("order 2 chain, printed as its order-1 chart"), chart)
        XCTAssertEqual(tableLines(chart), tableLines(Markov(from: "1 2 3 | 3 2 1", order: 1).chart))
    }

    func testDegreesPrintAsNumbersAndAnythingElseAsStrings() {
        XCTAssertTrue(Markov(from: "1 2 | 3 1").chart.contains("Markov([1: ["))
        XCTAssertTrue(Markov(from: "1 - | 3 1").chart.contains("Markov([\"-\": ["))
        XCTAssertTrue(Markov(from: "1maj - | 6m -").chart.contains("\"1maj\""))
    }

    func testAStatedChartPrintsBackAsItself() {
        XCTAssertEqual(Markov([1: [2, 2, 2, 3], 2: [1, 1, 1], 3: [1]], start: 1, slots: 4).chart,
                       "Markov([1: [2, 2, 2, 3],\n"
                       + "        2: [1, 1, 1],\n"
                       + "        3: [1]], start: 1, slots: 4)")
    }

    func testAnEmptyChainPrintsSomethingThatCompiles() {
        let chart = Markov(from: "", order: 1).chart
        XCTAssertTrue(chart.contains("Markov([Int: [Int]](), slots:"), chart)
        XCTAssertFalse(chart.contains("[:]"), "a bare [:] is ambiguous between the two constructors")
    }

    func testTokensAreReadTheWayTheParserReadsThem() {
        XCTAssertEqual(SectionBuilder.barTokens("[1 3 5] ?(1 3) {1 2 3} - R"),
                       ["[1 3 5]", "?(1 3)", "{1 2 3}", "-", "R"])
    }
}

class AutomationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        SectionBuilder.timeSignature = .fourFour
    }
    override func tearDown() {
        SectionBuilder.timeSignature = .fourFour
        super.tearDown()
    }

    // MARK: the four units

    func testTheFourUnitsSpellTheSameCurve() {
        let bars = Section { "| 1 3 5 5 | 5 3 2 1 |" }
        XCTAssertEqual(bars.duration, 2.0, "two 4/4 bars are two whole notes")

        let over  = bars.automate(.volume, over:  [0: 0.2, 1: 1.0])
        let at    = bars.automate(.volume, at:    [0: 0.2, 2.0: 1.0])
        let inBars = bars.automate(.volume, bars: [0: 0.2, 2: 1.0])
        let beats = bars.automate(.volume, beats: [0: 0.2, 8: 1.0])

        XCTAssertEqual(over, at)
        XCTAssertEqual(at, inBars)
        XCTAssertEqual(inBars, beats)
    }

    func testBarsAndBeatsAgreeInAnOddMeter() {
        SectionBuilder.timeSignature = TimeSignature(7, 8)
        let section = Section { "| 1 2 3 4 5 6 7 |" }
        XCTAssertEqual(section.duration, 7.0 / 8.0, accuracy: 1e-9)
        XCTAssertEqual(section.automate(.volume, bars:  [0: 0.5, 1: 1.0]),
                       section.automate(.volume, beats: [0: 0.5, 7: 1.0]))
    }

    func testUnitsAreReadUnderTheMeterTheStringIsParsedUnder() {
        SectionBuilder.timeSignature = .threeFour
        let section = Section { "| 1 2 3 |" }
        XCTAssertEqual(section.duration, 0.75, accuracy: 1e-9)
        XCTAssertEqual(section.automate(.volume, bars: [0: 0.5, 1: 1.0]),
                       section.automate(.volume, at:   [0: 0.5, 0.75: 1.0]))
    }

    // MARK: the curve itself

    func testBreakpointsAreSortedAtIngestWhateverTheLiteralOrder() {
        let curve = AutomationCurve(target: .volume, points: [
            AutomationPoint(time: 1, value: 1),
            AutomationPoint(time: 0, value: 0),
            AutomationPoint(time: 0.5, value: 0.25),
        ])
        XCTAssertEqual(curve.points.map(\.time), [0, 0.5, 1])
    }

    func testValueHoldsOutsideAndInterpolatesBetween() {
        let curve = AutomationCurve.make(.volume, [0: 0.0, 1: 1.0], timeScale: 1)!
        XCTAssertEqual(curve.value(at: -5), 0.0, accuracy: 1e-9)
        XCTAssertEqual(curve.value(at: 0.25), 0.25, accuracy: 1e-9)
        XCTAssertEqual(curve.value(at: 99), 1.0, accuracy: 1e-9)
    }

    func testMaxValueIsExactAtAnyWindowWidth() {
        let curve = AutomationCurve(target: .volume, points: [
            AutomationPoint(time: 0, value: 0),
            AutomationPoint(time: 0.5, value: 1),
            AutomationPoint(time: 1, value: 0),
        ])
        XCTAssertEqual(curve.maxValue(from: 0, to: 1), 1.0, accuracy: 1e-9)
        XCTAssertEqual(curve.maxValue(from: 0.4, to: 0.6), 1.0, accuracy: 1e-9)
        XCTAssertEqual(curve.maxValue(from: 0, to: 0.25), 0.5, accuracy: 1e-9)
    }

    func testEmptyBreakpointsChangeNothing() {
        let plain = Section { "C D E F" }
        XCTAssertEqual(plain.automate(.volume, over: [:]), plain)
        XCTAssertNil(AutomationCurve.make(.volume, [:], timeScale: 1))
    }

    func testValuesAreHeldToTheirTargetsRange() {
        XCTAssertEqual(AutomationCurve.make(.volume, [0: 4.0], timeScale: 1)!.points[0].value, 1.0,
                       "a boost is what .velocity(scale:) is for")
        XCTAssertEqual(AutomationCurve.make(.volume, [0: -1.0], timeScale: 1)!.points[0].value, 0.0)
        XCTAssertEqual(AutomationCurve.make(.cutoff, [0: 6000], timeScale: 1)!.points[0].value, 6000,
                       "cutoff is Hz, not a fraction")
    }

    // MARK: slicing onto the notes

    func testAFlatCurveLeavesTheNoteAlone() {
        let section = Section { "C D E F" }.automate(.volume, over: [0: 1.0, 1: 1.0])
        XCTAssertTrue(section.notes.allSatisfy { $0.automation == nil },
                      "a note the fade never moves must stay off the chunked render path")
    }

    func testAConstantSliceIsASinglePoint() {
        let section = Section { "C D E F" }.automate(.volume, over: [0: 0.5, 1: 0.5])
        let curve = section.notes.first?.automation?.first
        XCTAssertEqual(curve?.points.count, 1,
                       "one breakpoint at t=0 keeps the voice on its fast path")
        XCTAssertEqual(curve?.points.first?.value ?? 0, 0.5, accuracy: 1e-9)
    }

    func testEachNoteKeepsItsOwnStretchOfTheFade() {
        let section = Section { "| C - - - | C - - - |" }.automate(.volume, over: [0: 0.0, 1: 1.0])
        let sounding = section.notes.filter { $0.pitch != nil }
        XCTAssertEqual(sounding.count, 2)

        let first = sounding[0].automation?.first
        XCTAssertEqual(first?.value(at: 0) ?? -1, 0.0, accuracy: 1e-9)
        XCTAssertEqual(first?.value(at: 1.0) ?? -1, 0.5, accuracy: 1e-9,
                       "the first bar's note ends halfway up the fade")

        let second = sounding[1].automation?.first
        XCTAssertEqual(second?.value(at: 0) ?? -1, 0.5, accuracy: 1e-9)
        XCTAssertEqual(second?.value(at: 1.0) ?? -1, 1.0, accuracy: 1e-9)
    }

    func testANoteStraddlingABreakpointKeepsIt() {
        let section = Section { "| C - - - |" }.automate(.volume, over: [0: 0, 0.5: 1, 1: 0])
        let curve = section.notes.first(where: { $0.pitch != nil })?.automation?.first
        XCTAssertEqual(curve?.points.count, 3, "the peak inside the note is not smoothed away")
        XCTAssertEqual(curve?.value(at: 0.5) ?? -1, 1.0, accuracy: 1e-9)
    }

    // MARK: surviving every transform that moves a note

    func testTempoWarpsTheCurveWithTheNotes() {
        let section = Section { "C" }.automate(.volume, over: [0: 0, 1: 1]).tempo(120)
        let curve = section.notes.first?.automation?.first
        XCTAssertEqual(curve?.points.last?.time ?? 0, 2.0, accuracy: 1e-9,
                       "240/120 — a fade left in whole notes would drift against a note in seconds")
    }

    func testDurationsRescaleTheSliceThroughScalingSlides() {
        let section = Section { "C" }.automate(.volume, over: [0: 0, 1: 1]).durations(.n2)
        let curve = section.notes.first?.automation?.first
        XCTAssertEqual(curve?.points.last?.time ?? 0, 0.5, accuracy: 1e-9)
    }

    func testArrangementStateSurvivesTheRebuild() {
        let section = Section { "C" }.active(loops: 0...2).mute()
            .automate(.volume, over: [0: 0, 1: 1])
        XCTAssertNotNil(section.activity, "replacingNotes must carry activity")
        XCTAssertTrue(section.isMuted, "…and the mute switch")
    }

    func testTwoVolumeCurvesMultiply() {
        let section = Section { "| C - - - |".automate(.volume, over: [0: 0.5, 1: 0.5]) }
            .automate(.volume, over: [0: 0.5, 1: 0.5])
        let lanes = section.notes.first(where: { $0.pitch != nil })?.automation ?? []
        XCTAssertEqual(lanes.count, 2)
        XCTAssertEqual(lanes.gain(at: 0), 0.25, accuracy: 1e-9,
                       "gains multiply here as they do at every other stage")
    }

    // MARK: track parameters live on the Section

    func testATrackParameterWrittenOnAStringIsHoistedToItsSection() {
        let section = Section { "| 1 3 5 5 |".automate(.cutoff, over: [0: 400, 1: 6000]) }
        XCTAssertEqual(section.automation?.first?.target, .cutoff)
        XCTAssertTrue(section.notes.allSatisfy { $0.automation == nil },
                      "one filter per track — it cannot ride a voice")
        XCTAssertEqual(section.automation?.first?.points.first?.time ?? -1, 0, accuracy: 1e-9)
        XCTAssertEqual(section.automation?.first?.points.last?.time ?? -1, 1.0, accuracy: 1e-9)
    }

    func testAnInnerTrackParameterWins() {
        let section = Section { "| 1 3 5 5 |".automate(.cutoff, over: [0: 400, 1: 6000]) }
            .automate(.cutoff, over: [0: 100, 1: 200])
        XCTAssertEqual(section.automation?.count, 1)
        XCTAssertEqual(section.automation?.first?.points.last?.value ?? 0, 6000, accuracy: 1e-9,
                       "the rule .key(...) already follows")
    }

    func testASectionsOwnTrackParameterSurvivesNesting() {
        let outer = Section {
            Section { "| 1 3 5 5 |" }.automate(.reverb, over: [0: 0.1, 1: 0.8])
        }
        XCTAssertEqual(outer.automation?.first?.target, .reverb)
    }

    // MARK: reaching the player

    func testAFadeMakesTheSessionUnequal() {
        let plain = Session { Track(name: "t") { Section { "C D E F" } } }
        let faded = Session {
            Track(name: "t") { Section { "C D E F" }.automate(.volume, over: [0: 0, 1: 1]) }
        }
        XCTAssertNotEqual(plain, faded,
                          "or ContentView's alreadyCurrent check swallows the edit")
    }

    func testATrackParameterAloneMakesTheSessionUnequal() {
        let plain = Session { Track(name: "t") { Section { "C D E F" } } }
        let swept = Session {
            Track(name: "t") { Section { "C D E F" }.automate(.cutoff, bars: [0: 400, 1: 6000]) }
        }
        XCTAssertNotEqual(plain, swept)
    }

    func testTheCurveCrossesTheJSONBoundary() throws {
        let session = Session {
            Track(name: "t") {
                Section { "C D E F" }
                    .automate(.volume, over: [0: 0, 1: 1])
                    .automate(.cutoff, over: [0: 400, 1: 6000])
            }
        }
        let data = try JSONEncoder().encode(session)
        XCTAssertEqual(try JSONDecoder().decode(Session.self, from: data), session)
    }

    // MARK: a curve written on the track

    func testATrackVolumeCurveSpansItsSectionsRatherThanRestartingInEach() {
        let track = Track(name: "t") {
            Section { "| C - - - |" }
            Section { "| G - - - |" }
        }.automate(.volume, over: [0: 0.0, 1: 1.0])

        XCTAssertEqual(track.duration, 2.0, accuracy: 1e-9)
        let first = track.sections[0].notes[0].automation?.first
        let second = track.sections[1].notes[0].automation?.first
        XCTAssertEqual(first?.points.first?.value ?? -1, 0.0, accuracy: 1e-9)
        XCTAssertEqual(first?.points.last?.value ?? -1, 0.5, accuracy: 1e-9,
                       "the first bar covers the first half of the curve")
        XCTAssertEqual(second?.points.first?.value ?? -1, 0.5, accuracy: 1e-9,
                       "and the second picks it up where the first left off")
        XCTAssertEqual(second?.points.last?.value ?? -1, 1.0, accuracy: 1e-9)
        XCTAssertEqual(second?.points.first?.time ?? -1, 0.0, accuracy: 1e-9)
    }

    func testATrackParameterIsCutIntoTheSectionsOwnWindows() {
        let track = Track(name: "t") {
            Section { "| 1 3 5 5 |" }
            Section { "| 5 3 2 1 |" }
        }.automate(.cutoff, over: [0: 400, 1: 6000])

        let a = track.sections[0].automation?.first
        let b = track.sections[1].automation?.first
        XCTAssertEqual(a?.target, .cutoff)
        XCTAssertEqual(a?.points.first?.value ?? -1, 400, accuracy: 1e-6)
        XCTAssertEqual(a?.points.last?.value ?? -1, 3200, accuracy: 1e-6)
        XCTAssertEqual(b?.points.first?.value ?? -1, 3200, accuracy: 1e-6)
        XCTAssertEqual(b?.points.last?.value ?? -1, 6000, accuracy: 1e-6)
        XCTAssertEqual(b?.points.first?.time ?? -1, 0.0, accuracy: 1e-9,
                       "section-relative, like every other lane the player reads")
        XCTAssertNil(track.sections[0].notes.first?.automation,
                     "a track parameter is not per-voice and must not ride the notes")
    }

    func testASectionsOwnSweepWinsOverTheTracks() {
        let track = Track(name: "t") {
            Section { "| 1 3 5 5 |" }.automate(.cutoff, over: [0: 100, 1: 200])
            Section { "| 5 3 2 1 |" }
        }.automate(.cutoff, over: [0: 400, 1: 6000])

        XCTAssertEqual(track.sections[0].automation?.count, 1)
        XCTAssertEqual(track.sections[0].automation?.first?.points.last?.value ?? -1, 200, accuracy: 1e-6)
        XCTAssertEqual(track.sections[1].automation?.first?.points.last?.value ?? -1, 6000, accuracy: 1e-6)
    }

    func testTheFourUnitsSpellTheSameTrackCurve() {
        func built(_ apply: (Track) -> Track) -> Track {
            apply(Track(name: "t") {
                Section { "| 1 3 5 5 |" }
                Section { "| 5 3 2 1 |" }
            })
        }
        let over  = built { $0.automate(.volume, over:  [0: 0.2, 1: 1.0]) }
        let at    = built { $0.automate(.volume, at:    [0: 0.2, 2.0: 1.0]) }
        let bars  = built { $0.automate(.volume, bars:  [0: 0.2, 2: 1.0]) }
        let beats = built { $0.automate(.volume, beats: [0: 0.2, 8: 1.0]) }
        XCTAssertEqual(over.sections, at.sections)
        XCTAssertEqual(at.sections, bars.sections)
        XCTAssertEqual(bars.sections, beats.sections)
    }

    func testAnEmptyDictionaryLeavesTheTrackAlone() {
        let plain = Track(name: "t") { Section { "C D E F" } }
        XCTAssertEqual(plain.automate(.volume, over: [:]).sections, plain.sections)
        XCTAssertEqual(plain.automate(.cutoff, bars: [:]).sections, plain.sections)
    }

    func testATrackFadeAndASectionFadeBothRideTheNote() {
        let track = Track(name: "t") {
            Section { "| C - - - |" }.automate(.volume, over: [0: 0.5, 1: 0.5])
        }.automate(.volume, over: [0: 0.5, 1: 0.5])
        XCTAssertEqual(track.sections[0].notes[0].automation?.count, 2)
    }

    func testATrackCurveMakesTheSessionUnequal() {
        let sections: () -> [Section] = { [Section { "C D E F" }] }
        let plain = Session { Track(name: "t", sections) }
        let swept = Session { Track(name: "t", sections).automate(.cutoff, bars: [0: 400, 1: 6000]) }
        XCTAssertNotEqual(plain, swept,
                          "or ContentView's alreadyCurrent check swallows the edit")
    }

    // MARK: a curve written on a drum lane

    func testALaneCurveRidesThatLanesHitsAlone() {
        let section = Section {
            Kick("x... x...")
            Hat("x.x. x.x.").automate(.volume, over: [0: 0.25, 1: 1.0])
        }
        let hats = section.notes.filter { $0.pitch == DrumPiece.closedHat.midiKey }
        let kicks = section.notes.filter { $0.pitch == DrumPiece.kick.midiKey }
        XCTAssertEqual(hats.count, 4)
        XCTAssertEqual(kicks.count, 2)
        XCTAssertTrue(hats.allSatisfy { $0.automation?.count == 1 })
        XCTAssertTrue(kicks.allSatisfy { $0.automation == nil },
                      "one voice of a groove swells while the others hold")
        XCTAssertEqual(hats[0].automation?.first?.points.first?.value ?? -1, 0.25, accuracy: 1e-9)
        XCTAssertEqual(hats[3].automation?.first?.points.first?.value ?? -1,
                       0.25 + 0.75 * 0.75, accuracy: 1e-9)
    }

    func testALaneTrackParameterIsHoistedToTheSection() {
        let section = Section {
            Kick("x... x...")
            Hat("x.x. x.x.").automate(.cutoff, over: [0: 400, 1: 6000])
        }
        XCTAssertEqual(section.automation?.count, 1)
        XCTAssertEqual(section.automation?.first?.target, .cutoff)
        XCTAssertEqual(section.automation?.first?.points.first?.time ?? -1, 0.0, accuracy: 1e-9)
        XCTAssertEqual(section.automation?.first?.points.last?.time ?? -1, 1.0, accuracy: 1e-9)
        XCTAssertTrue(section.notes.allSatisfy { $0.automation == nil })
    }

    func testALaneCurveIsMeasuredAgainstItsWrittenBarsNotItsLastHit() {
        let section = Section { Hat("x... | ....").automate(.volume, over: [0: 0.0, 1: 1.0]) }
        XCTAssertEqual(section.duration, 2.0, accuracy: 1e-9)
        let hit = section.notes.first { $0.pitch != nil }
        XCTAssertEqual(hit?.automation?.first?.points.last?.value ?? -1, 0.125, accuracy: 1e-9,
                       "an eighth of the way through two bars, not through one")
    }

    func testTheFourUnitsSpellTheSameLaneCurve() {
        func built(_ lane: DrumLane) -> Section { Section { lane } }
        let grid = "x.x. x.x. | x.x. x.x."
        XCTAssertEqual(built(Hat(grid).automate(.volume, over:  [0: 0.2, 1: 1.0])),
                       built(Hat(grid).automate(.volume, at:    [0: 0.2, 2.0: 1.0])))
        XCTAssertEqual(built(Hat(grid).automate(.volume, bars:  [0: 0.2, 2: 1.0])),
                       built(Hat(grid).automate(.volume, beats: [0: 0.2, 8: 1.0])))
    }

    func testALaneKeepsItsLevelAndItsCurveBoth() {
        let section = Section { Hat("x.x. x.x.").volume(0.5).automate(.volume, over: [0: 0, 1: 1]) }
        let hits = section.notes.filter { $0.pitch != nil }
        XCTAssertEqual(hits.first?.velocity, 50, "the level is still a velocity scale")
        XCTAssertEqual(hits.first?.automation?.count, 1, "and the curve still rides the hit")
    }

    func testAMutedLaneHasNoHitsLeftToCarryACurve() {
        let section = Section { Hat("x.x. x.x.").mute().automate(.volume, over: [0: 0, 1: 1]) }
        XCTAssertTrue(section.notes.allSatisfy { $0.pitch == nil })
        XCTAssertTrue(section.notes.allSatisfy { $0.automation == nil })
        XCTAssertEqual(section.duration, 1.0, accuracy: 1e-9,
                       "and the lane still holds its bar under the others")
    }

    func testAnEmptyDictionaryLeavesTheLaneAlone() {
        XCTAssertEqual(Section { Hat("x.x. x.x.").automate(.volume, over: [:]) },
                       Section { Hat("x.x. x.x.") })
    }
}

class AutomationShapeTests: XCTestCase {

    private func curve(_ points: [Double: Double], _ shape: AutomationShape) -> AutomationCurve {
        AutomationCurve.make(.volume, points, timeScale: 1, curve: shape)!
    }

    func testEveryShapeStartsAndEndsWhereItIsWritten() {
        for shape in AutomationShape.allCases {
            let c = curve([0: 0.25, 1: 0.75], shape)
            XCTAssertEqual(c.value(at: 0), 0.25, accuracy: 1e-9, "\(shape) moved its start")
            XCTAssertEqual(c.value(at: 1), 0.75, accuracy: 1e-9, "\(shape) missed its end")
        }
    }

    func testTheShapesDifferWhereTheyShould() {
        XCTAssertEqual(curve([0: 0, 1: 1], .linear).value(at: 0.5), 0.5, accuracy: 1e-9)
        XCTAssertGreaterThan(curve([0: 0, 1: 1], .exponential).value(at: 0.5), 0.6,
                             "exponential gets most of the way early — that's the point for a fade")
        XCTAssertEqual(curve([0: 0, 1: 1], .smooth).value(at: 0.5), 0.5, accuracy: 1e-9)
        XCTAssertLessThan(curve([0: 0, 1: 1], .smooth).value(at: 0.1), 0.1, "eased in")
        XCTAssertEqual(curve([0: 0, 1: 1], .hold).value(at: 0.9), 0, accuracy: 1e-9)
        XCTAssertEqual(curve([0: 0, 1: 1], .hold).value(at: 1.0), 1, accuracy: 1e-9)
    }

    func testNoShapeEverLeavesTheBand() {
        for shape in AutomationShape.allCases {
            let c = curve([0: 0.2, 0.5: 1.0, 1: 0.4], shape)
            for t in stride(from: 0.0, through: 1.0, by: 0.005) {
                XCTAssertLessThanOrEqual(c.value(at: t), 1.0 + 1e-9, "\(shape) overshot at \(t)")
                XCTAssertGreaterThanOrEqual(c.value(at: t), 0.2 - 1e-9, "\(shape) undershot at \(t)")
            }
        }
    }

    func testMaxValueStaysExactUnderEveryShape() {
        for shape in AutomationShape.allCases {
            let c = curve([0: 0, 0.5: 1, 1: 0], shape)
            for a in stride(from: 0.0, to: 1.0, by: 0.05) {
                let claimed = c.maxValue(from: a, to: a + 0.05)
                for t in stride(from: a, through: a + 0.05, by: 0.005) {
                    XCTAssertLessThanOrEqual(c.value(at: t), claimed + 1e-9,
                                             "\(shape) beat its own maximum at \(t)")
                }
            }
        }
    }

    func testAShapeSurvivesTheJourneyOntoANote() {
        let section = Section { "| C - - - |" }
            .automate(.volume, over: [0: 1.0, 1: 0.0], curve: .exponential)
        let c = section.notes.first { $0.pitch != nil }?.automation?.first
        XCTAssertNotNil(c)
        XCTAssertGreaterThan(c?.points.count ?? 0, 8, "the shape was spent as breakpoints")
        XCTAssertLessThan(c?.value(at: 0.5) ?? 1, 0.4, "…and it still curves")
    }

    func testShapeIsIrrelevantForASingleBreakpoint() {
        for shape in AutomationShape.allCases {
            XCTAssertEqual(AutomationCurve.make(.volume, [0: 0.5], timeScale: 1, curve: shape)?.points.count, 1)
        }
    }
}

class WaveTests: XCTestCase {

    private func curve(_ points: [Double: Double]) -> AutomationCurve {
        AutomationCurve.make(.volume, points, timeScale: 1)!
    }

    func testASineStaysInsideItsBandAndFillsIt() {
        let wave = Wave.sine(cycles: 4, between: 0.6...1.0)
        XCTAssertEqual(curve(wave).value(at: 0), 1.0, accuracy: 1e-6, "phase 0 starts unmodulated")
        XCTAssertEqual(wave.values.min() ?? 0, 0.6, accuracy: 1e-6)
        XCTAssertEqual(wave.values.max() ?? 0, 1.0, accuracy: 1e-6)
    }

    func testDepthIsTheTremoloPedalsKnob() {
        let none = Wave.sine(cycles: 4, between: 0.2...1.0, depth: 0...0)
        XCTAssertTrue(none.values.allSatisfy { abs($0 - 1.0) < 1e-9 },
                      "depth 0 pins the parameter at the band's top — no modulation at all")

        let fadingIn = Wave.sine(cycles: 8, between: 0.4...1.0, depth: 0...1)
        let byTime = fadingIn.sorted { $0.key < $1.key }
        let early = byTime.prefix(8).map(\.value)
        let late = byTime.suffix(8).map(\.value)
        XCTAssertLessThan((early.max() ?? 0) - (early.min() ?? 0), 0.1, "no wobble yet")
        XCTAssertGreaterThan((late.max() ?? 0) - (late.min() ?? 0), 0.4, "full wobble by the end")
    }

    func testASquareSteps() {
        let c = curve(Wave.square(cycles: 2, between: 0.0...1.0))
        XCTAssertEqual(c.value(at: 0.1), 1.0, accuracy: 1e-9)
        XCTAssertEqual(c.value(at: 0.4), 0.0, accuracy: 1e-9)
        XCTAssertGreaterThan(c.value(at: 0.2499), 0.99, "the edge is a step, not a ramp")
    }

    func testSpanPutsTheWaveInTheUnitTheLabelNames() {
        let overSpan = Wave.triangle(cycles: 4, between: 0...1)
        let barsSpan = Wave.triangle(cycles: 4, span: 8, between: 0...1)
        XCTAssertEqual(overSpan.keys.max() ?? 0, 1.0, accuracy: 1e-9)
        XCTAssertEqual(barsSpan.keys.max() ?? 0, 8.0, accuracy: 1e-9)
    }

    func testSampleAndHoldIsDeterministic() {
        XCTAssertEqual(Wave.random(steps: 8, between: 0.2...1.0, seed: 3),
                       Wave.random(steps: 8, between: 0.2...1.0, seed: 3),
                       "a wobble that rerolled on every recompile would export a take you never heard")
        XCTAssertNotEqual(Wave.random(steps: 8, between: 0.2...1.0, seed: 3),
                          Wave.random(steps: 8, between: 0.2...1.0, seed: 4))
    }

    func testAWaveIsJustTheDictionaryYouWouldHaveTyped() {
        let section = Section { "| C - - - |" }
            .automate(.volume, over: Wave.sine(cycles: 4, between: 0.5...1.0))
        XCTAssertGreaterThan(section.notes.first { $0.pitch != nil }?.automation?.first?.points.count ?? 0, 20)

        let swept = Section { "| C - - - |" }
            .automate(.cutoff, bars: Wave.triangle(cycles: 2, span: 1, between: 400...6000))
        XCTAssertEqual(swept.automation?.first?.target, .cutoff)
    }

    func testAnEmptyWaveChangesNothing() {
        let plain = Section { "C D E F" }
        XCTAssertEqual(plain.automate(.volume, over: Wave.random(steps: 0, between: 0...1)), plain)
    }
}

class JoinedNotationTests: XCTestCase {

    override func setUp() { super.setUp(); SectionBuilder.timeSignature = .fourFour }

    func testStringPlusStringIsStillPlainConcatenation() {
        let text = "| C D E F " + "| G A B C6 |"
        XCTAssertEqual(text, "| C D E F | G A B C6 |")
    }

    func testPartsAreLaidEndToEnd() {
        let joined = Section { "| C D E F |".transpose(0) + "| G A B C6 |" }
        let plain = Section { "| C D E F | G A B C6 |" }
        XCTAssertEqual(joined.duration, plain.duration, accuracy: 1e-9)
        XCTAssertEqual(joined.notes.compactMap(\.pitch), plain.notes.compactMap(\.pitch))
    }

    func testEachPartKeepsItsOwnFade() {
        let section = Section {
            "| C - - - |".automate(.volume, over: [0: 1.0, 1: 0.0])
                + "| G - - - |".automate(.volume, over: [0: 0.0, 1: 1.0])
        }
        let sounding = section.notes.filter { $0.pitch != nil }
        XCTAssertEqual(sounding.count, 2)
        XCTAssertEqual(sounding[0].automation?.first?.points.last?.value ?? -1, 0.0, accuracy: 1e-9,
                       "the first part fades out")
        XCTAssertEqual(sounding[1].automation?.first?.points.last?.value ?? -1, 1.0, accuracy: 1e-9,
                       "…and the second fades in, on its own terms")
    }

    func testEachPartKeepsItsOwnKey() {
        let section = Section { "1 2 3".key(.C, .major) + "1 2 3".key(.D, .major) }
        let pitches = section.notes.compactMap(\.pitch)
        XCTAssertEqual(pitches.count, 6)
        XCTAssertNotEqual(Array(pitches.prefix(3)), Array(pitches.suffix(3)))
    }

    func testAFadeCanSpanTheWholeJoin() {
        let section = Section {
            ("| C - - - |" + "| G - - - |").automate(.volume, over: [0: 1.0, 1: 0.0])
        }
        let sounding = section.notes.filter { $0.pitch != nil }
        XCTAssertEqual(sounding[0].automation?.first?.value(at: 0) ?? -1, 1.0, accuracy: 1e-9)
        XCTAssertEqual(sounding[1].automation?.first?.points.last?.value ?? -1, 0.0, accuracy: 1e-9)
    }

    func testAPartsFadeMultipliesWithTheJoinsFade() {
        let section = Section {
            ("| C - - - |".automate(.volume, over: [0: 0.5, 1: 0.5]) + "| G - - - |")
                .automate(.volume, over: [0: 0.5, 1: 0.5])
        }
        let first = section.notes.first { $0.pitch != nil }
        XCTAssertEqual((first?.automation ?? []).gain(at: 0), 0.25, accuracy: 1e-9)
    }

    func testSerialTrackParametersBothSurvive() {
        let section = Section {
            "| C - - - |".automate(.cutoff, over: [0: 400, 1: 2000])
                + "| G - - - |".automate(.cutoff, over: [0: 6000, 1: 8000])
        }
        let lane = section.automation?.first
        XCTAssertEqual(lane?.target, .cutoff)
        XCTAssertEqual(lane?.value(at: 0) ?? 0, 400, accuracy: 1e-6)
        XCTAssertEqual(lane?.points.last?.value ?? 0, 8000, accuracy: 1e-6)
        XCTAssertEqual(lane?.points.map(\.time), lane?.points.map(\.time).sorted())
    }

    func testParallelTrackParametersStillContest() {
        let section = Section {
            "| C - - - |".automate(.cutoff, over: [0: 400, 1: 2000])
            "| G - - - |".automate(.cutoff, over: [0: 6000, 1: 8000])
        }
        XCTAssertEqual(section.automation?.count, 1, "one filter per track")
        XCTAssertEqual(section.automation?.first?.points.last?.value ?? 0, 8000, accuracy: 1e-6,
                       "the later-written layer takes it")
    }

    func testOnlyTheFirstPartClaimsTokenOffsets() {
        let section = Section { "| C D |".transpose(0) + "| E F |" }
        let sounding = section.notes.filter { $0.pitch != nil }
        XCTAssertNotNil(sounding.first?.sourceOffset)
        XCTAssertNil(sounding.last?.sourceOffset)
    }

    func testInterpolationKeepsTheNotesAndDropsTheModifiers() {
        let faded = "C D E".automate(.volume, over: [0: 1, 1: 0])
        XCTAssertEqual("\(faded)", "C D E")
        let section = Section { "\(faded) | G" }
        XCTAssertEqual(section.notes.filter { $0.pitch != nil }.count, 4)
        XCTAssertTrue(section.notes.allSatisfy { $0.automation == nil })
    }

    func testMixedJoinsWithPlainStrings() {
        let section = Section { "| C - - - |".automate(.volume, over: [0: 1, 1: 0]) + "| G - - - |" }
        let sounding = section.notes.filter { $0.pitch != nil }
        XCTAssertEqual(sounding.count, 2)
        XCTAssertNotNil(sounding[0].automation)
        XCTAssertNil(sounding[1].automation, "a plain part is plain")
    }
}

// MARK: - Loop (explicit repetition)

final class LoopTests: XCTestCase {

    private let bar: MusicTimeStamp = 1.0

    private func end(of track: Track) -> MusicTimeStamp {
        track.sections.map(\.duration).max() ?? 0
    }

    private func sounding(_ track: Track) -> [Note] {
        track.sections.flatMap(\.notes).filter { $0.pitch != nil }
    }

    override func setUp() {
        super.setUp()
        SectionBuilder.timeSignature = .fourFour
    }

    // MARK: The grid

    func testTheGridHoldsWhateverTheBodyBuilds() {
        let track = Track(name: "d") {
            Loop(bars: 2, times: 4) { _ in Section { "| 1 1 1 1 |" } }
        }
        XCTAssertEqual(end(of: track), 8 * bar, accuracy: 1e-9,
                       "4 time rounds of 2 bars is 8 bars, whatever the body built")
        XCTAssertEqual(sounding(track).count, 16)
        XCTAssertEqual(sounding(track).map(\.startTime).filter { $0.truncatingRemainder(dividingBy: 2) == 0 }.count, 4)
    }

    func testATimeRoundThatSitsOutKeepsItsBars() {
        let track = Track(name: "d") {
            Loop(bars: 1, times: 4) { loop in
                if loop % 2 == 0 { Section { "| 1 1 1 1 |" } }
            }
        }
        XCTAssertEqual(end(of: track), 4 * bar, accuracy: 1e-9)
        XCTAssertEqual(sounding(track).count, 8, "two rounds sound, two are silent")
        XCTAssertEqual(sounding(track).map(\.startTime).min(), 0)
        XCTAssertEqual(sounding(track).map(\.startTime).max() ?? -1, 2.75, accuracy: 1e-9,
                       "the third round opens at bar 3, not bar 2")
    }

    // MARK: Saying what the grid dropped

    func testALoopReportsAStatementItsGridNeverReached() {
        let session = Session {
            Track(name: "d") {
                Loop(bars: 1, times: 8) { _ in
                    Section { "| 1 1 1 1 |" }
                    Section { "| 5 5 5 5 |" }
                }
            }
        }
        XCTAssertEqual(session.advisories.count, 1,
                       "one loop reports once, not once per time round")
        let advisory = try! XCTUnwrap(session.advisories.first)
        XCTAssertTrue(advisory.message.contains("1 section after it never sounds"),
                      advisory.message)
        XCTAssertNotNil(advisory.line)
    }

    func testAScoreThatFitsItsGridSaysNothing() {
        let session = Session {
            Track(name: "d") {
                Loop(bars: 2, times: 4) { _ in
                    Section { "| 1 1 1 1 |" }
                    Section { "| 5 5 5 5 |" }
                }
            }
        }
        XCTAssertTrue(session.advisories.isEmpty)
    }

    func testACroppedSectionIsNotReported() {
        let session = Session {
            Track(name: "d") {
                Loop(bars: 1, times: 3) { _ in Section { "| 1 1 1 1 | 5 5 5 5 |" } }
            }
        }
        XCTAssertTrue(session.advisories.isEmpty)
    }

    func testAFillingLoopReportsOnceAcrossBothPasses() {
        let session = Session {
            Track(name: "d") {
                Loop(bars: 1) { _ in
                    Section { "| 1 1 1 1 |" }
                    Section { "| 5 5 5 5 |" }
                }
            }
            Track(name: "m") { Section { "| 1 1 1 1 | 2 2 2 2 | 3 3 3 3 | 4 4 4 4 |" } }
        }
        XCTAssertEqual(session.advisories.count, 1)
    }

    func testAnAdvisorySurvivesTheSessionRoundTrip() throws {
        let session = Session {
            Track(name: "d") {
                Loop(bars: 1, times: 2) { _ in
                    Section { "| 1 1 1 1 |" }
                    Section { "| 5 5 5 5 |" }
                }
            }
        }.tempo(174).volume(0.6)
        XCTAssertEqual(session.advisories.count, 1, "and the modifiers carry it forward")
        let decoded = try JSONDecoder().decode(
            Session.self, from: try JSONEncoder().encode(session))
        XCTAssertEqual(decoded.advisories, session.advisories)
    }

    func testTheGridFollowsTheSessionMeter() {
        SectionBuilder.timeSignature = TimeSignature(3, 4)
        defer { SectionBuilder.timeSignature = .fourFour }
        let track = Track(name: "d") {
            Loop(bars: 2, times: 2) { _ in Section { "| 1 1 1 |" } }
        }
        XCTAssertEqual(end(of: track), 3.0, accuracy: 1e-9, "2 bars x 2 rounds x 0.75")
    }

    func testABodyOverrunningTheGridIsCropped() {
        let track = Track(name: "d") {
            Loop(bars: 1, times: 3) { _ in Section { "| 1 1 1 1 | 5 5 5 5 |" } }
        }
        XCTAssertEqual(end(of: track), 3 * bar, accuracy: 1e-9)
        XCTAssertEqual(sounding(track).count, 12, "the second bar of each round is past the grid")
        XCTAssertTrue(sounding(track).allSatisfy { $0.pitch == sounding(track)[0].pitch },
                      "only the first bar's notes survive")
    }

    func testANoteCannotRingPastTheGrid() {
        let track = Track(name: "d") {
            Loop(bars: 1, times: 3) { _ in
                Section { Note(pitch: 60, velocity: 100, startTime: 0, duration: 3.0) }
            }
        }
        XCTAssertEqual(end(of: track), 3 * bar, accuracy: 1e-9)
        XCTAssertEqual(sounding(track).map(\.duration), [1.0, 1.0, 1.0])
        XCTAssertEqual(sounding(track).map(\.startTime), [0.0, 1.0, 2.0])
    }

    // MARK: Reacting to the time round

    func testTheBodyIsHandedTheTimeRound() {
        let track = Track(name: "d") {
            Loop(bars: 1, times: 4) { loop in
                if loop == 3 { Section { "| 5 5 5 5 |" } } else { Section { "| 1 - - - |" } }
            }
        }
        let byRound = Dictionary(grouping: sounding(track)) { $0.loop?.iteration ?? -1 }
        XCTAssertEqual(byRound[0]?.count, 1)
        XCTAssertEqual(byRound[3]?.count, 4, "the fill lands on the fourth round only")
        XCTAssertNotEqual(byRound[0]?.first?.pitch, byRound[3]?.first?.pitch)
    }

    func testControlFlowWorksInAPlainTrackBody() {
        let track = Track(name: "d") {
            for i in 0..<3 {
                if i == 1 { Section { "| 5 5 5 5 |" } } else { Section { "| 1 1 1 1 |" } }
            }
        }
        XCTAssertEqual(sounding(track).count, 12)
        XCTAssertEqual(end(of: track), 3 * bar, accuracy: 1e-9)
    }

    func testALoopNestsInsideALoop() {
        let track = Track(name: "d") {
            Loop(bars: 4, times: 2) { _ in
                Loop(bars: 1, times: 4) { inner in
                    Section { inner == 3 ? "| 5 5 5 5 |" : "| 1 1 1 1 |" }
                }
            }
        }
        XCTAssertEqual(end(of: track), 8 * bar, accuracy: 1e-9)
        XCTAssertEqual(sounding(track).count, 32)
    }

    // MARK: The dice

    func testEachTimeRoundRollsItsOwnDice() {
        let track = Track(name: "d") {
            Loop(bars: 1, times: 6) { _ in Section { "| ?(1 2 3 5) - - - |" } }
        }
        let salts = Set(sounding(track).filter { $0.pitchVariants != nil }.map(\.diceSalt))
        XCTAssertEqual(salts.count, 6, "one die per time round, not one for all six")
    }

    func testTheSamePieceRollsTheSameWayTwice() {
        func build() -> [Pitch?] {
            let track = Track(name: "d") {
                Loop(bars: 1, times: 8) { _ in Section { "| ?(1 2 3 5) - - - |" } }
            }
            return sounding(track).map { $0.resolvedPitchForTest(seed: 11) }
        }
        XCTAssertEqual(build(), build())
    }

    func testTheLoopStampSurvivesJSON() throws {
        let session = Session {
            Track(name: "d") { Loop(bars: 1, times: 2) { _ in Section { "| 1 1 1 1 |" } } }
        }
        let back = try JSONDecoder().decode(Session.self, from: JSONEncoder().encode(session))
        let stamps = back.tracks[0].sections.flatMap(\.notes).compactMap { $0.loop?.iteration }
        XCTAssertEqual(Set(stamps), [0, 1])
    }

    // MARK: Filling

    func testAFillingLoopRunsAsLongAsTheWrittenVoice() {
        let session = Session {
            Track(name: "Drums") { Loop(bars: 2) { _ in Section { "| 1 1 1 1 |" } } }
            Track(name: "Voice") {
                Section { "| 1 2 3 4 | 5 6 7 1' | 1' 7 6 5 | 4 3 2 1 |" }
                Section { "| 1 2 3 4 | 5 6 7 1' | 1' 7 6 5 | 4 3 2 1 |" }
            }
        }
        XCTAssertEqual(end(of: session.tracks[0]), 8 * bar, accuracy: 1e-9)
        XCTAssertEqual(end(of: session.tracks[1]), 8 * bar, accuracy: 1e-9)
        XCTAssertEqual(sounding(session.tracks[0]).count, 16, "four rounds of four hits")
    }

    func testAFillingLoopCoversAPieceItDoesNotDivide() {
        let session = Session {
            Track(name: "Drums") { Loop(bars: 2) { _ in Section { "| 1 1 1 1 |" } } }
            Track(name: "Voice") { Section { "| 1 | 2 | 3 | 4 | 5 |" } }
        }
        XCTAssertEqual(end(of: session.tracks[0]), 6 * bar, accuracy: 1e-9,
                       "three rounds of two bars is the first grid that covers five")
    }

    func testEveryTrackFillingRunsOneTimeRound() {
        let session = Session {
            Track(name: "a") { Loop(bars: 2) { _ in Section { "| 1 1 1 1 |" } } }
            Track(name: "b") { Loop(bars: 1) { _ in Section { "| 5 5 5 5 |" } } }
        }
        XCTAssertEqual(end(of: session.tracks[0]), 2 * bar, accuracy: 1e-9)
        XCTAssertEqual(end(of: session.tracks[1]), 1 * bar, accuracy: 1e-9)
    }

    func testAStatedCountReadsTheContentOnce() {
        var reads = 0
        let session = Session {
            Track(name: "d") {
                Loop(bars: 1, times: 2) { _ in
                    Section { "| 1 1 1 1 |" }
                }
            }
            .volume({ reads += 1; return 1.0 }())
        }
        XCTAssertEqual(reads, 1)
        XCTAssertEqual(end(of: session.tracks[0]), 2 * bar, accuracy: 1e-9)
    }
}

private extension Note {
    func resolvedPitchForTest(seed: UInt64) -> Pitch? {
        guard let base = pitch else { return nil }
        guard let variants = pitchVariants, variants.count > 1 else { return base }
        return variants[(variantMode ?? .up).variantIndex(
            loopIndex: rollPassForTest(0), count: variants.count,
            salt: Dice.salt(diceSalt, for: .pitch, seed: seed))]
    }
    func rollPassForTest(_ loopIndex: Int) -> Int { loopIndex + (loop?.iteration ?? 0) }
}

final class BuilderControlFlowTests: XCTestCase {

    override func setUp() {
        super.setUp()
        SectionBuilder.timeSignature = .fourFour
    }

    private func sounding(_ track: Track) -> [Note] {
        track.sections.flatMap(\.notes).filter { $0.pitch != nil }
    }

    func testAnIfInsideASectionAddsALayerOnSomeRounds() {
        let drums = Section {
            Kick("x... x... x... x...")
            Hat("x.x. x.x. x.x. x.x.")
        }
        let track = Track(name: "Drums") {
            Loop(bars: 1, times: 4) { loop in
                Section {
                    drums
                    if loop % 4 == 3 {
                        Section { Clap("x... x..x x... xx..") }
                    }
                }
            }
        }
        let byRound = Dictionary(grouping: sounding(track)) { $0.loop?.iteration ?? -1 }
            .mapValues(\.count)
        XCTAssertEqual(byRound[0], 12)
        XCTAssertEqual(byRound[1], 12)
        XCTAssertEqual(byRound[2], 12)
        XCTAssertEqual(byRound[3], 18, "the clap joins on the fourth round only")
    }

    func testIfElseInsideASection() {
        func build(_ loud: Bool) -> Section {
            Section {
                if loud { "| 1 1 1 1 |" } else { "| 1 - - - |" }
            }
        }
        XCTAssertEqual(build(true).notes.filter { $0.pitch != nil }.count, 4)
        XCTAssertEqual(build(false).notes.filter { $0.pitch != nil }.count, 1)
    }

    func testAForInsideASectionStacksItsLayers() {
        let section = Section {
            for degree in ["| 1 - - - |", "| 3 - - - |", "| 5 - - - |"] { degree }
        }
        let pitched = section.notes.filter { $0.pitch != nil }
        XCTAssertEqual(pitched.count, 3, "a triad, stacked as parallel layers")
        XCTAssertTrue(pitched.allSatisfy { $0.startTime == 0 }, "layers all start together")
    }

    func testATrackCurveInsideAnIfIsStillHoisted() {
        let on = true
        let section = Section {
            "| 1 1 1 1 |"
            if on {
                "| 5 - - - |".automate(.cutoff, over: [0: 0.2, 1: 0.9])
            }
        }
        XCTAssertNotNil(section.automation, "the sweep reached the section")
        XCTAssertEqual(section.automation?.first?.target, .cutoff)
        XCTAssertTrue(section.notes.allSatisfy { $0.automation == nil },
                      "and came off the note it rode in on")
    }

    func testATrackCanBeConditional() {
        func session(_ withBass: Bool) -> Session {
            Session {
                Track(name: "Drums") { Section { "| 1 1 1 1 |" } }
                if withBass {
                    Track(name: "Bass") { Section { "| 1 1 5 5 |" } }
                }
                for i in 0..<2 {
                    Track(name: "Pad\(i)") { Section { "| [1 3 5] - - - |" } }
                }
            }
        }
        XCTAssertEqual(session(true).tracks.map(\.name), ["Drums", "Bass", "Pad0", "Pad1"])
        XCTAssertEqual(session(false).tracks.map(\.name), ["Drums", "Pad0", "Pad1"])
    }
}

final class SessionPassTests: XCTestCase {

    private let bar: MusicTimeStamp = 1.0

    override func setUp() {
        super.setUp()
        SectionBuilder.timeSignature = .fourFour
        ScoreAdvisories.collected = []
    }

    private func sounding(_ session: Session, _ trackName: String? = nil) -> [Note] {
        session.tracks
            .filter { trackName == nil || $0.name == trackName }
            .flatMap { $0.sections.flatMap(\.notes) }
            .filter { $0.pitch != nil }
    }

    private func pitches(_ session: Session, onPass pass: Int,
                         track: String? = nil) -> [Pitch] {
        sounding(session, track)
            .filter { $0.activity?.isActive(loopIndex: pass) ?? true }
            .sorted { $0.startTime < $1.startTime }
            .compactMap(\.pitch)
    }

    // MARK: The passes are overlaid, not laid out

    func testEveryPassIsBuiltIntoOneWindow() {
        let session = Session { pass in
            Track(name: "Bass") { Section { pass < 2 ? "| C4 - - - |" : "| D4 - - - |" } }
        }
        .loops(4)

        XCTAssertEqual(session.tracks[0].sections.count, 1)
        XCTAssertEqual(session.tracks[0].sections[0].duration, bar, accuracy: 1e-9,
                       "four passes of one bar is one bar — the piece going round repeats it")
        XCTAssertEqual(sounding(session).count, 4, "one copy per pass, all at time 0")
        XCTAssertEqual(pitches(session, onPass: 0), [48])
        XCTAssertEqual(pitches(session, onPass: 1), [48])
        XCTAssertEqual(pitches(session, onPass: 2), [50])
        XCTAssertEqual(pitches(session, onPass: 3), [50])
    }

    func testTheLoopsModifierReachesTheBody() {
        let body: (Int) -> Session = { count in
            Session { pass in
                Track(name: "Bass") { Section { Note(pitch: Pitch(60 + pass), velocity: 100,
                                                     startTime: 0, duration: 0.25) } }
            }
            .loops(count)
        }
        XCTAssertEqual(body(2).effectiveLoopCount, 2)
        XCTAssertEqual(Set(body(2).tracks[0].sections[0].notes.compactMap(\.pitch)), [60, 61])
        XCTAssertEqual(Set(body(5).tracks[0].sections[0].notes.compactMap(\.pitch)),
                       [60, 61, 62, 63, 64], "the body is read again for the count it names")
    }

    func testTheBodySurvivesModifiersWrittenBeforeLoops() {
        let session = Session { pass in
            Track(name: "Bass") { Section { pass == 0 ? "| C4 - - - |" : "| D4 - - - |" } }
        }
        .tempo(90)
        .volume(0.5)
        .seed(7)
        .loops(2)

        XCTAssertEqual(session.tempo, 90)
        XCTAssertEqual(pitches(session, onPass: 0), [48])
        XCTAssertEqual(pitches(session, onPass: 1), [50])
    }

    func testAKeyWrittenBeforeLoopsSurvivesTheRebuild() {
        let session = Session { pass in
            Track(name: "Bass") { Section { pass == 0 ? "| 1 - - - |" : "| 5 - - - |" } }
        }
        .key(.D4, .minor)
        .loops(2)

        XCTAssertEqual(pitches(session, onPass: 0), [50], "degree 1 of D minor")
        XCTAssertEqual(pitches(session, onPass: 1), [57], "degree 5 of D minor")
    }

    // MARK: How long the form is

    func testTheArrangementCanDeclareTheFormOnItsOwn() {
        let session = Session { pass in
            Track(name: "Bass") {
                Section { "| C4 - - - |" }
                Section { pass == 0 ? "| E4 - - - |" : "| G4 - - - |" }.active(loops: 1...2)
            }
        }
        XCTAssertEqual(session.effectiveLoopCount, 3)
        XCTAssertEqual(pitches(session, onPass: 0), [48], "the gated section still says no")
        XCTAssertEqual(pitches(session, onPass: 1), [48, 55])
        XCTAssertEqual(pitches(session, onPass: 2), [48, 55])
    }

    func testAVaryingBodyWithNoFormIsReported() {
        let session = Session { pass in
            Track(name: "Bass") { Section { pass == 0 ? "| C4 - - - |" : "| D4 - - - |" } }
        }
        XCTAssertEqual(session.effectiveLoopCount, 1)
        XCTAssertEqual(session.advisories.count, 1)
        XCTAssertTrue(session.advisories[0].message.contains("nothing says how many passes"),
                      session.advisories[0].message)
    }

    func testStatingTheCountClearsThatReport() {
        func session(_ n: Int) -> Session {
            Session { pass in
                Track(name: "Bass") { Section { pass == 0 ? "| C4 - - - |" : "| D4 - - - |" } }
            }
            .loops(n)
        }
        XCTAssertTrue(session(4).advisories.isEmpty, "\(session(4).advisories)")
        XCTAssertTrue(session(1).advisories.isEmpty,
                      "one pass, stated, is a decision rather than an oversight")
    }

    func testAnUnvaryingBodySaysNothing() {
        let session = Session { _ in
            Track(name: "Bass") { Section { "| C4 - - - |" } }
        }
        XCTAssertTrue(session.advisories.isEmpty, "\(session.advisories)")
        XCTAssertEqual(session.effectiveLoopCount, 1)
    }

    // MARK: Merging the tracks

    func testATrackOnlySomePassesWriteKeepsItsSlot() {
        let session = Session { pass in
            Track(name: "Bass") { Section { "| C4 - - - |" } }
            if pass >= 1 { Track(name: "Lead") { Section { "| G5 - - - |" } } }
        }
        .loops(2)

        XCTAssertEqual(session.tracks.map(\.name), ["Bass", "Lead"])
        XCTAssertTrue(pitches(session, onPass: 0, track: "Lead").isEmpty)
        XCTAssertEqual(pitches(session, onPass: 1, track: "Lead"), [67])
    }

    func testAPassGivingATrackADifferentSoundIsReported() {
        let session = Session { pass in
            Track(name: "Keys") { Section { "| C5 - - - |" } }.volume(pass == 0 ? 0.4 : 0.9)
        }
        .loops(2)

        XCTAssertEqual(session.advisories.count, 1)
        XCTAssertTrue(session.advisories[0].message.contains("volume"),
                      session.advisories[0].message)
        XCTAssertEqual(session.tracks[0].volume, 0.4, "the first pass's is what plays")
    }

    func testALoopInsideAPassRunsItsRoundsWithinThatPass() {
        let session = Session { pass in
            Track(name: "Drums") {
                Loop(bars: 1, times: 4) { loop in
                    if loop == 0 || pass == 1 { Section { "| C4 - - - |" } }
                }
            }
        }
        .loops(2)

        XCTAssertEqual(session.tracks[0].sections.map(\.duration).max() ?? 0, 4 * bar,
                       accuracy: 1e-9,
                       "the loop's four rounds are four bars, laid out serially; the passes share them")
        XCTAssertEqual(session.tracks[0].sections.count, 4)
        XCTAssertEqual(pitches(session, onPass: 0).count, 1, "only the loop's first round")
        XCTAssertEqual(pitches(session, onPass: 1).count, 4, "every round")
    }

    func testAnInnerGateIntersectsRatherThanBeingLost() {
        let session = Session { _ in
            Track(name: "G") {
                Section {
                    Section { "| C4 - - - |" }.active(loops: [0, 2])
                }
            }
        }
        .loops(4)

        XCTAssertEqual(pitches(session, onPass: 0), [48])
        XCTAssertTrue(pitches(session, onPass: 1).isEmpty, "the inner gate still says no")
        XCTAssertEqual(pitches(session, onPass: 2), [48])
        XCTAssertTrue(pitches(session, onPass: 3).isEmpty)
    }

    func testAMutedLayerStaysSilentOnEveryPass() {
        let session = Session { _ in
            Track(name: "G") {
                Section {
                    "| C4 - - - |"
                    Section { "| G4 - - - |" }.mute()
                }
            }
        }
        .loops(2)

        for pass in 0..<2 {
            XCTAssertEqual(pitches(session, onPass: pass), [48], "pass \(pass)")
        }
    }

    func testAMutedTrackStaysMuted() {
        let session = Session { _ in
            Track(name: "Pad") { Section { "| C4 - - - |" } }.mute()
        }
        .loops(2)
        XCTAssertTrue(session.tracks[0].isMuted)
    }

    func testATracksArrangementIsTheTracksAndDisagreementIsReported() {
        let session = Session { pass in
            Track(name: "A") {
                Section { Note(pitch: Pitch(60 + pass), velocity: 100,
                               startTime: 0, duration: 0.25) }
            }
            .active(loops: [pass])
        }
        .loops(2)

        XCTAssertEqual(session.tracks[0].activity, .set([0]), "the first pass's, once")
        XCTAssertEqual(pitches(session, onPass: 1), [61],
                       "pass 1's material is gated by its own pass, not by pass 0's arrangement")
        XCTAssertEqual(session.advisories.count, 1)
        XCTAssertTrue(session.advisories[0].message.contains("arrangement"),
                      session.advisories[0].message)
    }

    func testAConsistentTrackArrangementSaysNothing() {
        let session = Session { pass in
            Track(name: "L") {
                Section { Note(pitch: Pitch(60 + pass), velocity: 100,
                               startTime: 0, duration: 0.25) }
            }
            .active(loops: 1...)
        }
        .loops(3)

        XCTAssertEqual(session.tracks[0].activity, .range(from: 1, through: nil))
        XCTAssertTrue(session.advisories.isEmpty, "\(session.advisories)")
        XCTAssertEqual(pitches(session, onPass: 2), [62])
    }

    // MARK: Saying what cannot be seen downstream

    func testRaggedPassesAreReported() {
        let session = Session { pass in
            Track(name: "R") {
                Section { pass == 0 ? "| C5 - - - |" : "| C5 - - - | D5 - - - |" }
                Section { "| E5 - - - |" }
            }
        }
        .loops(2)

        XCTAssertEqual(session.advisories.count, 1)
        XCTAssertTrue(session.advisories[0].message.contains("disagree about how long"),
                      session.advisories[0].message)
    }

    func testAShorterLastPassIsNotReported() {
        let session = Session { pass in
            Track(name: "R") {
                Section { pass == 0 ? "| C5 - - - |" : "| C5 - - - | D5 - - - |" }
            }
        }
        .loops(2)
        XCTAssertTrue(session.advisories.isEmpty, "\(session.advisories)")
    }

    func testTwoPassesMovingOneTrackParameterIsReported() {
        let session = Session { pass in
            Track(name: "F") {
                Section {
                    "| C4 - - - |".automate(.cutoff, over: pass == 0 ? [0: 200, 1: 8000]
                                                                     : [0: 8000, 1: 200])
                }
            }
        }
        .loops(2)

        XCTAssertEqual(session.advisories.count, 1)
        XCTAssertTrue(session.advisories[0].message.contains("cutoff"),
                      session.advisories[0].message)
        XCTAssertEqual(session.tracks[0].sections[0].automation?.count, 1,
                       "the first pass's curve is the one that plays")
    }

    func testTheSameCurveOnEveryPassIsNotReported() {
        let session = Session { pass in
            Track(name: "F") {
                Section {
                    "| C4 - - - |".automate(.cutoff, over: [0: 200, 1: 8000])
                    if pass == 2 { "| G4 - - - |" }
                }
            }
        }
        .loops(3)
        XCTAssertTrue(session.advisories.isEmpty, "\(session.advisories)")
    }

    func testAFillingLoopInsideAPassBodyKeepsEarlierReports() {
        let session = Session { pass in
            Track(name: "Voice") { Section { "| 1 2 3 4 | 5 6 7 1' |" } }
            Track(name: "Drums") {
                Loop(bars: 1) { _ in
                    Section { "| C4 - - - |" }
                    if pass == 0 { Section { "| D4 - - - |" } }
                }
            }
        }
        .loops(2)

        XCTAssertEqual(session.tracks[1].sections.count, 2,
                       "the filling loop covered the two-bar voice")
        XCTAssertEqual(session.advisories.count, 1)
        XCTAssertTrue(session.advisories[0].message.contains("grid is full"),
                      session.advisories[0].message)
    }

    func testOnePassBuildsWhatThePlainSessionBuilds() {
        let plain = Session {
            Track(name: "Bass") {
                Section { "| C4 - - - | D4 - - - |" }
                Section { "| E4 - - - |" }
            }
            Track(name: "Lead") { Section { "| G5 - - - |" } }
        }
        let passed = Session { _ in
            Track(name: "Bass") {
                Section { "| C4 - - - | D4 - - - |" }
                Section { "| E4 - - - |" }
            }
            Track(name: "Lead") { Section { "| G5 - - - |" } }
        }
        XCTAssertEqual(plain.tracks.map(\.name), passed.tracks.map(\.name))
        for (a, b) in zip(plain.tracks, passed.tracks) {
            XCTAssertEqual(a.sections.map(\.duration), b.sections.map(\.duration), a.name)
            XCTAssertEqual(a.sections.flatMap { $0.notes.map(\.startTime) },
                           b.sections.flatMap { $0.notes.map(\.startTime) }, a.name)
            XCTAssertEqual(a.sections.flatMap { $0.notes.compactMap(\.pitch) },
                           b.sections.flatMap { $0.notes.compactMap(\.pitch) }, a.name)
        }
    }

    func testAnAdvisorySurvivesTheSessionRoundTrip() throws {
        let session = Session { pass in
            Track(name: "Bass") { Section { pass == 0 ? "| C4 - - - |" : "| D4 - - - |" } }
        }
        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(Session.self, from: data)
        XCTAssertEqual(decoded.advisories, session.advisories)
        XCTAssertEqual(decoded.tracks, session.tracks)
    }
}

// MARK: - Samples

final class SampleTests: XCTestCase {

    func testEachSliceLabelWritesItsOwnUnit() {
        let s = Sample("amen.wav")
        XCTAssertEqual(s.slice(from: 0.5, to: 1.25).start, .seconds(0.5))
        XCTAssertEqual(s.slice(from: 0.5, to: 1.25).end, .seconds(1.25))
        XCTAssertEqual(s.slice(fraction: 0.1, to: 0.5).start, .fraction(0.1))
        XCTAssertEqual(s.slice(beats: 2, count: 1).start, .beats(2))
        XCTAssertEqual(s.slice(beats: 2, count: 1).end, .beats(3))
        XCTAssertEqual(s.slice(bars: 1, count: 0.5).end, .bars(1.5))
    }

    func testAnUnslicedSampleIsTheWholeFile() {
        let s = Sample("amen.wav")
        XCTAssertNil(s.start)
        XCTAssertNil(s.end)
    }

    func testSlicesChopTheWholeFileIntoEvenFractions() {
        let chops = Sample("amen.wav").slices(4)
        XCTAssertEqual(chops.count, 4)
        XCTAssertEqual(chops[0].start, .fraction(0))
        XCTAssertEqual(chops[0].end, .fraction(0.25))
        XCTAssertEqual(chops[3].start, .fraction(0.75))
        XCTAssertEqual(chops[3].end, .fraction(1))
        XCTAssertTrue(chops.allSatisfy { $0.file == "amen.wav" })
    }

    func testSlicesDivideTheCurrentWindowInItsOwnUnit() {
        let chops = Sample("amen.wav").slice(from: 1.0, to: 3.0).slices(2)
        XCTAssertEqual(chops[0].start, .seconds(1.0))
        XCTAssertEqual(chops[0].end, .seconds(2.0))
        XCTAssertEqual(chops[1].end, .seconds(3.0))
    }

    func testSlicesNeverAnswerFewerThanOne() {
        XCTAssertEqual(Sample("a.wav").slices(0).count, 1)
        XCTAssertEqual(Sample("a.wav").slices(-3).count, 1)
    }

    func testSlicingAgainReplacesTheWindow() {
        let s = Sample("a.wav").slice(from: 1, to: 2).slice(from: 4, to: 5)
        XCTAssertEqual(s.start, .seconds(4))
        XCTAssertEqual(s.end, .seconds(5))
    }

    func testModifiersAreCopyAndMutate() {
        let base = Sample("a.wav")
        let loud = base.gain(0.5).tune(-12).speed(2).reverse()
        XCTAssertEqual(base.gain, 1.0)
        XCTAssertEqual(base.tune, 0)
        XCTAssertFalse(base.reversed)
        XCTAssertEqual(loud.gain, 0.5)
        XCTAssertEqual(loud.tune, -12)
        XCTAssertEqual(loud.speed, 2)
        XCTAssertTrue(loud.reversed)
    }

    func testFadesAreTheAmpEnvelopesTwoEdges() {
        let s = Sample("a.wav").fade(in: 0.002, out: 0.03)
        XCTAssertEqual(s.fadeIn, 0.002, accuracy: 1e-9)
        XCTAssertEqual(s.fadeOut, 0.03, accuracy: 1e-9)
        XCTAssertEqual(Sample("a.wav").fade(in: -1).fadeIn, 0)
    }

    func testTheInsertChainKeepsItsWrittenOrder() {
        let s = Sample("a.wav").bitCrush(bits: 6).drive(2).ringMod(120)
        XCTAssertEqual(s.effects, [.bitCrush(bits: 6, rate: nil), .drive(2), .ringMod(120)])
    }

    func testBitDepthIsHeldToWhatAnIntegerSampleCanHold() {
        guard case .bitCrush(let low, _) = Sample("a.wav").bitCrush(bits: 0).effects[0],
              case .bitCrush(let high, _) = Sample("a.wav").bitCrush(bits: 99).effects[0]
        else { return XCTFail("expected a bit crusher") }
        XCTAssertEqual(low, 1)
        XCTAssertEqual(high, 24)
    }

    func testASliceSurvivesTheJSONBoundary() throws {
        let written = Sample("break.wav")
            .slice(beats: 2, count: 1)
            .fade(in: 0.002, out: 0.03)
            .gain(0.7).tune(-5).speed(1.5).reverse()
            .bitCrush(bits: 8, rate: 8000)
        let data = try JSONEncoder().encode(written)
        XCTAssertEqual(try JSONDecoder().decode(Sample.self, from: data), written)
    }
}

final class SampleKitTests: XCTestCase {

    func testKitLandsSlicesOnConsecutiveKeysFromTheGMKick() {
        let patch = Synth.kit(Sample("amen.wav").slices(4)).build()
        let kit = try? XCTUnwrap(patch.sampleKit)
        XCTAssertEqual(kit?.slices.count, 4)
        XCTAssertEqual(kit?.baseKey, 36)
        XCTAssertEqual(kit?.chromatic, false)
    }

    func testSlotZeroIsTheKitsBaseKey() {
        let patch = Synth.kit(Sample("amen.wav").slices(4)).build()
        XCTAssertEqual(DrumPiece.slot(0).midiKey, patch.sampleKit?.baseKey)
        XCTAssertEqual(DrumPiece.slot(3).midiKey, (patch.sampleKit?.baseKey ?? 0) + 3)
    }

    func testASampleTrackIsChromaticAroundItsRoot() {
        let patch = Synth.sample(Sample("hit.wav"), root: .C4).build()
        XCTAssertEqual(patch.sampleKit?.chromatic, true)
        XCTAssertEqual(patch.sampleKit?.rootKey, Pitch.C4)
        XCTAssertEqual(patch.sampleKit?.slices.count, 1)
    }

    func testAKitAttacksInstantly() {
        let patch = Synth.kit([Sample("a.wav")]).build()
        XCTAssertEqual(patch.envelope.attack, 0)
        XCTAssertEqual(patch.envelope.sustain, 1.0)
    }

    func testEditingASliceBreaksPatchEquality() {
        let a = Synth.kit([Sample("a.wav").gain(1.0)]).build()
        let b = Synth.kit([Sample("a.wav").gain(0.5)]).build()
        XCTAssertNotEqual(a, b)
        XCTAssertEqual(a, Synth.kit([Sample("a.wav").gain(1.0)]).build())
    }

    func testAKitPatchSurvivesTheJSONBoundary() throws {
        let patch = Synth.kit(Sample("amen.wav").slices(8), from: 60).build()
        let data = try JSONEncoder().encode(patch)
        XCTAssertEqual(try JSONDecoder().decode(SynthPatch.self, from: data), patch)
    }

    func testAKitNamesNeitherASoundFontNorAPlugin() {
        let patch = Synth.kit([Sample("a.wav")]).build()
        XCTAssertNil(patch.sampler)
        XCTAssertNil(patch.audioUnit)
    }
}

// MARK: - A sample as a statement
final class SampleStatementTests: XCTestCase {

    private let trumpets = Sample("trumpets1.wav")
    private let bass = Sample("bass3.wav")
    private let amen = Sample("amen.wav")

    override func setUp() {
        super.setUp()
        SampleKitCollector.reset()
        ScoreAdvisories.collected = []
    }

    private func notes(_ track: Track) -> [Note] {
        track.sections[0].notes
            .filter { $0.pitch != nil }
            .sorted { $0.startTime < $1.startTime }
    }

    func testABareSampleIsOneBarAtTheSectionStart() {
        let track = Track("t") { Section { trumpets } }
        let notes = notes(track)
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes[0].startTime, 0)
        XCTAssertEqual(notes[0].duration, TimeSignature.fourFour.barDuration)
        XCTAssertEqual(notes[0].velocity, DrumLane.hitVelocity)
        XCTAssertEqual(track.sections[0].duration, TimeSignature.fourFour.barDuration)
    }

    func testTwoSampleStatementsSoundTogether() {
        let track = Track("t") { Section { trumpets; bass } }
        let notes = notes(track)
        XCTAssertEqual(notes.count, 2)
        XCTAssertEqual(notes.map(\.startTime), [0, 0])
        XCTAssertEqual(track.sections[0].duration, TimeSignature.fourFour.barDuration)
    }

    func testAJoinedPairSoundsOneAfterTheOther() {
        let bar = TimeSignature.fourFour.barDuration
        let track = Track("t") { Section { trumpets + bass } }
        let notes = notes(track)
        XCTAssertEqual(notes.map(\.startTime), [0, bar])
        XCTAssertEqual(track.sections[0].duration, bar * 2)
    }

    func testHoldSetsTheSlotAndTheNextTakeFollowsIt() {
        let beat = 1.0 / Double(TimeSignature.fourFour.noteValue)
        let track = Track("t") { Section { trumpets.hold(beats: 2) + bass } }
        let notes = notes(track)
        XCTAssertEqual(notes[0].duration, beat * 2)
        XCTAssertEqual(notes[1].startTime, beat * 2)
    }

    func testHoldReadsAllThreeUnits() {
        let bar = TimeSignature.fourFour.barDuration
        XCTAssertEqual(notes(Track("t") { Section { trumpets.hold(bars: 2) } })[0].duration, bar * 2)
        XCTAssertEqual(notes(Track("t") { Section { trumpets.hold(beats: 1) } })[0].duration,
                       1.0 / Double(TimeSignature.fourFour.noteValue))
        XCTAssertEqual(notes(Track("t") { Section { trumpets.hold(0.25) } })[0].duration, 0.25)
    }

    func testAnArrayOfSlicesIsSerial() {
        let bar = TimeSignature.fourFour.barDuration
        let track = Track("t") { Section { amen.slices(4) } }
        let notes = notes(track)
        XCTAssertEqual(notes.count, 4)
        XCTAssertEqual(notes.map(\.startTime), [0, bar, bar * 2, bar * 3])
    }

    func testTheSameSliceClaimsOneKey() {
        let track = Track("t") { Section { trumpets + bass + trumpets } }
        let keys = notes(track).compactMap(\.pitch)
        XCTAssertEqual(keys.count, 3)
        XCTAssertEqual(keys[0], keys[2])
        XCTAssertNotEqual(keys[0], keys[1])
        XCTAssertEqual(track.instrument?.sampleKit?.laneSlices.count, 2)
    }

    func testTheTrackBuildsItsKitFromWhatItsStatementsClaimed() {
        let track = Track("t") { Section { trumpets + bass } }
        let kit = track.instrument?.sampleKit
        XCTAssertEqual(kit?.laneSlices, [trumpets, bass])
        XCTAssertEqual(kit?.laneBaseKey, SampleKitConfig.laneBase)
        let keys = notes(track).compactMap(\.pitch)
        XCTAssertEqual(keys, [SampleKitConfig.laneBase, SampleKitConfig.laneBase + 1])
    }

    func testAReelAndALaneShareATrack() {
        let track = Track("t") {
            Section {
                trumpets + bass
                Lane(amen, "x... x...")
            }
        }
        XCTAssertEqual(track.instrument?.sampleKit?.laneSlices, [trumpets, bass, amen])
        let keys = Set(notes(track).compactMap(\.pitch))
        XCTAssertEqual(keys.count, 3)
    }

    func testACurveOnPartOfAJoinDoesNotStretchOverTheRest() {
        let track = Track("t") {
            Section { (trumpets + bass).automate(.volume, over: [0: 1.0, 1: 0.0]) + amen }
        }
        let notes = notes(track)
        XCTAssertEqual(notes.count, 3)
        XCTAssertEqual(notes[0].automation?.first?.points.last?.value ?? -1, 0.5, accuracy: 0.0001)
        XCTAssertEqual(notes[1].automation?.first?.points.last?.value ?? -1, 0.0, accuracy: 0.0001)
        XCTAssertNil(notes[2].automation)
    }

    func testATrackWideCurveOnAReelReachesTheSection() {
        let track = Track("t") {
            Section { (trumpets + bass).automate(.cutoff, over: [0: 400, 1: 6000]) }
        }
        let lane = track.sections[0].automation?.first
        XCTAssertEqual(lane?.target, .cutoff)
        XCTAssertEqual(lane?.points.first?.time, 0)
        XCTAssertEqual(lane?.points.last?.time, TimeSignature.fourFour.barDuration * 2)
    }

    func testMoreSlicesThanTheBankHoldsIsReported() {
        let session = Session { Track("t") { Section { amen.slices(40) } } }
        XCTAssertTrue(session.advisories.contains { $0.message.contains("keys run out") },
                      "expected an advisory, got \(session.advisories.map(\.message))")
    }

    func testABankThatFitsSaysNothing() {
        let session = Session { Track("t") { Section { amen.slices(16) } } }
        XCTAssertTrue(session.advisories.isEmpty,
                      "unexpected advisory: \(session.advisories.map(\.message))")
    }
}
