# Chords and Voicings

Chord names, qualities, voicings, strums and arpeggios.

## Overview

A chord built from a root and a quality — either as explicit Swift values or parsed from notation. Chord modifiers mutate and return the same chord, so they chain.

## Creating

### Chord

```swift
Chord(_ root: String, _ quality: ChordQuality, _ duration: MusicTimeStamp = 1.0)
```

- term `root`: The chord's root as a note name — "C", "F#", "Bb". An octave may be written on it ("C4"); without one the chord sits in the default register.
- term `quality`: Which intervals stack on the root: .major, .minor, .dominant7, .major7, .sus4, .custom(…) and the rest. The quality is in semitones, so it does not move when a key changes.
- term `duration`: How long every note of the chord rings, in whole notes. A whole note unless given.

Root name ("C", "F#", "Bb") plus quality.

```swift
Chord("C", .minor7)
```

### Chord

```swift
Chord(_ notation: String, _ duration: MusicTimeStamp = 1.0)
```

- term `notation`: Root and quality in one string — "Cmaj7", "F#m7", "Bbm7b5" — using the quality suffixes listed below. No octave can be written here; the chord sits in the default register.
- term `duration`: How long every note of the chord rings, in whole notes.

Parsed from notation like "Cmaj7" or "F#m7". The initializer is failable: it returns nil when the string does not start with a note name. A suffix it does not recognise gives a major chord, so "C6" and "C9" here are C major — write "Cmaj6" and "Cdom9".

```swift
if let chord = Chord("Bbm7b5") {
    // B♭ half-diminished
}
```

## ChordQuality

### .major

0 4 7 — notation: (empty), M, maj.

### .minor

0 3 7 — notation: m, mi, min, − (minus sign).

### .diminished

0 3 6 — notation: dim, o.

### .augmented

0 4 8 — notation: aug, +.

### .dominant7

0 4 7 10 — notation: 7, dom7, dom.

### .major7

0 4 7 11 — notation: M7, maj7, Δ7, Δ.

### .minor7

0 3 7 10 — notation: m7, mi7, min7, −7.

### .halfDiminished

0 3 6 10 — notation: ø7, ø, m7b5.

### .diminished7

0 3 6 9 — notation: o7, dim7.

### .add9

0 4 7 14 — notation: add9.

### .add11

0 4 7 17 — notation: add11.

### .sus4

0 5 7 — notation: sus4, sus.

### .sus2

0 2 7 — notation: sus2.

### .majorSixth

0 4 7 9 — notation: maj6, M6, 6th ("C6" is a pitch, never this chord).

### .minorSixth

0 3 7 9 — notation: m6, mi6, min6, −6.

### .dominant7sus4

0 5 7 10 — notation: 7sus4, dom7sus4.

### .power

0 7 — notation: pow, no3 ("C5" is a pitch, never this chord).

### Extended and altered

| Quality | Intervals | Notation |
|---|---|---|
| .dominant9 | 0 4 7 10 14 | dom9 |
| .major9 | 0 4 7 11 14 | M9, maj9, Δ9 |
| .minor9 | 0 3 7 10 14 | m9, mi9, min9 |
| .minor11 | 0 3 7 10 14 17 | m11, mi11, min11 |
| .dominant11 | 0 7 10 14 17 | 11, dom11 |
| .major11 | 0 7 11 14 17 | maj11, M11 |
| .dominant13 | 0 4 7 10 14 21 | 13, dom13 |
| .major13 | 0 4 7 11 14 21 | maj13, M13 |
| .minor13 | 0 3 7 10 14 21 | m13, mi13, min13 |
| .sixNine | 0 4 7 9 14 | 69, 6/9, 6add9 |
| .minorMajor7 | 0 3 7 11 | mMaj7, mM7, minMaj7 |
| .augmented7 | 0 4 8 10 | aug7, +7 |
| .augmentedMajor7 | 0 4 8 11 | augMaj7, augM7, +M7 |
| .minorAdd9 | 0 3 7 14 | madd9, minadd9 |
| .dominant9sus4 | 0 5 7 10 14 | 9sus4, dom9sus4 |

The eleventh chords leave out the third, which clashes with the eleventh. A dominant ninth has no bare "9" spelling because "C9" is a pitch.

### .custom

```swift
.custom("0,4,7,10,14")
```

Any interval stack, comma-separated semitones from the root. Altered tokens like "C7b9" parse to a custom quality.

## Modifiers

### .duration()

```swift
duration(_ duration: MusicTimeStamp) -> Chord
```

- term `duration`: One length for every note of the chord, in whole notes. Start times are left alone, so an arpeggio stays an arpeggio.

Sets every chord note to the same duration.

### .velocities()

```swift
velocities(_ velocities: UInt32...) -> Chord
```

- term `velocities`: One value per note, 0–127, in the chord's own note order: the quality's tones from the root up, then any extensions in the order they were added. Notes past the end of the list keep what they had, so a short list voices only the bottom of the chord.

Per-note velocities, in the chord's note order. Notes beyond the list keep their current velocity.

### .natural()

```swift
natural() -> Chord
```

Humanizes velocities: each note gets 80 plus a small variation (0–10), and the lowest note 15 more. The variation comes from ``Dice``, so the chord sounds the same on every compile.

### .ext()

```swift
ext(_ extensions: String...) -> Chord
```

- term `extensions`: Tones to add above the chord: "7", "b7", "maj7", "9", "b9", "#9", "11", "#11", "13", "b13", "b5", "#5". An altered fifth replaces the natural one; anything already in the chord, and any token not in this list, is ignored.

Adds jazz extension tones. "b7" and "maj7" name the seventh outright; a bare "7" adds the one the quality implies — a major seventh on a major, augmented or add9 chord, a diminished seventh on a diminished one, a minor seventh otherwise — and nothing on a chord that already has a seventh.

```swift
Chord("C", .dominant7).ext("b9", "#11")
```

## Arpeggios

### .arpeggio()

```swift
arpeggio(_ pattern: ArpeggioPattern = .up, delay: MusicTimeStamp = 0.05) -> Chord
```

- term `pattern`: The order the notes enter: .up, .down, .alternating, .random, .rootFirst, .rootLast, .custom([Int]).
- term `delay`: The gap between one note and the next, in whole notes — a fixed strum, independent of how long the chord is. 0.05 is tight.

Staggers the chord notes by a fixed delay in the given order. Each note keeps its own length, so the last one ends later than the first.

### .arpeggio(over:)

```swift
arpeggio(over totalDuration: MusicTimeStamp, pattern: ArpeggioPattern = .up) -> Chord
```

- term `over`: How long the whole roll takes, in whole notes; the notes are spread evenly across it whatever the chord's own length is.
- term `pattern`: The order the notes enter.

Spreads the notes evenly across a total duration.

### .arpeggioUp() / .arpeggioDown()

```swift
arpeggioUp(delay: MusicTimeStamp = 0.05)
```

- term `delay`: The gap between one note and the next, in whole notes. The pattern is fixed by which of the two you call.

Shorthand for .arpeggio(.up) / .arpeggio(.down).

### .arpeggioCustom()

```swift
arpeggioCustom(_ order: [Int], delay: MusicTimeStamp = 0.05)
```

- term `order`: The indices to play, in the order to play them — 0-based, in the chord's own note order (as for .velocities()). On a triad [0, 2, 1] plays root, fifth, third. An index past the last note is skipped.
- term `delay`: The gap between one note and the next, in whole notes.

Notes in an explicit index order. The other patterns sort by pitch first; this one does not, so on a chord extended out of order an index names the note as it was added.

### ArpeggioPattern

```swift
.up .down .random .alternating .rootFirst .rootLast .custom([Int])
```

.alternating plays low, high, then the middle notes upward; .rootFirst/.rootLast pin the root at either end. .random is shuffled by ``Dice``, so it is the same on every compile.
