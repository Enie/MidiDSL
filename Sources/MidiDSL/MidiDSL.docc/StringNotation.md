# String Notation

Melodies, chords and rhythms written as strings.

## Overview

Any string literal inside a Section is parsed as music.

Two modes: inline notation (tokens separated by spaces, each lasting one whole note by default, with a space between two notes counting as a rest beat — see Rests) and bar notation (the string contains "|"; each bar's tokens split the bar evenly, bar length follows the time signature, and a space only separates). Most music reads best in bar notation; the examples below use it wherever a rhythm matters.

## Notes & rests

### Note names

```swift
C  D#4  Bb2  E6  E#  Cb4  F##  'G7
```

Letter + any run of #/b + optional octave. A bare name (no octave) means octave 5, so "C" is MIDI 60. The name is read, not looked up in a table of the twelve keys, so a note may be spelled the way the music spells it: "E#" is the F above E, "Cb" the B below C (an octave under a written "B", since the octave belongs to the letter), "B#5" the C above, "F##" a G. Careful: "G7" is the pitch G octave 7, not a chord, in every mode — inline, in bars, in [stacks] and in slides — so write "Gdom7" for the chord. A leading apostrophe also forces the pitch reading ("'G7"), which is what an element after a chord name in a [stack] needs.

### Compact runs

```swift
"CDEF"  "C4E4G4"
```

A single token of run-together notes is split character-wise into a sequence — accidentals and octave digits attach to the note before them. Note names only: a run of degrees can't be spelled this way ("135" would be the degree 135), so write those as a { } run group.

```swift
"CDEFGABC6"        // one octave up-run
```

### Run groups

```swift
{1 2 3 4}  {C5 D5 E5}  {1 2 3}
```

Everything inside a { } group shares the one slot the group sits in — the serial twin of the [ ] stack, which sounds its contents together. Inside, a space separates the notes sharing the slot (never a rest beat), and anything a bar can hold works: ties, rests, chord stacks, chords on degrees, slides, and further groups. This is how a fast figure fits in an otherwise slow bar without re-gridding it, how degrees get a compact run, and the only way to write a tuplet: the slot divides by however many notes are in the group, so three is a triplet and five a quintuplet. A - after the group extends the group's last note.

```swift
"| 1 - - {1 2 3 4} |"   // three slow beats, then four fast ones
"| 1 - - {1 2 3} |"     // a triplet on the last beat
"| {C5 D5 E5} G5 |"     // works for note names too
"| 1 - - {1 {2 3}} |"   // groups nest
```

### Rests

```swift
R  _  (space)
```

R or _ is a one-beat rest. In inline notation a space between two sounding tokens also inserts one rest slot (consecutive spaces collapse into one), so "C E G" is C, rest, E, rest, G. No rest goes in next to an explicit R or _, or before a token that continues what came before it — one starting with -, +, > or ^. These implicit rests are beats like any other — per-beat modifiers such as .durations() and .velocities() count them. Write "CEG" or "| C E G |" for three notes in a row.

```swift
"C R E _ G"        // note, rest, note, rest, note
```

## Chords

### Chord tokens

```swift
Cm7  Fmaj7  Bbm7b5  Gdom7  Ddim  Eaug  Cm9
```

Root + quality suffix. Suffixes: (empty)/M/maj, m/mi/min, dim/o, aug/+, dom7/dom (dominant 7), M7/maj7/Δ, m7/min7, add9, add11, sus4, sus2, 7sus4, maj6/M6/6th, m6/min6, pow/no3 (power chord, root + fifth), ø7/ø/m7b5, o7/dim7, m9/min9, M9/maj9, dom9, m11/min11, dom13. A token that spells a pitch is the pitch everywhere — "C7" is the pitch C octave 7 (write "Cdom7"), "C9" a pitch (write "Cdom9"), "C6" the pitch C octave 6 (write "Cmaj6"), "C5" a pitch (write "Cpow"). A 7 that carries an alteration spells no pitch, so "G7b9" is still a chord.

### Altered chord tokens

```swift
G7b9  Cmaj7#11  Am7b13  C7b5
```

Any quality suffix can carry trailing alterations b/# + 5, 9, 11 or 13 in one token. The longest known quality wins first — "Cm7b5" is still half-diminished, and "Cm7b5b9" is half-diminished + b9. Altered fifths replace the natural fifth ("C7b5" = C E Gb Bb); other alterations stack on top as extra tones. One inline quirk: a string whose only token is all note-run characters ("G7b9" alone) reads as a compact run, not a chord — use bar mode or more tokens.

```swift
"Dm7 G7b9 | Cmaj7#11"
```

### Jazz extension brackets

```swift
[Cmaj7 9 #11]  [Gdom7 b9 13]
```

A bracketed chord adds extension tones: 7, b7, maj7, 9, b9, #9, 11, #11, 13, b13, b5, #5 (altered fifths replace the natural fifth). Extensions that duplicate an existing chord tone are ignored.

```swift
"[Dm7 9] [Gdom7 b9] [Cmaj7 9 #11]"
```

### Custom note stacks

```swift
[C E G Bb4]  [C7 E]  [Cdom7 'G8]
```

If the first element isn't a chord name, the bracketed notes simply sound together as a custom chord. "[C7 E]" stacks the pitches C7 and E. After a chord name, an apostrophe marks an element as a raw pitch rather than an extension: "[Cdom7 'G8]" adds the pitch G8 on top of the C dominant 7 chord.

## Note sets (per-loop variation)

### (C E G)

```swift
(pitch pitch …)
```

One note per pass, cycling through the listed pitches on each loop iteration. Prefix chooses the order: ~ up (default), ~~ down, ~* alternating, ? random.

```swift
"| C2 (C3 Eb3 G3) C2 ?(C3 Eb3 G3 Bb3) |"
```

## Arpeggios

### Pattern marks

```swift
~Cm7  ~~Cm7  ~*Cm7  ?Cm7   (also postfix: Cm7~)
```

Arpeggiate a chord token: ~ up, ~~ down, ~* alternating (low-high-middle), ? random. Prefix or postfix, also on bracket chords. Default note spacing is a tight 0.05 strum.

### Fill spread

```swift
~=Cm7   Cm7~=   ~~=Cm7
```

Adding = spreads the arpeggio evenly over the chord's own duration instead of a tight strum.

### Timed spread

```swift
~0.25Cm7   Cm7~0.25   Cm7~~0.5
```

A number after the mark spreads the arpeggio over exactly that duration (in whole notes).

### Stack arpeggios

```swift
~=[D3 A3 E4 F#4]   [B4 G#4 F#4 D4]~=
```

Arpeggio marks on a custom note stack play it in its *written* order — the listed order is the picking order (a named chord arpeggiates pitch-sorted instead). ~~ reverses the listed order, ~* plays first, last, then the middles, ? shuffles. Each note rings through the slot, so a fingerpicked voicing sounds let-ring — spell the same pitches as a compact run ("D3A3E4F#4") for sequential, non-ringing sixteenths.

```swift
"| ~=[D3 A3 E4 F#4] C#5 - ~=[C#5 E5 C#5 A4] |"
```

## Joining notation

### +

```swift
"…" + "…"  /  expression + expression
```

Between two plain strings, + is Swift's own: it joins the text, and one set of modifiers then owns all of it. Between notation that carries modifiers it does something else — each part is parsed and modified on its own, and only then are the parts laid end to end, the way a track lays out its sections one level up. So each part keeps its own key, its own velocities and its own fade. Mixing is fine: a plain string on either side of an expression joins the same way.

```swift
"| 1 3 5 5 |".automate(.volume, over: [0: 0.2, 1: 1.0])
    + "| 5 3 2 1 |".automate(.volume, over: [0: 1.0, 1: 0.2])
```

### Automating a join

```swift
(a + b).automate(_ target: AutomationTarget, over breakpoints: [Double: Double], curve: AutomationShape = .linear)
```

- term `target`: As on a single line — see .automate. A per-voice curve here multiplies with any a part carries; a track parameter written on a part covers that part's own window, and two serial parts sweeping the same one are two sweeps, not a contest.
- term `over`: time: value across the whole join, as a fraction of its total span. at:, bars: and beats: work here too, exactly as they do on one line.
- term `curve`: The shape between breakpoints — .linear, .exponential, .smooth, .hold.

A curve written on the join covers all of it. Other modifiers belong on the parts, which is the point of joining rather than concatenating.

### Interpolation

```swift
"\(expression) | G"
```

Interpolating notation that carries modifiers into another string keeps the notes and loses the modifiers — there is nowhere in a string to put a fade. Use + to keep them. Interpolating a plain String variable is unaffected and still the way to reuse a motif.

## Suspensions & ties

### Hold  -

```swift
"Cm - - -"   "Cm - - - | - - - -"
```

A lone - extends the previous token's notes through its slot instead of re-attacking them. Works across barlines. A space before - or + does not insert a rest.

```swift
"Cm7 - Fm7 - | Bbdom7 - - -"
```

### Add notes  +

```swift
+9  +[9]  +[9 13]  +D5  +Cm9
```

Keeps the previous notes ringing and attacks new ones on top. Bare tokens or [brackets] are extensions resolved against the held chord; a pitch adds that pitch; a full chord name attacks only the pitches not already sounding — "Cm +Cm9" re-attacks just the 7th and 9th.

```swift
"Cm - +Cm9 -"      // Cm suspends into Cm9
```

### Arpeggiated adds

```swift
+Cm9~0.15   +~0.15[9 13]
```

Arpeggio marks on a + token strum only the newly attacked notes; held notes keep ringing untouched.

### Compact ties

```swift
"C-D-E"
```

Inside a compact run, - extends the previous note by one slot: C and D last two slots each, E one.

## Slides

### Slide into  >

```swift
"C >E"   "Cm - >Fm -"   "Cm >[Fm7 9]"   "Cmaj | >Fmaj"
```

A token starting with > continues the previous notes into new pitches — one voice, no re-attack, gliding at the slot boundary. Like - and +, a space before it inserts no rest, and it works across barlines. Chords pair voices low to high; unpaired target voices attack normally. Targets can also be [brackets]: ">[Cm7 9]" slides into the chord with its extensions, ">[C E G 'C7]" into a custom stack of pitches (the ' escape forces a pitch reading). Targets may be written as degrees too — ">5", ">3'", ">[4 6 1']", ">6m" — and a key then moves the glide at both ends, or only at the end when it lands on an absolute name ("1 >C6"). Note sets ">(C Eb)" and arpeggiated targets ">~Fm" are not supported — they warn, and the previous notes are held through the slot (like -) instead.

```swift
"Cm - >Fm -"       // Cm two slots, slides into Fm for two
"Cm >[Fm7 9]"      // three voices glide, the 7th and 9th attack
"| 1 >5 - - |"     // the same in numbers: glide to the fifth
```

### Bent note  >

```swift
"C>E"   "CD>EF"   "Am>Gmaj"   "[C E]>[D F]"   "1>3"   "C>D>E"
```

> inside a token fuses its pitches into one bent note in a single slot: attack at the first pitch, glide, land on the last. Works in compact runs, between chord names, between [bracket] stages — "[C E]>[D F]" bends both voices together — and between degrees, "1>3" or "[1 3 5]>[4 6 1']". Extra > stages divide the slot evenly. Extend with ties: "C>E-".

```swift
"C>E G"            // bent note, rest, G
"| 1>3 - - - |"    // the same written in numbers
```

### Glide timing

```swift
>E   >=E   >0.25E   (a bare number is a degree: >5)
```

Default is a quick ~80 ms glide. = spreads the glide over the whole available span (a continuous glissando); a number glides over exactly that duration in whole notes. One rule keeps that apart from degree notation: if the whole payload after > names a degree it is the target, not a timing — ">5" slides to the fifth, ">0.25E" glides into E over a quarter note. A written length can't precede a plain degree, though: ">0.255" reads as one number and leaves no target (it warns). Use the default, use ">=5" to fill the slot, or write the length before a target that doesn't start with a digit — a name (">0.25C6") or an altered degree (">0.25#5"). A MIDI file writes slides as pitch-bend curves, with the bend range set per track (RPN 0) to fit the widest slide.

```swift
"C >=C6"           // octave glissando filling the second slot
"| 1 >=5 - - |"    // the same in numbers: glide fills the slot
```

### Scoop  >-3E

```swift
">-3E"   ">+5E"   ">0.1-3E"   ">-3Am"
```

A signed interval after > names the scoop source relative to the target: the note attacks gliding in from that many semitones below (-) or above (+). Order after >: optional glide length, signed interval, target — ">0.1-3E" scoops E from 3 below over 0.1 whole notes. Chord and [bracket] targets scoop every voice by the interval in parallel. The signed form always attacks fresh — anything still held just ends at the slot. Scoops are their own token; inside a compact run, write the source explicitly with an infix bend ("C>E") instead. Degree targets work when they carry a b/# (">-3b3"), and the source then follows the key with the target; a plain-digit degree can't be scooped, since the interval's own digits run into it.

```swift
">-3E"             // E, scooped from C# at the attack
">+5Am"            // Am, every voice sliding down into place
```

### Portamento  R >E

```swift
"C R >E"
```

A bare > target with nothing held scoops from the last pitch the string sounded — a portamento across the rest. Single-pitch targets only; chord targets and a > at the very start of the string (no history) attack plain and warn, suggesting the signed form (">-3E"). There is deliberately no default interval. If the remembered note was written as a degree, the scoop starts from wherever the key puts it — "| 1 R >5 - |" glides from the first degree, not from a fixed C.

```swift
"C R >E"           // C, rest, then E sliding in from C
```

### Hammer-on / pull-off  ^

```swift
"C ^E"   "C^E"   "E^C"   "C^0.7E"   "Am^Gmaj"   "C^D^E"
```

^ is the legato connector: like >, but the pitch changes instantly — a hammer-on (upward) or pull-off (downward) — with no re-attack, the ring carrying on slightly softer. A token starting with ^ hammers the held notes onto new pitches at the slot boundary ("C ^E", "Cm - ^Fm", works across barlines); inside a token it fuses stages into one slot ("C^E" is a grace hammer at the attack, "CD^EF" works in compact runs, "Am^Gmaj" pairs chord voices low to high). Each step keeps 90% of the ringing level by default; a decimal right after ^ sets the carry — "^0.7E" keeps 70%, "^1E" keeps all of it. Carries compound along a chain ("C^D^E"). A MIDI file writes the step as an instant pitch bend at unchanged velocity; the carry is there for a player that can lower a ringing note's level. Degrees work on both sides, as with > — "1 ^3" hammers onto the third, and a bare number after ^ is that degree, not a carry factor (a carry is a decimal written before the target, "^0.7E"). Note sets and arpeggiated targets warn and hold, like slides; scoop intervals ("^-3E") don't apply to legato.

```swift
"C ^E ^G"          // C, hammer to E, then to G — one voice
"| G E ^D E |"     // pull-off from E to D, then E re-attacks
```

### Fall  C>-3  C>_

```swift
"C>-3"   "C>+2"   "C>_"   "C>0.25-3"   "Am>_"   "CDE>-3"
```

A trailing > with a signed interval makes the note fall away as it ends: the pitch ramps to the interval exactly at note-off and the release rings at the fallen pitch. >_ is the default drop (a fifth down, -5 st). An optional number before the interval is the fall length in whole notes; the default is quick (0.15 s or a quarter of the note, whichever is shorter). On a chord every voice falls in parallel; after a compact run the fall lands on the run's last note; on a tie ("C ->-3") the held note falls at that slot's end. Composes with slides ("C>E>-3") and scoops (">-3E>_"), warps with .tempo() and rescales with the duration modifiers. A MIDI file writes it as a bend curve and recentres the bend after the note-off.

```swift
"C>-3"             // C, dropping 3 st into the release
"Am>_ | Gm>_"      // each chord falls off as the bar turns
```

## Bar notation

### "… | … | …"

```swift
"Cm7 | Fm7 Bbdom7 | Ebmaj7 | R"
```

Bars are separated by |. Each bar's tokens share it equally: one chord fills the bar, two chords get half each. Unlike inline notation, a space here is just a separator — no rest slot — so bar notation is the way to write chords back to back. A compact melody run ("CDEF", ties and > glides included) is one token: its notes subdivide the token's slot evenly, so "CDEF | G" is four quarter notes then a bar of G. A { } run group does the same for anything a bar can hold — degrees, stacks, chords — and is the way to write a tuplet. An empty bar or R is a full-bar rest; use - to hold a chord for extra slots. "G7" is the pitch G octave 7 here as everywhere — the dominant chord is "Gdom7". Bar length comes from the session's .timeSignature(): beatsPerBar/noteValue of a whole note, so 4/4 (the default) = 1.0 and 3/4 = 0.75 — the same bars a MIDI file's time signature marks.

```swift
"Dm7 Gdom7 | Cmaj7 | ~=Am7 | [Gdom7 b9]"
"Am - - Fmaj7 | Gmaj"    // Am 3/4 bar, Fmaj7 1/4, G the whole bar
"CDEF Cmaj | G"          // the run fills half the bar: four eighths, then the chord
```

## String modifiers

### .duration()

```swift
"…".duration(_ d: MusicTimeStamp)
```

- term `d`: One length for every beat, in whole notes (.n8 an eighth, .n4 a quarter). It also re-spaces: beats still on the default grid are laid back to back, so this changes how long the string lasts.

Gives every beat the same duration and re-spaces beats that sit on the default grid back to back — "CDEF".duration(.n8) is four consecutive eighths.

```swift
"CEGC6".duration(.n8)
```

### .durations()

```swift
"…".durations(_ ds: MusicTimeStamp...)
```

- term `ds`: One length per beat, in order, re-spaced back to back. Every slot counts — including the rest slots that spaces insert in inline notation. Beats past the end of the list keep the whole-note default, which can silently overrun the loop.

One duration per beat, re-spaced back to back like .duration(); chord notes share their beat's value. Every slot counts — including the rest slots that spaces insert in inline notation, so "Am Fmaj7" is three beats: chord, rest, chord. Beats beyond the list keep the whole-note default, which can silently overrun the loop. To put chords back to back without rests, use bar notation or one statement per chord instead.

```swift
"Am~0.15 Fmaj7~0.15".durations(.n2, .n2, .n1)   // strum, breath, strum held
```

### .automate(over:)

```swift
"…".automate(_ target: AutomationTarget, over breakpoints: [Double: Double], curve: AutomationShape = .linear)
```

- term `target`: What moves. .volume is a gain, 0…1, and rides each voice — so a held note fades while it rings and two layers of one section can fade differently. .cutoff (Hz), .resonance, .reverb (0…1) and .cc(n) move something the whole track shares — one MIDI channel — and a MIDI file carries them as CC 74, CC 71, CC 91 and CC n.
- term `over`: time: value, with the time as a fraction of this line's own span — 0 is its start, 1 its end. The curve is linear between breakpoints and holds outside them, so one breakpoint is a constant and an empty dictionary changes nothing. Each time may appear only once: a repeated key is a Swift error at the literal, not a later value quietly winning.
- term `curve`: How the value gets from one breakpoint to the next. .linear (the default) is a straight line; .exponential is the shape a decay has and is usually what a volume fade wants, since gain is linear but hearing is not — a straight line drops fast and then lingers; .smooth eases in and out so there is no corner where segments meet; .hold does not ramp at all, holding each value until the next breakpoint and then jumping. The shape is spent when it is written: it becomes breakpoints, so everything downstream reads one piecewise-linear curve.

Move a parameter over time — a fade, a swell, a filter sweep. Four spellings, one per unit of time; this one measures the curve against the line's own length, so it survives a tempo change or an edit that makes the line longer. Write .automate last in a chain: .durations() after it stretches each note's slice of the curve rather than moving the note along it.

```swift
"| 1 3 5 5 | 5 3 2 1 |".automate(.volume, over: [0: 0.2, 1: 1.0])
Section { … }.automate(.volume, over: [0: 1, 0.75: 1, 1: 0])
```

### .automate(at:)

```swift
"…".automate(_ target: AutomationTarget, at breakpoints: [Double: Double], curve: AutomationShape = .linear)
```

- term `target`: What moves. .volume is a gain, 0…1, and rides each voice — so a held note fades while it rings and two layers of one section can fade differently. .cutoff (Hz), .resonance, .reverb (0…1) and .cc(n) move something the whole track shares — one MIDI channel — and a MIDI file carries them as CC 74, CC 71, CC 91 and CC n.
- term `at`: time: value, with the time in whole notes from this line's start — the DSL's own unit, so .n4 and .n2 work as keys. Otherwise exactly as over:.
- term `curve`: How the value gets from one breakpoint to the next. .linear (the default) is a straight line; .exponential is the shape a decay has and is usually what a volume fade wants, since gain is linear but hearing is not — a straight line drops fast and then lingers; .smooth eases in and out so there is no corner where segments meet; .hold does not ramp at all, holding each value until the next breakpoint and then jumping. The shape is spent when it is written: it becomes breakpoints, so everything downstream reads one piecewise-linear curve.

The same curve, with times in musical whole notes from this line's start.

```swift
Section { … }.automate(.volume, at: [0: 0.2, .n1: 1.0])
```

### .automate(bars:)

```swift
"…".automate(_ target: AutomationTarget, bars breakpoints: [Double: Double], curve: AutomationShape = .linear)
```

- term `target`: What moves. .volume is a gain, 0…1, and rides each voice — so a held note fades while it rings and two layers of one section can fade differently. .cutoff (Hz), .resonance, .reverb (0…1) and .cc(n) move something the whole track shares — one MIDI channel — and a MIDI file carries them as CC 74, CC 71, CC 91 and CC n.
- term `bars`: time: value, with the time as a bar number counted from this line's start — not from the top of the piece. Read under the session's meter, the same meter bar notation is parsed under, so a bars: curve and a | … | phrase cannot disagree.
- term `curve`: How the value gets from one breakpoint to the next. .linear (the default) is a straight line; .exponential is the shape a decay has and is usually what a volume fade wants, since gain is linear but hearing is not — a straight line drops fast and then lingers; .smooth eases in and out so there is no corner where segments meet; .hold does not ramp at all, holding each value until the next breakpoint and then jumping. The shape is spent when it is written: it becomes breakpoints, so everything downstream reads one piecewise-linear curve.

The same curve, with times as bar numbers off the session's time signature, counted from this line's start.

```swift
Section { … }.automate(.cutoff, bars: [0: 400, 3: 6000])
```

### .automate(beats:)

```swift
"…".automate(_ target: AutomationTarget, beats breakpoints: [Double: Double], curve: AutomationShape = .linear)
```

- term `target`: What moves. .volume is a gain, 0…1, and rides each voice — so a held note fades while it rings and two layers of one section can fade differently. .cutoff (Hz), .resonance, .reverb (0…1) and .cc(n) move something the whole track shares — one MIDI channel — and a MIDI file carries them as CC 74, CC 71, CC 91 and CC n.
- term `beats`: time: value, with the time as a beat counted from this line's start. Agrees with bars: by construction — four beats of 4/4 are one bar.
- term `curve`: How the value gets from one breakpoint to the next. .linear (the default) is a straight line; .exponential is the shape a decay has and is usually what a volume fade wants, since gain is linear but hearing is not — a straight line drops fast and then lingers; .smooth eases in and out so there is no corner where segments meet; .hold does not ramp at all, holding each value until the next breakpoint and then jumping. The shape is spent when it is written: it becomes breakpoints, so everything downstream reads one piecewise-linear curve.

The same curve, with times as beats off the session's time signature. Note the limit a shared parameter brings: two statements moving the same .cutoff, .resonance, .reverb or .cc in one window cannot each have it, so the later-written one wins. Only .volume is per-voice, and volume curves multiply.

```swift
Section { … }.automate(.volume, beats: [0: 0.2, 4: 1.0])
```

### .velocity() / .velocities()

```swift
"…".velocity(90)  /  .velocities(110, 70, 90, 70)
```

Uniform or per-beat velocities (0–127).

### .arpeggio()

```swift
"…".arpeggio(_ pattern: ArpeggioPattern = .up, delay: MusicTimeStamp = 0.05)
```

- term `pattern`: The order the chord's notes enter: .up, .down, .alternating, .random. Random is deterministic — a dealt order, not a fresh one each recompile.
- term `delay`: The gap between one note and the next, in whole notes. A fixed strum: the chord's own length doesn't change it, so a long chord still enters quickly. 0.05 is a tight strum.

Arpeggiates every chord in the string with a fixed note delay.

### .arpeggioFill()

```swift
"…".arpeggioFill(_ pattern: ArpeggioPattern = .up)
```

- term `pattern`: The order the notes enter. The spacing isn't yours to set here — the entries are spread across the chord's own duration, so a longer chord rolls more slowly.

Arpeggiates every chord spread over the chord's own duration.

### .arpeggio(over:)

```swift
"…".arpeggio(over: MusicTimeStamp, pattern: ArpeggioPattern = .up)
```

- term `over`: How long the whole roll takes, in whole notes, however long the chord is. The notes are spread evenly across it.
- term `pattern`: The order the notes enter: .up, .down, .alternating, .random.

Arpeggiates every chord spread over an explicit duration.

### .transpose()

```swift
"…".transpose(_ semitones: Int)
```

- term `semitones`: How far to move every pitch, in half steps; negative goes down. 12 is an octave. Absolute names and degrees alike move, since this runs on the pitches.

Shifts all pitches by semitones (negative = down).

```swift
"CDEF".transpose(-12)   // one octave down
```

### .octave()

```swift
"…".octave(_ n: Int)
```

- term `n`: Which octave bare note names land in — the octave they'd have written after them. Names that already carry one ("C4") are left alone; 5 is the default register, so 4 is an octave down.

Moves bare note names (default octave 5) to the given octave.

```swift
"CEG".octave(3)
```
