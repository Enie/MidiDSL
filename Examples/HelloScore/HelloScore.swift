import MidiDSL

@main
struct HelloScore: Score {
    var session = Session {
        Track("Keys") {
            Section {
                "Cmaj | Gmaj | Am | Fmaj"
            }
        }

        Track("Lead") {
            Section {
                "1 2 3 5 | 5 3 2 1 | 6, 1 3 5 | 4 3 2 -".key(.C4, .major)
            }
        }

        Track("Drums", instrument: .drums(.standard)) {
            Loop(bars: 1, times: 4) { _ in
                Section {
                    Kick("x... x... x... x...")
                    Snare(".... x... .... x...")
                    Hat("x.x. x.x. x.x. x.?.")
                }
            }
        }
    }
    .tempo(120)
    .timeSignature(.fourFour)
}
