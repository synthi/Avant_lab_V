AVANT_LAB_V

Environment for Electroacoustic Research
Avant_lab_V is not just a looper or an effect. It is a simulation of a 1960s Electronic Music Studio living inside your Monome Norns.

It is designed to explore Texture, Resonance, and Degradation. Unlike modern digital samplers that aim for perfection, this instrument creates a living ecosystem where sound degrades, feedbacks, and evolves organically.

📚 1. THEORETICAL FUNDAMENTALS (Read This First)
To master this instrument, you must understand three physical concepts it emulates.

A. What is a "Fixed Filter Bank"?
Imagine a graphic equalizer, but instead of subtle tone shaping, it is extreme.

The Concept: It divides sound into 16 specific frequency bands (slices of the spectrum).
The Instrument: In Avant_lab_V, these bands are not just volume sliders; they are Resonators. Think of them like the strings of a piano. If you shout into a piano, the strings vibrate in sympathy. Here, the filters vibrate when audio passes through them. You can "tune" these strings to specific historical or mathematical scales.
B. The Phenomenon of Feedback
Feedback is what happens when a sound hears itself.

Positive Feedback: When the output flows back into the input, energy builds up.
The Edge of Chaos: This script is designed to live on the edge. If you increase the Feedback parameter, the filters will start to self-oscillate, turning percussive sounds into long, singing drones.
Note: The system includes safety math (physics modeling) to prevent digital explosions, but be careful with your speakers!
C. Magnetic Tape Physics
The loopers here are not digital buffers; they emulate magnetic tape.

No Undo: Tape is destructive. If you record over a sound, the old sound is physically magnetized away.
Varispeed: Changing pitch also changes time. Lowering the speed creates deep, slow textures.
Degradation: The tape wears out. Noise, hiss, and wobble (Wow/Flutter) are part of the aesthetic.
🧭 2. NAVIGATION & INTERFACE

The Golden Rule
The instrument is too complex for 3 knobs. We use K1 as a SHIFT key.

CHANGE PAGE: Hold K1 + Press K2 (Previous) or K3 (Next).
FINE TUNE: Holding K1 while turning an Encoder usually provides fine adjustment.
The Page Map (Signal Flow)
The 9 pages are organized by function:

Page 1 (GLOBAL): The master controls for the Resonator (Scale, Q, Feedback).
Page 2 (FILTER): Detailed control of the Filter Bank behavior.
Page 3 (MIX): Input levels, Reverb, and Routing.
Page 4 (TAPE FX): The physical properties of the tape machine.
Page 5 (PING): Internal impulse generator.
Page 6 (TIME): Sequencer speeds and Morphing times.
Page 7 (LOOPERS): The 4-Track Tape Machine (Recording/Editing).
Page 8 (LIBRARY): Save/Load your tape reels to disk.
Page 9 (MIXER): Final mixing console (Volume, EQ, Pan).
🎛️ 3. THE RESONATOR (Sound Design)
This is the heart of the sound. Go to Page 1.

Primary Controls
E1 (Scale): Selects the tuning of the 16 bands.
Examples: Bark (Psychoacoustic), Pythagorean (Harmonic), Marimba (Percussive).
Shift+E1 (Root): Transposes the entire scale (e.g., C to F#).
E2 (Feedback): The amount of signal sent back into the filters.
0%: Clean EQ.
50%: Metallic reverb tail.
90%: Self-oscillation (The filters become a synthesizer).
E3 (Global Q): The "sharpness" of the filters.
Low: Wide bands, blending together.
High: Laser-focused frequencies, bell-like tones.
Note on Physics: At very high frequencies (>10kHz), the system automatically tightens the Q to prevent digital aliasing. This is normal behavior.
Advanced Filter Physics (Page 2)
E1 (Mix): Blends between the raw input and the filtered sound.
E2 (HPF): High Pass Filter. Cuts sub-bass mud before it hits the resonators.
E3 (LPF): Low Pass Filter. Cuts harsh treble.
Shift+E2 (Drift): Simulates aging capacitors. The frequencies of the bands will slowly wander, creating a "living" chorus effect.
Shift+E3 (Spread): Pans odd bands Left and even bands Right for wide stereo images.
⚡ 4. THE SOURCE (Input & Ping)
How do we excite the resonator? Go to Page 3 (Mix) and Page 5 (Ping).

Input & Dirt (Page 3)
E1 (Reverb): A Master Reverb that sits after the filters to glue the sound.
Shift+E1 (Dirt): Adds vintage noise floor (Hiss, Hum, and Crackle). Essential for self-oscillation textures.
Shift+E3 (Noise): Injects white/pink noise. Useful for "playing" the filters like a wind instrument.
The Ping Generator (Page 5)
A built-in rhythmic engine to strike the filters.

K2 (Mode): Toggles between Free (Hz) and Euclidean (Tempo Synced).
E1 (Rate): Speed of the pulses.
E2 (Jitter): Humanizes the rhythm with randomness.
E3 (Timbre): Changes the "hardness" of the strike (Low pass vs Full spectrum).
📼 5. THE TAPE MACHINE (Loopers)
Navigate to Page 7. This is where you record.
You have 4 Independent Tape Decks.

The Transport (K2)
The main button K2 follows a strict cycle to encourage performance:

Empty -> Press K2 -> RECORD (Red).
Recording -> Press K2 -> OVERDUB (Orange). Loop is defined.
Overdubbing -> Press K2 -> PLAY (Green). Safe mode.
Playing -> Press K2 -> OVERDUB.
Any State -> Double Click K2 -> STOP (White).
Any State -> Hold K2 -> CLEAR.
Tape Physics (Encoders)
E1 (Vol): Playback volume of the selected track.
E2 (Speed): Varispeed.
1.0: Normal speed.
0.5: Octave down (Half speed).
-1.0: Reverse.
Note: Changing speed changes pitch. This is physical.
E3 (Dub): Feedback/Decay.
1.0: Infinite loops (Sound never dies).
0.9: Echos fade out slowly (Frippertronics style).
0.0: The loop is replaced by new audio immediately.
Degradation Effects (Page 4)
Here you damage the machine.

Shift+E1 (Erosion): Simulates magnetic dropout and dust. Creates rhythmic silence.
Shift+E2 (Wow): Slow pitch warping (warped vinyl).
Shift+E3 (Flutter): Fast pitch vibration (bad motor).
🎚️ 6. THE CONSOLE (Final Mixer)
Page 9 is your Sitral Console.

Select Track: K2 / K3.
E2 (Low): Vintage Low Shelf. Boost for warmth, Cut for clarity.
E3 (High): Vintage High Shelf. Boost for "Air".
Shift+E1 (Filter): A DJ-style combo filter. Center is clean. Left is Low-Pass, Right is High-Pass.
Shift+E2 (Pan): Stereo placement.
🎹 7. THE GRID (The Control Surface)
While Norns can do everything, the Monome Grid turns this script into a tactile instrument.

Visual Feedback
Rows 1-4: These are your 4 Tape Tracks.
Dim Pulse: The tape is moving.
Bright Dot: The Playhead (Audio position).
Fixed Dots: Start/End loop points.
Interaction: Touch the row to jump the playhead (Seek). Hold two buttons to set a new Loop.
The Fader Bank (Main View)
Rows 1-6 (Vertical): 16 Virtual Faders controlling the gain of the 16 Filter Bands.
Draw curves with your fingers to sculpt the spectrum.
The Ribbon Controller (Row 5)
Buttons 1-4: Select the active Track.
Buttons 6-16: A speed strip. Center is STOP. Left is Reverse, Right is Forward. Jump instantly between speeds.
Performance Row (Row 7)
Buttons 1-4 (Sequencers): Record your grid presses.
Click: Play/Rec.
Double: Stop.
Buttons 5-8 (Presets):
Click Empty: Save current state.
Click Full: Load state (Morph).
Buttons 9-12 (Master FX):
9 (Kill): Cuts all high frequencies instantly.
10 (Freeze): Max feedback + Reverb swell.
11 (Warble): Momentary extreme tape flutter.
12 (Brake): Tape stop effect.
System Row (Row 8)
Button 1 (Momentary): If active, Presets and Ribbon jumps only last while you hold the button.
Button 3 (Random): Randomizes the filter bank gains.
Buttons 7-16: Direct Page Access (Page 1 to 10).
🛠️ TIPS & TRICKS
The "Ghost" Choir: Set Scale to Roland VP-330, High Q, High Feedback. Feed white noise (Shift+E3 on Page 3). You will hear a ghostly choir singing.
Polyrhythmic Loops: Record Track 1 at normal speed. Record Track 2. Then set Track 2 speed to 0.5 or 1.5. The loops will drift apart.
The Drone Machine: Record a short sound. Set Loop Start/End points very close together on the Grid. Set Speed to 0.25. You now have a granular drone.
Feedback limit: If the sound disappears or "clicks" at very high frequencies, the Physics Engine has engaged protection mode to prevent speaker damage. This is normal. Lower the Q slightly.
