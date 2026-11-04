# Sessions

The whole piece: its tracks, tempo, meter, form, key and seed.

## Overview

The root container. Holds tracks plus global settings — tempo, master volume, loop length and time signature. All modifiers return a new Session, so they chain after the closing brace.

## Creating

### Session

```swift
Session { Track... }
```

Builds a session from one or more Track blocks. Written as `Session { pass in … }` the body is read once per pass, so a track can change from one time through to the next — see <doc:TracksAndArrangement>.

## Modifiers

### .tempo()

```swift
tempo(_ bpm: Double) -> Session
```

- term `bpm`: Quarter notes per minute, whatever the meter — in 6/8 at 120 a bar of six eighths lasts 1.5 s. It sets how fast the music goes in seconds and never changes what a bar holds. 120 when the score says nothing.

The tempo, in quarter notes per minute. A MIDI file carries it in its conductor track; the notes themselves are written in musical time, so changing it changes no note.

```swift
Session { … }.tempo(128)
```

### .volume()

```swift
volume(_ level: Double) -> Session
```

- term `level`: The master fader, 0.0–1.0. Multiplies every track's own volume, and lands on velocity, so exported MIDI carries it too. 1.0 is unattenuated.

Master volume, 0.0–1.0. Multiplies every track's own volume.

### .loopBars()

```swift
loopBars(_ count: Int) -> Session
```

- term `count`: How many bars one pass lasts. Left out, the pass is as long as the longest track — set it when a generated part is longer or shorter than the song.

Loop length in bars. Without it the loop length is derived from the longest track.

### .timeSignature()

```swift
timeSignature(_ beatsPerBar: Int, _ noteValue: Int) -> Session
```

- term `beatsPerBar`: The top number: how many beats a bar counts. Pass the same beats: to Grid and Phrase, or their bars won't be the song's bars.
- term `noteValue`: The bottom number: which note gets the beat. 4 is a quarter, 8 an eighth. Together they set the bar's length — 3/4 and 6/8 are both 0.75 of a whole note, 5/4 is 1.25.

Meter by numbers, e.g. timeSignature(3, 4) for a waltz. Bar notation ("… | …") follows it: each bar spans beatsPerBar/noteValue of a whole note (3/4 and 6/8 → 0.75, 5/4 → 1.25), the same bars the MIDI file's time signature marks. Inline notation is unaffected.

### .timeSignature()

```swift
timeSignature(_ signature: TimeSignature) -> Session
```

- term `signature`: A named meter — .fourFour, .threeFour, .sixEight — instead of the two numbers.

Meter from a preset.

```swift
Session { … }.timeSignature(.sixEight)
```

### More on a session

`.loops(_:)` sets how many passes the form runs — see <doc:TracksAndArrangement>. `.key(_:_:)` names the key degrees are read in — see <doc:ProgressionsAndScales>. `.seed(_:)` picks another set of dice rolls — see <doc:DiceAndChance>.

## TimeSignature presets

### .fourFour

4/4 — common time (default).

### .threeFour

3/4 — waltz.

### .sixEight

6/8 — compound meter.

### .fiveFour

5/4 — Take Five.

### .sevenEight

7/8 — odd meter.

### .twoFour

2/4 — march.

### .twelveEight

12/8 — slow blues.
