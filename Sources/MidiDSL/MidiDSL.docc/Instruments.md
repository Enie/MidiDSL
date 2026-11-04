# Instruments

What a track plays, as a MIDI file can say it: a General MIDI program, and drums on channel 10.

## Overview

A MIDI file carries no sound. It names an instrument by number and leaves the sound to whatever plays the file, so a track's ``Instrument`` is a number from the General MIDI list, the bank it comes from, and whether the track is drums. That is enough for a written file to open in GarageBand, Logic or any other DAW with a bass on the bass track and a kit on the drums, instead of a piano on everything.

```swift
Track("Bass", instrument: .generalMIDI(33)) {
    Section { "| C3 - G3 - | A3 - F3 - |" }
}

Track("Drums", instrument: .drums(.room)) {
    Section {
        Kick("x... x... x... x...")
        Snare(".... x... .... x...")
    }
}
```

A track without one sends no program change, so the player keeps its default, usually a piano.

## Choosing a sound

``Instrument/generalMIDI(_:bank:)`` names a melodic sound by its General MIDI program, 0…127. Programs count from 0, as the byte in the file does: 0 is the acoustic grand piano, 33 the fingered electric bass, 48 the string ensemble. A chart that numbers them from 1 is one higher. A bank other than 0 is sent as a bank select before the program.

``Instrument/drums(_:)`` makes a drum track. It is written on channel 10, where every General MIDI player keeps its kit, so the lanes' keys (36 kick, 38 snare, 42 closed hat…) play as drums as soon as the file opens. The ``DrumKit`` is the program; see <doc:Drums>.

``Instrument/init(_:program:bank:percussion:)`` is the same description with a name of your own.

Name a sound once and share it, or set it after the block with ``Track/instrument(_:)``:

```swift
let keys = Instrument.generalMIDI(4)          // electric piano
Track("keys", instrument: keys) { … }
Track("lead") { … }.instrument(.generalMIDI(81))
```

## Channels

Drum tracks are written on channel 10, and several drum tracks share it. Every other track takes the next free channel in the order the session lists them, stepping over 10 and wrapping after sixteen, so a piece with more than fifteen melodic tracks shares channels.

## Topics

- ``Instrument``
- ``DrumKit``
