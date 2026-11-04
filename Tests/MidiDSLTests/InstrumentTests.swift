import XCTest
@testable import MidiDSL

final class InstrumentTests: XCTestCase {

    func testGeneralMIDINamesAProgram() {
        let bass = Instrument.generalMIDI(33)
        XCTAssertEqual(bass.program, 33)
        XCTAssertEqual(bass.bank, 0)
        XCTAssertFalse(bass.percussion)
    }

    func testDrumsArePercussionAndTheKitIsTheProgram() {
        let kit = Instrument.drums(.jazz)
        XCTAssertTrue(kit.percussion)
        XCTAssertEqual(kit.program, DrumKit.jazz.rawValue)
    }

    func testTheProgramIsClampedToTheByte() {
        XCTAssertEqual(Instrument("x", program: 300).program, 127)
        XCTAssertEqual(Instrument("x", program: -3).program, 0)
    }

    func testATrackKeepsItsInstrument() {
        let track = Track("bass", instrument: .generalMIDI(33)) { Section { "C3" } }
        XCTAssertEqual(track.instrument, .generalMIDI(33))
        XCTAssertEqual(Track("bass") { Section { "C3" } }.instrument(.generalMIDI(38)).instrument?.program, 38)
    }

    func testTheMIDIHalfSurvivesJSON() throws {
        let instrument = Instrument("strings", program: 48, bank: 2)
        let decoded = try JSONDecoder().decode(Instrument.self, from: JSONEncoder().encode(instrument))
        XCTAssertEqual(decoded, instrument)
    }

    // MARK: - A host's own sound

    private struct Tone: HostSound, Equatable {
        static let kind = "test.tone"
        var waveform: String
    }

    private struct Plugin: HostSound, Equatable {
        static let kind = "test.plugin"
        var name: String
    }

    func testAHostSoundIsReadBackByAReaderThatKnowsIt() throws {
        let instrument = Instrument(name: "lead", program: 81, sound: Tone(waveform: "saw"))
        let decoder = JSONDecoder()
        decoder.userInfo[.hostSounds] = HostSounds([Tone.self])
        let decoded = try decoder.decode(Instrument.self, from: JSONEncoder().encode(instrument))
        XCTAssertEqual(decoded.sound as? Tone, Tone(waveform: "saw"))
        XCTAssertEqual(decoded, instrument)
    }

    func testAReaderThatDoesNotKnowTheSoundKeepsTheMIDIHalf() throws {
        let instrument = Instrument(name: "lead", program: 81, sound: Tone(waveform: "saw"))
        let decoded = try JSONDecoder().decode(Instrument.self, from: JSONEncoder().encode(instrument))
        XCTAssertNil(decoded.sound)
        XCTAssertEqual(decoded.program, 81)
    }

    func testTheSoundIsPartOfEquality() {
        XCTAssertNotEqual(Instrument(name: "a", sound: Tone(waveform: "saw")),
                          Instrument(name: "a", sound: Tone(waveform: "sine")))
        XCTAssertNotEqual(Instrument(name: "a", sound: Tone(waveform: "saw")), Instrument(name: "a"))
        XCTAssertEqual(Instrument(name: "a", sound: Tone(waveform: "saw")),
                       Instrument(name: "a", sound: Tone(waveform: "saw")))
    }

    // MARK: - Sounds on keys of their own

    private struct Hit: KeyedSound, Equatable, NoteSource {
        var file: String
        var keyName: String { file }
        static func adopt(_ claims: [KeyedClaim], into instrument: Instrument?, track: String) -> Instrument? {
            var adopted = instrument ?? Instrument("kit")
            adopted.name += "+" + claims.map { "\($0.key):\(($0.sound as! Hit).file)" }.joined(separator: ",")
            return adopted
        }
        func notes() -> [Note] {
            [Note(pitch: TrackKeys.claim(self), velocity: DrumLane.hitVelocity, startTime: 0, duration: 0.25)]
        }
    }

    override func setUp() {
        super.setUp()
        TrackKeys.reset()
        ScoreAdvisories.collected = []
    }

    func testAHostStatementBecomesStampedNotes() {
        let section = Section { Hit(file: "a.wav") }
        XCTAssertEqual(section.notes.first?.pitch, TrackKeys.firstKey)
        XCTAssertNotNil(section.notes.first?.sourceLine)
    }

    func testEachDistinctSoundClaimsTheNextKeyAndTheSameOneKeepsIt() {
        let track = Track("t") {
            Section { Hit(file: "a.wav"); Hit(file: "b.wav"); Hit(file: "a.wav") }
        }
        XCTAssertEqual(Set(track.sections[0].notes.compactMap(\.pitch)), [96, 97])
        XCTAssertEqual(track.instrument?.name, "kit+96:a.wav,97:b.wav")
    }

    func testTheClaimsFoldIntoTheWrittenInstrumentAndEachTrackStartsAgain() {
        let session = Session {
            Track("bass", instrument: .generalMIDI(33)) { Section { Hit(file: "a.wav") } }
            Track("other") { Section { Hit(file: "b.wav") } }
        }
        XCTAssertEqual(session.tracks[0].instrument?.program, 33)
        XCTAssertEqual(session.tracks[0].instrument?.name, "program 33+96:a.wav")
        XCTAssertEqual(session.tracks[1].instrument?.name, "kit+96:b.wav")
    }

    func testATrackThatClaimsNothingKeepsItsInstrument() {
        XCTAssertNil(Track("t") { Section { "C3" } }.instrument)
    }

    func testRunningOutOfKeysIsReported() {
        _ = Track("t") { Section { for i in 0..<40 { Hit(file: "\(i).wav") } } }
        XCTAssertTrue(ScoreAdvisories.collected.contains { $0.message.contains("keys run out") })
    }

    // MARK: - Which file a note was written in

    func testByDefaultEveryFileIsTheTextsOwn() {
        XCTAssertNil(SourceFiles.stamp("Score/Voices.swift"))
    }

    func testAHostNamesTheFilesThatAreElsewhere() {
        SourceFiles.elsewhere = ["Library/", "Score/"]
        SourceFiles.here = "Score/main_"
        defer { SourceFiles.elsewhere = []; SourceFiles.here = nil }
        XCTAssertNil(SourceFiles.stamp("Score/main_1.swift"), "the text being read")
        XCTAssertEqual(SourceFiles.stamp("Score/Voices.swift"), "Score/Voices.swift")
        XCTAssertEqual(SourceFiles.stamp("Library/Kit.swift"), "Library/Kit.swift")
        XCTAssertNil(SourceFiles.stamp("Tests/Fixture.swift"), "a file nobody named is the text's own")
    }
}
