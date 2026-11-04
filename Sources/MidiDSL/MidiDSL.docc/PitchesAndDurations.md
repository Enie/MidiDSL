# Pitches and Durations

Named pitches and the duration constants.

## Overview

Pitch is a MIDI note number (UInt32). Octave numbering starts at C0 = 0, so C5 = 60 and each octave adds 12. Bare note names without an octave mean octave 5. In Swift code use the named constants (.C4, .FSharp3); in notation strings use letters with #/b ("F#3", "Bb4").

Durations are Doubles in whole notes: `1.0` is a whole note, `0.25` a quarter, in every meter. The constants below name the common values.

## Pitch constants

### Named pitches

```
.C0 … .G10, .CSharp4, .ASharp5, …
```

Sharps are spelled out in Swift constants (CSharp4); string notation reads any spelling of a name — C#4, Db4, and the ones no keyboard has a key for (E#, Cb, F##). C5 = MIDI 60, C4 = 48, A5 = 69 (440 Hz).

## Durations — beat shorthand

### .n1

Whole note, 1.0. Four beats in 4/4.

### .n2

Half note, 0.5.

### .n4

Quarter note, 0.25. One beat in 4/4.

### .n8

Eighth note, 0.125.

### .n16

Sixteenth note, 0.0625.

### .n32 / .n64

32nd / 64th note.

### .n2d / .n4d / .n8d

Dotted half, quarter and eighth: 1.5 times the plain value.

### .n4t / .n8t

Quarter and eighth triplets: ⅔ of the plain value.

## Durations — traditional names

### .whole  .half  .quarter  .eighth  .sixteenth  .thirtysecond  .sixtyfourth

Same values under traditional names. British names exist too (.semibreve, .minim, .crotchet, .quaver, .semiquaver), plus long values .doubleWhole/.breve (2.0), .longa (4.0), .maxima (8.0).
