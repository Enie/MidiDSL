# Not in the Grammar

Things lead sheets write that string notation deliberately doesn't, and what to write instead.

## Overview

- **Slash chords** (`C/E`): build the stack, `[E3 C E G]`.
- **Roman numerals in strings**: use `Progression("I - V - vi", for: .C4)`, or write the chart in numbers with degrees, `"1maj7 | 5dom7 | 6m"` (see <doc:ProgressionsAndScales>).
- **In-string dynamics**: use `.velocity(...)` or `.velocities(...)` on the section, or a `.volume` curve (see <doc:Automation>).
- **Repeat signs**: use a `Loop(bars:times:)` or a Swift `for` in the track's body (see <doc:TracksAndArrangement>).
- **Grace notes, and meter changes mid-piece**: not yet. ``Section/tempo(_:)`` plays one section faster or slower, but a MIDI file reads it as notes placed further apart, not as a tempo change.

Tuplets *are* in the grammar. A run group divides its slot by however many notes it holds, so `"| 1 - - {1 2 3} |"` is three slow beats and a triplet (see <doc:StringNotation>).
