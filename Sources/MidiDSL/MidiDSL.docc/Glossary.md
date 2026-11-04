# Glossary

The words these pages use in a particular sense.

## Overview

- term whole note: The unit of musical time. Durations and start times are fractions of a whole note in every meter: `0.25` is a quarter, `0.125` an eighth.
- term beat: One beat of the session's time signature: a quarter in 4/4 and 3/4, an eighth in 6/8. The tempo counts quarter notes, whatever the beat.
- term bar: One bar of the time signature, `beatsPerBar / noteValue` whole notes long.
- term statement: One line in a `Section { }` block: a notation string, a drum lane, a note, a chord, a progression or a nested section.
- term layer: What a statement is within its section. Every layer of a section starts at the section's start, and the longest sets its length.
- term slot: One token's share of time. In bar notation a bar's tokens split it into equal slots; in inline notation each token is a whole-note slot, and a space between two notes is a rest slot.
- term beat position: A start time within a section. The per-beat section modifiers, such as ``Section/velocities(_:)``, count them; the notes of a chord share one.
- term degree: A number standing for a note of the key: `1` is the root, `5` the fifth. It sounds once a key is named.
- term key: The scale degrees are read in, named with `.key(root, mode)` on any level. The innermost one wins.
- term pass: One time through the whole piece. Every track goes round with it. ``Session/loops(_:)`` sets how many there are; `.active(loops:)` and the dice count them.
- term round: One time round a ``Loop``, inside one track. A loop's number counts rounds; a session body's `pass` counts passes.
- term form: All the passes of a piece, the length a MIDI file writes by default.
- term seed: The number a ``Dice`` rolls from, or, on a session, the number that changes every choice left to the passes. Each seed gives one take, the same every time.
- term stream: Dice of their own for one part, made with ``Dice/stream(_:)``, so two parts never move together.
- term take: One result of a seed: a generated part, or a performance of the choices left to the passes.
