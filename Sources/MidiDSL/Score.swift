import Foundation

/// A piece of music as a program.
///
/// Mark a conforming type `@main`, and its ``session`` is what the program hands over when it runs.
/// See <doc:WhatAScoreIs>.
public protocol Score {
    init()
    var session: Session { get }
}

public extension Score {
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

        let session = build()
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
