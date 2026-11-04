# Chords and Voicings

Chord names, qualities, extensions, strums and arpeggios.

## Overview

In notation a chord is just its name: `"| Am7 | Dm9 | Gdom7 | Cmaj7 |"`. Build a ``Chord`` in Swift when code chooses the chord or changes it.

```swift
Section {
    Chord("A", .minor7, 0.5).arpeggio(over: 0.25)
    Chord("D", .minor9, 0.5).natural()
}
```

``Chord/init(_:_:_:)`` takes a root and a ``ChordQuality``; ``Chord/init(_:_:)`` reads a chord symbol such as `"F#m7"` or `"Bbm7b5"`. The symbol form fails, returning `nil`, when the string does not start with a note name. A root without an octave is in octave 5.

Chord modifiers change the chord and return it, so they chain.

## Chord symbols

A symbol is a root followed by a quality. Each case of ``ChordQuality`` lists its spellings; the common ones:

| Quality | Tones above the root | Spellings |
|---|---|---|
| `.major` | 0 4 7 | (nothing), `M`, `maj` |
| `.minor` | 0 3 7 | `m`, `mi`, `min` |
| `.diminished` | 0 3 6 | `dim`, `o` |
| `.augmented` | 0 4 8 | `aug`, `+` |
| `.dominant7` | 0 4 7 10 | `7`, `dom7`, `dom` |
| `.major7` | 0 4 7 11 | `maj7`, `M7`, `Δ7`, `Δ` |
| `.minor7` | 0 3 7 10 | `m7`, `min7` |
| `.halfDiminished` | 0 3 6 10 | `m7b5`, `ø7`, `ø` |
| `.diminished7` | 0 3 6 9 | `dim7`, `o7` |
| `.sus4` / `.sus2` | 0 5 7 / 0 2 7 | `sus4`, `sus` / `sus2` |
| `.majorSixth` / `.minorSixth` | 0 4 7 9 / 0 3 7 9 | `maj6`, `M6`, `6th` / `m6`, `min6` |
| `.dominant9` | 0 4 7 10 14 | `dom9` |
| `.major9` / `.minor9` | 0 4 7 11 14 / 0 3 7 10 14 | `maj9`, `M9` / `m9`, `min9` |
| `.dominant13` | 0 4 7 10 14 21 | `13`, `dom13` |
| `.power` | 0 7 | `pow`, `no3` |

Tones are semitones above the root. The eleventh chords leave out the third, which clashes with the eleventh.

Some spellings are taken by pitches. In notation `"C6"`, `"C5"` and `"C9"` are the note C in octaves 6, 5 and 9, so the sixth chord is `"Cmaj6"`, the power chord `"Cpow"` and the dominant ninth `"Cdom9"`. ``Chord/init(_:_:)`` reads a quality it does not know as major, so `Chord("C9")` is a C major triad.

A symbol with altered tones, such as `"C7b9"` or `"Cm7#5"`, becomes a ``ChordQuality/custom(_:)`` quality, and so can any stack of semitones: `.custom("0,4,7,10,14")`.

## Extensions

``Chord/ext(_:)`` adds tones named as extensions: `"7"`, `"b7"`, `"maj7"`, `"9"`, `"b9"`, `"#9"`, `"11"`, `"#11"`, `"13"` and `"b13"`, and `"b5"` or `"#5"`, which replace the fifth. A tone the chord already has, and a name it does not know, are skipped.

```swift
Chord("C", .dominant7).ext("b9", "#11")
```

`"b7"` and `"maj7"` name the seventh outright. A bare `"7"` adds the seventh of the chord's own scale: major on a major, augmented or add9 chord, diminished on a diminished one, minor otherwise, and nothing if the chord already has a sixth or seventh.

## Voicing

``Chord/velocities(_:)`` gives each tone its own velocity, in the chord's own order: the quality's tones from the root up, then the extensions in the order they were added. ``Chord/natural()`` gives the tones the slightly uneven velocities of a played chord, the same on every build. ``Chord/duration(_:)`` and ``Chord/durations(_:)`` set how long the tones ring.

## Arpeggios

``Chord/arpeggio(_:delay:)`` starts each tone a fixed delay after the one before, in the order an ``ArpeggioPattern`` gives. Each tone keeps its length, so the last one ends later than the first. ``Chord/arpeggio(over:pattern:)`` spreads the tones evenly across a span instead.

```swift
Chord("C", .major7).arpeggio(.up, delay: 0.05)       // a quick strum
Chord("C", .major7).arpeggio(over: 0.5, pattern: .alternating)
```

The patterns sort the tones by pitch: `.up`, `.down`, `.alternating` (lowest, highest, then the middle rising), `.rootFirst` and `.rootLast`. `.random` shuffles them the same way on every build. `.custom([Int])` plays them in the order you list, by index into the chord as built, so `[0, 2, 1]` on a triad is root, fifth, third.

``Chord/arpeggioUp(delay:)``, ``Chord/arpeggioDown(delay:)`` and ``Chord/arpeggioCustom(_:delay:)`` are shorthands. Notation has its own marks for all of this; see <doc:StringNotation>.

## Topics

- ``Chord``
- ``ChordQuality``
- ``ArpeggioPattern``
