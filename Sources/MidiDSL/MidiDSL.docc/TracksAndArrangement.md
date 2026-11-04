# Tracks and Arrangement

One instrument's part, and when it plays across the passes.

## Overview

A ``Track`` is one instrument on one MIDI channel. Its sections play one after another.

```swift
Track("melody") { … }                                  // the player's default sound
Track("bass", instrument: .generalMIDI(33)) { … }      // fingered electric bass
Track("drums", instrument: .drums(.tr808)) { … }       // a drum kit, on channel 10
```

The name labels the track in an exported MIDI file, so keep it distinct. Without an instrument, a player uses its default sound and a MIDI file sends no program change. ``Track/instrument(_:)`` sets the instrument after the block instead. See <doc:Instruments>.

Two words name two different repetitions:

- term pass: One time through the whole piece. Every track goes round with it. ``Session/loops(_:)`` says how many passes the form has, and `.active(loops:)` picks passes.
- term round: One time round a ``Loop``, inside one track. A loop's rounds can be shorter than a pass: a two-bar groove under a sixteen-bar melody goes round eight times in one pass.

Both count from 0.

## Sound

``Track/volume(_:)`` sets the track's level against the others, from `0` to `1`. It multiplies into every note's velocity together with ``Session/volume(_:)``. ``Track/key(_:_:)`` reads the track's degrees in a key; a key on a section or a line inside it wins.

```swift
Track("bass", instrument: .generalMIDI(33)) { … }
    .key(.C3, .minor)
    .volume(0.8)
```

``Track/automate(_:over:curve:)`` moves a parameter across the whole track, so the curve spans its sections instead of starting again in each one. `over:` measures time as a fraction of the track, `bars:` in the bars you count from the top of the piece:

```swift
Track("pad") { … }.automate(.volume, over: [0: 0, 0.25: 1, 1: 0])
Track("bass") { … }.automate(.cutoff, bars: [0: 300, 8: 5000])
```

A section that moves the same parameter keeps its own curve. Two volume curves multiply, so a section that fades inside a track that fades does both. See <doc:Automation>.

``Track/mute(_:)`` silences a track. It keeps its place, so the other tracks keep their MIDI channels.

## Repeating: Loop

A ``Loop`` plays its body again and again inside a track, each round on a grid of `bars` bars. Anything outside a loop plays once, straight through.

```swift
Session {
    Track("drums", instrument: .drums()) {
        Loop(bars: 2) { round in                 // as long as the piece
            Section { Kick("x..x"); Snare("..x.") }
            if round % 4 == 3 { Section { Crash("x...") } }
        }
    }
    Track("bass") {
        Loop(bars: 4, times: 8) { _ in Section { "| 1 1 5 5 |" } }
    }
    Track("voice") {                             // no loop: written once
        Section { "| 1 2 3 4 | 5 - - - |" }
        Section { "| 5 6 7 1' | 1' - - - |" }
    }
}
```

A round always takes its bars exactly. A body that builds nothing is silent for them, which is how a part drops out without moving anything under it, and a body that runs longer is cut off. Without `times:`, the loop runs as long as the longest part written out in full, so adding a phrase to the melody lengthens the groove under it.

The body is an ordinary Swift closure handed the round number, so `if round == 0` and `if round % 4 == 3` choose what each round plays. The dice roll separately in every round, so a `?` step or a note set varies from round to round as well as from pass to pass.

## The form: passes

A session's body can take the pass number. It is read once per pass, so a track can change from one time through the piece to the next:

```swift
Session { pass in
    Track("drums", instrument: .drums()) {
        Loop(bars: 1) { _ in Section { Kick("x..x"); Snare("..x.") } }
    }
    Track("bass") {
        Section { pass < 2 ? "| 1 1 5 5 |" : "| 1 b3 4 5 |" }
    }
}
.loops(4)
```

``Session/loops(_:)`` says how many passes the form has; a player goes round and round through them. Without it the form is as long as the arrangement asks for, and a body that reads `pass` without `.loops` is warned about, since its form would be a single pass.

Vary the material between passes, and write the sound once: a track's instrument, volume and section order belong to the track, and the score warns when two passes disagree about them.

A ternary and an `if` play the same. They differ only for an editor that maps notes back to the text: two branches written identically cannot be told apart, so write those as `if`/`else`.

A loop's round and the session's pass can be read together:

```swift
Session { pass in
    Track("drums", instrument: .drums()) {
        Loop(bars: 1) { round in
            Section { Kick("x..x") }
            if pass == 3 && round % 2 == 1 { Section { Crash("x...") } }
        }
    }
}
.loops(4)
```

## When a track plays

`.active` plays a track, or a section, on some passes only. It takes a range, a list, or a period:

```swift
Track("lead") { … }.active(loops: 2...)        // from the third pass on
Track("pad") { … }.active(loops: [0, 1, 4])    // the first, second and fifth
Section { "| Cm7~= - - - |" }.active(every: 4) // passes 0, 4, 8, …
```

On an inactive pass the track is silent and the time goes on; a section's time stays reserved. All the gates compose: a note sounds only if its nested section, its section and its track all play on the pass.

``Track/shuffleSections()`` plays the sections in a new order on every pass after the first. The order comes from ``Dice``: it is the same on every build, and tracks with the same number of sections shuffle alike, so they stay together. ``Track/shuffleSections(loops:)-4i8nk`` shuffles only the passes you name, so a fixed opener and closer can bracket the passes that move.

```swift
Track("melody") { … }.shuffleSections()
Track("drums") { … }.shuffleSections(loops: [1, 2, 4, 5])
```

A track curve is laid onto the sections, so a shuffled pass plays the curve shuffled with them.

## Topics

- ``Track``
- ``Loop``
