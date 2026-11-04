import Foundation

/// A piece of music as a program.
///
/// Mark a conforming type `@main`, and its ``session`` is what the program hands over when it runs.
/// See <doc:WhatAScoreIs>.
///
/// ```swift
/// import MidiDSL
///
/// @main
/// struct Waltz: Score {
///     var session: Session {
///         Session {
///             Track("melody") { Section { "| 1 2 3 | 5 - - |" } }
///         }
///         .timeSignature(.threeFour)
///     }
/// }
/// ```
public protocol Score {
    /// Makes the score.
    init()
    /// The piece.
    var session: Session { get }
}

public extension Score {
    /// Builds the session and writes it out: as a MIDI file with `--midi <path>`, otherwise as
    /// JSON. See <doc:WhatAScoreIs>.
    static func main() {
        ScoreRunner.run { Self().session }
    }
}

enum ScoreRunner {

    public static func run(_ build: () -> Session) {
        let arguments = CommandLine.arguments
        if let flag = arguments.firstIndex(of: "--time-signature"), flag + 1 < arguments.count {
            let parts = arguments[flag + 1].split(separator: "/").compactMap { Int($0) }
            if parts.count == 2, parts[0] > 0, parts[1] > 0 {
                SectionBuilder.timeSignature = TimeSignature(parts[0], parts[1])
            }
        }

        if let value = path(after: "--tempo", in: arguments).flatMap(Double.init), value > 0 {
            SectionBuilder.tempo = value
        }

        if let list = path(after: "--sources-elsewhere", in: arguments) {
            SourceFiles.elsewhere = list.split(separator: ",").map(String.init)
        }
        SourceFiles.here = path(after: "--source-here", in: arguments)

        let session = Session.build(build)
        let jsonPath = path(after: "--session-json", in: arguments)

        if let midiPath = path(after: "--midi", in: arguments) {
            do {
                try MIDIFile.write(session, to: URL(fileURLWithPath: midiPath))
            } catch {
                FileHandle.standardError.write(Data("could not write \(midiPath): \(error)\n".utf8))
            }
            // Asked for a MIDI file and nothing else: leave stdout to the score.
            guard jsonPath != nil else { return }
        }

        let data: Data
        do {
            data = try JSONEncoder().encode(session)
        } catch {
            data = Data("{\"error\": \"\(error)\"}".utf8)
        }

        if let jsonPath {
            try? data.write(to: URL(fileURLWithPath: jsonPath))
        } else {
            FileHandle.standardOutput.write(data)
        }
    }

    private static func path(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }
}
