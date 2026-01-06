# AVANT_LAB_V // SPECTRAL LABORATORY
### Monome Norns

**Avant_lab_V** is a historical reconstruction of an electronic music studio from the 1960s living inside your Norns. It combines a **16-Band Resonant Filter Bank** (Serge/Buchla style) with a **4-Track Varispeed Tape Machine**.

It is designed to explore **Texture, Resonance, and Degradation**. Unlike modern digital samplers that aim for perfection, this instrument creates a living ecosystem where sound degrades, feedbacks, and evolves organically.

> **⚠️ HARDWARE NOTE: THE GRID**
> While Avant_lab_V is fully functional on Norns standalone, **a Monome Grid (128) is highly recommended**.
> The Grid transforms the script into a tactile instrument, providing direct access to the 16 filter faders, the tape loop windows, and the performance sequencers simultaneously.

---

## 🧭 1. NAVIGATION (The Golden Rule)

The instrument is vast, so we use **Pages**.

*   **K1 (The SHIFT Key):** Holding **K1** changes the function of Knobs and Buttons.
*   **CHANGE PAGE:** Hold **K1** + Press **K2** (Previous) or **K3** (Next).
*   **The Loop:** Pages wrap around (Page 10 -> Page 1).

---

## 🎛️ 2. THE RESONATOR (Pages 1 & 2)

### The Concept: "Playing the EQ"
In the 1960s, composers realized that if you fed noise into a bank of filters and turned up the resonance (Q), the filters would "sing". The EQ became an instrument.
> **🏛️ Historical Context:** This technique was pioneered by **Eliane Radigue** on her ARP 2500, creating slowly evolving drones by carefully adjusting feedback loops to the edge of oscillation.

### PAGE 1: GLOBAL CONTROL
*   **E1 (Scale):** Selects the tuning of the 16 bands.
    *   *Choices:* From scientific (**B&K 2107**) to musical (**Pythagorean**) to physical materials (**Glass, Plate**).
    *   **Shift+E1 (Root):** Transposes the frequency map of the scale.
*   **E2 (Feedback):** The dangerous knob. Feeds the output back into the input.
    *   *0-40%: Be color.*
    *   *40-80%: Metallic Reverb.*
    *   *90-100%: Self-Oscillation.*
*   **E3 (Global Q):** Bandwidth / Sharpness.
    *   *Low:* Wide bands, white noise texture.
    *   *High:* Laser-focused tones.

### PAGE 2: FILTER TOPOLOGY
*   **E1 (Filter Mix):** Blends between the raw input and the filtered signal.
*   **E2 (HPF):** High Pass Filter. Removing sub-bass (<50Hz) is crucial to prevent the resonator from "choking" on low energy.
*   **E3 (LPF):** Low Pass Filter. Tames the harsh digital top end.
*   **Shift+E1 (Stabilizer):** A compressor within the feedback loop. Increases stability at high resonance.
*   **Shift+E2 (Drift):** Simulates aging capacitors. The frequencies wander slightly over time, creating a "living" chorus effect.
*   **Shift+E3 (Spread):** Stereo separation (Odd bands Left, Even bands Right).

---

## ⚡ 3. SIGNAL PROCESSING (Pages 3, 4 & 5)

### PAGE 3: MIX & DIRT
Here we define the "Air" of the studio.
*   **E1 (Reverb Mix):** Master Reverb level.
*   **E2 (Ring Mod Mix):** *See below.*
*   **E3 (Monitor Level):** Overall output volume.
*   **Shift+E1 (System Dirt):** Adds a noise floor (Hiss, Hum, Dust). Essential for self-oscillation textures; it gives the feedback something to "chew on" when silence is present.
*   **Shift+E2 (RM Freq):** *See below.*
*   **Shift+E3 (Noise Input):** Injects White/Pink noise. Useful for sound design without external input.

### 💍 The Ring Modulator (Integrated in Page 3)
> **🏛️ Historical Context:** The **Institute of Sonology** (Utrecht) and **Stockhausen** (*Mixtur, Mantra*) used Ring Modulation to transform harmonic instruments (pianos, voices) into inharmonic, bell-like textures. It multiplies two signals, outputting the sum and difference frequencies.

*   **E2 (Mix):** Blends the Ring Modulator signal.
*   **Shift+E2 (Frequency):** Tunes the Carrier Oscillator.
    *   *Low Freq:* Tremolo / Rhythmic chopping.
    *   *High Freq:* Metallic, robotic, and bell-like timbres.
*   *Note:* The Carrier wave shape can be changed in the Params menu.

### PAGE 4: TAPE FX & REVERB
The physical properties of the recording medium and the space.
*   **E1 (Tape Mix):** Blends the "Tape Echo" simulation.
*   **E2 (Time):** Delay time of the main tape echo.
*   **E3 (Feedback):** Repeats of the tape echo.
*   **Shift+E1 (Erosion):** Simulates magnetic dropout and dust. Creates rhythmic silence and texture loss.
*   **Shift+E2 (Wow):** Slow pitch warping (warped vinyl).
*   **Shift+E3 (Flutter):** Fast pitch vibration (bad motor).

> **About the Reverb:** The Reverb parameters (Time/Damp) are mapped to **Shift+E2/E3** on this page or accessible via the Params menu. It acts as the "Room" where the laboratory sits.

### PAGE 5: PING GENERATOR
A rhythmic impulse engine to strike the filters like a percussion instrument.
*   **K2 (Mode):** Toggles **Internal** (Free Hz) or **Euclidean** (Tempo Synced).
*   **E1 (Rate):** Speed of the pulses.
*   **E2 (Jitter):** Humanizes the rhythm with randomness.
*   **E3 (Timbre):** Hardness of the strike (Low Pass vs Full Spectrum noise burst).

---

## 📼 4. THE TAPE LOOPERS (Page 7)

> **🏛️ Historical Context:** Before digital samplers, **Pierre Schaeffer** created the "Sillon Fermé" (Locked Groove) and **Brian Eno / Robert Fripp** developed "Frippertronics" using two reel-to-reel machines to create infinite layers of sound.

You have **4 Independent Tape Decks**. Navigate to **Page 7**.

### The Transport (K2)
The main button **K2** follows a "Performance Cycle":
1.  **Empty** -> Press K2 -> **RECORD** (Red).
2.  **Recording** -> Press K2 -> **OVERDUB** (Orange). *Loop is defined.*
3.  **Overdubbing** -> Press K2 -> **PLAY** (Green). *Safe mode.*
4.  **Playing** -> Press K2 -> **OVERDUB**.
5.  **Any State** -> Double Click K2 -> **STOP** (White).
6.  **Any State** -> Hold K2 (1s) -> **CLEAR**.

### Tape Controls
*   **E1 (Vol):** Playback volume.
*   **E2 (Speed):** **Varispeed**.
    *   *1.0:* Normal.
    *   *0.5:* Octave Down / Half Speed.
    *   *-1.0:* Reverse.
*   **E3 (Dub):** **Feedback/Decay**.
    *   *1.0:* Infinite loops (Sound never dies).
    *   *0.9:* Echos fade out slowly (Frippertronics).
    *   *0.0:* Replace audio immediately (Looper style).

### Grid Interaction (Tape View)
*   **Rows 1-4:** Each row is a track.
*   **Bright Dot:** Playhead.
*   **Touch:** Jump playhead (Seek).
*   **Hold 2 Buttons:** Set Loop Start/End points.

---

## 💾 5. AUTOMATION & MEMORY (Page 6 & Grid Row 7)

### Presets (Morphing)
The 4 Preset slots (Grid Row 7, buttons 5-8) are not just static snapshots.
*   **Saving:** Click an empty button to save the current state of the Filter Bank.
*   **Loading:** Click a lit button to **Morph** to that state.
*   **Page 6 E3 (Morph Time):** Sets how long it takes to travel from Preset A to Preset B. You can create slow, evolving transitions of 30 seconds or instant jumps.

### Event Sequencers
Each Tape Track has a "Ghost" hand recording your movements (Grid Row 7, buttons 1-4).
*   **Concept:** It does not record audio or MIDI. It records **Grid Events**. If you play the filters like a piano on the Grid, the sequencer remembers the finger movements.
*   **Usage:** Press button to Record. Play the Grid. Press again to Loop your gestures.
*   **Page 6 E1 (Seq Rate):** Changes the playback speed of the gestures.

---

## 🎚️ 6. THE CONSOLE (Page 9 & 10)

### Page 9: The "Sitral" Mixer
Modeled after vintage German broadcast consoles.
*   **Select Track:** Press **K2** / **K3**.
*   **E2 (Low):** Vintage Low Shelf (Warmth).
*   **E3 (High):** Vintage High Shelf (Air).
*   **Shift+E1 (Filter):** DJ-Style Combo Filter.
*   **Shift+E2 (Pan):** Stereo placement.

### Page 10: Master Bus
*   **E2 (Comp Thresh):** Bus Compressor Threshold. Glue your mix.
*   **E3 (Comp Ratio):** Compression intensity.
*   **Shift+E2 (Balance):** Master Left/Right balance.
*   **Shift+E3 (Drive):** Output saturation.

---

## 🛠️ 8 PRO TIPS (Historical Techniques)

1.  **The Stockhausen Bells:** Go to Page 3. Set **Ring Mod Mix** to 50%. Set **Scale** to *Harmonic A*. Feed a simple sine wave or guitar. Tune the **RM Freq** (Shift+E2) until you hear complex, inharmonic bell tones.
2.  **Frippertronics:** On Page 7, set **Dub (E3)** to *0.85*. Record a short phrase. It will repeat and slowly fade into the background, creating a "bed" for new solos.
3.  **The "Ghost" Choir:** Set Scale to *Roland VP-330* (Vocoder), High Q, High Feedback. Feed white noise (Shift+E3 on Page 3). You will hear a ghostly choir singing chords.
4.  **Polyrhythmic Phasing:** Record Track 1 at normal speed. Record Track 2 with a similar loop. Set Track 2 speed to *1.01* (using the Grid Ribbon for fine tuning if possible, or slight detune). The loops will phase shift like Steve Reich's "Piano Phase".
5.  **Granular Drone:** Record a short sound. On the Grid (Rows 1-4), hold two adjacent buttons to create a tiny loop (e.g., 50ms). Slow speed to *0.25*. You now have a granular synthesizer.
6.  **The Broken Radio:** Go to Page 4. Turn up **Erosion** (Shift+E1) and **Flutter** (Shift+E3). Set Scale to *BBC Speech*. The result sounds like a shortwave radio transmission from the past.
7.  **Sub-Bass Generator:** If your input lacks bass, go to Page 1 and select the *B&K Bass* scale. Turn up **Feedback** on the lower bands (faders 1-4 on Grid). The filter will self-oscillate and generate a massive sine wave sub-bass.
8.  **Physics Protection:** If you hear a click or silence at very high frequencies (Band 16), the engine's **Nyquist Protection** has engaged to prevent mathematical explosion. This is a safety feature. Lower the Q slightly.
