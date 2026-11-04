# Sections

Layers that sound together, and the modifiers that shape them.

## Overview

A ``Section`` is a group of statements that start together. Each statement in the block is a layer: a notation string, a drum lane, a ``Note``, a ``Chord``, a ``Progression``, a ``NoteSet`` or another `Section`. All of them begin at the section's start, and the longest one sets the section's length.

```swift
Section {
    "CDEFGABC6".duration(.n8)  // an eighth-note run
    "[C3 G3]".duration(.n1)    // over a held fifth
}
```

To play things one after another, put them in separate sections: a track plays its sections back to back. Inside one statement, bar notation and progressions also run in order.

```swift
Track("piano") {
    Section { "| C E G C6 |" }
    Section { "| Am~0.15 | Fmaj7~0.15 |" }   // starts when the first section ends
}
```

Every modifier returns a changed copy, so they chain. A modifier acts on the notes the section holds when it is called, so the order of a chain can matter: write ``Section/automate(_:over:curve:)`` last.

## Loudness

``Section/velocity(_:)`` gives every note one velocity, which flattens accents and ghost notes. ``Section/velocity(scale:)`` multiplies instead, so the ratios survive: it is how you balance one variant of a part against another.

```swift
Section { Kick("x..o x...") }.velocity(scale: 0.8)   // accent and ghost stay apart
```

``Section/velocities(_:)`` gives each *beat position* its own velocity. A beat position is a start time, so the notes of a chord share one. With several layers, the positions are counted layer by layer in the order the statements are written.

```swift
Section { "CCGG" }.velocities(110, 70, 90, 70)
```

## Length

``Section/durations(_:)`` changes how long each beat position rings and leaves the start times alone. ``Section/noteDuration(_:)`` gives every note one duration and lays them back to back, which changes the section's length. It treats every note as its own step, so use it on a single line of single notes.

```swift
Section { "CDEFGAB" }.noteDuration(.n8)
```

The modifiers of the same names on a notation string also lay the notes back to back. See <doc:StringNotation>.

## Timing and feel

``Section/swing(_:)`` moves the off-beat eighths later in their beat: `0.5` is straight, `0.67` a triplet swing, `0.75` a heavy one.

```swift
Section { "CC6ABC6GAF" }.noteDuration(.n8).swing()
```

``Section/syncopate(by:)`` pulls every note that lands on a quarter-note beat a little earlier, except a note at the section's very start.

``Section/tempo(_:)`` plays one section at a tempo of its own, measured against the session's: at `.tempo(60)` in a session at 120 the section is half as fast and twice as long, and the sections after it move to make room.

```swift
Session {
    Track("lead") {
        Section { "| 1 2 3 5 |" }
        Section { "| 5 3 2 1 |" }.tempo(60)   // the same bar, twice as slow
    }
}
.tempo(120)
```

A section reads the session's tempo while the score is built, so build the session in a ``Score`` or with ``Session/build(_:)``. Tempo is set on sections and on the session; a track has none of its own.

## Generating a section

``Section/random(from:count:duration:velocity:)-9wtbe`` writes a run of notes drawn from a set of pitches, and ``Section/random(from:count:duration:velocity:)-3a05n`` does the same from note names. The draw comes from ``Dice``, so the same set always gives the same run. Draw from a scale's ``Scale/pitches`` to stay in key:

```swift
Section.random(from: Scale(.C5, .major).pitches, count: 8)
```

For anything more deliberate, see <doc:GeneratingParts> and <doc:GeneratingMelodies>.

## When a section plays

A section can sound on some passes only. ``Section/active(loops:)-v4wc`` and its siblings take the passes as a range or a list, and ``Section/active(every:offset:)`` takes a period. On the other passes the section's time stays reserved, so what follows keeps its place.

A section nested inside another is a layer like any other, so a gated nested section is an alternative for some passes:

```swift
Section {
    Section { "| D3 A3 E4 F#4 | C#5 - A4 - |" }.active(loops: [0, 1])
    Section { "| [Dmaj7 9]~0.05 - - - |" }.active(loops: 2...)
}
```

``Section/pickOne()`` lets the dice choose one layer per pass instead. ``Section/mute(_:)`` silences a section and keeps its time. See <doc:TracksAndArrangement> for passes, and <doc:DiceAndChance> for what the dice decide.

## Topics

- ``Section``
