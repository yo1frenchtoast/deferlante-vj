# MIDI control

Déferlante reads MIDI directly. A controller goes into a USB port on the machine
that runs the show, and that is the whole setup — no Chataigne in the middle, no
second laptop to keep awake through the set.

What a controller is *made* to send is not what it has to send. Both of the
controllers below let you assign every note, every CC and every channel, so the
dialect is a choice rather than a fact. It is made once, here, and several devices
speak it.

## Plugging one in

Plug it in. The show looks at what the machine reports and takes the profile whose
`match` names it:

```
MIDI: Novation Launch Control XL 3 on "LCXL3 1" — 48 controls on channel 1
```

That line is also on the status row under the panel, beside the web address and
the OSC address, because a surface that is silently absent is the failure this
project refuses everywhere else. Nothing plugged in says so too.

The **`MIDI` row of the launcher** overrides the guess. `whatever is plugged in`
is the ordinary answer; naming a profile forces that one even with nothing
connected, which is what a test rig needs; `off` stops the show opening MIDI at
all. It is saved to `launch.cfg` like the other rows.

A cable pushed in — or pulled out — during a set is picked up within a couple of
seconds. The show re-reads the device list rather than trusting the one it took at
start-up.

### Nothing lights up, and that is the design

Godot has no MIDI **out**. `InputEventMIDI` is an input event and there is no
counterpart, so the show cannot tell a controller anything: not that a preset was
recalled, not that the auto-pilot moved a fader, not which of two states a toggle
is in. Both controllers here can display colours, and the Launch Control can even
be sent them; it is the engine that cannot speak.

Everything else follows from that:

- **No pages and no banks.** A page you cannot see is a page you will be on by
  mistake. Every profile is flat: fixed functions, all live at once.
- **The colours are a legend, set once** in the maker's editor. They say what a pad
  *does*, never what the show is doing.
- **Faders take over softly.** An absolute fader is lying about where a setting is
  the moment anything else moves it — a preset recall, the auto-pilot, a phone. So
  a fader is read but not obeyed until it meets the value it is about to take, and
  then it has it. Sweep through and it catches.

### Two known limits

`OS.open_midi_inputs()` **crashes a `--headless` build** — measured on 4.7.2, a
segfault through a null driver singleton. The show therefore does not open MIDI
without a display, and says so in the log. A settings dump or a `--write-movie`
render is unaffected.

**Android has no MIDI driver in Godot at all**, so the show does not pretend to
look for one there.

## The profiles that ship

The **eight faders carry the same eight settings on both**, on CC 5 to 12, so a
set started on one finishes on the other. That is as far as the sharing goes, and
deliberately: the APC64's buttons are its pads, which send notes, while the Launch
Control's sixteen buttons send CCs.

The Launch Control profile is built on its **factory custom mode, unedited** —
faders CC 5–12, encoders CC 13–36 (absolute), buttons CC 37–52, **on channel 16**.
Nothing to set up in Components: load the mode and play. The numbers and the
channel are what the device was measured sending, not what its documentation
implies; the two disagreed about the channel.

The APC64 profile is built on its **Custom Mode**, also as measured, and its pads
count from the **bottom left**: note 36 is the pad under your left thumb, each row
up adds 8, and the top row is 92 to 99. The table below prints the note each pad
actually sends, so nothing has to be typed into the Project Editor.

**On Linux the APC64 needs a bridge before it says anything.** It is one ALSA
device with four subdevices — DAW, Notes, MIDI, Custom — and Godot's driver opens
a device without naming a subdevice, so ALSA hands it number 0, the DAW port,
which stays silent in Custom Mode. `/proc/asound/cardN/midi0` shows it plainly:
Godot owns `Input 0` and receives nothing while `Input 3` counts up. So run

    tools/apc64-bridge.sh

once after plugging in and before starting the show. It pours the Custom port
into a `snd-virmidi` cable, which Godot opens like any other device — and since
the show opens every input and `InputEventMIDI` carries no port, the notes arrive
without anything in the show knowing. Nothing is written to the APC64 itself.

The layout is the same idea twice. **Movement under the left hand** — speed,
chaos, audio reactivity, glow. **The layers under the right** — the four counts
that fade a layer out at zero, which together are the closest thing the show has
to a blackout.

<!-- generated: python3 tools/build_midi_map.py --table -->
### Akai APC64

8x8 pads, 8 touch faders — Custom Mode, APC64 Project Editor  
Profile `midi/apc64.json`, channel 1.

| Control | Sends | Does |
| --- | --- | --- |
| Fader 1 | CC 5 | `global/speed` over -3 – 3 |
| Fader 2 | CC 6 | `global/chaos` over 0 – 1 |
| Fader 3 | CC 7 | `audio/reactivity` over 0 – 1 |
| Fader 4 | CC 8 | `global/glow` over 0 – 2 |
| Fader 5 | CC 9 | `lasers/count` over 0 – 40 |
| Fader 6 | CC 10 | `spot/radius` over 20 – 600 |
| Fader 7 | CC 11 | `sphere/count` over 0 – 80 |
| Fader 8 | CC 12 | `warp/count` over 0 – 400 |
| R1C1 PRESET 1 | note 92 (G#5) | fires `preset:recall:1` |
| R1C2 PRESET 2 | note 93 (A5) | fires `preset:recall:2` |
| R1C3 PRESET 3 | note 94 (A#5) | fires `preset:recall:3` |
| R1C4 PRESET 4 | note 95 (B5) | fires `preset:recall:4` |
| R1C5 PRESET 5 | note 96 (C6) | fires `preset:recall:5` |
| R1C6 PRESET 6 | note 97 (C#6) | fires `preset:recall:6` |
| R1C7 PRESET 7 | note 98 (D6) | fires `preset:recall:7` |
| R1C8 PRESET 8 | note 99 (D#6) | fires `preset:recall:8` |
| R2C1 SAVE 1 | note 84 (C5) | fires `preset:save:1` after 1000 ms held |
| R2C2 SAVE 2 | note 85 (C#5) | fires `preset:save:2` after 1000 ms held |
| R2C3 SAVE 3 | note 86 (D5) | fires `preset:save:3` after 1000 ms held |
| R2C4 SAVE 4 | note 87 (D#5) | fires `preset:save:4` after 1000 ms held |
| R2C5 SAVE 5 | note 88 (E5) | fires `preset:save:5` after 1000 ms held |
| R2C6 SAVE 6 | note 89 (F5) | fires `preset:save:6` after 1000 ms held |
| R2C7 SAVE 7 | note 90 (F#5) | fires `preset:save:7` after 1000 ms held |
| R2C8 SAVE 8 | note 91 (G5) | fires `preset:save:8` after 1000 ms held |
| R3C1 SHUFFLE GLOBAL | note 76 (E4) | fires `shuffle:global` |
| R3C2 SHUFFLE COLOR | note 77 (F4) | fires `shuffle:color` |
| R3C3 SHUFFLE MIRROR | note 78 (F#4) | fires `shuffle:mirror` |
| R3C4 SHUFFLE LASERS | note 79 (G4) | fires `shuffle:lasers` |
| R3C5 SHUFFLE SPOT | note 80 (G#4) | fires `shuffle:spot` |
| R3C6 SHUFFLE AUDIO | note 81 (A4) | fires `shuffle:audio` |
| R3C7 SHUFFLE SPHERE | note 82 (A#4) | fires `shuffle:sphere` |
| R3C8 SHUFFLE WARP | note 83 (B4) | fires `shuffle:warp` |
| R4C1 GLITCH | note 68 (G#3) | fires `glitch` |
| R4C2 RANDOMIZE | note 69 (A3) | fires `randomize` |
| R4C3 SHUFFLE | note 70 (A#3) | fires `shuffle` |
| R4C4 FREEZE | note 71 (B3) | `global/speed` → 0 while held |
| R4C5 BOOST | note 72 (C4) | `global/speed` → 2.5 while held |
| R4C6 MIRROR | note 73 (C#4) | `mirror/effect` ↔ 1 |
| R4C7 GLOW | note 74 (D4) | `global/glow` ↔ 1 |
| R4C8 AIMING | note 75 (D#4) | `spot/manual` ↔ 1 |
| R5C1 2 | note 60 (C3) | `mirror/segments` → 2 |
| R5C2 3 | note 61 (C#3) | `mirror/segments` → 3 |
| R5C3 4 | note 62 (D3) | `mirror/segments` → 4 |
| R5C4 5 | note 63 (D#3) | `mirror/segments` → 5 |
| R5C5 6 | note 64 (E3) | `mirror/segments` → 6 |
| R5C6 8 | note 65 (F3) | `mirror/segments` → 8 |
| R5C7 12 | note 66 (F#3) | `mirror/segments` → 12 |
| R5C8 16 | note 67 (G3) | `mirror/segments` → 16 |
| R6C1 0 | note 52 (E2) | `sphere/sides` → 0 |
| R6C2 3 | note 53 (F2) | `sphere/sides` → 3 |
| R6C3 4 | note 54 (F#2) | `sphere/sides` → 4 |
| R6C4 5 | note 55 (G2) | `sphere/sides` → 5 |
| R6C5 6 | note 56 (G#2) | `sphere/sides` → 6 |
| R6C6 7 | note 57 (A2) | `sphere/sides` → 7 |
| R6C7 8 | note 58 (A#2) | `sphere/sides` → 8 |
| R6C8 12 | note 59 (B2) | `sphere/sides` → 12 |
| R7C1 -1 | note 44 (G#1) | `lasers/spin` → -1 |
| R7C2 -0.6 | note 45 (A1) | `lasers/spin` → -0.6 |
| R7C3 -0.3 | note 46 (A#1) | `lasers/spin` → -0.3 |
| R7C4 -0.05 | note 47 (B1) | `lasers/spin` → -0.05 |
| R7C5 +0.05 | note 48 (C2) | `lasers/spin` → 0.05 |
| R7C6 +0.3 | note 49 (C#2) | `lasers/spin` → 0.3 |
| R7C7 +0.6 | note 50 (D2) | `lasers/spin` → 0.6 |
| R7C8 +1 | note 51 (D#2) | `lasers/spin` → 1 |
| R8C1 RANDOM | note 36 (C1) | `color/mode` → 0 |
| R8C2 #FF401A | note 37 (C#1) | colour → 1 0.25 0.1, and manual |
| R8C3 #FF9400 | note 38 (D1) | colour → 1 0.58 0, and manual |
| R8C4 #FFE000 | note 39 (D#1) | colour → 1 0.88 0, and manual |
| R8C5 #33FF66 | note 40 (E1) | colour → 0.2 1 0.4, and manual |
| R8C6 #00E6FF | note 41 (F1) | colour → 0 0.9 1, and manual |
| R8C7 #295CFF | note 42 (F#1) | colour → 0.16 0.36 1, and manual |
| R8C8 #BF40FF | note 43 (G1) | colour → 0.75 0.25 1, and manual |

### Novation Launch Control XL 3

24 encoders, 8 faders, 16 buttons — the factory custom mode, unedited: faders CC 5-12, encoders CC 13-36, buttons CC 37-52, channel 16, buttons latching  
Profile `midi/launch-control-xl3.json`, channel 16.

| Control | Sends | Does |
| --- | --- | --- |
| Fader 1 | CC 5 | `global/speed` over -3 – 3 |
| Fader 2 | CC 6 | `global/chaos` over 0 – 1 |
| Fader 3 | CC 7 | `audio/reactivity` over 0 – 1 |
| Fader 4 | CC 8 | `global/glow` over 0 – 2 |
| Fader 5 | CC 9 | `lasers/count` over 0 – 40 |
| Fader 6 | CC 10 | `spot/radius` over 20 – 600 |
| Fader 7 | CC 11 | `sphere/count` over 0 – 80 |
| Fader 8 | CC 12 | `warp/count` over 0 – 400 |
| Encoder 1 | CC 13 | `spot/pulse` over 0 – 300 |
| Encoder 2 | CC 14 | `spot/width` over 1 – 24 |
| Encoder 3 | CC 15 | `spot/speed` over 0 – 2 |
| Encoder 4 | CC 16 | `spot/hold` over 0 – 3 |
| Encoder 5 | CC 17 | `spot/shake` over 0 – 3 |
| Encoder 6 | CC 18 | `spot/frequency` over 0 – 20 |
| Encoder 7 | CC 19 | `spot/spread` over 0 – 1 |
| Encoder 8 | CC 20 | `spot/glitch` over 0 – 0.05 |
| Encoder 9 | CC 21 | `lasers/width` over 1 – 24 |
| Encoder 10 | CC 22 | `lasers/length` over 0.1 – 2 |
| Encoder 11 | CC 23 | `lasers/spin` over -1 – 1 |
| Encoder 12 | CC 24 | `lasers/parallel` over 0 – 1 |
| Encoder 13 | CC 25 | `lasers/scroll` over -1 – 1 |
| Encoder 14 | CC 26 | `mirror/segments` over 2 – 16 |
| Encoder 15 | CC 27 | `mirror/rotation` over -1 – 1 |
| Encoder 16 | CC 28 | `global/randomizer` over 0 – 1 |
| Encoder 17 | CC 29 | `sphere/size` over 0.03 – 0.8 |
| Encoder 18 | CC 30 | `sphere/sides` over 0 – 12 |
| Encoder 19 | CC 31 | `sphere/radius` over 100 – 800 |
| Encoder 20 | CC 32 | `sphere/spin` over -1 – 1 |
| Encoder 21 | CC 33 | `sphere/depth` over 1.2 – 10 |
| Encoder 22 | CC 34 | `warp/speed` over 0 – 4 |
| Encoder 23 | CC 35 | `warp/streak` over 0 – 0.4 |
| Encoder 24 | CC 36 | `warp/spread` over 0.1 – 2 |
| Button 1 PRESET 1 | CC 37 | fires `preset:recall:1` |
| Button 2 PRESET 2 | CC 38 | fires `preset:recall:2` |
| Button 3 PRESET 3 | CC 39 | fires `preset:recall:3` |
| Button 4 PRESET 4 | CC 40 | fires `preset:recall:4` |
| Button 5 PRESET 5 | CC 41 | fires `preset:recall:5` |
| Button 6 PRESET 6 | CC 42 | fires `preset:recall:6` |
| Button 7 PRESET 7 | CC 43 | fires `preset:recall:7` |
| Button 8 PRESET 8 | CC 44 | fires `preset:recall:8` |
| Button 9 GLITCH | CC 45 | fires `glitch` |
| Button 10 RANDOMIZE | CC 46 | fires `randomize` |
| Button 11 SHUFFLE | CC 47 | fires `shuffle` |
| Button 12 FREEZE | CC 48 | `global/speed` → 0 while held |
| Button 13 BOOST | CC 49 | `global/speed` → 2.5 while held |
| Button 14 MIRROR | CC 50 | `mirror/effect` ↔ 1 |
| Button 15 GLOW | CC 51 | `global/glow` ↔ 1 |
| Button 16 AIMING | CC 52 | `spot/manual` ↔ 1 |
