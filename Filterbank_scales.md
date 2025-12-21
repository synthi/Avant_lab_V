# AVANT_LAB_V // SCALES REFERENCE MANUAL

This document provides historical context and technical details for the 58 filter bank scales included in **Avant_lab_V**. These scales emulate the frequency distribution of legendary hardware, vocoders, and mathematical phenomena.

---

## 1. PSYCHOACOUSTIC STANDARD (Default)

### Bark Scale (Psychoacoustic)
**Origin:** Eberhard Zwicker (1961)
**Description:** The "Bark scale" divides the audible frequency range into 24 critical bands that correspond to how the human ear perceives pitch and loudness.
**Usage:** This is the default scale because it sounds the most "natural" and balanced to the human ear. It provides equal perceptual resolution across the spectrum.

---

## 2. VINTAGE LAB HARDWARE & FILTER BANKS

### Siemens ELA (Klangfilm)
**Origin:** Germany (1950s/60s)
**Hardware:** Siemens ELA 75-15 Universal Filter
**Context:** Used in German cinema and broadcast studios. Known for its "musical" and warm character.
**Sound:** Smooth, rich mids, designed for high-fidelity optical sound reproduction.

### Siemens Oct (Octave Filter)
**Origin:** Germany (1960s)
**Hardware:** Siemens Octave Filter Bank
**Context:** Standard industrial test equipment used by Siemens labs.
**Sound:** Surgical and precise German engineering. Very clean separation between bands.

### B&K 2112 (The Standard)
**Origin:** Denmark (1960s)
**Hardware:** Brüel & Kjær Type 2112 Audio Frequency Spectrometer
**Context:** The absolute world standard for acoustic measurement for decades. Found in every major acoustical laboratory.
**Sound:** Extremely flat and accurate 1/3 octave response. The "reference" sound.

### B&K 2107 (Analyzer)
**Origin:** Denmark (1960s)
**Hardware:** Brüel & Kjær Type 2107 Frequency Analyzer
**Context:** Unlike the 2112, the 2107 was a continuously tunable analyzer. This scale emulates a logarithmic sweep typical of 60s acoustic tests.
**Sound:** Slightly softer and more "smeared" than the 2112.

### B&K Bass & Lo-Mid
**Origin:** Denmark (Custom)
**Context:** Custom configurations of B&K filters focused exclusively on the lower spectrum.
**Usage:** Use "B&K Bass" for sub-heavy drones and "Lo-Mid" for warmth and body without high-end distraction.

### R&S BN (Rohde & Schwarz)
**Origin:** Germany (1960s/70s)
**Hardware:** Rohde & Schwarz Audio Analyzer Series BN
**Context:** The main competitor to B&K in the high-end European test market.
**Sound:** Very strict tolerances. A dry, analytical sound often associated with German broadcast testing.

### GenRad 1925 (General Radio)
**Origin:** USA (1970s)
**Hardware:** GenRad 1925 Multifilter
**Context:** The American standard for acoustic calibration. Used by NASA and US military labs.
**Sound:** Punchy and mid-forward, typical of American discrete electronics of the era.

### HP 3580 (Spectrum)
**Origin:** USA (1973)
**Hardware:** Hewlett-Packard 3580A Spectrum Analyzer
**Context:** The first "low cost" spectrum analyzer that brought FFT-like analysis to smaller labs.
**Sound:** A unique logarithmic spacing used for analyzing noise floors in telecommunications.

### Altec 9860A
**Origin:** USA (1960s)
**Hardware:** Altec Lansing 9860A Active Equalizer
**Context:** Used in legendary recording studios (Capitol, United Western) for room tuning and monitor equalization ("Acousta-Voicing").
**Sound:** Musical "West Coast" sound. Very effective for shaping tone.

### K+H UE-100
**Origin:** Germany (1960s)
**Hardware:** Klein + Hummel UE-100 Universal Equalizer
**Context:** A massive, tube-based equalizer found in premier European mastering studios.
**Sound:** Often called the "Fairchild of EQs". Extremely smooth, elegant, and expensive-sounding curves.

### WDR Cologne
**Origin:** Germany (1950s)
**Context:** Based on the custom filter banks used at the WDR Studio for Electronic Music in Cologne (Stockhausen, Eimert).
**Sound:** The sound of early "Elektronische Musik". Designed for scientific deconstruction of sound.

### Serge Res (Serge Modular)
**Origin:** USA (1970s)
**Hardware:** Serge Resonant Equalizer (EQ)
**Context:** A classic module from the Serge West Coast synthesizer system.
**Sound:** Famous for its irregular band spacing and unique resonance that creates formant-like textures.

### Moog 914
**Origin:** USA (1960s)
**Hardware:** Moog Modular 914 Fixed Filter Bank
**Context:** The most famous FFB in history. Used by Wendy Carlos, Tangerine Dream, etc.
**Sound:** Deep, warm, and very musical. The classic "Moog" texture.

### Buchla 296
**Origin:** USA (1978)
**Hardware:** Buchla 296 Spectral Programmable Processor
**Context:** The complex spectral processor from the Buchla 200 series.
**Sound:** Complex, shifting, and organic. Ideal for spectral morphing.

### Utrecht (Sonology)
**Origin:** Netherlands (1960s/70s)
**Context:** Based on the custom filter banks at the Institute of Sonology (Utrecht/The Hague).
**Sound:** Academic, experimental, and precise. Used in Dutch electroacoustic music.

---

## 3. LEGENDARY VOCODERS

### Synton 221
**Origin:** Netherlands (1980)
**Hardware:** Synton Syntovox 221
**Context:** Often considered the best sounding analog vocoder ever made.
**Sound:** Extremely intelligible and bright. The "Holy Grail" of vocoding.

### EMS 5000
**Origin:** UK (1976)
**Hardware:** EMS Vocoder 5000 (The "Studio" Beast)
**Context:** A massive studio unit used by Kraftwerk ("The Robots") and in sci-fi movie soundtracks.
**Sound:** Clinical, robotic, and incredibly powerful. Very steep 18dB/octave slopes.

### EMS 2000
**Origin:** UK (1979)
**Hardware:** EMS Vocoder 2000 (The "Portable" One)
**Context:** A slightly scaled-down version of the 5000, easier to transport.
**Sound:** Slightly warmer and "mushier" than the 5000, but still unmistakably British and robotic.

### Roland VP-330
**Origin:** Japan (1979)
**Hardware:** Roland VP-330 Vocoder Plus
**Context:** The sound of Vangelis (Blade Runner). Combines vocoder with a string machine.
**Sound:** Lush, wide, and choral. Less about intelligibility, more about texture.

### Roland 100 (System-100m)
**Origin:** Japan (1979)
**Hardware:** Roland System-100m Model 191-J (Portion) / VP-330 Analysis
**Context:** Based on the filter topology of Roland's modular systems.
**Sound:** Resonant and squelchy, typical of the late 70s Roland sound.

### Senn VSM-201
**Origin:** Germany (1978)
**Hardware:** Sennheiser VSM-201
**Context:** An ultra-rare and expensive unit ($18,000 in 1978). Famous for its use by Herbie Hancock and Kraftwerk.
**Sound:** Extremely hi-fi, articulate, and "expensive". The "Rolls Royce" of vocoders.

### Korg VC-10
**Origin:** Japan (1978)
**Hardware:** Korg VC-10
**Context:** A popular, affordable vocoder with a built-in gooseneck mic.
**Sound:** Gritty, lo-fi, and aggressive. A cult classic for "trashy" robot voices.

### EHX Vocoder
**Origin:** USA (1970s)
**Hardware:** Electro-Harmonix Vocoder (Rackmount)
**Context:** A rare rack unit from the famous pedal manufacturer.
**Sound:** Raw, resonant, and psychedelic. Very different from the Japanese or German sound.

### Kraft K3
**Origin:** USSR (1980s)
**Hardware:** Kraft (Krasnogorsk) K3
**Context:** An obscure Soviet vocoder/filter bank.
**Sound:** Dark, heavy, and industrial. Unusual band spacing focused on low-mids.

---

## 4. MATH, PHYSICS & NATURE

### Schumann Res (Resonance)
**Concept:** The global electromagnetic resonance of the Earth (7.83 Hz).
**Implementation:** The fundamental and its harmonics multiplied by 10 to reach audible range.
**Sound:** Deep, grounding, and drone-like.

### Phi Spirals
**Concept:** The Golden Angle (137.5 degrees) used in phyllotaxis (plant growth).
**Implementation:** Frequencies are distributed using the golden angle ratio.
**Sound:** Organic, non-repeating, and naturally dissonant.

### Prime Series
**Concept:** Prime numbers (2, 3, 5, 7, 11...).
**Implementation:** A 40Hz fundamental multiplied by the sequence of prime numbers.
**Sound:** A harmonic series that never repeats octaves. Hollow and stretched.

### Kepler Orbits
**Concept:** Orbital resonance of the Solar System.
**Implementation:** Orbital periods of planets and moons scaled up by 32 octaves into the audio range.
**Sound:** The "Music of the Spheres". Complex, shifting clusters.

### Bubble Phys (Minnaert)
**Concept:** The Minnaert resonance formula for air bubbles in water.
**Implementation:** Simulates the resonant frequencies of bubbles of varying radii.
**Sound:** Liquid, organic, and "gurgling".

### Collatz Fractal
**Concept:** The 3n+1 mathematical conjecture.
**Implementation:** Frequencies follow the "hailstone" numbers generated by the conjecture.
**Sound:** Chaotic, seemingly random but with a hidden descending/ascending logic.

### Fibonacci
**Concept:** The famous sequence (1, 1, 2, 3, 5, 8...).
**Implementation:** Ratios derived from the sequence applied to frequency.
**Sound:** Starts consonant and harmonic, quickly becomes dense and clustered.

---

## 5. MUSICAL SCALES & TUNING

### Just Intonation
**Description:** Tuning based on simple whole-number ratios (pure intervals) rather than the compromised 12-tone equal temperament.
**Sound:** Extremely pure, stable, and resonant. No "beating" between intervals.

### Harmonic A / Harmonic C
**Description:** The natural harmonic series (overtones) based on a fundamental of A (55Hz) or C (65Hz).
**Sound:** Spectral, ghostly, and perfectly consonant.

### Overtone High
**Description:** High-order harmonics (16th to 32nd partials).
**Sound:** "Shimmer" effect. Sounds like a halo of light without a clear fundamental.

### Penta Min / Penta Maj
**Description:** Pentatonic scales distributed across the spectrum.
**Sound:** Very musical, folk-like, and pleasant. Hard to make "bad" sounds.

### Whole Tone
**Description:** A scale consisting entirely of whole steps.
**Sound:** Dreamy, floating, and ambiguous (like Debussy or flashbacks).

### Hirajoshi / Pelog / Slendro
**Description:** Traditional Japanese (Hirajoshi) and Indonesian Gamelan (Pelog, Slendro) tunings.
**Sound:** Exotic, bell-like, and culturally distinct.

### Bohlen-Pierce
**Description:** An experimental tuning that replaces the 2:1 Octave with the 3:1 "Tritave".
**Sound:** Alien. Your ear expects an octave but never finds it. Very eerie.

### Prometheus
**Description:** Based on the "Mystic Chord" used by Alexander Scriabin.
**Sound:** Tense, mystical, and suspended.

---

## 6. INSTRUMENTS & OTHERS

### Marimba / Vibraphone / Gong / Sitar
**Description:** Frequencies extracted from the spectral analysis of these physical instruments.
**Usage:** Imposes the "body" and resonance of these instruments onto your input signal (physical modeling-lite).

### Plate Reverb
**Description:** Resonant modes of a classic EMT 140 steel plate.
**Usage:** Creates a metallic, dense reverberant texture.

### Glass / Membrane
**Description:** Resonant modes of a wine glass and a circular drum membrane.
**Usage:** Adds "ping" and physical character to noises.

### BBC Speech
**Description:** A filter bank designed by the BBC for analyzing speech intelligibility.
**Usage:** Great for processing vocals or "robotizing" speech.