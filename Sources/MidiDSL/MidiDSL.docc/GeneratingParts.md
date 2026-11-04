# Generating Parts

Drum grids and phrases computed by code instead of typed.

## Overview

A drum lane takes a grid string. ``Grid(bars:beats:subdivisions:_:)`` writes that string for you: it calls your closure once per step and joins the bars with `|`. So a part can be described by its rules, such as "ride on every beat, a skip note after 2 and 4, the odd stray triplet", instead of typed out.

```swift
Grid(bars: 2, beats: 4, subdivisions: 3) { step in step.isOnBeat ? "x" : "." }
// "x..x..x..x.. | x..x..x..x.."
```

What comes back is an ordinary string. It goes into ``Lane(_:_:)``, ``Kick(_:)`` or any other lane exactly like a literal, and it can be kept in a `let` and used in several places. With ``Dice`` deciding, the part depends on the seed and is still as fixed and reproducible as one you typed.

``Phrase(bars:beats:subdivisions:_:)`` does the same for notes; see <doc:GeneratingMelodies>.

## The grid's shape

Each bar gets `beats × subdivisions` steps. Without `beats:`, the session's time signature decides, so a grid in a 3/4 session has three beats a bar. `subdivisions:` is the resolution:

| `subdivisions:` | Steps in a 4/4 bar | Good for |
|---|---|---|
| `4` (the default) | 16 sixteenths | straight, gridded parts |
| `3` | 12 triplet eighths | swing: a swung ride lands on these |
| `2` | 8 eighths | a simple backbeat |

Writing swing on a triplet grid puts each note where it belongs, which is easier to reason about than writing straight eighths and moving them with ``Section/swing(_:)``.

```swift
// A ride: on every beat, with the skip note after 2 and 4
Grid(bars: 1, subdivisions: 3) { step in
    if step.isOnBeat { return step.beat % 2 == 0 ? "X" : "x" }
    return step.sub == 2 && step.beat % 2 == 1 ? "x" : "."
}
// "X..x.xX..x.x"
```

Match `bars:` to the part. When a session sets ``Session/loopBars(_:)``, a longer grid is cut off at the end of the pass, and a shorter one leaves the lane silent for the rest of it.

## Where a step is

The closure is handed a ``GridStep``. Every count starts at 0.

| Property | Is |
|---|---|
| `bar` | the bar |
| `beat` | the beat within the bar; `beat % 2 == 1` is beats 2 and 4 |
| `sub` | the place within the beat; with 3 subdivisions, `2` is the swung note before the next beat |
| `stepInBar` | the step within the bar, starting again every bar |
| `index` | the step counted from the start of the grid, never starting again |
| `isOnBeat` | `true` on the beat itself, `sub == 0` |
| `isDownbeat` | `true` on the first beat of a bar |
| `isLastBeat`, `isLastBar` | `true` in the bar's last beat, the grid's last bar |
| `bars`, `beats`, `subdivisions` | the shape of the whole grid |

```swift
Grid(bars: 2, beats: 2, subdivisions: 2) { step in Character("\(step.stepInBar)") }  // "0123 | 0123"
Grid(bars: 2, beats: 2, subdivisions: 2) { step in Character("\(step.index)") }      // "0123 | 4567"
```

Use `stepInBar` for anything that should repeat bar to bar, and `index` for anything that should develop across the whole grid.

## What to return

The character you return lands in the string, so a generated grid reads like a written one: `x` hit, `X` accent, `o` ghost, `.` rest, `?` and `1`…`9` a hit on some passes. Anything else is a rest, so a typo goes quiet.

There are two kinds of chance here, and they compose. Dice asked inside the closure decide once, while the score is built: they place the pattern. A `?` or a digit is decided again on every pass, while the piece plays. So `ride.chance(0.3, at: step) ? "?" : "."` means "put a maybe in three places in ten, and sound each one on half the passes".

## Recipes

### A spine and a field of maybes

State the notes that make the part recognisable and leave the rest to chance. The spine never drops out, so the groove stays itself while everything around it moves.

```swift
let ride = Dice(seed: 7).stream("ride")
let grid = Grid(bars: 4, subdivisions: 3) { step in
    if step.isOnBeat { return step.beat % 2 == 0 ? "X" : "x" }
    if step.sub == 2 && step.beat % 2 == 1 { return "x" }
    return ride.chance(0.3, at: step) ? "?" : "."
}
// "X..x.xX..x.x | X..x.xX..x?x | X..x?xX?.x.x | X..x.xX.?x.x"
```

### A stream per lane

Two lanes asking the same dice about the same step get the same answer and move together, which sounds like one lane doubled. Give each its own ``Dice/stream(_:)``:

```swift
let dice  = Dice(seed: 7)
let ride  = dice.stream("ride")
let snare = dice.stream("snare")
```

### A fill in the last bar

Raise the odds where the phrase answers itself, and the part shapes itself into sentences without a fill written out.

```swift
let snare = Dice(seed: 7).stream("snare")
let grid = Grid(bars: 4, subdivisions: 3) { step in
    let roll = snare(at: step)
    if step.sub == 2 { return roll < (step.isLastBar ? 0.50 : 0.22) ? "7" : "." }
    return roll < (step.isLastBar ? 0.30 : 0.08) ? "4" : "."
}
// "..7...4..... | ............ | ......4..... | ..7447..7..."
```

`step.bar % 4 == 3` puts the fill on every fourth bar of a longer grid instead.

### Picking from a set

``Dice/pick(_:_:at:)-(T,T...,GridStep)`` chooses between characters when the choice is not yes or no. Write an option twice to make it likelier.

```swift
let hats = Dice(seed: 7).stream("hats")
let grid = Grid(bars: 4) { step in step.isOnBeat ? "x" : hats.pick("o", ".", ".", at: step) }
```

### Developing across the grid

`index` does not start again at the barline, so anything keyed to it changes over the whole passage.

```swift
let open = Dice(seed: 7).stream("open")
let grid = Grid(bars: 8) { step in               // the hat opens up as the bars go by
    open.chance(Double(step.index) / 128, at: step) ? "x" : "."
}
```

## Written or generated

A written grid shows you the groove; a generated one shows the rules that made it. That is usually the better trade for eight bars of comping, and the wrong one for a hook you want to see. Mix them: generate the parts that should feel played, and write out the parts that should feel decided.

## Topics

- ``Grid(bars:beats:subdivisions:_:)``
- ``Phrase(bars:beats:subdivisions:_:)``
- ``GridStep``
- ``Dice``
