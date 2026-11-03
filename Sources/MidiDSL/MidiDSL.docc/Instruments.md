# Instruments

What a track plays, as a MIDI file can say it: a General MIDI program, and drums on channel 10.

## Overview

A MIDI file carries no sound. It names an instrument by number and leaves the sound to whatever plays the file, so a track's ``Instrument`` is a number from the General MIDI list, the bank it comes from, and whether the track is drums. That is enough for a written file to open in GarageBand, Logic or any other DAW with a bass on the bass track and a kit on the drums, instead of a piano on everything.

```swift
Track("Bass", instrument: .generalMIDI(33)) {
    Section { "C2 - G2 - | A2 - F2 -" }
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

### Instrument.generalMIDI()

```swift
Instrument.generalMIDI(_ program: Int, bank: Int = 0)
```

- term `program`: The General MIDI program, 0–127. It counts from 0, as the byte in the file does: 0 is the acoustic grand piano, 33 the fingered electric bass, 48 the string ensemble. A chart that numbers from 1 is one higher.
- term `bank`: The bank to choose it from, sent as a bank select (controller 0 and 32) before the program. 0, the General MIDI bank, sends none.

A melodic instrument. The file opens the track with a program change, before its first note.

### Instrument.drums()

```swift
Instrument.drums(_ kit: DrumKit = .standard)
```

- term `kit`: Which General MIDI kit: .standard, .room, .power, .electronic, .tr808, .jazz, .brush, .orchestra. The kit is the program; each lane's piece is the key.

A drum track. It is written on channel 10, where every General MIDI player keeps its kit, so the lanes' keys (36 kick, 38 snare, 42 closed hat…) play as drums the moment the file opens. Several drum tracks share the channel.

### Instrument()

```swift
Instrument(_ name: String, program: Int? = nil, bank: Int = 0, percussion: Bool = false)
```

- term `name`: What the sound is called.
- term `program`: The General MIDI program, or nil to send none.
- term `percussion`: Whether the track is drums, on channel 10.

The same description with a name of its own.

### .instrument()

```swift
instrument(_ instrument: Instrument) -> Track
```

Gives a track its instrument after the block rather than in the header.

```swift
Track("lead") { … }.instrument(.generalMIDI(81))
```

## Channels

Drum tracks are written on channel 10. Every other track takes the next free channel in the order the session lists them, stepping over 10 and wrapping after sixteen, so a piece with more than fifteen melodic tracks shares channels.

## Sounds a host makes

A host that makes its own sounds attaches them to the same ``Instrument``: [Componium](https://eniestudio.de/componium) puts its synthesizer, its sampled instruments and Audio Unit plugins there, written in a score that also imports `Componium`. They travel with the session, and a MIDI file leaves them out, keeping the General MIDI program a sound names for that purpose.

## Topics

- ``Instrument``
- ``DrumKit``
