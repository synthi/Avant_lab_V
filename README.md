# AVANT_LAB_V // SPECTRAL LABORATORY
### Version 2010 | Monome Norns

**Avant_lab_V** is a historical reconstruction of an electronic music studio from the 1960s living inside your Norns. It combines a **16-Band Resonant Filter Bank** (Serge/Buchla style) with a **4-Track Varipspeed Tape Machine**.

It is designed to explore **Texture, Resonance, and Degradation**. Unlike modern digital samplers that aim for perfection, this instrument creates a living ecosystem where sound degrades, feedbacks, and evolves organically.

> **⚠️ HARDWARE NOTE: THE GRID**
> While Avant_lab_V is fully functional on Norns standalone, **a Monome Grid (128) is highly recommended**.
> The Grid transforms the script into a tactile instrument, providing direct access to the 16 filter faders, the tape loop windows, and the performance sequencers simultaneously.

---

## 📚 1. THEORETICAL FUNDAMENTALS (Read This First)

To master this instrument, you must understand the three physical concepts it emulates.

### A. The "Fixed Filter Bank" as an Instrument
Imagine a graphic equalizer, but instead of subtle tone shaping, it is extreme.
*   **The Concept:** It divides sound into 16 specific frequency bands.
*   **The Instrument:** In Avant_lab_V, these bands are **Resonators**. Think of them like the strings of a piano. If you feed noise or audio into them, they vibrate. By increasing **Feedback**, they self-oscillate, effectively turning the EQ into a Polyphonic Synthesizer.
*   **Tuning:** You can "tune" these 16 bands to specific historical scales (Siemens, Moog) or mathematical series (Fibonacci, Golden Ratio).

### B. Feedback & The "Edge of Chaos"
Feedback occurs when the output flows back into the input.
*   **Positive Feedback:** Creates energy buildup.
*   **Physics Engine:** This script uses complex math to prevent digital clipping, but it allows the energy to grow massively. The sweet spot is often just before distortion, where the sound becomes "liquid."

### C. Magnetic Tape Physics
The loopers here are not digital buffers; they emulate physical tape.
*   **Destructive Recording:** There is no "Undo". If you record over a sound, the magnets erase the previous layer.
*   **Varispeed:** Changing speed changes pitch. Slowing down the tape creates deep, disintegration textures.
*   **Erosion:** The tape wears out. Noise, hiss, and wobble (Wow/Flutter) are essential parts of the aesthetic.

---

## 🧭 2. NAVIGATION (The Golden Rule)

The instrument is vast, so we use **Pages**.

*   **K1 (The SHIFT Key):** Holding **K1** changes the function of Knobs and Buttons.
*   **CHANGE PAGE:** Hold **K1** + Press **K2** (Previous) or **K3** (Next).
*   **The Loop:** Pages wrap around (Page 10 -> Page 1).

### The Page Map
*   **1. GLOBAL:** Master Resonator controls.
*   **2. FILTER:** Filter bank topology & Drift.
*   **3. MIX:** Inputs, Dirt, and Routing.
*   **4. TAPE FX:** Degradation engine (Wow/Flutter).
*   **5. PING:** Internal rhythmic pulse generator.
*   **6. TIME:** Morphing and Sequencer speeds.
*   **7. LOOPERS:** The 4-Track Tape Machine (Main View).
*   **8. LIBRARY:** Load/Save Reels to disk.
*   **9. MIXER:** The "Sitral" Console (Volume/EQ).
*   **10. MASTER:** Dynamics & Metering.

---

## 🎛️ 3. THE RESONATOR (Sound Design)

This is the heart of the sound. Start on **Page 1**.

### Primary Controls (Page 1)
*   **E1 (Scale):** Selects the tuning of the 16 bands.
    *   *Vintage:* **B&K 2107** (Scientific), **Moog 914** (Classic).
    *   *Math:* **Pythagorean** (Harmonic), **Fibonacci** (Natural).
    *   *Shift+E1 (Root):* Transposes the frequency map.
*   **E2 (Feedback):** The amount of signal sent back into the filters.
    *   *0%:* Clean EQ.
    *   *50%:* Metallic reverb tail.
    *   *90%+:* Self-oscillation (Drone generator).
*   **E3 (Global Q):** Bandwidth / Resonance.
    *   *Low:* Wide bands, blending together (Noise).
    *   *High:* Laser-focused frequencies (Tones).
    *   *Note:* The system automatically tightens the Q at high frequencies (>8kHz) to prevent digital aliasing and protect your speakers.

### Advanced Filter Physics (Page 2)
*   **E1 (Mix):** Dry/Wet blend of the Filter Bank.
*   **E2 (HPF):** Cuts sub-bass mud before the resonators.
*   **E3 (LPF):** Cuts harsh treble.
*   **Shift+E1 (Stabilizer):** Limits the energy per band.
*   **Shift+E2 (Drift):** Simulates aging capacitors. The frequencies wander slightly, creating a "living" chorus effect.
*   **Shift+E3 (Spread):** Stereo separation (Odd bands Left, Even bands Right).

---

## ⚡ 4. THE SOURCE (Exciting the Resonator)

How do we make it sound? Go to **Page 3** and **Page 5**.

### Input & Dirt (Page 3)
*   **E1 (Reverb):** Master Reverb (Post-Filter).
*   **Shift+E1 (System Dirt):** Adds a noise floor (Hiss, Hum, Dust). Essential for self-oscillation textures (gives the feedback something to "chew on").
*   **Shift+E3 (Noise Level):** Injects White/Pink noise. Useful for sound design without external input.

### The Ping Generator (Page 5)
A rhythmic impulse engine to strike the filters like a bell.
*   **K2 (Mode):** Toggles **Internal** (Free Hz) or **Euclidean** (Tempo Synced).
*   **E1 (Rate):** Speed of the pulses.
*   **E2 (Jitter):** Humanizes the rhythm with randomness.
*   **E3 (Timbre):** Hardness of the strike (Low Pass vs Full Spectrum).

---

## 📼 5. THE TAPE MACHINE (Loopers)

Navigate to **Page 7**. You have **4 Independent Tape Decks**.

### The Transport (K2)
The main button **K2** follows a "Performance Cycle":
1.  **Empty** -> Press K2 -> **RECORD** (Red).
2.  **Recording** -> Press K2 -> **OVERDUB** (Orange). *Loop defined.*
3.  **Overdubbing** -> Press K2 -> **PLAY** (Green). *Safe mode.*
4.  **Playing** -> Press K2 -> **OVERDUB**.
5.  **Any State** -> Double Click K2 -> **STOP** (White).
6.  **Any State** -> Hold K2 (1s) -> **CLEAR**.

### Tape Physics (Encoders)
*   **E1 (Vol):** Playback volume.
*   **E2 (Speed):** **Varispeed**.
    *   *1.0:* Normal.
    *   *0.5:* Octave Down / Half Speed.
    *   *-1.0:* Reverse.
*   **E3 (Dub):** **Feedback/Decay**.
    *   *1.0:* Infinite loops (Sound never dies).
    *   *0.9:* Echos fade out slowly (Frippertronics).
    *   *0.0:* Replace audio immediately.

### Degradation (Page 4)
*   **Shift+E1 (Erosion):** Simulates magnetic dropout and dust.
*   **Shift+E2 (Wow):** Slow pitch warping (warped vinyl).
*   **Shift+E3 (Flutter):** Fast motor vibration.

---

## 🎚️ 6. THE CONSOLE (Mixing)

**Page 9** is your "Sitral" Mixing Console.
*   **Select Track:** Press **K2** / **K3**.
*   **E2 (Low):** Vintage Low Shelf (Warmth).
*   **E3 (High):** Vintage High Shelf (Air).
*   **Shift+E1 (Filter):** DJ-Style Combo Filter.
*   **Shift+E2 (Pan):** Stereo placement.

---

## 🎹 7. THE GRID (Control Surface)

### 🅰️ MAIN VIEW (Pages 1, 2, 3, 4, 6, 9)
*   **Rows 1-6 (Vertical):** 16 Virtual Faders. Control the gain of each filter band directly.

### 🅱️ TAPE VIEW (Page 7 / or Override)
*   **Rows 1-4:** Represents Tracks 1-4.
    *   **Dim Pulse:** Tape moving.
    *   **Bright Dot:** Playhead (Audio position).
    *   **Touch:** Jump playhead (Seek).
    *   **Hold 2 Buttons:** Set Loop Start/End points.
*   **Row 5 (1-4):** **Track Select**.
*   **Row 5 (6-16):** **Ribbon Controller**. Jump instantly between speeds (-2x, -1x, 0, +1x, +2x).
*   **Row 6:** **Tape Brake**. Apply pressure to slow down the tape manually.

### 👇 PERFORMANCE ROW (Row 7)
*   **1-4 (Sequencers):** Record your grid presses.
    *   *Click:* Play/Rec. *Double:* Stop. *Hold:* Clear.
*   **5-8 (Presets):** Save/Load snapshots of the system.
    *   *Click Empty:* Save. *Click Full:* Morph.
*   **9 (Kill):** Momentary High-Cut filter.
*   **10 (Freeze):** Max Feedback + Reverb Swell.
*   **11 (Warble):** Extreme Flutter effect.
*   **12 (Brake):** Global Tape Stop.
*   **13-16 (Transport):** Direct Rec/Play control for Tracks 1-4.

---

## 🛠️ TIPS & TRICKS

1.  **The "Ghost" Choir:** Set Scale to *Roland VP-330*, High Q, High Feedback. Feed white noise (Shift+E3 on Page 3). You will hear a ghostly choir singing chords.
2.  **Polyrhythmic Loops:** Record Track 1 at normal speed. Record Track 2. Then set Track 2 speed to *0.5* or *1.5*. The loops will drift apart over time.
3.  **The Drone Machine:** Record a short sound. On the Grid, set Loop Start/End points very close together (1 or 2 buttons). Set Speed to *0.25*. You now have a granular drone synthesizer.
4.  **Physics Protection:** If you hear a click or silence at very high frequencies (Band 16), the engine is protecting the audio path from mathematical explosion. Lower the Q or Feedback slightly.
