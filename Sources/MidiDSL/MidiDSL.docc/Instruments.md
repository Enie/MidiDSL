# Instruments

The built-in synthesizer, sampled instruments and Audio Unit plugins.

## Overview

Synth is a chainable builder for SynthPatch — the per-track sound: oscillators, envelope, filter, reverb, overtones. Start from Synth.named() or a preset, chain overrides, and finish with .build(). The audio path is Oscillators → ADSR → Velocity → Filter → Reverb.

## Creating

### Synth.named()

```swift
Synth.named(_ name: String) -> Synth
```

- term `name`: What the patch is called. It labels the patch; it does not affect the sound.

A fresh patch: one sine oscillator, default envelope, filter and reverb off.

```swift
Synth.named("pluck")
    .oscillator(0, waveform: .triangle)
    .envelope(attack: 0.002, decay: 0.4, sustain: 0.0,
              release: 0.15, curve: .exponential)
    .build()
```

### .build()

```swift
build() -> SynthPatch
```

Finalizes the builder into the SynthPatch a Track expects.

## Oscillators

### .oscillators()

```swift
oscillators(_ count: Int) -> Synth
```

- term `count`: How many oscillators the voice runs, 1–4 (clamped). More oscillators cost more voices — detune them against each other for width.

Number of oscillators, clamped to 1–4.

### .oscillator()

```swift
oscillator(_ index: Int, waveform: SynthWaveform? = nil, mix: Float? = nil, detune: Float? = nil, overtones: OvertoneConfig? = nil) -> Synth
```

- term `index`: Which oscillator to configure, 0-based, up to the count set by .oscillators().
- term `waveform`: Its shape: .sine, .square, .triangle, .sawtooth, .noise. Left nil, the current one stays.
- term `mix`: How loud this oscillator is in the blend, 0.0–1.0, before the envelope.
- term `detune`: How far it is shifted from the note, in semitones. 0.1–0.3 thickens by beating against the others; 12 is an octave, 7 a fifth.
- term `overtones`: Harmonics stacked on this oscillator alone, when the patch-wide .overtones() is not what you want.

Configures one oscillator. detune is in semitones — 0.1–0.3 gives chorus thickening, 12 is an octave.

```swift
.oscillator(1, waveform: .sawtooth, mix: 0.4, detune: 0.15)
```

### SynthWaveform

```swift
.sine .square .triangle .sawtooth .noise
```

Oscillator waveforms; .noise is white noise (drums, hats).

## Envelopes

### .envelope()

```swift
envelope(attack: Double?, decay: Double?, sustain: Float?, release: Double?, curve: EnvelopeCurve?) -> Synth
```

- term `attack`: Seconds from the note-on to full loudness. Near 0 is a click or a pluck; tenths give a pad its swell.
- term `decay`: Seconds from full loudness down to the sustain level.
- term `sustain`: The level held while the note lasts, 0.0–1.0 — a level, not a time. 0 makes every note a pluck however long it is written.
- term `release`: Seconds to fade after the note ends. It rings past the written length.
- term `curve`: The shape of decay and release: .linear for organs and pads, .exponential for plucks and percussion.

ADSR in seconds (sustain is a 0–1 level). curve shapes decay/release: .linear for organs and pads, .exponential for plucks and percussion. All parameters optional — only what you pass changes.

### .pitchEnvelope()

```swift
pitchEnvelope(_ semitones: Float, decay: Double = 0.05) -> Synth
```

- term `semitones`: How far off the written pitch the note starts. +24 with a short decay is the classic kick punch; small negative values scoop into a pad.
- term `decay`: Seconds to glide from that offset onto the real pitch.

The note starts offset by the given semitones and glides to its pitch over decay seconds. +24 with a short decay is the classic kick punch; small negative values scoop into pads.

```swift
.pitchEnvelope(24, decay: 0.04)
```

## Filter, reverb & volume

### .filter()

```swift
filter(_ type: SynthFilterType, cutoff: Float? = nil, resonance: Float? = nil, enabled: Bool = true) -> Synth
```

- term `type`: .lowPass takes the top off, .highPass the bottom, .bandPass keeps a band.
- term `cutoff`: The corner frequency in Hz — where the filter starts working.
- term `resonance`: How much the corner itself is emphasised. Higher values whistle at the cutoff.
- term `enabled`: false leaves the settings written but takes the filter out of the path.

EQ filter. Types: .lowPass, .highPass, .bandPass. Cutoff in Hz.

```swift
.filter(.lowPass, cutoff: 1500, resonance: 0.4)
```

### .reverb()

```swift
reverb(enabled: Bool = true, mix: Float? = nil) -> Synth
```

- term `enabled`: Whether the reverb send is in the path at all.
- term `mix`: How much of the signal goes through it, 0.0–1.0. Reverb applies to sampled and plugin patches too, unlike the oscillator settings.

Reverb send; mix 0.0–1.0.

### .volume()

```swift
volume(_ level: Float) -> Synth
```

- term `level`: The instrument's own output level, 0.0–1.0 (clamped). It is the patch's gain rather than a per-note dynamic, and it multiplies with the track's and the session's volumes. The default is 0.8.

Patch volume, clamped to 0.0–1.0.

## Overtones

### .overtones()

```swift
overtones(_ count: Int, mix: Float = 0.5, decay: OvertoneDecay = .exponential) -> Synth
```

- term `count`: How many harmonics to stack above every oscillator, 1–8.
- term `mix`: How loud the harmonics are against the fundamental, 0.0–1.0.
- term `decay`: How the harmonics fall off with number: .linear is 1/N, .exponential is 0.5^N — the steeper, darker one.

Adds 1–8 harmonic overtones to every oscillator. decay picks the amplitude falloff: .linear (1/N) or .exponential (0.5^N).

### .overtonesLinear() / .overtonesExponential()

```swift
overtonesLinear(_ count: Int = 3, mix: Float = 0.5)
```

- term `count`: How many harmonics to stack, 1–8.
- term `mix`: How loud they are against the fundamental, 0.0–1.0. The falloff is fixed by which of the two you call.

Shorthands for the two falloff curves.

### .overtonesCustom()

```swift
overtonesCustom(_ amplitudes: [Float], mix: Float = 1.0) -> Synth
```

- term `amplitudes`: One level per harmonic, in order from the first above the fundamental — the falloff written out instead of chosen from a curve.
- term `mix`: How loud the whole stack is against the fundamental, 0.0–1.0.

Explicit per-harmonic amplitudes.

```swift
.overtonesCustom([0.45, 0.25, 0.14, 0.08], mix: 0.5)
```

## Presets (chain overrides before .build())

### Synth.kick()

Punchy kick drum — sine with a fast pitch drop. Play it around C2.

### Synth.snare()

Noise crack over a tuned triangle body. Play it around D3.

### Synth.hihat()

```swift
hihat(open: Bool = false)
```

- term `open`: false is a closed hat — filtered noise with a short decay; true opens it, letting the noise ring.

Filtered noise; open: true for an open hat.

### Synth.bass()

Round finger bass — sine fundamental with saw growl. Play C1–C3.

### Synth.guitar()

Plucked guitar with warm harmonics and a pick transient.

### Synth.pad()

Warm pad — three detuned saws, slow attack, generous reverb.

### Synth.lead()

Singing lead — detuned saw/square pair.

```swift
Synth.lead().filter(.lowPass, cutoff: 2200).build()
```

## Sampled instruments (real recordings)

### Synth.piano()

Sampled grand piano from the built-in General MIDI bank.

### Synth.acousticGuitar()

Sampled steel-string acoustic guitar. Nylon: Synth.sampled("nylon", program: 24).

### Synth.sampled()

```swift
sampled(_ name: String, soundFont: String? = nil, program: Int = 0, bank: Int = 0)
```

- term `name`: What the patch is called; it does not pick the sound.
- term `soundFont`: Path to a .sf2, or a bare file name in ~/Library/Audio/Sounds/Banks. Left nil, the system General MIDI bank is used.
- term `program`: Which instrument inside the bank: 0 grand piano, 24 nylon guitar, 25 steel guitar, 32 acoustic bass, 40 violin, 48 strings.
- term `bank`: Which bank inside the SoundFont, when it carries more than one. 0 unless the file says otherwise.

Play a track from real recordings via the system sampler instead of the oscillator engine. Without a soundFont, the built-in General MIDI bank is used and program picks the instrument (0 grand piano, 24 nylon guitar, 25 steel guitar, 32 acoustic bass, 40 violin, 48 strings). Pass a .sf2 SoundFont path (or a bare file name in ~/Library/Audio/Sounds/Banks) to use your own sample library. Oscillator, envelope and filter settings don't apply to sampled patches; reverb and volume do. Note slides play as pitch bends (up to ±24 semitones); overlapping notes sliding differently at the same moment share one bend — the newest wins.

```swift
Synth.sampled("strings", soundFont: "MyOrchestra.sf2", program: 48).reverb(enabled: true, mix: 0.3).build()
```

## Audio Unit plugins

### Synth.audioUnit()

```swift
audioUnit(_ name: String, preset: String? = nil)
```

- term `name`: The installed AU instrument to load, matched case-insensitively ("Manufacturer: Name" also works). An unknown name falls back to the GM sampler with a warning.
- term `preset`: The sound to come back at, by name: a preset saved beside this score (Componium's ⌘S writes one per hosted track into “<Score> presets”) first, a factory preset of that name second. Written for you when you save; without one, sound libraries and wrapper plugins stay silent until a sound is chosen in their own editor.

Play a track through an installed Audio Unit instrument plugin instead of the oscillator engine. The name is matched case-insensitively against installed AU instruments ("Manufacturer: Name" also works); the preset names the sound to load. In Componium, saving the score writes that name for you, alongside a real .aupreset holding the plugin's state, so the sound comes back when the score is reopened. Without one, sound libraries and wrapper plugins (e.g. Komplete Kontrol) are silent until a sound is chosen in their editor UI. Oscillator, envelope and filter settings don't apply; reverb and volume do. Note slides play as pitch bends, same as sampled patches.

```swift
Synth.audioUnit("Cardinal Synth").volume(0.8).build()
```

### .effect()

```swift
effect(_ name: String, preset: String? = nil)
```

- term `name`: The installed effect plugin to load, matched like an instrument's name. One that can't be found is left out with a warning, and the track still plays.
- term `preset`: The sound to come back at, by name, as for an instrument. Componium's ⌘S writes one per effect into “<Score> presets”.

Run a plugin or sampled track through an installed effect plugin, such as an amp emulator. Several effects run in the order they're written, before the track's reverb. Exports render through the same chain. Oscillator tracks have no plugin chain and ignore it. Intel-only plugins can't load on Apple silicon and don't appear there.

```swift
Synth.audioUnit("Voltstring", preset: "DI for Amp Sim").effect("AUDelay")
```
