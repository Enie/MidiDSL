# Generating Parts

Grids and phrases computed from code instead of typed.

## Overview

A drum lane takes a grid string. Grid writes that string for you — it calls your closure once per step and joins the bars with | — so a part can be described by its rules ("ride on every beat, swing eighths before 2 and 4, the occasional stray triplet") instead of typed out character by character.

What comes back is an ordinary String. Nothing downstream knows it was generated: it goes to Lane, Kick, Snare or any other lane constructor exactly like a literal, and it expands to the same notes. Pair it with Dice(seed:) and the part becomes a function of the seed while staying every bit as fixed, exportable and reproducible as one you wrote by hand.

Melodies are generated the same way one level up, by Phrase and Markov — see the Generating Melodies topic.

## The call

### Grid()

```swift
Grid(bars: Int, beats: Int = 4, subdivisions: Int = 4, _ fill: (GridStep) -> Character) -> String
```

- term `bars`: How many bars to lay out. Match it to the session's .loopBars(…) or the tail never plays and the lane goes silent for the rest of the pass.
- term `beats`: Beats per bar — match your time signature. 4 unless the piece says otherwise.
- term `subdivisions`: Steps per beat, and so the resolution: 4 gives sixteenths, 3 the triplet eighths a swung ride actually lands on. Each bar gets beats × subdivisions characters.
- term `fill`: Called once per step, in order, with that step's coordinates; answers the one character the step holds.

Calls fill for every step of every bar, in order, and joins the bars with " | ". Each bar gets beats × subdivisions characters — with the defaults, 4 × 4 = 16 sixteenths.

bars is how many bars to lay out; match it to the session's .loopBars(…) or the lane will be longer or shorter than the loop. beats is beats per bar — match your time signature. subdivisions is steps per beat, which is the resolution knob (see below). bars: 0 gives an empty string; beats and subdivisions below 1 are treated as 1.

```swift
// Every downbeat, nothing else — two bars of 4 × 3
Grid(bars: 2, beats: 4, subdivisions: 3) { s in
    s.isDownbeat ? "x" : "."
}
// → "x..x..x..x.. | x..x..x..x.."
```

### Where it goes

```swift
Lane(.ride, Grid(…))
```

The result is a String, so it can go straight into a lane, be stored in a let and reused across lanes, or be built once and sliced. The lane divides each bar evenly by however many step characters that bar holds, so the resolution you chose in Grid is the resolution you get.

```swift
let ride = Grid(bars: 8, subdivisions: 3) { … }

Section {
    Lane(.ride, ride)
    Snare(snare)
    Kick(kick).volume(0.4)
}
```

## Where you are — GridStep

### s.bar

```swift
Int, 0-based
```

Which bar this step is in. s.bar % 4 == 3 is the classic "every fourth bar opens up into a fill".

### s.beat

```swift
Int, 0-based
```

Which beat of the bar. s.beat % 2 == 1 is beats 2 and 4 — where the backbeat and the hi-hat foot live.

### s.sub

```swift
Int, 0-based
```

Which subdivision within the beat. With subdivisions: 3, sub 0 is the beat, sub 1 the middle triplet and sub 2 the swung "da" just before the next beat. With subdivisions: 4, sub 2 is the eighth-note offbeat.

### s.isDownbeat

```swift
Bool
```

The beat itself rather than one of its subdivisions — the same as s.sub == 0, spelled the way you think about it.

### s.step

```swift
Int, 0-based
```

The step's position within its bar: beat × subdivisions + sub. It restarts at 0 on every bar, which makes it the right coordinate for anything that should repeat bar to bar.

```swift
Grid(bars: 2, beats: 2, subdivisions: 2) { s in Character("\(s.step)") }
// → "0123 | 0123"
```

### s.index

```swift
Int, 0-based
```

The step counted from the start of the whole grid, never restarting. Use it for anything that should move continuously across the bars — a hat that opens a little more every bar, a crescendo, a pattern with a period that isn't the bar.

```swift
Grid(bars: 2, beats: 2, subdivisions: 2) { s in Character("\(s.index)") }
// → "0123 | 4567"
```

## What to return

### One character per step

```swift
x  X  o  .  -  ?  1–9  0
```

The character you return is exactly what lands in the string, so a generated grid reads like a written one: x hit, X accent, o ghost, . or - rest. Return ? for an even coin and 1–9 for odds in tenths (see <doc:DiceAndChance>) and the step becomes a maybe the machine re-decides on every pass — that is how a generated part keeps evolving instead of repeating the pattern the seed produced. 0 is a rest, not a never-sounding note.

Anything else — a space, a letter — is a rest too, so a typo goes quiet rather than crashing.

### Two levels of chance

```swift
d.chance(…) ? "?" : "."
```

Worth keeping straight, because they compose. The dice you call *inside* the closure run once, while the piece compiles: they decide the pattern — where the maybes are. A ? or digit *character* is decided again on every pass, while the piece plays. So d.chance(0.3, …) ? "?" : "." means "the dice put a maybe here in three of ten places, and each of those sounds on half the passes".

## Choosing a resolution

### subdivisions: 4

```swift
16 steps per bar
```

Sixteenths — the drum-machine default, and what you want for straight, gridded music.

```swift
Grid(bars: 1) { s in s.isDownbeat ? "X" : (s.sub == 2 ? "x" : ".") }
// → "X.x.X.x.X.x.X.x."
```

### subdivisions: 3

```swift
12 steps per bar
```

Triplet eighths — where a swung ride actually lands. Writing swing on a triplet grid puts each note where it belongs, which is more honest (and easier to reason about) than writing straight eighths and pushing them around with .swing(0.67) afterwards.

```swift
// ride: ding on each beat, ding-DA before 2 and 4
Grid(bars: 1, subdivisions: 3) { s in
    if s.isDownbeat { return s.beat % 2 == 0 ? "X" : "x" }
    return s.sub == 2 && s.beat % 2 == 1 ? "x" : "."
}
```

### subdivisions: 2

```swift
8 steps per bar
```

Eighths — enough for a simple backbeat, and the shortest grid that still reads at a glance.

## Recipes

### A spine and a field of maybes

The shape most generated parts want: state the notes that make the part recognisable, and leave the rest to chance. The spine never drops out, so the groove stays itself while everything around it moves.

```swift
let d = Dice(seed: 7)
Lane(.ride, Grid(bars: 8, subdivisions: 3) { s in
    if s.isDownbeat { return s.beat % 2 == 0 ? "X" : "x" }
    if s.sub == 2 && s.beat % 2 == 1 { return "x" }
    return d.chance(0.3, 1, s.bar, s.step) ? "?" : "."
})
// → "X?.x?xX..x?x | X??x?xX?.x?x | X..x?xX.?x.x | …"
```

### One stream per lane

Give each part its own leading number. Two lanes that call the dice with the same coordinates get the same answers and start moving together — which sounds like one lane doubled, not like two players.

```swift
let ride  = Grid(…) { s in d.chance(0.3, 1, s.bar, s.step) ? "?" : "." }
let snare = Grid(…) { s in d.chance(0.3, 2, s.bar, s.step) ? "?" : "." }
//                                     ↑ different stream
```

### Fills on the fourth bar

Raise the odds on the bar that answers the phrase, and the part shapes itself into four-bar sentences without you writing the fill.

```swift
let snare = Grid(bars: 8, subdivisions: 3) { s in
    let fill = s.bar % 4 == 3
    let roll = d(2, s.bar, s.step)
    if s.sub == 2 { return roll < (fill ? 0.50 : 0.22) ? "7" : "." }
    return roll < (fill ? 0.30 : 0.08) ? "4" : "."
}
// → "647..7..o... | o4.6.7.4o... | ..oo.o...o.. | .47.476.7..7"
```

### Pick from a set

.pick chooses between characters directly when the decision isn't yes-or-no — a hit that might be a ghost, an accent that might be a rest.

```swift
let hats = Grid(bars: 4) { s in
    s.isDownbeat ? "x" : (d.pick(["o", ".", "."], 3, s.bar, s.step) ?? ".")
}
```

### Motion across the whole grid

s.index doesn't restart on the barline, so anything keyed to it develops over the whole passage instead of repeating each bar.

```swift
// opens up as the eight bars go by
let hat = Grid(bars: 8) { s in
    d.chance(Double(s.index) / 128.0, 4, s.index) ? "x" : "."
}
```

## Worth knowing

### You trade the pattern for the intent

A written grid shows you the groove; a generated one shows you the rules that made it. That is usually the better trade for eight bars of comping, and the wrong one for a hook you want to see. Mix freely — generate the parts that should feel played, write out the parts that should feel decided.

### Match bars to the loop

Grid lays out exactly the bars you ask for. If the session loops fewer bars than the grid holds, the tail never plays; if it loops more, the lane goes silent for the rest. .loopBars(bars) with the same bars you passed keeps them in step.

```swift
let bars = 8
let ride = Grid(bars: bars, subdivisions: 3) { … }
// …
.loopBars(bars)
```
