# Progressions and Scales

Roman-numeral progressions, keys and scale degrees.

## Overview

A Progression expands roman numerals (or chord names) in a key into a chord sequence. Inside a Section its chords play back to back, each lasting its own duration (default one whole note).

## Creating

### Progression

```swift
Progression(_ progression: String, for pitch: Pitch, minor: Bool = false)
```

- term `progression`: Roman numerals separated by " - ". Case decides major or minor outside the key's table; a suffix overrides both ("V7", "iim7"). Plain chord notations can be mixed in.
- term `for`: The key's tonic as a pitch — the root the numerals are counted from, and the register the chords land in.
- term `minor`: false reads the numerals against the major table, true against the natural-minor one (i, ii°, III, iv, v, VI, VII).

Roman numerals separated by " - ". Diatonic numerals use the key's table (vii = diminished in major); outside the table the case you wrote wins: uppercase = major, lowercase = minor — so "II" in C is D major. A trailing quality suffix overrides both ("V7", "iim7", "Imaj7"). Plain chord notations can be mixed in.

```swift
Progression("I - vi - IV - V", for: .C4)
```

### Progression (minor key)

```swift
Progression(_ progression: String, for: Pitch, minor: true)
```

- term `progression`: Roman numerals separated by " - ", read against the minor table.
- term `for`: The key's tonic as a pitch.
- term `minor`: true here. "V" is not diatonic in natural minor, so its uppercase resolves it major — the harmonic-minor dominant.

minor: true uses the natural-minor table (i, ii°, III, iv, v, VI, VII). "V" is not diatonic there, so uppercase resolves it major — the harmonic-minor dominant.

```swift
Progression("i - iv - V", for: .A4, minor: true)
```

### Progression

```swift
Progression(chords: Chords)
```

- term `chords`: The chords, already built, in playing order. They are laid back to back unless .startTimes() says otherwise.

From an explicit [Chord] array.

## Modifiers

### .durations()

```swift
durations(_ durations: Double...) -> Progression
```

- term `durations`: One length per chord, in whole notes, in order. The chords are re-laid to follow one another, so this changes how long the progression lasts.

One duration per chord.

### .velocities()

```swift
velocities(_ velocities: UInt32...) -> Progression
```

- term `velocities`: One value per chord, 0–127, in order. Every note of a chord takes its chord's value.

One velocity per chord.

### .qualities()

```swift
qualities(_ qualities: ChordQuality...) -> Progression
```

- term `qualities`: One quality per chord, in order, replacing what the numeral resolved to — a plain V turned into .dom7, say. Chords past the end of the list keep theirs.

Overrides the quality per step — turn a plain V into a dominant 7, etc.

```swift
Progression("ii - V - I", for: .C4)
    .qualities(.minor7, .dominant7, .major7)
```

### .startTimes()

```swift
startTimes(_ startTimes: Double...) -> Progression
```

- term `startTimes`: Where each chord begins, in whole notes from the progression's start, in order. This replaces the back-to-back layout, so chords can overlap or leave gaps.

Explicit start time per chord — overrides the default back-to-back layout.

### .syncopate()

```swift
syncopate(by amount: MusicTimeStamp = .n16) -> Progression
```

- term `by`: How far earlier to pull every chord after the first, in whole notes. .n16 is a sixteenth; the first chord stays put so the downbeat is still the downbeat.

Anticipates every chord after the first by the given amount.

## Degrees & Keys

### degree notation

```swift
"1 2 3 5 | 5 3 2 1"
```

A melody written as scale degrees instead of note names. 1–7 are the degrees of the key; counting past 7 keeps going (8 is the root above). A degree is simply a way of writing a pitch, so everything else in notation works unchanged — bars, holds (-), rests (R), chord stacks ([1 3 5]), note sets ((1 3)), slides (1 >5), hammers (1 ^3), fused stages (1>3, [1 3 5]>[4 6 1']) and additions (1 +3). Degrees and note names mix freely ([1 3 C5], "1 >C6"): only the degrees move when a key lands. The one thing that has no degree spelling is the compact run ("CDEF"), because "135" cannot be told apart from the degree 135 — write a { } run group instead: "| 1 - - {1 2 3 4} |". Write degree melodies in bar notation: unbarred, a space is a rest beat, the same rule note names follow.

### chords on a degree

```swift
6m  5dom7  1sus4  [2m7 9]
```

A chart written in numbers: the number is the chord's root, the suffix its quality, and every quality note names works here. The root follows the key, the quality never does — "6m" is minor in every key, because a quality is an interval in semitones. Spell the quality in letters ("5dom7", not "57"): a token that is wholly a degree is always the degree, so "17" is the seventeenth. That is the rule note names already follow for "G7" (the pitch G octave 7, with "Gdom7" for the chord).

### octave marks

```swift
1'  1,  1''
```

' raises a degree an octave, , lowers it, and they stack — the mark is on the number, the way jianpu writes its octave dots and tonic sol-fa its strokes. The degree itself stays 1–7.

### alterations

```swift
b3  #4  b7   (also 3b  4#  7b)
```

b flattens a degree, # raises it, both by a semitone. "1 2 b3 4 | 5 b6 b7 1'" is the natural minor written over a major key. The accidental may be written on either side of the number — "b3" and "3b" are the same degree, and so are "#4'" and "4'#" — so a chart that spells them after the number reads as written. On a degree chord the same holds for the root ("2#m7" is "#2m7"), with one precedence rule: a suffix that names a chord alteration is read as one, so "1b9" is the flat ninth on degree 1 and never a flattened 1.

### .key()

```swift
key(_ root: Pitch, _ mode: ScaleMode)
```

- term `root`: The pitch degree 1 sounds at — .C5 is middle C. It sets the register as well as the key, so degrees land where you put the root.
- term `mode`: Which scale the degrees are counted in: .major, .dorian, .minorPentatonic … The mode's size is the degree count, so a pentatonic key's 6 is the root an octave up.

The key degrees are read in. Written on a Session, a Track, a Section or a single notation string — the innermost one wins, so a score names its key once and one line can still borrow another. Absolute note names are never touched by a key. A degree with no key anywhere still sounds, read in C major.

### ScaleMode

```swift
.major .minor .dorian .phrygian .lydian .mixolydian .locrian .harmonicMinor .melodicMinor .majorPentatonic .minorPentatonic .blues .wholeTone .chromatic
```

A scale's size is its degree count, so in a pentatonic key the sixth number is the root an octave up — which is what a five-degree scale means by "6".

### Scale

```swift
Scale(_ root: Pitch, _ mode: ScaleMode)
```

- term `root`: The pitch degree 1 sounds at.
- term `mode`: Which scale the degrees are counted in.

The key as a value, if you want to name it once and pass it around: let key = Scale(.C5, .major), then .key(key). Its `pitches` are the scale's own notes, one per degree.

## Scale (note names)

### Scale.majorScale()

```swift
majorScale(for root: String) -> [String]
```

- term `for`: The scale's root as a note name — accidentals allowed ("F#", "Bb"). The answer comes back in sharp spelling, so Bb gives A#.

Note names of the major scale — useful with Section.random. Roots may carry accidentals ("F#", "Bb"); flats come back in sharp spelling (Bb → A#).

### Scale.minorScale()

```swift
minorScale(for root: String) -> [String]
```

- term `for`: The scale's root as a note name — accidentals allowed ("F#", "Bb"). The answer comes back in sharp spelling, so Bb gives A#.

Natural minor scale.

### Scale.dorianScale()

```swift
dorianScale(for root: String) -> [String]
```

- term `for`: The scale's root as a note name — accidentals allowed ("F#", "Bb"). The answer comes back in sharp spelling, so Bb gives A#.

Dorian mode.

### Scale.generateScale()

```swift
generateScale(root: String, intervals: [Int]) -> [String]
```

- term `root`: The scale's root as a note name; accidentals allowed.
- term `intervals`: The step pattern in semitones, one entry per degree — [2, 2, 1, 2, 2, 2, 1] is major. The last step closes the octave, so a seven-note scale takes seven intervals.

Any scale from a root and step pattern, e.g. [2, 2, 1, 2, 2, 2, 1].
