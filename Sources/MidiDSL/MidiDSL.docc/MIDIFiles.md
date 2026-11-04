# MIDI Files

Write any session as a Standard MIDI File.

## Overview

From the command line, any score writes itself:

```bash
swift run HelloScore --midi hello.mid
```

From code, ``MIDIFile`` does the same for any ``Session``:

```swift
try MIDIFile.write(session, to: URL(fileURLWithPath: "piece.mid"))
let bytes = MIDIFile.data(for: session, loops: 4)
```

### What is in the file

The file is format 1 at 480 ticks per quarter note.

- **A conductor track** carries the tempo and the time signature.
- **One named track per `Track`**, opening with its instrument's program change. A drum track (`.drums(kit)`) is written on channel 10, where every General MIDI player keeps its kit; the others take channels in session order around it. See <doc:Instruments>.
- **Time is musical.** Notes are placed in ticks, so the file holds the same notes whatever the tempo.

### Every pass as it plays

By default the file holds the session's whole form: `.loops(n)` if the session states it, or otherwise as many passes as the arrangement implies (see <doc:TracksAndArrangement>). Each pass is written the way a player sounds it:

- Note sets and dice are resolved for that pass (see <doc:DiceAndChance>).
- `.active(...)` gates and shuffled sections are applied.
- Muted tracks and sections are left out, and track and session volumes scale the velocities.
- Slides become pitch-bend curves, with the bend range set per track to fit the widest slide, up to 24 semitones. Bend is per channel, so a sliding note that overlaps notes with a different curve falls back to re-attacked segments.
- A `.volume` automation curve becomes expression, CC 11 (see <doc:Automation>).
- A track-wide curve becomes its controller on the track's channel: `.cutoff` CC 74 (mapped in octaves across 20 Hz…20 kHz), `.resonance` CC 71, `.reverb` CC 91, `.cc(n)` CC n. A host's own parameter (`.host(...)`) has no MIDI word and is left out.

Pass `loops:` to write a different number of passes.

## Topics

- ``MIDIFile``
