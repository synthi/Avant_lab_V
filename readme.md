# AVANT_LAB_V // QUICK START GUIDE

**Avant_lab_V** is a Spectral Laboratory for Monome Norns.
It functions as a historical reconstruction of an electronic music studio from the 1960s, combining a **16-Band Fixed Filter Bank** with a **4-Track Tape Machine**.

> **⚠️ NOTE ON HARDWARE:**
> While you can use Norns standalone, **a Monome Grid is highly recommended**. The Grid provides direct tactile access to the 16 filter bands, the tape loop windows, and the sequencers. This guide assumes you have one connected, but the script is fully functional without it.

---

## 🧭 1. THE GOLDEN RULE: NAVIGATION

Before making sound, you must learn how to move. The script is divided into **9 Pages**.

*   **K1 (The Shift Key):** Holding **K1** changes the function of other knobs and buttons.
*   **CHANGE PAGE:** Hold **K1** and press **K2** (Previous) or **K3** (Next).
*   **The Loop:** The pages wrap around. If you are on Page 9 and press Next, you go to Page 1.

### The Page Map
*   **1-6:** Sound Synthesis & FX (Global, Ping, Mix, Tape FX, Time, Filter).
*   **7:** **Tape Loopers** (Recording & Editing).
*   **8:** Tape Library (Load/Save).
*   **9:** **Sitral Mixer** (Volume, EQ & Pan).

---

## 🔊 2. MAKING SOUND (Filter Bank)

Start on **Page 1 (Global)**.
1.  **Audio In:** Connect a sound source to Norns Input L/R.
2.  **Choose a Scale (E1):** Turn Encoder 1. This changes the "tuning" of the 16 filters. Try *Bark* (Natural) or *Siemens ELA* (Vintage).
3.  **Resonance (E2):** Turn up **Feedback**. You will hear the filters start to "sing" and resonate with the input signal.
4.  **Bandwidth (E3):** Adjust **Global Q**. Lower is a standard EQ; Higher is a metallic resonator.

---

## 📼 3. RECORDING A LOOP (The Tapes)

Navigate to **Page 7 (Loopers)**. This page looks different; it shows the status of the 4 tape tracks.

**Controls for the Selected Track:**
*   **K2 (Transport):** This is your main button.
    *   **Click 1:** **REC** (Starts recording).
    *   **Click 2:** **DUB** (Closes the loop and immediately starts Overdubbing).
    *   **Click 3:** **PLAY** (Stops recording, keeps playing).
    *   **Double Click:** **STOP**.
    *   **Hold (1 sec):** **CLEAR** (Erases the tape).
*   **E1:** Track Volume (dB).
*   **E2:** **Varispeed**. Speed up, slow down, or reverse the tape.
*   **E3:** Overdub Level (Feedback).

> *Tip: Use the Grid (Row 5) to select which Track (1-4) you are controlling.*

---

## 🎚️ 4. MIXING & COLOR (The Console)

Once you have loops playing, go to **Page 9 (Mixer)**.
This page simulates a vintage **Klangfilm/Siemens** broadcasting console.

*   **Select Track:** Press **K2** (Left) or **K3** (Right) to select the active channel (1-4).
*   **E1 (Fader):** Volume fader (up to +12dB).
*   **E2 (Low EQ):** Vintage low shelf (110Hz). Gives "body" and saturation.
*   **E3 (High EQ):** Vintage high shelf (6.5kHz). Adds "air" and presence.

**Shift Functions (Hold K1):**
*   **E1:** Filter (DJ style HPF/LPF).
*   **E2:** Pan.
*   **E3:** Stereo Width.

---

## 🎹 GRID CHEATSHEET

*   **Rows 1-6 (Top):** Control the 16 Filter Bands (Faders).
*   **Row 7 (Performance):**
    *   **1-4:** Sequencers (Record automation for the loops).
    *   **5-8:** Presets (Short press: Save/Morph. Long press: Clear).
    *   **9-12:** FX Macros (Kill, Freeze, Warble, Brake).
    *   **13-16:** Direct Transport controls for Tracks 1-4.