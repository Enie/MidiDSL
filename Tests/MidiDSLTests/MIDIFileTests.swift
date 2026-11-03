import XCTest
import MidiDSL

// Tests against the public API only, the way a package user writes a MIDI file.

final class MIDIFileStructureTests: XCTestCase {

    private var session: Session {
        Session {
            Track("keys") { Section { "C D E F" } }
            Track("bass") { Section { "C3 - G3 -" } }
        }
        .tempo(90)
    }

    /// The file split into its chunks: (type, body).
    private func chunks(_ data: Data) -> [(String, Data)] {
        var result: [(String, Data)] = []
        var i = data.startIndex
        while i + 8 <= data.endIndex {
            let type = String(decoding: data[i..<i + 4], as: UTF8.self)
            let length = data[i + 4..<i + 8].reduce(0) { $0 << 8 | Int($1) }
            result.append((type, data[i + 8..<i + 8 + length]))
            i += 8 + length
        }
        return result
    }

    func testAFormatOneFileWithAConductorAndOneTrackPerTrack() {
        let parts = chunks(MIDIFile.data(for: session))
        XCTAssertEqual(parts.map(\.0), ["MThd", "MTrk", "MTrk", "MTrk"])
        let header = Array(parts[0].1)
        XCTAssertEqual(header, [0, 1, 0, 3, 0x01, 0xE0], "format 1, three tracks, 480 ticks per quarter")
    }

    func testTheConductorCarriesTempoAndMeter() {
        let conductor = Array(chunks(MIDIFile.data(for: session))[1].1)
        let usPerQuarter = 60_000_000 / 90
        let tempo: [UInt8] = [0xFF, 0x51, 0x03,
                              UInt8(usPerQuarter >> 16 & 0xFF), UInt8(usPerQuarter >> 8 & 0xFF), UInt8(usPerQuarter & 0xFF)]
        XCTAssertNotNil(conductor.firstRange(of: tempo))
        XCTAssertNotNil(conductor.firstRange(of: [0xFF, 0x58, 0x04, 4, 2]), "4/4")
    }

    func testEachTrackIsNamedAndOnItsOwnChannel() {
        let parts = chunks(MIDIFile.data(for: session))
        for (index, name) in ["keys", "bass"].enumerated() {
            let body = Array(parts[index + 2].1)
            XCTAssertNotNil(body.firstRange(of: [0xFF, 0x03, UInt8(name.utf8.count)] + Array(name.utf8)))
            XCTAssertTrue(body.contains(0x90 | UInt8(index)), "\(name) plays note-ons on channel \(index + 1)")
        }
    }

    func testTheDrumChannelIsSkipped() {
        let tracks = (0..<11).map { Track("t\($0)") { Section { "C" } } }
        let parts = chunks(MIDIFile.data(for: Session { tracks }))
        let tenth = Array(parts[11].1)
        XCTAssertTrue(tenth.contains(0x9A), "the tenth track goes to channel 11, not the drum channel")
    }

    func testAnInstrumentOpensItsTrackWithAProgramChange() {
        let parts = chunks(MIDIFile.data(for: Session {
            Track("bass", instrument: .generalMIDI(33)) { Section { "C3" } }
        }))
        let body = Array(parts[2].1)
        let programAt = body.firstRange(of: [0xC0, 33])
        XCTAssertNotNil(programAt, "program 33 on the track's channel")
        XCTAssertLessThan(programAt!.lowerBound, body.firstIndex(of: 0x90)!, "before the first note")
    }

    func testABankIsSelectedBeforeTheProgram() {
        let events = MIDIFile.trackEvents(
            for: Track("strings", instrument: .generalMIDI(48, bank: 130)) { Section { "C" } },
            loops: 1, loopTicks: 1920, tempo: 120)
        XCTAssertEqual(Array(events.prefix(3).map(\.kind)), [
            .controller(number: 0, value: 1),
            .controller(number: 32, value: 2),
            .programChange(program: 48),
        ])
    }

    func testATrackWithoutAnInstrumentSendsNoProgram() {
        let events = MIDIFile.trackEvents(for: Track("keys") { Section { "C" } },
                                          loops: 1, loopTicks: 1920, tempo: 120)
        XCTAssertFalse(events.contains { if case .programChange = $0.kind { true } else { false } })
    }

    func testDrumsGoOnChannelTenAndTheOthersCloseAroundThem() {
        let parts = chunks(MIDIFile.data(for: Session {
            Track("keys") { Section { "C" } }
            Track("drums", instrument: .drums(.tr808)) { Section { Kick("x...") } }
            Track("bass") { Section { "C3" } }
        }))
        XCTAssertNotNil(Array(parts[2].1).firstIndex(of: 0x90), "keys on channel 1")
        XCTAssertNotNil(Array(parts[3].1).firstRange(of: [0xC9, UInt8(DrumKit.tr808.rawValue)]),
                        "the kit is chosen on channel 10")
        XCTAssertNotNil(Array(parts[3].1).firstIndex(of: 0x99), "drums play on channel 10")
        XCTAssertNotNil(Array(parts[4].1).firstIndex(of: 0x91), "bass takes channel 2")
    }

    func testLoopsDefaultsToTheSessionsForm() {
        let form = Session { Track("t") { Section { "C D E F" } } }.loops(3)
        let noteOns = { (data: Data) in data.filter { $0 == 0x90 }.count }
        XCTAssertEqual(noteOns(MIDIFile.data(for: form)), noteOns(MIDIFile.data(for: form, loops: 3)))
        XCTAssertGreaterThan(noteOns(MIDIFile.data(for: form)), noteOns(MIDIFile.data(for: form, loops: 1)))
    }

    func testWriteWritesTheSameBytes() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mididsl-\(UUID()).mid")
        defer { try? FileManager.default.removeItem(at: url) }
        try MIDIFile.write(session, to: url)
        XCTAssertEqual(try Data(contentsOf: url), MIDIFile.data(for: session))
    }

    func testAMutedTrackKeepsItsSlotAndPlaysNothing() {
        let muted = Session {
            Track("a") { Section { "C D" } }.mute()
            Track("b") { Section { "E F" } }
        }
        let events = MIDIFile.trackEvents(for: muted.tracks[0], loops: 1,
                                          loopTicks: MIDIFile.loopLengthTicks(for: muted), tempo: 120)
        XCTAssertTrue(events.isEmpty)
        XCTAssertEqual(chunks(MIDIFile.data(for: muted)).count, 4, "the muted track still has its chunk")
    }
}

final class MIDIFilePitchBendTests: XCTestCase {

    private func events(for session: Session, loopCount: Int = 1) -> [MIDIFile.TrackEvent] {
        MIDIFile.trackEvents(for: session.tracks[0],
                             loops: loopCount,
                             loopTicks: MIDIFile.loopLengthTicks(for: session),
                             tempo: session.tempo ?? 120.0)
    }

    private func bends(_ events: [MIDIFile.TrackEvent]) -> [(tick: Int, value: UInt16)] {
        events.compactMap {
            if case .pitchBend(let value) = $0.kind { return ($0.tick, value) }
            return nil
        }
    }

    func testOctaveGlissandoExportsAsBendCurve() {
        let session = Session {
            Track(name: "lead") { Section { "C >=C6" } }
        }
        let evs = events(for: session)

        let expectedSetup: [MIDIFile.TrackEvent.Kind] = [
            .controller(number: 101, value: 0),
            .controller(number: 100, value: 0),
            .controller(number: 6, value: 12),
            .controller(number: 38, value: 0),
        ]
        XCTAssertEqual(Array(evs.prefix(4).map(\.kind)), expectedSetup)
        XCTAssertTrue(evs.prefix(4).allSatisfy { $0.tick == 0 })

        let noteOns = evs.filter { if case .noteOn = $0.kind { return true }; return false }
        XCTAssertEqual(noteOns.count, 1)
        XCTAssertEqual(noteOns[0].kind, .noteOn(note: 72, velocity: 100))
        XCTAssertEqual(noteOns[0].tick, 0)

        let curve = bends(evs)
        XCTAssertEqual(curve.first?.tick, 0)
        XCTAssertEqual(curve.first?.value, 0)
        XCTAssertGreaterThanOrEqual(curve.count, 16)
        XCTAssertEqual(curve.max(by: { $0.value < $1.value })?.value, 8192)
        for (a, b) in zip(curve, curve.dropFirst()) {
            XCTAssertLessThanOrEqual(a.tick, b.tick)
            XCTAssertLessThanOrEqual(a.value, b.value, "bend curve must rise monotonically")
        }
        XCTAssertTrue(curve.dropFirst().dropLast().allSatisfy { $0.tick >= 1920 && $0.tick < 3840 })

        guard let offIndex = evs.firstIndex(where: {
            if case .noteOff(note: 72) = $0.kind { return true }; return false
        }) else { return XCTFail("missing note-off") }
        XCTAssertEqual(evs[offIndex].tick, 3840)
        let reset = evs[(offIndex + 1)...].first {
            if case .pitchBend(value: 8192) = $0.kind { return true }; return false
        }
        XCTAssertNotNil(reset, "bend must reset to 8192 center after note-off")
        XCTAssertEqual(reset?.tick, 3840)
    }

    func testPlainNotesEmitNoBendMachinery() {
        let session = Session {
            Track(name: "keys") { Section { "C D E F" } }
        }
        let evs = events(for: session)
        XCTAssertTrue(bends(evs).isEmpty)
        XCTAssertFalse(evs.contains { if case .controller = $0.kind { return true }; return false })
        let noteOns = evs.filter { if case .noteOn = $0.kind { return true }; return false }
        XCTAssertEqual(noteOns.count, 4)
    }

    func testOverlappingDifferentRampsFallBackToReattack() {
        var sliding = Note(pitch: 64, velocity: 100, startTime: 0, duration: 1.0)
        sliding.slides = [SlideStep(from: 60, at: 0, over: 0.5)]
        let held = Note(pitch: 43, velocity: 100, startTime: 0, duration: 1.0)
        let session = Session {
            Track(name: "clash") { Section(notes: [sliding, held]) }
        }
        let evs = events(for: session)

        XCTAssertTrue(bends(evs).isEmpty, "no bends may hit the channel while the plain note sounds")
        XCTAssertFalse(evs.contains { if case .controller = $0.kind { return true }; return false })
        let onNotes = evs.compactMap { if case .noteOn(let n, _) = $0.kind { return n }; return nil as UInt8? }
        XCTAssertEqual(onNotes.sorted(), [43, 60, 64])
    }

    func testParallelChordSlideSharesOneBendCurve() {
        let session = Session {
            Track(name: "pad") { Section { "Cmaj>Dmaj" } }
        }
        let evs = events(for: session)

        let noteOns = evs.filter { if case .noteOn = $0.kind { return true }; return false }
        XCTAssertEqual(noteOns.count, 3, "each chord voice sustains, no re-attacks")
        let curve = bends(evs)
        XCTAssertFalse(curve.isEmpty)
        XCTAssertEqual(curve.first?.value, 0)
        for (a, b) in zip(curve, curve.dropFirst()) where a.tick < 480 {
            XCTAssertLessThanOrEqual(a.value, b.value)
        }
        XCTAssertTrue(evs.contains { $0.kind == .controller(number: 6, value: 2) })
    }

    func testAVolumeCurveBecomesExpression() {
        let session = Session {
            Track("swell") { Section { "C - - -".automate(.volume, over: [0: 0, 1: 1]) } }
        }
        let expression = events(for: session).compactMap {
            if case .controller(number: 11, let value) = $0.kind { return value }
            return nil
        }
        XCTAssertFalse(expression.isEmpty)
        XCTAssertEqual(expression.first, 0)
        XCTAssertEqual(expression.last, 127, "expression is restored when the curve ends")
    }
}

final class SectionShuffleTests: XCTestCase {

    private var session: Session {
        Session {
            Track(name: "t") {
                Section(notes: [Note(pitch: 60, velocity: 100, startTime: 0, duration: 1.0)])
                Section(notes: [Note(pitch: 64, velocity: 100, startTime: 0, duration: 1.0)])
                Section(notes: [Note(pitch: 67, velocity: 100, startTime: 0, duration: 1.0)])
            }
            .shuffleSections()
        }
        .tempo(120)
    }

    func testPassZeroIsIdentityAndLaterPassesShuffle() {
        XCTAssertEqual(SectionShuffle.permutation(loopIndex: 0, count: 5), [0, 1, 2, 3, 4],
                       "the piece introduces itself as written")
        var sawNonIdentity = false
        for loopIndex in 1...6 {
            let perm = SectionShuffle.permutation(loopIndex: loopIndex, count: 5)
            XCTAssertEqual(perm.sorted(), [0, 1, 2, 3, 4], "every pass plays every section once")
            XCTAssertEqual(perm, SectionShuffle.permutation(loopIndex: loopIndex, count: 5),
                           "same pass, same order — deterministic")
            if perm != [0, 1, 2, 3, 4] { sawNonIdentity = true }
        }
        XCTAssertTrue(sawNonIdentity, "later passes actually reshuffle")
    }

    func testWindowsRecoverSerialLayout() {
        let windows = SectionShuffle.windows(of: session.tracks[0].sections)
        XCTAssertEqual(windows.map(\.start), [0, 1, 2])
        XCTAssertEqual(windows.map(\.duration), [1, 1, 1])
    }

    func testShuffledStartsAreAPermutationOfSlots() {
        let windows = SectionShuffle.windows(of: session.tracks[0].sections)
        for loopIndex in 0...4 {
            let starts = SectionShuffle.shuffledStarts(windows: windows, loopIndex: loopIndex)
            XCTAssertEqual(starts.sorted(), [0, 1, 2], "sections land on the same slot grid")
            for (i, window) in windows.enumerated() {
                let writtenPos = window.start + 0.25
                let shuffledPos = writtenPos - window.start + starts[i]
                XCTAssertEqual(SectionShuffle.writtenPosition(shuffledPos, windows: windows, loopIndex: loopIndex),
                               writtenPos, accuracy: 1e-9)
            }
        }
    }
}

final class MIDIRampTests: XCTestCase {

    // MARK: bendValue scaling

    func testCenterAndExtremes() {
        XCTAssertEqual(MIDIRamp.bendValue(semitones: 0), 8192)
        XCTAssertEqual(MIDIRamp.bendValue(semitones: MIDIRamp.bendRangeSemitones), 16383)
        XCTAssertEqual(MIDIRamp.bendValue(semitones: -MIDIRamp.bendRangeSemitones), 0)
    }

    func testLinearScalingWithinRange() {
        XCTAssertEqual(MIDIRamp.bendValue(semitones: 12), 12288)
        XCTAssertEqual(MIDIRamp.bendValue(semitones: -12), 4096)
        XCTAssertEqual(MIDIRamp.bendValue(semitones: 1), 8533)
    }

    func testClampBeyondBendRange() {
        XCTAssertEqual(MIDIRamp.bendValue(semitones: 48), 16383)
        XCTAssertEqual(MIDIRamp.bendValue(semitones: -48), 0)
    }

    // MARK: rampOffset

    func testRampOffsetFlatBeforeFirstBreakpoint() {
        let ramp = [PitchRampPoint(time: 0.5, semitones: -4),
                    PitchRampPoint(time: 0.6, semitones: 0)]
        XCTAssertEqual(MIDIRamp.rampOffset(ramp, elapsed: 0.0), -4)
        XCTAssertEqual(MIDIRamp.rampOffset(ramp, elapsed: 0.49), -4)
    }

    func testRampOffsetInterpolatesLinearly() {
        let ramp = [PitchRampPoint(time: 0.0, semitones: -4),
                    PitchRampPoint(time: 1.0, semitones: 0)]
        XCTAssertEqual(MIDIRamp.rampOffset(ramp, elapsed: 0.5), -2, accuracy: 1e-6)
        XCTAssertEqual(MIDIRamp.rampOffset(ramp, elapsed: 0.25), -3, accuracy: 1e-6)
    }

    func testRampOffsetZeroAfterLastBreakpoint() {
        let ramp = [PitchRampPoint(time: 0.0, semitones: -4),
                    PitchRampPoint(time: 0.1, semitones: 0)]
        XCTAssertEqual(MIDIRamp.rampOffset(ramp, elapsed: 5.0), 0)
    }

    func testRampOffsetMultiStage() {
        let ramp = [PitchRampPoint(time: 0.0, semitones: -4),
                    PitchRampPoint(time: 0.2, semitones: -2),
                    PitchRampPoint(time: 0.2, semitones: -2),
                    PitchRampPoint(time: 0.4, semitones: 0)]
        XCTAssertEqual(MIDIRamp.rampOffset(ramp, elapsed: 0.1), -3, accuracy: 1e-6)
        XCTAssertEqual(MIDIRamp.rampOffset(ramp, elapsed: 0.3), -1, accuracy: 1e-6)
    }

    // MARK: bendEvents — the stepped stream

    func testBendEventsStartAtSourcePitchAndEndCentered() {
        let ramp = [PitchRampPoint(time: 0.0, semitones: -4),
                    PitchRampPoint(time: 0.08, semitones: 0)]
        let events = MIDIRamp.bendEvents(ramp: ramp)
        XCTAssertEqual(events.first?.time, 0.0)
        XCTAssertEqual(events.first?.value, MIDIRamp.bendValue(semitones: -4))
        XCTAssertEqual(events.last?.time ?? -1, 0.08, accuracy: 1e-9)
        XCTAssertEqual(events.last?.value, MIDIRamp.center)
    }

    func testBendEventsStepGranularityAndMonotonicity() {
        let ramp = [PitchRampPoint(time: 0.0, semitones: -12),
                    PitchRampPoint(time: 1.0, semitones: 0)]
        let events = MIDIRamp.bendEvents(ramp: ramp)
        XCTAssertGreaterThan(events.count, 150)
        for pair in zip(events, events.dropFirst()) {
            XCTAssertLessThan(pair.0.time, pair.1.time)
            XCTAssertLessThan(pair.0.value, pair.1.value)
            XCTAssertLessThanOrEqual(pair.1.time - pair.0.time,
                                     MIDIRamp.stepInterval + 1e-9)
        }
    }

    func testBendEventsDeduplicateFlatStretch() {
        let ramp = [PitchRampPoint(time: 0.5, semitones: -2),
                    PitchRampPoint(time: 0.58, semitones: 0)]
        let events = MIDIRamp.bendEvents(ramp: ramp)
        XCTAssertEqual(events.first?.time, 0.0)
        let beforeSlide = events.filter { $0.time > 0 && $0.time < 0.5 }
        XCTAssertTrue(beforeSlide.isEmpty)
        for pair in zip(events, events.dropFirst()) {
            XCTAssertNotEqual(pair.0.value, pair.1.value)
        }
        XCTAssertEqual(events.last?.value, MIDIRamp.center)
    }

    func testBendEventsEmptyRamp() {
        XCTAssertTrue(MIDIRamp.bendEvents(ramp: []).isEmpty)
    }

    func testBendEventsClampRampBeyondBendRange() {
        let ramp = [PitchRampPoint(time: 0.0, semitones: -30),
                    PitchRampPoint(time: 0.5, semitones: 0)]
        let events = MIDIRamp.bendEvents(ramp: ramp)
        XCTAssertEqual(events.first?.value, 0)
        XCTAssertTrue(events.allSatisfy { $0.value <= 16383 })
        XCTAssertEqual(events.last?.value, MIDIRamp.center)
    }

    // MARK: end-to-end with the shared ramp builder

    func testPitchRampPointsFeedBendEvents() {
        let slides = [SlideStep(from: 48, at: 0.0, over: 0.1)]
        let ramp = pitchRampPoints(slides: slides, duration: 0.5, finalPitch: 60)
        let events = MIDIRamp.bendEvents(ramp: ramp)
        XCTAssertEqual(events.first?.value, MIDIRamp.bendValue(semitones: -12))
        XCTAssertEqual(events.last?.value, MIDIRamp.center)
        XCTAssertEqual(events.last?.time ?? -1, 0.1, accuracy: 1e-9)
        let mid = events.min { abs($0.time - 0.05) < abs($1.time - 0.05) }!
        let expected = MIDIRamp.bendValue(
            semitones: MIDIRamp.rampOffset(ramp, elapsed: mid.time))
        XCTAssertEqual(mid.value, expected)
    }

    // MARK: what a ramp does and does not send

    func testARampThatNeverMovesThePitchBendsNothing() {
        let still = [PitchRampPoint(time: 0, semitones: 0), PitchRampPoint(time: 1, semitones: 0, amp: 0.5)]
        XCTAssertTrue(MIDIRamp.bendEvents(ramp: still).isEmpty)
        XCTAssertFalse(MIDIRamp.expressionEvents(ramp: still).isEmpty)
    }

    func testAGlideEndsOnItsTarget() {
        let glide = pitchRampPoints(slides: [SlideStep(from: 60, at: 0, over: 0.5)], duration: 1, finalPitch: 72)
        XCTAssertEqual(glide.first?.semitones, -12)
        XCTAssertEqual(glide.last?.semitones, 0)
        XCTAssertEqual(MIDIRamp.bendEvents(ramp: glide).last?.value, MIDIRamp.center)
    }
}
