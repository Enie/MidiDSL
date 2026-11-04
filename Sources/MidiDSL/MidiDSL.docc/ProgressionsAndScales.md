# Progressions and Scales

Roman-numeral progressions, keys and scale degrees.

## Overview

A melody or a chart can be written in numbers instead of note names. The numbers are degrees of a key, and the key is named once, on the session or on any part:

```swift
Track("lead") {
    Section { "| 1 2 3 5 | 6 5 3 - |" }
}
.key(.D5, .dorian)
```

Change the key and everything written in degrees moves with it.

## Degrees

`1` to `7` are the degrees of a seven-note key, and counting goes on past them: `8` is the root an octave up. A degree is just a way of writing a pitch, so the rest of notation works unchanged: bars, holds, rests, stacks (`[1 3 5]`), note sets (`(1 3)`), slides (`1 >5`), hammers (`1 ^3`) and additions (`1 +3`). Degrees and note names mix freely, and only the degrees move when a key changes.

Write degree melodies in bar notation: in inline notation a space is a rest beat. A degree has no compact run, because `"135"` is the degree 135; write a group instead, `"| 1 - - {1 2 3 4} |"`.

### Octaves and accidentals

`'` raises a degree an octave and `,` lowers it, and they stack: `1'`, `1,`, `1''`. The mark is on the number, the way jianpu writes its octave dots. The degree itself stays 1–7.

`b` lowers a degree a semitone and `#` raises it, on either side of the number: `b3` and `3b` are the same. `"| 1 2 b3 4 | 5 b6 b7 1' |"` is natural minor written over a major key.

### Chords on a degree

A chart in numbers: the number is the chord's root and the suffix its quality, with every quality chord symbols know. `6m`, `5dom7`, `1sus4`, `[2m7 9]`.

The root follows the key, and the quality never does: `6m` is minor in every key, because a quality is a set of intervals. Spell the quality in letters, `5dom7` and not `57`, since a token that is wholly a number is a degree: `17` is the seventeenth. On a degree chord, a suffix that names a chord alteration is read as one, so `1b9` is degree 1 with a flat ninth, never a flattened 1.

## Keys

`.key(root, mode)` names the key degrees are read in. It can be written on a ``Session``, a ``Track``, a ``Section`` or a single notation string, and the innermost one wins, so a score names its key once and one line can still borrow another. Note names are never moved by a key. A degree with no key anywhere is read in C major, from C5.

The root sets the register as well as the key: `.key(.C5, .major)` puts degree 1 on middle C, and `.key(.C3, .major)` two octaves lower.

A ``ScaleMode`` says which scale the degrees count through: the church modes, harmonic and melodic minor, the pentatonics, blues, whole tone and chromatic. A scale's size is its number of degrees, so in a pentatonic key `6` is the root an octave up.

A ``Scale`` is a key as a value, for naming it once and passing it around. Its ``Scale/pitches`` are its notes, one per degree:

```swift
let home = Scale(.C5, .major)
let melody = Section { "| 1 3 5 3 |" }.key(home)
let run = Section.random(from: home.pitches, count: 8)
```

## Progressions

A ``Progression`` reads Roman numerals in a key and plays the chords one after another, a whole note each unless ``Progression/durations(_:)`` says otherwise.

```swift
Section { Progression("I - vi - IV - V", for: .C4) }
```

The steps are separated by `" - "`. A numeral in the key's table takes the table's quality: in a major key `ii` is minor and `vii` diminished. Outside the table the case decides, uppercase major and lowercase minor, so `"II"` in C is D major. A suffix sets the quality outright: `"V7"`, `"iim7"`, `"Imaj7"`. A chord symbol can stand in for a numeral, and a step that is neither is left out.

With `minor: true` the numerals are read in the natural minor table: i, ii°, III, iv, v, VI, VII. An uppercase `V` is not in that table, so it is major, the harmonic minor's dominant:

```swift
Section { Progression("i - iv - V", for: .A4, minor: true) }
```

Only the tonic's note name counts: the chords' roots are in octave 5, whatever octave you give.

### Shaping a progression

The modifiers take one value per chord, in order; chords past the end of the list keep theirs.

- ``Progression/qualities(_:)`` replaces each chord's quality.
- ``Progression/durations(_:)`` sets how long each chord lasts, and so how long the progression is.
- ``Progression/velocities(_:)`` sets each chord's velocity.
- ``Progression/startTimes(_:)`` places each chord at a time of its own, so chords can overlap or leave gaps.
- ``Progression/syncopate(by:)`` pulls every chord after the first a little earlier. It works from the chords' durations, so write it after `durations`.

```swift
Section {
    Progression("ii - V - I", for: .C4)
        .qualities(.minor7, .dominant7, .major7)
        .durations(0.5, 0.5, 1)
        .syncopate(by: .n8)
}
```

## Topics

- ``Progression``
- ``Scale``
- ``ScaleMode``
