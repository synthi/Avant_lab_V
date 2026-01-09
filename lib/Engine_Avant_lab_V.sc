// lib/Engine_Avant_lab_V.sc | Version 2096
// UPDATE: FINAL GOLD. LeakDC inside loop (Fixes Band1). Sym/Asym Hybrid Saturation. Tape 2.0s.

Engine_Avant_lab_V : CroneEngine {
    var <synth;
    var <amp_bus_l, <amp_bus_r, <bands_bus, <tape_fb_bus, <aux_return_bus, <pos_bus;
    var <gr_bus; 
    var <track_out_buses; 
    var <buf1, <buf2, <buf3, <buf4;
    var <dummy_buf;
    var <osc_bridge; 

    alloc {
        var buffers;

        // 1. RAM ALLOCATION
        buf1 = Buffer.alloc(context.server, context.server.sampleRate * 120.0, 2);
        buf2 = Buffer.alloc(context.server, context.server.sampleRate * 120.0, 2);
        buf3 = Buffer.alloc(context.server, context.server.sampleRate * 120.0, 2);
        buf4 = Buffer.alloc(context.server, context.server.sampleRate * 120.0, 2);
        dummy_buf = Buffer.alloc(context.server, 44100, 2);
        
        buffers = [buf1, buf2, buf3, buf4];

        amp_bus_l = Bus.control(context.server);
        amp_bus_r = Bus.control(context.server);
        bands_bus = Bus.control(context.server, 16);
        pos_bus = Bus.control(context.server, 4);
        gr_bus = Bus.control(context.server); 
        
        tape_fb_bus = Bus.audio(context.server, 2);
        aux_return_bus = Bus.audio(context.server, 2);
        
        track_out_buses = { Bus.audio(context.server, 2) } ! 4;

        context.server.sync;

        // 2. OSC BRIDGE
        osc_bridge = OSCFunc({ |msg|
            NetAddr("127.0.0.1", 10111).sendMsg("/avant_lab_v/visuals", *msg.drop(3));
        }, '/avant_lab_v/visuals', context.server.addr).fix;

        // 3. DSP DEFINITION
        SynthDef(\avant_lab_v_synth, {
            |out_bus=0, in_bus=0, buf1=0, buf2=0, buf3=0, buf4=0, dummy_buf=0,
             tape_fb_bus_idx=0, aux_return_bus_idx=0, bus_l_idx=0, bus_r_idx=0, 
             bands_bus_base=0, pos_bus_base=0, gr_bus_idx=0,
             t1_bus=0, t2_bus=0, t3_bus=0, t4_bus=0,
             gonio_source=1, main_src_sel=3,
             comp_thresh=0.5, comp_ratio=2.0, comp_drive=0.0, comp_gain=0.0, 
             bass_focus_mode=0, limiter_ceil=0.0, balance=0.0| 

            // Variables
            var trig_meter, all_visual_data;
            var report_amp_l, report_amp_r, report_gr;
            var sum_l = 0.0, sum_r = 0.0;
            
            // [SYSTEM] Pointers initialized (Fix OSC Shift)
            var pointers = Array.fill(4, { DC.kr(0) });
            
            var bands_clean_read;

            // DSP Vars
            var fb_amt, global_q, xfeed_amt, reverb_mix;
            var reverb_time, reverb_damp;
            var input_amp, noise_amp, noise_type;
            var ping_active, ping_mode, ping_amp, ping_timbre, ping_jitter, ping_rate;
            var t_seq, t_manual;
            var rm_freq, rm_wave, rm_mix, rm_inst, rm_drive;
            var raw_pre_hpf, raw_pre_lpf, pre_hpf, pre_lpf;
            var stabilizer, spread, swirl_depth, swirl_rate, filter_mix, fader_lag; 
            var lfo_depth, lfo_rate, lfo_min_db;
            var tm_mix, tm_time, tm_fb, tm_sat, tm_wow, tm_flut, tm_ero;
            var system_dirt, filter_drift, main_mon;
            
            var l_rec, l_play, l_vol, l_speed, l_start, l_end;
            var l_src, l_dub, l_aux, l_deg, l_xfade, l_brake;
            var l_rec_lvl; 
            var l_low, l_high, l_filter, l_pan, l_width;
            var l_seek_t, l_seek_p;
            
            var synth_buffers, track_buses, init_freqs;
            var noise, input, source, local, input_sum, tap_clean;
            var ping, ping_env, trig_int_sig, trig_seq_sig, trig_man_sig, auto_trig, master_trig;
            var dirt_sig, hiss_vol, hum_vol, dust_dens, dust_vol, dust_sig;
            
            var tape_proc, tape_out, sig_main_tape, tap_post_tape;
            var shared_wow, shared_flutter, shared_mod, shared_dust_trig, shared_dropout_env;
            
            var rm_drift, rm_osc, rm_carrier, rm_processed_l, rm_processed_r, rm_stereo;
            var bank_in, bank_out, sig_filters, tap_post_filter;
            var sig_post_reverb, wet_reverb, final_signal, tap_post_reverb;
            var aux_feedback_in, loop_outputs_sum, loop_aux_sum;
            var monitor_signal, main_mon_amp, master_out, gonio_sig;
            var trk1_in, trk2_in, trk3_in, trk4_in;
            var driven_sig, master_glue, gr_sig;
            
            // Bass Focus Optimization vars
            var bf_freq, bf_mono, bf_processed;
            
            // Asymmetric Saturation Function (For Tape & Output Bus)
            var asym_sat = { |sig| (sig + 0.2).tanh - 0.2 };

            monitor_signal = Silent.ar(2);
            master_out = Silent.ar(2);

            fb_amt = \fb_amt.kr(0) * 0.6;
            global_q = \global_q.kr(1);
            xfeed_amt = \xfeed_amt.kr(0);
            reverb_mix = \reverb_mix.kr(1);
            reverb_time = \reverb_time.kr(1.5);
            reverb_damp = \reverb_damp.kr(10000);
            
            input_amp = \input_amp.kr(1);
            noise_amp = \noise_amp.kr(0);
            noise_type = \noise_type.kr(0);
            
            ping_active = \ping_active.kr(0);
            ping_mode = \ping_mode.kr(0);
            ping_amp = \ping_amp.kr(0);
            ping_timbre = \ping_timbre.kr(0);
            ping_jitter = \ping_jitter.kr(0);
            ping_rate = \ping_rate.kr(1);
            t_seq = \t_seq.tr(0);
            t_manual = \t_manual.tr(0);
            
            rm_freq = \rm_freq.kr(100);
            rm_wave = \rm_wave.kr(0);
            rm_mix = \rm_mix.kr(0);
            rm_inst = \rm_instability.kr(0);
            rm_drive = \rm_drive.kr(0);
            
            raw_pre_hpf = \pre_hpf.kr(20);
            raw_pre_lpf = \pre_lpf.kr(20000);
            
            stabilizer = \stabilizer.kr(0);
            spread = \spread.kr(0);
            swirl_depth = \swirl_depth.kr(0); 
            swirl_rate = \swirl_rate.kr(0.1); 
            filter_mix = \filter_mix.kr(1);
            fader_lag = \fader_lag.kr(0.05);
            
            lfo_depth = \lfo_depth.kr(0);
            lfo_rate = \lfo_rate.kr(0.1);
            lfo_min_db = \lfo_min_db.kr(-60);
            
            tm_mix = \tape_mix.kr(1);
            tm_time = \tape_time.kr(0);
            tm_fb = \tape_fb.kr(0, 0.2);
            tm_sat = \tape_sat.kr(0);
            tm_wow = \tape_wow.kr(0, 0.2);
            tm_flut = \tape_flutter.kr(0, 0.2);
            tm_ero = \tape_erosion.kr(0);
            
            system_dirt = \system_dirt.kr(0);
            filter_drift = \filter_drift.kr(0);
            main_mon = \main_mon.kr(0.833);
            
            l_rec = [\l1_rec.kr(0), \l2_rec.kr(0), \l3_rec.kr(0), \l4_rec.kr(0)];
            l_play = [\l1_play.kr(0), \l2_play.kr(0), \l3_play.kr(0), \l4_play.kr(0)];
            l_vol = [\l1_vol.kr(0), \l2_vol.kr(0), \l3_vol.kr(0), \l4_vol.kr(0)];
            l_speed = [\l1_speed.kr(1), \l2_speed.kr(1), \l3_speed.kr(1), \l4_speed.kr(1)];
            l_start = [\l1_start.kr(0), \l2_start.kr(0), \l3_start.kr(0), \l4_start.kr(0)];
            l_end = [\l1_end.kr(1), \l2_end.kr(1), \l3_end.kr(1), \l4_end.kr(1)];
            l_src = [\l1_src.kr(0), \l2_src.kr(0), \l3_src.kr(0), \l4_src.kr(0)];
            l_dub = [\l1_dub.kr(0.5), \l2_dub.kr(0.5), \l3_dub.kr(0.5), \l4_dub.kr(0.5)];
            l_aux = [\l1_aux.kr(0), \l2_aux.kr(0), \l3_aux.kr(0), \l4_aux.kr(0)];
            l_deg = [\l1_deg.kr(0), \l2_deg.kr(0), \l3_deg.kr(0), \l4_deg.kr(0)];
            l_xfade = [\l1_xfade.kr(0.05), \l2_xfade.kr(0.05), \l3_xfade.kr(0.05), \l4_xfade.kr(0.05)];
            l_brake = [\l1_brake.kr(0), \l2_brake.kr(0), \l3_brake.kr(0), \l4_brake.kr(0)];
            l_rec_lvl = [\l1_rec_lvl.kr(0), \l2_rec_lvl.kr(0), \l3_rec_lvl.kr(0), \l4_rec_lvl.kr(0)];
            l_low = [\l1_low.kr(0), \l2_low.kr(0), \l3_low.kr(0), \l4_low.kr(0)];
            l_high = [\l1_high.kr(0), \l2_high.kr(0), \l3_high.kr(0), \l4_high.kr(0)];
            l_filter = [\l1_filter.kr(0.5), \l2_filter.kr(0.5), \l3_filter.kr(0.5), \l4_filter.kr(0.5)];
            l_pan = [\l1_pan.kr(0), \l2_pan.kr(0), \l3_pan.kr(0), \l4_pan.kr(0)];
            l_width = [\l1_width.kr(1), \l2_width.kr(1), \l3_width.kr(1), \l4_width.kr(1)];
            l_seek_t = [\l1_seek_t.tr(0), \l2_seek_t.tr(0), \l3_seek_t.tr(0), \l4_seek_t.tr(0)];
            l_seek_p = [\l1_seek_p.kr(0), \l2_seek_p.kr(0), \l3_seek_p.kr(0), \l4_seek_p.kr(0)];
            
            synth_buffers = [buf1, buf2, buf3, buf4];
            track_buses = [t1_bus, t2_bus, t3_bus, t4_bus];
            init_freqs = [50, 75, 110, 150, 220, 350, 500, 750, 1100, 1600, 2200, 3600, 5200, 7500, 11000, 15000];

            trk1_in = InFeedback.ar(t1_bus, 2);
            trk2_in = InFeedback.ar(t2_bus, 2);
            trk3_in = InFeedback.ar(t3_bus, 2);
            trk4_in = InFeedback.ar(t4_bus, 2);

            pre_hpf = Lag.kr(raw_pre_hpf, 0.1);
            pre_lpf = Lag.kr(raw_pre_lpf, 0.1);
            
            aux_feedback_in = InFeedback.ar(aux_return_bus_idx, 2).tanh; 
            
            // [NOISE] TRUE STEREO INDEPENDENT
            noise = Select.ar(noise_type, [
                { PinkNoise.ar } ! 2, 
                { WhiteNoise.ar * 0.5 } ! 2, 
                { Crackle.ar(1.9) } ! 2, 
                // [QUALITY] Digital Rain: Original Complex Chain Restored
                { Latch.ar(WhiteNoise.ar, Dust.ar(LFNoise1.kr(0.3).exprange(5, 50))) * 0.4 } ! 2,
                // [OPTIMIZATION] Growl: LFNoise1 (Replaces Lorenz)
                { LFNoise1.ar(500) * 0.7 } ! 2, 
                { Dust2.ar(LFNoise1.kr(0.3).exprange(300, 2000)) * 0.9 } ! 2
            ]);
            
            // [QUALITY] Keep tanh for noise character
            noise = noise * noise_amp * 0.6; 
            noise = LeakDC.ar(noise);         
            noise = noise.tanh;               
            
            // [DIRT] HYBRID (Stereo Hiss, Mono Hum)
            hiss_vol = (system_dirt.pow(0.75)) * 0.03;
            hum_vol = (system_dirt.pow(3)) * 0.015;
            dust_dens = LinLin.kr(system_dirt, 0.11, 1.0, 0.05, 11);
            dust_vol = LinExp.kr(system_dirt, 0.11, 1.0, 0.01, 0.5);
            
            dust_sig = Decay2.ar({Dust.ar(dust_dens)} ! 2, 0.001, 0.01) * {PinkNoise.ar(1)} ! 2;
            dust_sig = dust_sig * dust_vol * (system_dirt > 0.11);
            
            dirt_sig = ({PinkNoise.ar(hiss_vol)} ! 2 + SinOsc.ar(50, 0, hum_vol).dup + dust_sig) * 0.5;
            
            input = In.ar(in_bus, 2) * input_amp;
            input = HPF.ar(input, 35);
            input = LPF.ar(input, 18000);
            
            trig_int_sig = Impulse.ar(ping_rate * (1 + (LFNoise2.kr(ping_rate) * ping_jitter * 1.5)).clip(0.1, 40)) * ping_active;
            trig_seq_sig = Trig1.ar(K2A.ar(t_seq), SampleDur.ir);
            trig_man_sig = Trig1.ar(K2A.ar(t_manual), SampleDur.ir);
            auto_trig = Select.ar(ping_mode, [trig_int_sig, trig_seq_sig]);
            master_trig = auto_trig + trig_man_sig;
            SendReply.ar(master_trig, "/ping_pulse", [ping_amp], 1234);
            ping_env = Decay2.ar(master_trig, 0.001, 0.2);
            
            // [PING] Unified Source
            ping = LPF.ar(PinkNoise.ar, LinExp.kr(ping_timbre, 0, 1, 200, 18000)) * ping_env * ping_amp;
            
            source = input + noise + ping.dup + aux_feedback_in;
            local = LocalIn.ar(2); 
            input_sum = source + (local * fb_amt);
            tap_clean = input_sum;
            
            input_sum = LeakDC.ar(input_sum + dirt_sig);
            
            shared_wow = OnePole.kr(LFNoise2.kr(Rand(0.5, 2.0)) * tm_wow * 0.005, 0.95); 
            shared_flutter = LFNoise1.kr(15) * tm_flut * 0.0005;
            shared_mod = shared_wow + shared_flutter;
            shared_dust_trig = Dust.kr(tm_ero * 15);
            shared_dropout_env = Decay.kr(shared_dust_trig, 0.1);
            
            // [TAPE] Removed redundant LeakDC wrapper
            tape_proc = input_sum + (HPF.ar(InFeedback.ar(tape_fb_bus_idx, 2), 40) * tm_fb);
            
            tape_out = tape_proc.collect({ |chan|
                 var dt, sig, eh, el, drive, comp_gain, head_bump, gain_loss;
                 // [SYSTEM] Tape 2.0s for RAM safety
                 dt = (Lag.kr(tm_time, 0.5) + 0.01 + shared_mod).clip(0, 2.0);
                 sig = DelayC.ar(chan, 2.0, dt);
                 head_bump = BPeakEQ.ar(sig, 100, 1.0, tm_sat * 3.0);
                 drive = 1.0 + (tm_sat * 3.0);
                 comp_gain = 1.0 / (1.0 + (tm_sat * 1.8));
                 
                 // [QUALITY] Keep tanh saturation
                 sig = asym_sat.(head_bump * drive) * comp_gain;
                 
                 // [SAFETY] Keep Inner LeakDC for tape stop Thump protection
                 sig = LeakDC.ar(sig);
                 
                 // [TAPE] Tuned Erosion: 110Hz low, 9kHz high
                 eh = LinExp.kr(1.0 - tm_ero, 0.001, 1.0, 9000, 20000);
                 el = LinExp.kr(tm_ero, 0.001, 1.0, 10, 110);
                 sig = LPF.ar(sig, eh); 
                 sig = HPF.ar(sig, el);
                 gain_loss = (shared_dropout_env * tm_ero).clip(0, 0.9);
                 sig = sig * (1.0 - gain_loss);
                 sig
            });
            
            Out.ar(tape_fb_bus_idx, Limiter.ar(tape_out, 0.95));
            sig_main_tape = (input_sum * (1.0 - tm_mix)) + (tape_out * tm_mix);
            tap_post_tape = sig_main_tape;
            
            rm_drift = (LFNoise2.kr(0.1) * 0.02 * rm_inst) + (LFNoise1.kr(10) * 0.005 * rm_inst);
            // [RING MOD] Optimized: 2 Waves
            rm_osc = Select.ar(rm_wave.min(1), [
                SinOsc.ar(rm_freq * (1+rm_drift)), 
                LFPulse.ar(rm_freq * (1+rm_drift))
            ]);
            rm_carrier = (rm_osc * 1.5).tanh + (PinkNoise.ar(0.005 * rm_inst));
            
            rm_stereo = [sig_main_tape[0].tanh * rm_carrier, sig_main_tape[1].tanh * rm_carrier] * 2.5;
            rm_stereo = Slew.ar(rm_stereo, 4000, 4000);
            rm_processed_l = rm_stereo[0];
            rm_processed_r = rm_stereo[1];
            
            bank_in = [(sig_main_tape[0] * (1.0 - rm_mix)) + (rm_processed_l * rm_mix), (sig_main_tape[1] * (1.0 - rm_mix)) + (rm_processed_r * rm_mix)];
            bank_in = HPF.ar(bank_in, pre_hpf); bank_in = LPF.ar(bank_in, pre_lpf);
            
            // [FIX] GLOBAL INPUT DC PROTECTION (Double Safety)
            bank_in = LeakDC.ar(bank_in);

            16.do({ |i|
                var key_g, key_f, db, amp, f, jitter, effective_q, mod_q, raw_rq;
                var input_gain, base_gain;
                var band_l, band_r;
                var pan_pos, bal_l, bal_r, spread_val, swirl_osc;
                var max_safe_rq, final_rq, squish_factor, compensation;
                var high_boost;
                
                // [FILTER] Unified Detection Variable (Audio & Visuals)
                var amp_analisis_l, amp_analisis_r;
                
                key_g = ("g" ++ i).asSymbol; key_f = ("f" ++ i).asSymbol;
                db = Lag3.kr(NamedControl.kr(key_g, -60.0), fader_lag);
                amp = db.dbamp; 
                
                f = NamedControl.kr(key_f, init_freqs[i.clip(0,15)], 0.05) * (1 + (LFNoise2.kr(0.05+(i*0.02)).range(0.9,1.1) * filter_drift * 0.06));
                f = f.clip(20, 18000);
                
                jitter = LFNoise1.kr(1.0+(i*0.1)).range(1.0-(filter_drift*0.15), 1.0+(filter_drift*0.05));
                
                effective_q = (global_q * LinLin.kr(db, -60, 0, 0.5, 1.2)) / (1.0 + (f/12000));
                // [OPTIMIZATION] LFNoise1 for filter modulation
                mod_q = effective_q * LFNoise1.kr(0.2).range(1.0, 1.0-(filter_drift*0.3));
                
                raw_rq = (1.0 / mod_q.max(0.5));
                max_safe_rq = (2.44 - (f * 0.0001075)).max(0.01);
                final_rq = raw_rq.min(max_safe_rq);
                squish_factor = final_rq / raw_rq;
                compensation = (1.0 / squish_factor).sqrt.clip(1.0, 1.8);
                
                base_gain = (600 / f).pow(0.28).clip(0.1, 3.0);
                high_boost = (f / 4000.0).max(1.0).pow(0.08); 
                input_gain = base_gain * compensation * high_boost;
                
                spread_val = (i%2) * 2 - 1; 
                spread_val = spread_val * spread;
                swirl_osc = SinOsc.kr(swirl_rate, (i / 16.0) * 2pi) * swirl_depth;
                pan_pos = (spread_val + swirl_osc).clip(-1.0, 1.0);
                bal_l = (1.0 - pan_pos).sqrt;
                bal_r = (1.0 + pan_pos).sqrt;
                
                band_l = BPF.ar(bank_in[0] * input_gain, f, final_rq) * (2.0 + (mod_q * 0.05)) * bal_l;
                band_r = BPF.ar(bank_in[1] * input_gain, f, final_rq) * (2.0 + (mod_q * 0.05)) * bal_r;
                
                // [FIX] LeakDC INSIDE LOOP (Restored from v2055)
                // This removes the "Ghost DC" generated by BPF movement before detection/saturation.
                band_l = LeakDC.ar(band_l);
                band_r = LeakDC.ar(band_r);
                
                // [FILTER] UNIFIED DETECTION (0.01/0.24) - Measures CLEAN signal
                amp_analisis_l = Amplitude.kr(band_l, 0.01, 0.24);
                amp_analisis_r = Amplitude.kr(band_r, 0.01, 0.24);
                
                // [FILTER] STABILIZER (Internal Compression) - Symmetric Tanh
                // Using .tanh ensures we don't generate NEW DC inside the saturator
                band_l = band_l * (1.0 - ((amp_analisis_l - 0.25).max(0) * stabilizer * 2.0).distort);
                band_r = band_r * (1.0 - ((amp_analisis_r - 0.25).max(0) * stabilizer * 2.0).distort);
                
                // [FILTER] VISUALS (Independent Detector removed, using Unified)
                // Since 'band_l' is now DC-free thanks to LeakDC, this value is accurate.
                Out.kr(bands_bus_base + i, (amp_analisis_l + amp_analisis_r) * 0.5);
                
                // [FILTER] SUMMING with SYMMETRIC SATURATION
                // We use .tanh (Symmetric) here to keep the sum clean of DC.
                sum_l = sum_l + (band_l.tanh * amp * jitter * 2.8);
                sum_r = sum_r + (band_r.tanh * amp * jitter * 2.8);
            });
            
            // [OUTPUT] ASYMMETRIC COLOR + LEAKDC (Bus Level)
            // Apply the "Warmth" (Asym Sat) here, then clean resulting DC.
            sum_l = LeakDC.ar(asym_sat.(sum_l));
            sum_r = LeakDC.ar(asym_sat.(sum_r));
            
            bank_out = [sum_l, sum_r];
            sig_filters = (bank_in * (1.0 - filter_mix)) + (bank_out * filter_mix);
            tap_post_filter = sig_filters;
            
            sig_post_reverb = [
                sig_filters[0] + (LPF.ar(sig_filters[1], 800) * xfeed_amt * 0.7),
                sig_filters[1] + (LPF.ar(sig_filters[0], 800) * xfeed_amt * 0.7)
            ];
            
            wet_reverb = sig_post_reverb.collect({ |chan, idx|
                var p = DelayN.ar(chan, 0.1, 0.03); 
                var combs = 6.collect({ 
                    var dt = Rand(0.03, 0.07);
                    var mod = LFNoise2.kr(Rand(0.1, 0.3)).range(0, 0.0025); 
                    CombL.ar(p, 0.2, dt + mod, reverb_time) 
                }).sum;
                // [REVERB] Optimized: Reduced Allpass to 2
                2.do({ |i| combs = AllpassN.ar(combs, 0.050, Rand(0.01, 0.05), 1); });
                combs * 0.2; 
            });
            
            wet_reverb = Decimator.ar(wet_reverb, 32000, 12);
            wet_reverb = LPF.ar(wet_reverb, reverb_damp);
            
            final_signal = (sig_filters * (1-reverb_mix)) + (HPF.ar(wet_reverb, 10) * reverb_mix);
            tap_post_reverb = final_signal;
            
            LocalOut.ar(final_signal); 

            loop_outputs_sum = Silent.ar(2);
            loop_aux_sum = Silent.ar(2);
            4.do({ |i|
                var b_idx, bus_idx, gate_rec, gate_play;
                var trk_vol, trk_spd, trk_start, trk_end;
                var trk_src, trk_dub, trk_aux, trk_deg, trk_xfade, trk_brake;
                var trk_rec_lvl_db, trk_rec_amp;
                var trk_low, trk_high, trk_filter, trk_pan, trk_width;
                var seek_t, seek_p;
                var in, rate_slew, ptr, play_sig, rec_sig, cutoff;
                var dynamic_cutoff, output_sig;
                var target_buf;
                var brake_mod, lfo_mod, brake_idx, lfo_lag_time; 
                var start_pos, end_pos;
                var fade_len_user, fade_len_micro, dist_start, dist_end;
                var fade_in_user, fade_out_user, gain_out_user;
                var fade_in_micro, fade_out_micro, gain_micro;
                var loop_ero, loop_dust_trig, loop_dropout_env, loop_gain_loss;
                var corrosion_am, flutter_delay, deg_curve;
                var c_lpf, c_hpf, f_lpf, f_hpf;
                var mid, side, new_l, new_r;
                var eq_max_db, sat_drive;
                var organic_brake_hpf, flux_gain;
                var input_fade_in, input_fade_out, input_win_gain;
                var sig_out, sig_dub; 
                var loop_len, rec_mix; 
                var dub_memory, fade_out_time;
                
                b_idx = synth_buffers[i];
                bus_idx = track_buses[i];
                
                dub_memory = LagUD.kr(l_dub[i], 0, 0.5);
                fade_out_time = Select.kr(dub_memory > 0.01, [0.025, 0.3]);
                gate_rec = LagUD.kr(l_rec[i], 0.005, fade_out_time); 
                
                gate_play = Lag.kr(l_play[i], 0.01); 
                trk_vol = l_vol[i];
                trk_spd = l_speed[i]; trk_start = l_start[i]; trk_end = l_end[i];
                trk_src = l_src[i]; trk_dub = l_dub[i]; trk_aux = l_aux[i]; trk_deg = l_deg[i];
                trk_xfade = l_xfade[i]; trk_brake = l_brake[i]; 
                trk_rec_lvl_db = l_rec_lvl[i];
                trk_rec_amp = trk_rec_lvl_db.dbamp;
                trk_low = l_low[i]; trk_high = l_high[i]; trk_filter = l_filter[i];
                trk_pan = l_pan[i]; trk_width = l_width[i];
                seek_t = l_seek_t[i]; seek_p = l_seek_p[i];
                
                target_buf = Select.kr(gate_rec > 0.0001, [dummy_buf, b_idx]);
                
                in = Select.ar(trk_src, [tap_clean, tap_post_tape, tap_post_filter, tap_post_reverb, trk1_in, trk2_in, trk3_in, trk4_in]);
                brake_idx = (trk_brake * 4).round;
                brake_mod = Select.kr(brake_idx, [1.0, 1.0, 1.0, 0.5, 0.0]);
                brake_mod = Lag3.kr(brake_mod, 0.3);
                lfo_mod = Select.kr(brake_idx, [1.0, LFNoise2.kr(2).range(0.95, 1.05), LFNoise2.kr(8).range(0.88, 1.12), LFNoise2.kr(4).range(0.95, 1.05), 1.0]);
                lfo_lag_time = Select.kr(brake_idx, [0.1, 0.25, 0.1, 0.05, 0.05]);
                lfo_mod = Lag.kr(lfo_mod, lfo_lag_time);
                rate_slew = Lag.kr(trk_spd, 0.05) * brake_mod * lfo_mod; 
                organic_brake_hpf = LinExp.kr(rate_slew.abs + 0.001, 0.001, 1.0, 250, 10);
                organic_brake_hpf = Lag.kr(organic_brake_hpf, 0.1);
                flux_gain = (rate_slew.abs * 5.0).clip(0, 1).pow(3);
                
                start_pos = trk_start * BufFrames.kr(b_idx);
                end_pos = trk_end * BufFrames.kr(b_idx);
                
                loop_len = (end_pos - start_pos).abs;
                fade_len_user = (trk_xfade * SampleRate.ir).min(loop_len * 0.5).max(100);
                fade_len_micro = (0.01 * SampleRate.ir).min(loop_len * 0.5).max(4);

                ptr = Phasor.ar(seek_t, rate_slew * BufRateScale.kr(b_idx), start_pos, end_pos, seek_p * BufFrames.kr(b_idx));
                pointers[i] = A2K.kr(ptr / BufFrames.kr(b_idx));
                Out.kr(pos_bus_base + i, pointers[i]); 
                
                dist_start = (ptr - start_pos).abs; dist_end = (end_pos - ptr).abs;
                fade_in_user = (dist_start / fade_len_user).clip(0, 1).pow(1.5); 
                fade_out_user = (dist_end / fade_len_user).clip(0, 1);
                gain_out_user = (fade_in_user.min(fade_out_user) * 0.5 * pi).sin;
                fade_in_micro = (dist_start / fade_len_micro).clip(0, 1);
                fade_out_micro = (dist_end / fade_len_micro).clip(0, 1);
                gain_micro = fade_in_micro.min(fade_out_micro).pow(0.5);
                
                play_sig = BufRd.ar(2, b_idx, ptr, 1, 2);
                deg_curve = trk_deg.pow(3.0); 
                corrosion_am = 1.0 - (LFNoise2.kr(8 + (i*2)).unipolar * deg_curve * 0.6);
                play_sig = play_sig * corrosion_am;
                loop_ero = LinLin.kr(trk_deg, 0.4, 1.0, 0.0, 0.5).max(0);
                loop_dust_trig = Dust.kr(loop_ero * 15);
                loop_dropout_env = Decay.kr(loop_dust_trig, 0.1);
                loop_gain_loss = (loop_dropout_env * loop_ero).clip(0, 0.9);
                play_sig = play_sig * (1.0 - loop_gain_loss);
                flutter_delay = OnePole.ar(LFNoise2.ar(4 + (i*1.5)).range(0, 0.008 * deg_curve), 0.90);
                play_sig = DelayC.ar(play_sig, 0.05, flutter_delay);
                cutoff = LinExp.kr(deg_curve, 0, 1, 20000, 2100);
                play_sig = LPF.ar(play_sig, cutoff);
                play_sig = (play_sig * (1 + (deg_curve * 0.8))).tanh;
                dynamic_cutoff = (rate_slew.abs * 20000).clip(10, 20000);
                play_sig = LPF.ar(play_sig, dynamic_cutoff);
                
                sig_out = play_sig * gain_out_user; 
                sig_dub = play_sig * gain_micro;    
                
                rec_sig = (in * gain_micro * trk_rec_amp) + (sig_dub * trk_dub);
                rec_mix = (play_sig * (1.0 - gate_rec)) + (rec_sig * gate_rec);
                
                BufWr.ar(LeakDC.ar(rec_mix).tanh, target_buf, ptr);
                
                output_sig = sig_out * gate_play; 
                output_sig = HPF.ar(output_sig, organic_brake_hpf);
                output_sig = output_sig * flux_gain;
                output_sig = BLowShelf.ar(output_sig, 60, 4.0, trk_low);
                output_sig = BHiShelf.ar(output_sig, 10000, 4.0, trk_high);
                c_lpf = trk_filter.min(0.5) * 2; 
                c_hpf = (trk_filter - 0.5).max(0) * 2;
                f_lpf = LinExp.kr(c_lpf, 0, 1, 20, 20000);
                f_hpf = LinExp.kr(c_hpf, 0, 1, 20, 20000);
                output_sig = LPF.ar(output_sig, f_lpf);
                output_sig = HPF.ar(output_sig, f_hpf);
                eq_max_db = trk_low.abs.max(trk_high.abs);
                sat_drive = 1.0 + (eq_max_db / 18.0).squared;
                output_sig = (output_sig * sat_drive).tanh;
                mid = (output_sig[0] + output_sig[1]) * 0.5;
                side = (output_sig[0] - output_sig[1]) * 0.5;
                new_l = mid + (side * trk_width);
                new_r = mid - (side * trk_width);
                output_sig = [new_l, new_r];
                output_sig = Balance2.ar(output_sig[0], output_sig[1], trk_pan);
                Out.ar(bus_idx, output_sig);
                loop_outputs_sum = loop_outputs_sum + (output_sig * LinLin.kr(trk_vol, 0, 1, -60, 12).dbamp * (trk_vol > 0.001));
                loop_aux_sum = loop_aux_sum + (output_sig * trk_aux);
            });
            
            monitor_signal = Select.ar(main_src_sel, [tap_clean, tap_post_tape, tap_post_filter, tap_post_reverb]);
            master_out = monitor_signal + loop_outputs_sum;
            
            // [BASS FOCUS] Optimized Variable Crossover (Single Filter Pair)
            bf_freq = Select.kr(bass_focus_mode.clip(1, 3), [50, 100, 200]); 
            bf_mono = LPF.ar(master_out, bf_freq).sum; 
            bf_processed = HPF.ar(master_out, bf_freq) + (bf_mono ! 2);
            
            master_out = Select.ar(bass_focus_mode > 0, [master_out, bf_processed]);
            
            driven_sig = master_out * comp_drive.dbamp;
            
            master_glue = Compander.ar(driven_sig, driven_sig, 
                thresh: comp_thresh.dbamp, 
                slopeBelow: 1.0, 
                slopeAbove: 1.0 / comp_ratio, 
                clampTime: 0.01, 
                relaxTime: 0.1
            );
            
            gr_sig = (Peak.kr(driven_sig, Impulse.kr(20)) - Peak.kr(master_glue, Impulse.kr(20))).max(0);
            report_gr = LagUD.kr(gr_sig.sum, 0, 0.1);
            Out.kr(gr_bus_idx, report_gr);
            master_glue = Balance2.ar(master_glue[0], master_glue[1], balance);
            master_out = Limiter.ar(master_glue.tanh, limiter_ceil.dbamp);
            gonio_sig = Select.ar(gonio_source, [final_signal, master_out]);
            report_amp_l = LagUD.kr(Peak.kr(gonio_sig[0], Impulse.kr(30)), 0, 0.1);
            report_amp_r = LagUD.kr(Peak.kr(gonio_sig[1], Impulse.kr(30)), 0, 0.1);
            Out.kr(bus_l_idx, report_amp_l);
            Out.kr(bus_r_idx, report_amp_r);
            
            // [SYSTEM] Calculated safely at end
            main_mon_amp = LinLin.kr(main_mon, 0, 1, -60, 12).dbamp * (main_mon > 0.001);
            master_out = master_out * main_mon_amp;
            
            trig_meter = Impulse.kr(60);
            bands_clean_read = 16.collect({ |i| In.kr(bands_bus_base + i) });
            
            // [SYSTEM] Force Mix on reports to ensure OSC matrix alignment
            all_visual_data = [
                Mix(report_amp_l), 
                Mix(report_amp_r), 
                Mix(report_gr), 
                pointers[0], pointers[1], pointers[2], pointers[3],
                bands_clean_read
            ].flat;
            
            SendReply.kr(trig_meter, '/avant_lab_v/visuals', all_visual_data);
            Out.ar(aux_return_bus_idx, loop_aux_sum);
            Out.ar(out_bus, master_out);
        }).add;

        context.server.sync;
        synth = Synth.new(\avant_lab_v_synth, [
            \out_bus, context.out_b, \in_bus, context.in_b,
            \buf1, buf1, \buf2, buf2, \buf3, buf3, \buf4, buf4, \dummy_buf, dummy_buf,
            \tape_fb_bus_idx, tape_fb_bus.index, \aux_return_bus_idx, aux_return_bus.index,
            \bus_l_idx, amp_bus_l.index, \bus_r_idx, amp_bus_r.index,
            \bands_bus_base, bands_bus.index, \pos_bus_base, pos_bus.index,
            \gr_bus_idx, gr_bus.index,
            \t1_bus, track_out_buses[0].index, \t2_bus, track_out_buses[1].index,
            \t3_bus, track_out_buses[2].index, \t4_bus, track_out_buses[3].index
        ], context.xg);

        context.server.sync;
        
        // Commands
        this.addCommand("buffer_read", "is", { |msg| 
            var remote = NetAddr("127.0.0.1", 10111);
            var bufnum = buffers[msg[1]-1]; 
            if(File.exists(msg[2]), { 
                bufnum.zero; 
                Buffer.readChannel(context.server, msg[2], 0, bufnum.numFrames, [0, 1], action: { |b| 
                    var dur = b.numFrames / context.server.sampleRate; 
                    b.copyData(bufnum); 
                    b.free; 
                    remote.sendMsg("/buffer_info", msg[1], dur); 
                }); 
            }); 
        });
        
        this.addCommand("buffer_write", "isf", { |msg| 
            var bufnum = buffers[msg[1]-1]; 
            var duration = msg[3]; 
            var numFrames = (duration * context.server.sampleRate).asInteger; 
            if(numFrames > 0, { bufnum.write(msg[2], "wav", "int24", numFrames); }, { bufnum.write(msg[2], "wav", "int24"); }); 
        });
        
        this.addCommand("l_speed", "if", { |msg| synth.set(("l" ++ msg[1] ++ "_speed").asSymbol, msg[2]); });
        this.addCommand("l_vol", "if", { |msg| synth.set(("l" ++ msg[1] ++ "_vol").asSymbol, msg[2]); });
        this.addCommand("l_low", "if", { |msg| synth.set(("l" ++ msg[1] ++ "_low").asSymbol, msg[2]); });
        this.addCommand("l_high", "if", { |msg| synth.set(("l" ++ msg[1] ++ "_high").asSymbol, msg[2]); });
        this.addCommand("l_filter", "if", { |msg| synth.set(("l" ++ msg[1] ++ "_filter").asSymbol, msg[2]); });
        this.addCommand("l_pan", "if", { |msg| synth.set(("l" ++ msg[1] ++ "_pan").asSymbol, msg[2]); });
        this.addCommand("l_width", "if", { |msg| synth.set(("l" ++ msg[1] ++ "_width").asSymbol, msg[2]); });
        this.addCommand("l_rec_lvl", "if", { |msg| synth.set(("l" ++ msg[1] ++ "_rec_lvl").asSymbol, msg[2]); });
        this.addCommand("l1_config", "ffffffffffff", { |msg| synth.set(\l1_rec, msg[1], \l1_play, msg[2], \l1_vol, msg[3], \l1_speed, msg[4], \l1_start, msg[5], \l1_end, msg[6], \l1_src, msg[7], \l1_dub, msg[8], \l1_aux, msg[9], \l1_deg, msg[10], \l1_xfade, msg[11], \l1_brake, msg[12]); });
        this.addCommand("l2_config", "ffffffffffff", { |msg| synth.set(\l2_rec, msg[1], \l2_play, msg[2], \l2_vol, msg[3], \l2_speed, msg[4], \l2_start, msg[5], \l2_end, msg[6], \l2_src, msg[7], \l2_dub, msg[8], \l2_aux, msg[9], \l2_deg, msg[10], \l2_xfade, msg[11], \l2_brake, msg[12]); });
        this.addCommand("l3_config", "ffffffffffff", { |msg| synth.set(\l3_rec, msg[1], \l3_play, msg[2], \l3_vol, msg[3], \l3_speed, msg[4], \l3_start, msg[5], \l3_end, msg[6], \l3_src, msg[7], \l3_dub, msg[8], \l3_aux, msg[9], \l3_deg, msg[10], \l3_xfade, msg[11], \l3_brake, msg[12]); });
        this.addCommand("l4_config", "ffffffffffff", { |msg| synth.set(\l4_rec, msg[1], \l4_play, msg[2], \l4_vol, msg[3], \l4_speed, msg[4], \l4_start, msg[5], \l4_end, msg[6], \l4_src, msg[7], \l4_dub, msg[8], \l4_aux, msg[9], \l4_deg, msg[10], \l4_xfade, msg[11], \l4_brake, msg[12]); });
        this.addCommand("l1_seek", "f", { |msg| synth.set(\l1_seek_p, msg[1], \l1_seek_t, 1); });
        this.addCommand("l2_seek", "f", { |msg| synth.set(\l2_seek_p, msg[1], \l2_seek_t, 1); });
        this.addCommand("l3_seek", "f", { |msg| synth.set(\l3_seek_p, msg[1], \l3_seek_t, 1); });
        this.addCommand("l4_seek", "f", { |msg| synth.set(\l4_seek_p, msg[1], \l4_seek_t, 1); });
        this.addCommand("feedback", "f", { |msg| synth.set(\fb_amt, msg[1]); });
        this.addCommand("global_q", "f", { |msg| synth.set(\global_q, msg[1]); });
        this.addCommand("cross_feed", "f", { |msg| synth.set(\xfeed_amt, msg[1]); });
        this.addCommand("input_amp", "f", { |msg| synth.set(\input_amp, msg[1]); });
        this.addCommand("noise_amp", "f", { |msg| synth.set(\noise_amp, msg[1]); });
        this.addCommand("noise_type", "f", { |msg| synth.set(\noise_type, msg[1]); });
        this.addCommand("reverb_mix", "f", { |msg| synth.set(\reverb_mix, msg[1]); });
        this.addCommand("reverb_time", "f", { |msg| synth.set(\reverb_time, msg[1]); });
        this.addCommand("reverb_damp", "f", { |msg| synth.set(\reverb_damp, msg[1]); });
        this.addCommand("pre_hpf", "f", { |msg| synth.set(\pre_hpf, msg[1]); });
        this.addCommand("pre_lpf", "f", { |msg| synth.set(\pre_lpf, msg[1]); });
        this.addCommand("stabilizer", "f", { |msg| synth.set(\stabilizer, msg[1]); });
        this.addCommand("spread", "f", { |msg| synth.set(\spread, msg[1]); });
        this.addCommand("swirl_depth", "f", { |msg| synth.set(\swirl_depth, msg[1]); });
        this.addCommand("swirl_rate", "f", { |msg| synth.set(\swirl_rate, msg[1]); });
        
        this.addCommand("filter_mix", "f", { |msg| synth.set(\filter_mix, msg[1]); });
        this.addCommand("system_dirt", "f", { |msg| synth.set(\system_dirt, msg[1]); });
        this.addCommand("filter_drift", "f", { |msg| synth.set(\filter_drift, msg[1]); });
        this.addCommand("fader_lag", "f", { |msg| synth.set(\fader_lag, msg[1]); });
        this.addCommand("lfo_depth", "f", { |msg| synth.set(\lfo_depth, msg[1]); });
        this.addCommand("lfo_rate", "f", { |msg| synth.set(\lfo_rate, msg[1]); });
        this.addCommand("lfo_min_db", "f", { |msg| synth.set(\lfo_min_db, msg[1]); });
        this.addCommand("ping_sequence", "f", { |msg| synth.set(\t_seq, 1); });
        this.addCommand("ping_manual", "f", { |msg| synth.set(\t_manual, 1); });
        this.addCommand("ping_active", "f", { |msg| synth.set(\ping_active, msg[1]); });
        this.addCommand("ping_mode", "f", { |msg| synth.set(\ping_mode, msg[1]); }); 
        this.addCommand("ping_amp", "f", { |msg| synth.set(\ping_amp, msg[1]); });
        this.addCommand("ping_rate", "f", { |msg| synth.set(\ping_rate, msg[1]); }); 
        this.addCommand("ping_jitter", "f", { |msg| synth.set(\ping_jitter, msg[1]); });
        this.addCommand("ping_timbre", "f", { |msg| synth.set(\ping_timbre, msg[1]); });
        this.addCommand("rm_drive", "f", { |msg| synth.set(\rm_drive, msg[1]); }); 
        this.addCommand("rm_freq", "f", { |msg| synth.set(\rm_freq, msg[1]); });
        this.addCommand("rm_wave", "f", { |msg| synth.set(\rm_wave, msg[1]); });
        this.addCommand("rm_mix", "f", { |msg| synth.set(\rm_mix, msg[1]); });
        this.addCommand("rm_instability", "f", { |msg| synth.set(\rm_instability, msg[1]); });
        this.addCommand("tape_sat", "f", { |msg| synth.set(\tape_sat, msg[1]); });
        this.addCommand("tape_wow", "f", { |msg| synth.set(\tape_wow, msg[1]); });
        this.addCommand("tape_flutter", "f", { |msg| synth.set(\tape_flutter, msg[1]); });
        this.addCommand("tape_erosion", "f", { |msg| synth.set(\tape_erosion, msg[1]); });
        this.addCommand("tape_time", "f", { |msg| synth.set(\tape_time, msg[1]); });
        this.addCommand("tape_fb", "f", { |msg| synth.set(\tape_fb, msg[1]); });
        this.addCommand("tape_brake", "f", { |msg| synth.set(\tape_brake, msg[1]); });
        this.addCommand("tape_mix", "f", { |msg| synth.set(\tape_mix, msg[1]); });
        this.addCommand("main_mon", "f", { |msg| synth.set(\main_mon, msg[1]); });
        this.addCommand("band_gain", "if", { |msg| synth.set(("g" ++ msg[1]).asSymbol, msg[2]); });
        this.addCommand("band_freq", "if", { |msg| synth.set(("f" ++ msg[1]).asSymbol, msg[2]); });
        this.addCommand("gonio_source", "i", { |msg| synth.set(\gonio_source, msg[1]); });
        this.addCommand("main_source", "i", { |msg| synth.set(\main_src_sel, msg[1]); }); 
        
        this.addCommand("comp_thresh", "f", { |msg| synth.set(\comp_thresh, msg[1]); });
        this.addCommand("comp_ratio", "f", { |msg| synth.set(\comp_ratio, msg[1]); });
        this.addCommand("comp_drive", "f", { |msg| synth.set(\comp_drive, msg[1]); }); 
        this.addCommand("bass_focus", "i", { |msg| synth.set(\bass_focus_mode, msg[1]); });
        this.addCommand("limiter_ceil", "f", { |msg| synth.set(\limiter_ceil, msg[1]); });
        this.addCommand("balance", "f", { |msg| synth.set(\balance, msg[1]); });
        
        this.addCommand("clear", "i", { |msg| buffers[msg[1]-1].zero; });
    }

    free {
        osc_bridge.free; synth.free;
        amp_bus_l.free; amp_bus_r.free; bands_bus.free;
        tape_fb_bus.free; aux_return_bus.free; pos_bus.free;
        gr_bus.free; 
        track_out_buses.do(_.free);
        buf1.free; buf2.free; buf3.free; buf4.free; dummy_buf.free;
    }
}
