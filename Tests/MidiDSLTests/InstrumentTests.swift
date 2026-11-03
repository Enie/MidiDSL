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
        var replacedBySamples: String? { nil }
    }

    private struct Plugin: HostSound, Equatable {
        static let kind = "test.plugin"
        var name: String
        var replacedBySamples: String? { "plugin" }
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

    // MARK: - Samples on a track

    override func setUp() {
        super.setUp()
        SampleKitCollector.reset()
        ScoreAdvisories.collected = []
    }

    func testSamplesJoinTheTracksInstrumentAndKeepItsProgram() {
        let track = Track("t", instrument: .generalMIDI(33)) { Section { Sample("hit.wav") } }
        XCTAssertEqual(track.instrument?.program, 33)
        XCTAssertEqual(track.instrument?.sampleKit?.laneSlices, [Sample("hit.wav")])
    }

    func testSamplesThatReplaceTheSoundSaySo() {
        _ = Track("t", instrument: Instrument(name: "amp", sound: Plugin(name: "amp"))) {
            Section { Sample("hit.wav") }
        }
        XCTAssertEqual(ScoreAdvisories.collected.count, 1)
        XCTAssertTrue(ScoreAdvisories.collected[0].message.contains("plugin"))
    }

    func testAnInstrumentPlaysOnItsOwnAsAPart() {
        let session = PartSession.of(Instrument.drums())
        XCTAssertEqual(session.tracks.first?.sections.first?.notes.first?.pitch, 36, "a drum kit plays its kick")
        XCTAssertEqual(PartSession.of(Instrument.generalMIDI(0)).tracks.first?.sections.first?.notes.first?.pitch, 60)
    }
}
