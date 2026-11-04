# Notes, Rests and Note Sets

The values a section is made of.

## Overview

The explicit, Swift-typed way to write notes when string notation isn't enough — exact velocities, unusual durations, or per-loop pitch variants.

## Note

### Note

```swift
Note(pitch: Pitch?)
```

- term `pitch`: Which note sounds, as a Pitch constant (.C4, .ASharp5) or a raw MIDI number. nil is silence — a rest that still occupies its slot.

Quarter-note duration, velocity 100. A nil pitch is silence.

```swift
Note(pitch: .C4)
```

### Note

```swift
Note(pitch: Pitch?, duration: MusicTimeStamp)
```

- term `pitch`: Which note sounds, as a Pitch constant (.C4, .ASharp5) or a raw MIDI number. nil is silence — a rest that still occupies its slot.
- term `duration`: How long the note rings, in whole notes: 1.0 a whole note, 0.25 a quarter. It does not move what comes after it.

Explicit duration (1.0 = whole note), velocity 100.

### Note

```swift
Note(pitch: Pitch?, velocity: UInt32, duration: MusicTimeStamp)
```

- term `pitch`: Which note sounds, as a Pitch constant (.C4, .ASharp5) or a raw MIDI number. nil is silence — a rest that still occupies its slot.
- term `velocity`: How hard the note is struck, 0–127, clamped. It is multiplied by the track's volume and the session's master volume on the way out.
- term `duration`: How long the note rings, in whole notes: 1.0 a whole note, 0.25 a quarter. It does not move what comes after it.

Explicit velocity (clamped to 0–127) and duration.

### Note

```swift
Note(pitch: Pitch?, velocity: UInt32, startTime: MusicTimeStamp, duration: MusicTimeStamp)
```

- term `pitch`: Which note sounds, as a Pitch constant (.C4, .ASharp5) or a raw MIDI number. nil is silence — a rest that still occupies its slot.
- term `velocity`: How hard the note is struck, 0–127, clamped. It is multiplied by the track's volume and the session's master volume on the way out.
- term `startTime`: Where the note begins inside the statement, in whole notes from its start. Notes given the same startTime sound together — this is how a chord is written by hand.
- term `duration`: How long the note rings, in whole notes: 1.0 a whole note, 0.25 a quarter. It does not move what comes after it.

Full control including the start time inside the statement — notes given the same startTime sound together.

## Rest

### Rest

```swift
Rest()
```

One whole note of silence.

### Rest

```swift
Rest(startTime: MusicTimeStamp, duration: MusicTimeStamp)
```

- term `startTime`: Where the silence begins inside the statement, in whole notes from its start.
- term `duration`: How long it lasts, in whole notes. A rest is a real note with no pitch, so this keeps the slot's time.

Silence with explicit position and length.

## NoteSet

### NoteSet

```swift
NoteSet(_ pitches: Pitch..., duration: MusicTimeStamp = .quarter)
```

- term `pitches`: The pitches the slot may sound, in order. One of them plays per pass; the list is walked upward unless a mode says otherwise.
- term `duration`: How long whichever pitch sounds rings, in whole notes. A quarter unless given.

One note slot that plays a different pitch on each loop pass, cycling upward through the list.

```swift
NoteSet(.C3, .Eb3, .G3)
```

### NoteSet

```swift
NoteSet(_ mode: NoteSetMode, _ pitches: Pitch..., duration: MusicTimeStamp = .quarter)
```

- term `mode`: How the list is walked across passes: .up, .down, .alternating, or .random for a deterministic draw.
- term `pitches`: The pitches the slot may sound, in order.
- term `duration`: How long whichever pitch sounds rings, in whole notes.

Same, with an explicit cycling mode.

```swift
NoteSet(.random, .C3, .Eb3, .G3, .Bb3)
```

### NoteSetMode

```swift
.up  .down  .random  .alternating
```

Order in which the pitch variants are chosen across loop passes.
