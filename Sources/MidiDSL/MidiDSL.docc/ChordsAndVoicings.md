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
- term `quality`: Which intervals stack on the root: .major, .minor, .dom7, .maj7, .sus4, .custom(…) and the rest. The quality is in semitones, so it does not move when a key changes.
- term `duration`: How long every note of the chord rings, in whole notes. A whole note unless given.

Root name ("C", "F#", "Bb") plus quality.

```swift
Chord("C", .minor7)
```

### Chord

```swift
Chord(_ notation: String, _ duration: MusicTimeStamp = 1.0)
```

- term `notation`: Root and quality in one string — "Cmaj7", "F#m7", "Bbm7b5" — using the same suffixes string notation accepts.
- term `duration`: How long every note of the chord rings, in whole notes.

Parsed from notation like "Cmaj7" or "F#m7" — same quality suffixes as string notation.

```swift
Chord("Bbm7b5")
```

## ChordQuality

### .major

0 4 7 — notation: (empty), M, maj.

### .minor

0 3 7 — notation: m, mi, min.

### .diminished

0 3 6 — notation: dim, o.

### .augmented

0 4 8 — notation: aug, +.

### .dominant7

0 4 7 10 — notation: 7, dom7, dom.

### .major7

0 4 7 11 — notation: M7, maj7, Δ.

### .minor7

0 3 7 10 — notation: m7, mi7, min7.

### .halfDiminished

0 3 6 10 — notation: ø7, ø, m7b5.

### .diminished7

0 3 6 9 — notation: o7, dim7.

### .add9

0 4 7 14 — notation: add9.

### .add11

0 4 7 17 — notation: add11.

### .sus4

0 5 7 — notation: sus4.

### .sus2

0 2 7 — notation: sus2.

### .majorSixth

0 4 7 9 — notation: maj6, M6, 6th ("C6" is a pitch, never this chord).

### .minorSixth

0 3 7 9 — notation: m6, mi6, min6.

### .dominant7sus4

0 5 7 10 — notation: 7sus4, dom7sus4.

### .power

0 7 — notation: pow, no3 ("C5" is a pitch, never this chord).

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

- term `duration`: One length for every note of the chord, in whole notes. It does not re-space anything: a chord's notes already start together.

Sets every chord note to the same duration.

### .velocities()

```swift
velocities(_ velocities: UInt32...) -> Chord
```

- term `velocities`: One value per note, 0–127, in the chord's own note order (root upward). Notes past the end of the list keep what they had, so a short list voices only the bottom of the chord.

Per-note velocities, in the chord's note order. Notes beyond the list keep their current velocity.

### .natural()

```swift
natural() -> Chord
```

Humanizes velocities: slight random variation with the bass note emphasized.

### .ext()

```swift
ext(_ extensions: String...) -> Chord
```

- term `extensions`: Tones to add above the chord: "7", "b7", "maj7", "9", "b9", "#9", "11", "#11", "13", "b13", "b5", "#5". An altered fifth replaces the natural one; anything already in the chord is ignored.

Adds jazz extension tones: 7, b7, maj7, 9, b9, #9, 11, #11, 13, b13, b5, #5 (altered fifths replace the natural fifth). Duplicates of existing chord tones are ignored.

```swift
Chord("Cdom7").ext("b9", "#11")
```

## Arpeggios

### .arpeggio()

```swift
arpeggio(_ pattern: ArpeggioPattern = .up, delay: MusicTimeStamp = 0.05) -> Chord
```

- term `pattern`: The order the notes enter: .up, .down, .alternating, .random, .rootFirst, .rootLast, .custom([Int]).
- term `delay`: The gap between one note and the next, in whole notes — a fixed strum, independent of how long the chord is. 0.05 is tight.

Staggers the chord notes by a fixed delay in the given order.

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

- term `order`: The indices to play, in the order to play them — 0-based, counted from the chord's lowest note upward. [0, 2, 1] plays root, fifth, third.
- term `delay`: The gap between one note and the next, in whole notes.

Notes in an explicit index order (0-based, sorted by pitch).

### ArpeggioPattern

```swift
.up .down .random .alternating .rootFirst .rootLast .custom([Int])
```

.alternating plays low, high, then the middle notes; .rootFirst/.rootLast pin the root at either end.
