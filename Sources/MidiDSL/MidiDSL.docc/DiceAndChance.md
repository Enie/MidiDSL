# Dice and Chance

Chance that is the same on every run.

## Overview

Chance comes into a piece two ways:

- term While you write: ``Dice`` answers questions as the score is built, so code can generate a part instead of you typing every hit. What it writes is fixed material, like anything you typed.
- term While it plays: a `?` step, a note set, a drawn velocity or ``Section/pickOne()`` leaves a choice open, and a different answer comes up on each pass.

Neither is noise. Every answer depends only on where the choice is written, which pass is playing and the seed, so the same source always gives the same performance, and a player and an exported MIDI file hear the same music. Two choices written in different places roll independently, and a note's loudness and its length roll separately, so the loud passes are not also the long ones.

Never use `Double.random(in:)` in a score. It would write a different piece on every build, and the file you export would be one you never heard.

## Rolling while you write

A ``Dice`` does not hand out numbers one after another. You ask it about a place, and the answer depends only on the seed and the place:

```swift
let dice = Dice(seed: 7)
let lift = dice(2, 1)          // a number in 0..<1 for bar 2, beat 1: the same on every run
let fill = dice.chance(0.25, 3) // true about one time in four, here: bar 3
```

The numbers you pass are coordinates: any numbers that say which choice this is, usually a bar and a step. Their order matters, and at least one is required. Nothing is used up by asking, so asking again anywhere gives the same answer, which is what makes a generated part a fixed part.

The seed is the take: keep it and the part never changes, change it to hear another. Neighbouring seeds are unrelated draws.

### A stream per part

Two parts asking the same dice about the same bar and step get the same answer, and start moving together. Give each part its own stream:

```swift
let dice  = Dice(seed: 7)
let ride  = dice.stream("ride")
let snare = dice.stream("snare")
```

A stream is dice of its own, derived from the seed and the name. The name is only a label; the same name always gives the same stream.

### Shaping a roll

Every form reads the same number in `0..<1` and shapes it:

| Call | Answers |
|---|---|
| ``Dice/callAsFunction(_:_:)`` | the number itself |
| ``Dice/chance(_:_:_:)`` | `true` about `probability` of the time |
| ``Dice/pick(_:_:at:_:)`` | one of the options you write out |
| ``Dice/pick(_:_:_:)`` | one element of an array, or `nil` if it is empty |
| ``Dice/int(in:_:_:)`` | a whole number in a range, both ends included |
| ``Dice/value(_:)`` | the number, for coordinates already in an array |

Write an option twice to make it twice as likely: `pick("x", "x", "X", at: bar)`.

Inside a ``Grid(bars:beats:subdivisions:_:)`` or ``Phrase(bars:beats:subdivisions:_:)`` closure, ask at the ``GridStep`` you were handed. `ride.chance(0.3, at: step)` is `ride.chance(0.3, step.bar, step.stepInBar)`:

```swift
let ride = Dice(seed: 7).stream("ride")
Lane(.ride, Grid(bars: 4, subdivisions: 3) { step in
    if step.isOnBeat { return "x" }
    return ride.chance(0.3, at: step) ? "x" : "."
})
```

A roll can choose anything: a token, a drum piece, a whole phrase, a transposition per pass.

```swift
let fills = Dice(seed: 7).stream("fills")
let line = Phrase(bars: 4, beats: 1) { step in
    fills.pick(["1 2 3 5", "5 3 2 1", "1 - 5 -"], at: step) ?? "1"   // one figure per bar
}
```

```swift
let shifts = Dice(seed: 7).stream("shift")
Session { pass in
    Track("keys") {
        Section { "| C4 E4 G4 C5 |".transpose(shifts.int(in: -5...5, pass)) }
    }
}
.loops(8)
```

The coordinates go inside the roll's own parentheses: `.transpose(shifts.int(in: -5...5, pass))`.

## Leaving a choice to each pass

### Maybe steps

In a drum grid, `?` sounds on about half the passes and a digit on that many passes in ten. Each step rolls its own die from its own position, so two lanes never start agreeing.

```swift
Section {
    Kick( "x... x..3")   // the last kick on about three passes in ten
    Snare(".... x...")
    Hat(  "x.x? x.x7").volume(0.45)
}
```

Write what you decided as `x` and `X` and leave the rest as odds, and every pass is a different performance of the same music. Let the dice place the maybes and the passes sound them: `ride.chance(0.3, at: step) ? "?" : "."`.

### Note sets

`?(…)` in notation is a note set whose member is drawn on each pass. Without a prefix, or with `~`, the members take turns upward; `~~` walks them down and `~*` up and back.

```swift
Section { "| C ?(E G B) C |" }               // one note, three readings
Section { "| ?(1maj 6m) - ?(4maj 2m) - |" }  // a chord drawn per pass
Section { "| ([1 3 5] [4 6 1']) |" }         // two stacks taking turns
```

A member can be a note, a chord symbol, a chord on a degree or a stack. Ties, rests and slides cannot: a set chooses between things that sound. In Swift the same thing is a ``NoteSet``.

### Velocity and length

``Section/velocity(random:)`` draws each note's velocity from a range on every pass, and ``Section/durations(random:)`` its length from a list. Start times never move, so the section keeps its shape however the draw goes.

```swift
Section { "| C E G C |" }.velocity(random: 70...110)
Section { "| C E G C |" }.durations(random: [.n8, .n4])
```

### Which layer, which order

``Section/pickOne()`` plays exactly one of a section's statements on each pass. ``Track/shuffleSections()`` plays a track's sections in a new order on each pass after the first.

```swift
Section {
    "| C5 E5 G5 - |"
    "| C5 F5 A5 - |"
    "| B4 D5 G5 - |"
}.pickOne()
```

## The performance

``Session/seed(_:)`` changes every choice left to the passes: note sets, maybe steps, `pickOne()`, drawn velocities and lengths. One score has as many performances as there are seeds, and each plays the same way every time. A score without a seed keeps the rolls it always had.

```swift
Session { … }.tempo(150).seed(11)
```

The session's seed does not change a ``Dice`` you made yourself: that one has its own seed.

## Topics

- ``Dice``
- ``GridStep``
- ``NoteSet``
