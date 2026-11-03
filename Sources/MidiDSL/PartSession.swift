import Foundation

@_documentation(visibility: internal)
public enum PartSession {

    public static let trackName = "part"

    // MARK: - Already music

    public static func of(_ section: Section) -> Session {
        Session { Track(trackName) { section } }
    }

    public static func of(_ sections: [Section]) -> Session {
        Session { Track(trackName) { sections } }
    }

    public static func of(_ track: Track) -> Session {
        Session { track }
    }

    public static func of(_ tracks: [Track]) -> Session {
        Session { tracks }
    }

    public static func of(_ loop: Loop) -> Session {
        Session { Track(trackName) { loop } }
    }

    public static func of(_ session: Session) -> Session { session }

    public static func of<S: Score>(_ score: S) -> Session { score.session }

    // MARK: - Notes made here

    public static func of(_ notation: String) -> Session {
        oneSection { Section { notation } }
    }

    public static func of(_ notation: NotationExpression) -> Session {
        oneSection { Section { notation } }
    }

    public static func of(_ notation: JoinedNotation) -> Session {
        oneSection { Section { notation } }
    }

    public static func of(_ progression: Progression) -> Session {
        oneSection { Section { progression } }
    }

    public static func of(_ chord: Chord) -> Session {
        oneSection { Section { chord } }
    }

    public static func of(_ note: Note) -> Session {
        oneSection { Section { note } }
    }

    public static func of(_ set: NoteSet) -> Session {
        oneSection { Section { set } }
    }

    public static func of(_ lane: DrumLane) -> Session {
        oneSection { Section { lane } }
    }

    public static func of(_ sample: Sample) -> Session {
        oneSection { Section { sample } }
    }

    public static func of(_ reel: SampleReel) -> Session {
        oneSection { Section { reel } }
    }

    public static func of(_ samples: [Sample]) -> Session {
        oneSection { Section { samples } }
    }

    // MARK: - A sound rather than music

    public static func of(_ instrument: Instrument) -> Session {
        let note = Note(pitch: referencePitch(for: instrument), velocity: 100, duration: .whole)
        return Session {
            Track(trackName, instrument: instrument) { unplaceable(Section { note }) }
        }
    }

    // MARK: - Nothing to play

    public static func of<T>(_ value: T) -> Session {
        Session { nothingToPlay(String(describing: T.self)) }
    }

    static func nothingToPlay(_ typeName: String) -> [Track] {
        ScoreAdvisories.note(SessionAdvisory(
            message: "there is nothing to play in this declaration — it is a \(typeName). "
                + "A part plays a Section, a Track, notation, a drum lane, a sample, "
                + "an instrument, or a type conforming to Score."))
        return []
    }

    // MARK: - Private

    private static func oneSection(_ build: () -> Section) -> Session {
        let section = unplaceable(build())
        return Session { Track(trackName) { section } }
    }

    private static func unplaceable(_ section: Section) -> Section {
        var marked = section
        marked.notes = section.notes.map { note in
            var n = note
            n.sourceFile = generatedFile
            return n
        }
        return marked
    }

    static let generatedFile = "MidiDSL/PartSession.swift"

    private static func referencePitch(for instrument: Instrument) -> Pitch {
        if let kit = instrument.sampleKit {
            if kit.chromatic { return kit.rootKey }
            if !kit.slices.isEmpty { return kit.baseKey }
            if !kit.laneSlices.isEmpty { return kit.laneBaseKey }
        }
        return instrument.percussion ? 36 : 60
    }
}
