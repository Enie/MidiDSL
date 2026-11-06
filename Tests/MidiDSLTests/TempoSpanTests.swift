import XCTest
@testable import MidiDSL

/// A section at a tempo of its own says so, for a host that keeps a beat.
final class TempoSpanTests: XCTestCase {

    private func build(_ make: () -> Session) -> Session { Session.build(make) }

    func testASectionAtItsOwnTempoCarriesOneSpanOverItsWholeLength() {
        let session = build {
            Session {
                Track("lead") {
                    Section { "| 1 2 3 5 |" }
                    Section { "| 5 3 2 1 |" }.tempo(60)
                }
            }
            .tempo(120)
        }
        let sections = session.tracks[0].sections
        XCTAssertNil(sections[0].tempoSpans, "a section at the session's speed says nothing")
        XCTAssertEqual(sections[1].tempoSpans, [TempoSpan(start: 0, end: 2, ratio: 0.5)],
                       "one bar at half speed takes two bars' time")
    }

    func testANestedTempoComposesAndComesFirst() {
        SectionBuilder.tempo = 120
        defer { SectionBuilder.tempo = Session.defaultTempo }
        let section = Section {
            "| 1 2 3 5 |"
            Section { "| 5 3 2 1 |" }.tempo(60)
        }
        .tempo(60)
        XCTAssertEqual(section.tempoSpans, [
            TempoSpan(start: 0, end: 4, ratio: 0.25),
            TempoSpan(start: 0, end: 4, ratio: 0.5),
        ], "half speed inside half speed is a quarter, and the innermost span is first")
    }

    func testModifiersThatMoveNotesLeaveTheSpansAlone() {
        SectionBuilder.tempo = 120
        defer { SectionBuilder.tempo = Session.defaultTempo }
        let slow = Section { "| 1 2 3 5 |" }.tempo(60)
        let expected = [TempoSpan(start: 0, end: 2, ratio: 0.5)]
        XCTAssertEqual(slow.durations(.n8, .n8).tempoSpans, expected)
        XCTAssertEqual(slow.noteDuration(.n8).tempoSpans, expected)
        XCTAssertEqual(slow.swing().velocity(90).tempoSpans, expected)
        XCTAssertEqual(slow.scalingTime(by: 0.5).tempoSpans, [TempoSpan(start: 0, end: 1, ratio: 0.5)],
                       "a player converting to seconds stretches the span with the notes")
    }

    func testALoopCutsASlowRoundAtItsGrid() {
        let session = build {
            Session {
                Track("lead") {
                    Loop(bars: 1, times: 2) { _ in
                        Section { "| 1 2 3 5 |" }.tempo(60)
                    }
                }
            }
            .tempo(120)
        }
        let spans = session.tracks[0].sections.compactMap(\.tempoSpans)
        XCTAssertEqual(spans, [[TempoSpan(start: 0, end: 1, ratio: 0.5)],
                               [TempoSpan(start: 0, end: 1, ratio: 0.5)]],
                       "each one-bar round keeps one bar of its half-speed stretch")
    }

    func testTheSpansSurviveTheJSONAndAnOlderScoreDecodesWithout() throws {
        let session = build {
            Session { Track("lead") { Section { "| 1 2 |" }.tempo(90) } }.tempo(120)
        }
        let decoded = try JSONDecoder().decode(Session.self, from: JSONEncoder().encode(session))
        XCTAssertEqual(decoded.tracks[0].sections[0].tempoSpans, session.tracks[0].sections[0].tempoSpans)

        var plain = try XCTUnwrap(JSONSerialization.jsonObject(
            with: JSONEncoder().encode(Section { "C D" })) as? [String: Any])
        plain.removeValue(forKey: "tempoSpans")
        let older = try JSONDecoder().decode(Section.self, from: JSONSerialization.data(withJSONObject: plain))
        XCTAssertNil(older.tempoSpans)
    }

    func testTheSpeedDoesNotChangeWhatSounds() {
        let session = build {
            Session { Track("lead") { Section { "| 5 3 2 1 |" }.tempo(60) } }.tempo(120)
        }
        XCTAssertEqual(session.tracks[0].sections[0].notes.map(\.startTime), [0, 0.5, 1, 1.5],
                       "the notes are placed at the speed, as they always were")
        XCTAssertFalse(session.tracks[0].sections[0].notes.contains { $0.carriedTempoSpans != nil },
                       "nothing is left riding on a note")
    }
}
