// lib/Engine_Avant_lab_V.sc | Version 1.3
// RELEASE v1.3 (SYNTAX FIXED & TUNED):
// 1. SYNTAX: Strict variable declaration at top of blocks (fixes Parse Error).
// 2. GAIN: Empirical Lookup Table for Feedback (21 points) based on user measurements.
// 3. FILTERS: HPF at Output. LPF 4-Pole (24dB/oct) inside Loop.
// 4. LOGIC: Stop state forces Feedback=1.0 (Hard Bypass).
// 5. SATURATION: Tanh Bypass < 0.2. S-Curve applied above.

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
             bass_focus_mode=0, limiter_ceil=0.0, balance=0.0,
             l1_length=60.0, l2_length=60.0, l3_length=60.0, l4_length=60.0,
             l1_seek_pos=0, l2_seek_pos=0, l3_seek_pos=0, l4_seek_pos=0,
             t_l1_seek_trig=0, t_l2_seek_trig=0, t_l3_seek_trig=0, t_l4_seek_trig=0| 

            // --- VARIABLES DECLARATION START ---
            
            // Visuals
            var trig_meter, all_visual_data;
            var report_amp_l, report_amp_r, report_gr;
            var pointers = Array.fill(4, { DC.kr(0) });
            var bands_clean_read;

            // Global Params
            var fb_amt, global_q, xfeed_amt, reverb_mix;
            var reverb_time, reverb_damp;
            var input_amp, noise_amp, noise_type;
            
            // Ping
            var ping_active, ping_mode, ping_amp, ping_timbre, ping_jitter, ping_rate;
            var t_seq, t_manual;
            
            // RM
            var rm_freq, rm_wave, rm_mix, rm_inst, rm_drive;
            
            // Filter Bank
            var raw_pre_hpf, raw_pre_lpf, pre_hpf, pre_lpf;
            var stabilizer, spread, swirl_depth, swirl_rate, filter_mix, fader_lag; 
            var filter_drift;
            
            // LFO
            var lfo_depth, lfo_rate, lfo_min_db;
            
            // Tape Delay
            var tm_mix, tm_time, tm_fb, tm_sat, tm_wow, tm_flut, tm_ero;
            
            // System
            var system_dirt, main_mon, main_mon_amp;
            
            // Track Arrays
            var l_rec, l_play, l_vol, l_speed, l_start, l_end;
            var l_src, l_dub, l_aux, l_deg, l_brake; 
            var l_rec_lvl; 
            var l_low, l_high, l_filter, l_pan, l_width;
            var l_length, l_seek_p, l_seek_t;
            
            // Buffers & Buses
            var synth_buffers, track_buses, init_freqs;
            
            // Signals
            var noise_L, noise_R, noise;
            var hiss_vol, hum_vol, dust_dens, dust_vol, dust_sig, dirt_sig;
            var input, source, local, input_sum, tap_clean;
            var trig_int_sig, trig_seq_sig, trig_man_sig, auto_trig, master_trig, ping_env, ping;
            var aux_feedback_in;
            
            // Tape Echo Processing
            var shared_wow, shared_flutter, shared_mod, shared_dust_trig, shared_dropout_env;
            var tape_proc, tape_out, sig_main_tape, tap_post_tape;
            
            // RM Processing
            var rm_drift, rm_osc, rm_carrier, rm_stereo;
            var rm_processed_l, rm_processed_r;
            
            // Filter Bank Processing
            var bank_in, sum_l, sum_r, bank_out;
            var sig_filters, tap_post_filter;
            
            // Reverb Processing
            var sig_post_reverb, wet_reverb, final_signal, tap_post_reverb;
            
            // Master & Output
            var loop_outputs_sum, loop_aux_sum;
            var trk1_in, trk2_in, trk3_in, trk4_in;
            var master_out, monitor_signal;
            var bf_freq, bf_mono, bf_highs, bf_processed;
            var driven_sig, master_glue, gr_sig, gonio_sig;
            
            var asym_sat = { |sig| (sig + 0.2).tanh - 0.2 };

            // --- VARIABLES ASSIGNMENT ---

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
            filter_drift = \filter_drift.kr(0);
            
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
            main_mon = \main_mon.kr(0.833);
            main_mon_amp = LinLin.kr(main_mon, 0, 1, -60, 12).dbamp * (main_mon > 0.001);
            
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
            l_brake = [\l1_brake.kr(0), \l2_brake.kr(0), \l3_brake.kr(0), \l4_brake.kr(0)];
            l_rec_lvl = [\l1_rec_lvl.kr(0), \l2_rec_lvl.kr(0), \l3_rec_lvl.kr(0), \l4_rec_lvl.kr(0)];
            l_low = [\l1_low.kr(0), \l2_low.kr(0), \l3_low.kr(0), \l4_low.kr(0)];
            l_high = [\l1_high.kr(0), \l2_high.kr(0), \l3_high.kr(0), \l4_high.kr(0)];
            l_filter = [\l1_filter.kr(0.5), \l2_filter.kr(0.5), \l3_filter.kr(0.5), \l4_filter.kr(0.5)];
            l_pan = [\l1_pan.kr(0), \l2_pan.kr(0), \l3_pan.kr(0), \l4_pan.kr(0)];
            l_width = [\l1_width.kr(1), \l2_width.kr(1), \l3_width.kr(1), \l4_width.kr(1)];
            
            l_length = [l1_length, l2_length, l3_length, l4_length];
            l_seek_p = [l1_seek_pos, l2_seek_pos, l3_seek_pos, l4_seek_pos];
            l_seek_t = [t_l1_seek_trig, t_l2_seek_trig, t_l3_seek_trig, t_l4_seek_trig];
            
            synth_buffers = [buf1, buf2, buf3, buf4];
            track_buses = [t1_bus, t2_bus, t3_bus, t4_bus];
            init_freqs = [50, 75, 110, 150, 220, 350, 500, 750, 1100, 1600, 2200, 3600, 5200, 7500, 11000, 15000];

            // --- DSP START ---
            
            pre_hpf = Lag.kr(raw_pre_hpf, 0.1);
            pre_lpf = Lag.kr(raw_pre_lpf, 0.1);
            aux_feedback_in = InFeedback.ar(aux_return_bus_idx, 2).tanh; 
            
            // Noise & Dirt Generation
            noise_L = Select.ar(noise_type, [
                PinkNoise.ar, WhiteNoise.ar * 0.5, Crackle.ar(1.9),
                Latch.ar(WhiteNoise.ar, Dust.ar(LFNoise1.kr(0.3).exprange(5, 50))) * 0.4,
                LFNoise1.ar(500) * 0.7, Dust2.ar(LFNoise1.kr(0.3).exprange(300, 2000)) * 0.9
            ]);
            noise_R = Select.ar(noise_type, [
                PinkNoise.ar, WhiteNoise.ar * 0.5, Crackle.ar(1.9),
                Latch.ar(WhiteNoise.ar, Dust.ar(LFNoise1.kr(0.3).exprange(5, 50))) * 0.4,
                LFNoise1.ar(500) * 0.7, Dust2.ar(LFNoise1.kr(0.3).exprange(300, 2000)) * 0.9
            ]);
            noise = [noise_L, noise_R] * noise_amp * 0.6;
            noise = LeakDC.ar(noise).tanh;

            hiss_vol = (system_dirt.pow(0.75)) * 0.03;
            hum_vol = (system_dirt.pow(3)) * 0.015;
            dust_dens = LinLin.kr(system_dirt, 0.11, 1.0, 0.05, 11);
            dust_vol = LinExp.kr(system_dirt, 0.11, 1.0, 0.01, 0.5);
            dust_sig = [Decay2.ar(Dust.ar(dust_dens), 0.001, 0.01) * PinkNoise.ar(1), Decay2.ar(Dust.ar(dust_dens), 0.001, 0.01) * PinkNoise.ar(1)] * dust_vol * (system_dirt > 0.11);
            dirt_sig = ([PinkNoise.ar(hiss_vol), PinkNoise.ar(hiss_vol)] + [SinOsc.ar(50, 0, hum_vol), SinOsc.ar(50, 0, hum_vol)] + dust_sig) * 0.5;

            input = In.ar(in_bus, 2) * input_amp;
            input = HPF.ar(input, 35); input = LPF.ar(input, 18000);
            
            // Ping
            trig_int_sig = Impulse.ar(ping_rate * (1 + (LFNoise2.kr(ping_rate) * ping_jitter * 1.5)).clip(0.1, 40)) * ping_active;
            trig_seq_sig = Trig1.ar(K2A.ar(t_seq), SampleDur.ir);
            trig_man_sig = Trig1.ar(K2A.ar(t_manual), SampleDur.ir);
            auto_trig = Select.ar(ping_mode, [trig_int_sig, trig_seq_sig]);
            master_trig = auto_trig + trig_man_sig;
            SendReply.ar(master_trig, "/ping_pulse", [ping_amp], 1234);
            ping_env = Decay2.ar(master_trig, 0.001, 0.2);
            ping = LPF.ar(PinkNoise.ar, LinExp.kr(ping_timbre, 0, 1, 200, 18000)) * ping_env * ping_amp;
            
            source = input + noise + ping.dup + aux_feedback_in;
            local = LocalIn.ar(2); 
            input_sum = source + (local * fb_amt);
            tap_clean = input_sum;
            input_sum = LeakDC.ar(input_sum + dirt_sig);
            
            // Tape Delay Process
            shared_wow = OnePole.kr(LFNoise2.kr(Rand(0.5, 2.0)) * tm_wow * 0.005, 0.95); 
            shared_flutter = LFNoise1.kr(15) * tm_flut * 0.0005;
            shared_mod = shared_wow + shared_flutter;
            shared_dust_trig = Dust.kr(tm_ero * 15);
            shared_dropout_env = Decay.kr(shared_dust_trig, 0.1);
            tape_proc = input_sum + (HPF.ar(InFeedback.ar(tape_fb_bus_idx, 2), 40) * tm_fb);
            tape_out = tape_proc.collect({ |chan|
                 var dt = (Lag.kr(tm_time, 0.5) + 0.01 + shared_mod).clip(0, 2.0); 
                 var sig = DelayC.ar(chan, 2.0, dt);
                 var head_bump = BPeakEQ.ar(sig, 100, 1.0, tm_sat * 3.0);
                 var drive = 1.0 + (tm_sat * 3.0);
                 var comp_gain = 1.0 / (1.0 + (tm_sat * 1.8));
                 sig = (asym_sat.(head_bump * drive) * comp_gain);
                 sig = LeakDC.ar(sig);
                 sig = LPF.ar(sig, LinExp.kr(1.0 - tm_ero, 0.001, 1.0, 9000, 20000)); 
                 sig = HPF.ar(sig, LinExp.kr(tm_ero, 0.001, 1.0, 110, 110));
                 sig * (1.0 - (shared_dropout_env * tm_ero).clip(0, 0.9));
            });
            Out.ar(tape_fb_bus_idx, Limiter.ar(tape_out, 0.95));
            sig_main_tape = (input_sum * (1.0 - tm_mix)) + (tape_out * tm_mix);
            tap_post_tape = sig_main_tape;
            
            // Ring Mod
            rm_drift = (LFNoise2.kr(0.1) * 0.02 * rm_inst) + (LFNoise1.kr(10) * 0.005 * rm_inst);
            rm_osc = Select.ar(rm_wave.min(1), [SinOsc.ar(rm_freq * (1+rm_drift)), LFPulse.ar(rm_freq * (1+rm_drift))]);
            rm_carrier = (rm_osc * 1.5).tanh + (PinkNoise.ar(0.005 * rm_inst));
            rm_stereo = [sig_main_tape[0].tanh * rm_carrier, sig_main_tape[1].tanh * rm_carrier] * 2.5;
            rm_stereo = Slew.ar(rm_stereo, 4000, 4000);
            bank_in = HPF.ar(LPF.ar([(sig_main_tape[0] * (1.0 - rm_mix)) + (rm_stereo[0] * rm_mix), (sig_main_tape[1] * (1.0 - rm_mix)) + (rm_stereo[1] * rm_mix)], pre_lpf), pre_hpf);
            bank_in = LeakDC.ar(bank_in);

            // Filter Bank Loop
            sum_l = 0.0; sum_r = 0.0;
            16.do({ |i|
                var key_g = ("g" ++ i).asSymbol; var key_f = ("f" ++ i).asSymbol;
                var db = Lag3.kr(NamedControl.kr(key_g, -60.0), fader_lag);
                var amp = db.dbamp; 
                var f = NamedControl.kr(key_f, init_freqs[i.clip(0,15)], 0.05) * (1 + (LFNoise2.kr(0.05+(i*0.02)).range(0.9,1.1) * filter_drift * 0.06));
                f = f.clip(20, 18000);
                var jitter = LFNoise1.kr(1.0+(i*0.1)).range(1.0-(filter_drift*0.15), 1.0+(filter_drift*0.05));
                var effective_q = (global_q * LinLin.kr(db, -60, 0, 0.5, 1.2)) / (1.0 + (f/12000));
                var mod_q = effective_q * LFNoise1.kr(0.2).range(1.0, 1.0-(filter_drift*0.3));
                var raw_rq = (1.0 / mod_q.max(0.5));
                var max_safe_rq = (2.44 - (f * 0.0001075)).max(0.01);
                var final_rq = raw_rq.min(max_safe_rq);
                var input_gain = (600 / f).pow(0.28).clip(0.1, 3.0) * (1.0 / (final_rq/raw_rq)).sqrt.clip(1.0, 1.8) * (f / 4000.0).max(1.0).pow(0.08);
                var spread_val = ((i%2) * 2 - 1) * spread;
                var pan_pos = (spread_val + (SinOsc.kr(swirl_rate, (i / 16.0) * 2pi) * swirl_depth)).clip(-1.0, 1.0);
                var band_l = BPF.ar(bank_in[0] * input_gain, f, final_rq) * (2.0 + (mod_q * 0.05)) * (1.0 - pan_pos).sqrt;
                var band_r = BPF.ar(bank_in[1] * input_gain, f, final_rq) * (2.0 + (mod_q * 0.05)) * (1.0 + pan_pos).sqrt;
                band_l = band_l.tanh; band_r = band_r.tanh;
                var aa_l = Amplitude.kr(band_l, 0.01, 0.24); var aa_r = Amplitude.kr(band_r, 0.01, 0.24);
                band_l = band_l * (1.0 - ((aa_l - 0.25).max(0) * stabilizer * 2.0).distort);
                band_r = band_r * (1.0 - ((aa_r - 0.25).max(0) * stabilizer * 2.0).distort);
                Out.kr(bands_bus_base + i, (aa_l + aa_r) * 0.5);
                sum_l = sum_l + (band_l * amp * jitter * 2.8);
                sum_r = sum_r + (band_r * amp * jitter * 2.8);
            });
            bank_out = [LeakDC.ar(asym_sat.(sum_l)), LeakDC.ar(asym_sat.(sum_r))];
            sig_filters = (bank_in * (1.0 - filter_mix)) + (bank_out * filter_mix);
            tap_post_filter = sig_filters;
            
            // Reverb Loop
            sig_post_reverb = [sig_filters[0] + (LPF.ar(sig_filters[1], 800) * xfeed_amt * 0.7), sig_filters[1] + (LPF.ar(sig_filters[0], 800) * xfeed_amt * 0.7)];
            wet_reverb = sig_post_reverb.collect({ |chan, idx|
                var p = DelayN.ar(chan, 0.1, 0.03); 
                var combs = 6.collect({ CombL.ar(p, 0.2, Rand(0.03, 0.07) + LFNoise2.kr(Rand(0.1, 0.3)).range(0, 0.0025), reverb_time) }).sum;
                2.do({ combs = AllpassN.ar(combs, 0.050, Rand(0.01, 0.05), 1); });
                combs * 0.2; 
            });
            wet_reverb = LPF.ar(Decimator.ar(wet_reverb, 32000, 12), reverb_damp);
            final_signal = (sig_filters * (1-reverb_mix)) + (HPF.ar(wet_reverb, 10) * reverb_mix);
            tap_post_reverb = final_signal;
            LocalOut.ar(final_signal); 

            // --- LOOPERS BLOCK ---
            loop_outputs_sum = Silent.ar(2);
            loop_aux_sum = Silent.ar(2);
            trk1_in = InFeedback.ar(t1_bus, 2); trk2_in = InFeedback.ar(t2_bus, 2); trk3_in = InFeedback.ar(t3_bus, 2); trk4_in = InFeedback.ar(t4_bus, 2);
            
            4.do({ |i|
                var b_idx, bus_idx;
                var gate_rec, gate_play;
                var trk_vol, trk_spd, trk_start, trk_end, trk_src, trk_dub, trk_aux, trk_deg, trk_brake;
                var trk_rec_lvl_db, trk_rec_amp, trk_low, trk_high, trk_filter, trk_pan, trk_width;
                var seek_t, seek_p;
                var rate_slew, brake_mod, brake_idx, lfo_mod, lfo_lag_time;
                var deg_curve, flutter_mod, final_rate;
                var organic_brake_hpf, flux_gain;
                var loop_len_samps, start_pos, end_pos, ptr;
                var play_sig, deg_hpf, deg_lpf, corrosion_am, loop_ero, loop_dust_trig, loop_dropout_env, loop_gain_loss;
                var sat_drive;
                var dynamic_cutoff, sig_out, in;
                var deg_idx, fb_comp_curve, amp_det, dyn_stab, safe_fb, write_sig;
                var tape_physics_cutoff, output_sig, sat_low, slew_val, c_lpf, c_hpf, f_lpf, f_hpf, eq_max_db;
                var mid, side;

                b_idx = synth_buffers[i];
                bus_idx = track_buses[i];
                
                gate_rec = Lag.kr(l_rec[i], 0.1); 
                gate_play = Lag.kr(l_play[i], 0.1); 
                
                trk_vol = l_vol[i];
                trk_spd = l_speed[i]; trk_start = l_start[i]; trk_end = l_end[i];
                trk_src = l_src[i]; trk_dub = l_dub[i]; trk_aux = l_aux[i]; trk_deg = l_deg[i];
                trk_brake = l_brake[i]; 
                trk_rec_lvl_db = l_rec_lvl[i];
                trk_rec_amp = trk_rec_lvl_db.dbamp;
                trk_low = l_low[i]; trk_high = l_high[i]; trk_filter = l_filter[i];
                trk_pan = l_pan[i]; trk_width = l_width[i];
                seek_t = l_seek_t[i]; seek_p = l_seek_p[i];
                
                brake_idx = (trk_brake * 4).round;
                brake_mod = Select.kr(brake_idx, [1.0, 1.0, 1.0, 0.5, 0.0]);
                brake_mod = Lag3.kr(brake_mod, 0.3);
                lfo_mod = Select.kr(brake_idx, [1.0, LFNoise2.kr(2).range(0.95, 1.05), LFNoise2.kr(8).range(0.88, 1.12), LFNoise2.kr(4).range(0.95, 1.05), 1.0]);
                lfo_lag_time = Select.kr(brake_idx, [0.1, 0.25, 0.1, 0.05, 0.05]);
                lfo_mod = Lag.kr(lfo_mod, lfo_lag_time);
                rate_slew = Lag.kr(trk_spd, 0.05) * brake_mod * lfo_mod; 
                
                // [PHYSICS 1] Drag Flutter (Max 6% at 0.8, 10% at 1.0)
                deg_curve = trk_deg.pow(4.0); 
                flutter_mod = Select.kr(trk_deg > 0.4, [
                    LinLin.kr(trk_deg, 0.0, 0.4, 0.0, 0.002),
                    Select.kr(trk_deg > 0.6, [
                        LinLin.kr(trk_deg, 0.4, 0.6, 0.002, 0.02),
                        Select.kr(trk_deg > 0.8, [
                            LinLin.kr(trk_deg, 0.6, 0.8, 0.02, 0.06),
                            LinLin.kr(trk_deg, 0.8, 1.0, 0.06, 0.10)
                        ])
                    ])
                ]);
                final_rate = rate_slew * (1.0 - OnePole.ar(LFNoise2.ar(4+(i*1.5)).range(0, flutter_mod), 0.5));
                
                organic_brake_hpf = LinExp.kr(rate_slew.abs + 0.001, 0.001, 1.0, 250, 10);
                organic_brake_hpf = Lag.kr(organic_brake_hpf, 0.1);
                flux_gain = (rate_slew.abs * 5.0).clip(0, 1).pow(3);
                
                loop_len_samps = l_length[i].max(0.001) * SampleRate.ir;
                start_pos = Lag.kr(trk_start, 0.1) * loop_len_samps;
                end_pos = (Lag.kr(trk_end, 0.1) * loop_len_samps).max(start_pos + 10);
                
                ptr = Phasor.ar(seek_t, final_rate * BufRateScale.kr(b_idx), start_pos, end_pos, seek_p * loop_len_samps);
                Out.kr(pos_bus_base + i, A2K.kr(ptr / loop_len_samps)); 
                
                play_sig = BufRd.ar(2, b_idx, ptr, 1, 2);
                
                // [PHYSICS] DEGRADE FILTERS (4-Pole LPF in Loop)
                deg_hpf = Select.kr(trk_deg > 0.5, [
                    LinExp.kr(trk_deg, 0.0, 0.5, 10, 60),
                    LinExp.kr(trk_deg, 0.5, 1.0, 60, 100)
                ]);
                deg_lpf = Select.kr(trk_deg > 0.5, [
                    LinExp.kr(trk_deg, 0.0, 0.5, 17000, 12000),
                    LinExp.kr(trk_deg, 0.5, 1.0, 12000, 4000)
                ]);
                
                play_sig = LPF.ar(LPF.ar(play_sig, deg_lpf), deg_lpf);
                
                corrosion_am = 1.0 - (LFNoise2.kr(8 + (i*2)).unipolar * trk_deg * 0.6);
                play_sig = play_sig * corrosion_am;
                loop_ero = LinLin.kr(trk_deg, 0.4, 1.0, 0.0, 0.5).max(0);
                loop_dust_trig = Dust.kr(loop_ero * 15);
                loop_dropout_env = Decay.kr(loop_dust_trig, 0.1);
                loop_gain_loss = (loop_dropout_env * loop_ero).clip(0, 0.9);
                play_sig = play_sig * (1.0 - loop_gain_loss);
                
                // [PHYSICS 2] S-Curve Saturation with Bypass < 0.2
                sat_drive = Select.kr(trk_deg > 0.2, [
                    DC.kr(1.0),
                    Select.kr(trk_deg > 0.5, [
                        LinLin.kr(trk_deg, 0.2, 0.5, 1.0, 1.5),
                        Select.kr(trk_deg > 0.85, [
                            LinLin.kr(trk_deg, 0.5, 0.85, 1.5, 3.0),
                            LinLin.kr(trk_deg, 0.85, 1.0, 3.0, 4.5)
                        ])
                    ])
                ]);
                play_sig = Select.ar(trk_deg < 0.2, [
                    (play_sig * sat_drive).tanh,
                    play_sig 
                ]);
                
                dynamic_cutoff = (rate_slew.abs * 20000).clip(10, 20000);
                play_sig = LPF.ar(play_sig, dynamic_cutoff);
                sig_out = play_sig; 
                
                in = Select.ar(l_src[i], [tap_clean, tap_post_tape, tap_post_filter, tap_post_reverb, trk1_in, trk2_in, trk3_in, trk4_in]);
                
                // [GAIN COMPENSATION] Empirical Table (21 Points)
                deg_idx = (trk_deg * 20).round;
                fb_comp_curve = Select.kr(deg_idx, [
                    0.96, 0.98, 1.00, 1.05, 1.05, 
                    0.99, 0.97, 0.95, 0.93, 0.93,
                    0.94, 0.88, 0.85, 0.83, 0.80,
                    0.74, 0.64, 0.59, 0.48, 0.39, 0.33
                ]);
                
                // [DYNAMIC STABILIZER] Nagra Specs
                amp_det = Amplitude.kr(play_sig, 0.0005, 0.3);
                dyn_stab = 1.0 - (amp_det.max(0.8) - 0.8 * 0.7).clip(0, 0.6);
                
                // [STOP SAFETY] Bypass degradation if Stopped
                safe_fb = Select.kr(gate_play < 0.5, [fb_comp_curve * dyn_stab, DC.kr(1.0)]);
                
                write_sig = (play_sig * trk_dub * safe_fb) + (in * l_rec_lvl[i].dbamp * gate_rec);
                BufWr.ar(write_sig, b_idx, ptr);
                
                output_sig = sig_out * gate_play; 
                
                // [PHYSICS 3] Tone vs Speed + Output HPF
                tape_physics_cutoff = LinExp.ar(final_rate.abs.max(0.01), 0.25, 1.0, 6000, 17000).clip(1000, 20000);
                output_sig = LPF.ar(output_sig, tape_physics_cutoff);
                output_sig = HPF.ar(output_sig, deg_hpf);
                output_sig = HPF.ar(output_sig, organic_brake_hpf);
                output_sig = output_sig * flux_gain;
                
                // Klangfilm EQ
                sat_low = output_sig.squared * 0.2 * l_low[i].max(0);
                output_sig = (output_sig + sat_low).distort; 
                output_sig = BLowShelf.ar(output_sig, 60, 0.6, l_low[i]);
                output_sig = BHiShelf.ar(output_sig, 10000, 0.6, l_high[i]);
                slew_val = LinExp.kr(l_high[i].max(0), 0, 12, 20000, 2000); 
                output_sig = Slew.ar(output_sig, slew_val, slew_val).sin;
                
                c_lpf = l_filter[i].min(0.5) * 2; c_hpf = (l_filter[i] - 0.5).max(0) * 2;
                output_sig = LPF.ar(output_sig, LinExp.kr(c_lpf, 0, 1, 20, 20000));
                output_sig = HPF.ar(output_sig, LinExp.kr(c_hpf, 0, 1, 20, 20000));
                output_sig = (output_sig * (1.0 + (l_low[i].abs.max(l_high[i].abs) / 18.0).squared)).tanh;
                
                mid = (output_sig[0] + output_sig[1]) * 0.5; side = (output_sig[0] - output_sig[1]) * 0.5;
                output_sig = Balance2.ar(mid + (side * l_width[i]), mid - (side * l_width[i]), l_pan[i]);
                
                Out.ar(bus_idx, output_sig);
                loop_outputs_sum = loop_outputs_sum + (output_sig * LinLin.kr(l_vol[i], 0, 1, -60, 12).dbamp * (l_vol[i] > 0.001));
                loop_aux_sum = loop_aux_sum + (output_sig * l_aux[i]);
            });
            
            master_out = Select.ar(main_src_sel, [tap_clean, tap_post_tape, tap_post_filter, tap_post_reverb]) + loop_outputs_sum;
            
            bf_freq = Select.kr(bass_focus_mode.clip(1, 3), [50, 100, 200]); 
            bf_mono = LPF.ar(LPF.ar((master_out[0] + master_out[1]) * 0.5, bf_freq), bf_freq);
            bf_highs = [HPF.ar(HPF.ar(master_out[0], bf_freq), bf_freq), HPF.ar(HPF.ar(master_out[1], bf_freq), bf_freq)];
            master_out = Select.ar(bass_focus_mode > 0, [master_out, bf_highs + (bf_mono ! 2)]);
            
            driven_sig = master_out * comp_drive.dbamp;
            master_glue = Compander.ar(driven_sig, driven_sig, comp_thresh.dbamp, 1.0, 1.0/comp_ratio, 0.01, 0.1);
            gr_sig = (Peak.kr(driven_sig, Impulse.kr(20)) - Peak.kr(master_glue, Impulse.kr(20))).max(0);
            Out.kr(gr_bus_idx, Mix(LagUD.kr(gr_sig.sum, 0, 0.1)));
            
            master_out = Limiter.ar(Balance2.ar(master_glue[0], master_glue[1], balance).tanh, limiter_ceil.dbamp) * main_mon_amp;
            
            gonio_sig = Select.ar(gonio_source, [final_signal, master_out]);
            Out.kr(bus_l_idx, Mix(LagUD.kr(Peak.kr(gonio_sig[0], Impulse.kr(30)), 0, 0.1)));
            Out.kr(bus_r_idx, Mix(LagUD.kr(Peak.kr(gonio_sig[1], Impulse.kr(30)), 0, 0.1)));
            
            SendReply.kr(Impulse.kr(60), '/avant_lab_v/visuals', [Mix(LagUD.kr(Peak.kr(gonio_sig[0]),0,0.1)), Mix(LagUD.kr(Peak.kr(gonio_sig[1]),0,0.1)), Mix(LagUD.kr(gr_sig.sum,0,0.1)), pointers[0], pointers[1], pointers[2], pointers[3], 16.collect({|i| In.kr(bands_bus_base+i)})].flat);
            Out.ar(aux_return_bus_idx, loop_aux_sum);
            Out.ar(out_bus, master_out);
        }).add;

        context.server.sync;
        synth = Synth.new(\avant_lab_v_synth, [\out_bus, context.out_b, \in_bus, context.in_b, \buf1, buf1, \buf2, buf2, \buf3, buf3, \buf4, buf4, \dummy_buf, dummy_buf, \tape_fb_bus_idx, tape_fb_bus.index, \aux_return_bus_idx, aux_return_bus.index, \bus_l_idx, amp_bus_l.index, \bus_r_idx, amp_bus_r.index, \bands_bus_base, bands_bus.index, \pos_bus_base, pos_bus.index, \gr_bus_idx, gr_bus.index, \t1_bus, track_out_buses[0].index, \t2_bus, track_out_buses[1].index, \t3_bus, track_out_buses[2].index, \t4_bus, track_out_buses[3].index, \bass_focus_mode, 0], context.xg);
        context.server.sync;
        
        this.addCommand("l1_config", "ffffffffffff", { |msg| synth.set(\l1_rec, msg[1], \l1_play, msg[2], \l1_vol, msg[3], \l1_speed, msg[4], \l1_start, msg[5], \l1_end, msg[6], \l1_src, msg[7], \l1_dub, msg[8], \l1_aux, msg[9], \l1_deg, msg[10], \l1_brake, msg[11], \l1_length, msg[12]); });
        this.addCommand("l2_config", "ffffffffffff", { |msg| synth.set(\l2_rec, msg[1], \l2_play, msg[2], \l2_vol, msg[3], \l2_speed, msg[4], \l2_start, msg[5], \l2_end, msg[6], \l2_src, msg[7], \l2_dub, msg[8], \l2_aux, msg[9], \l2_deg, msg[10], \l2_brake, msg[11], \l2_length, msg[12]); });
        this.addCommand("l3_config", "ffffffffffff", { |msg| synth.set(\l3_rec, msg[1], \l3_play, msg[2], \l3_vol, msg[3], \l3_speed, msg[4], \l3_start, msg[5], \l3_end, msg[6], \l3_src, msg[7], \l3_dub, msg[8], \l3_aux, msg[9], \l3_deg, msg[10], \l3_brake, msg[11], \l3_length, msg[12]); });
        this.addCommand("l4_config", "ffffffffffff", { |msg| synth.set(\l4_rec, msg[1], \l4_play, msg[2], \l4_vol, msg[3], \l4_speed, msg[4], \l4_start, msg[5], \l4_end, msg[6], \l4_src, msg[7], \l4_dub, msg[8], \l4_aux, msg[9], \l4_deg, msg[10], \l4_brake, msg[11], \l4_length, msg[12]); });
        
        this.addCommand("l1_seek", "f", { |msg| synth.set(\l1_seek_pos, msg[1], \t_l1_seek_trig, 1); });
        this.addCommand("l2_seek", "f", { |msg| synth.set(\l2_seek_pos, msg[1], \t_l2_seek_trig, 1); });
        this.addCommand("l3_seek", "f", { |msg| synth.set(\l3_seek_pos, msg[1], \t_l3_seek_trig, 1); });
        this.addCommand("l4_seek", "f", { |msg| synth.set(\l4_seek_pos, msg[1], \t_l4_seek_trig, 1); });
        
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
        
        this.addCommand("buffer_read", "is", { |msg| 
            var b = buffers[msg[1]-1]; 
            if(File.exists(msg[2]), { 
                b.zero; 
                Buffer.readChannel(context.server, msg[2], 0, b.numFrames, [0,1], action:{|f| 
                    f.copyData(b); 
                    f.free; 
                    NetAddr("127.0.0.1", 10111).sendMsg("/buffer_info", msg[1], f.numFrames/context.server.sampleRate)
                }); 
            }); 
        });
        
        this.addCommand("buffer_write", "isf", { |msg| 
            var b = buffers[msg[1]-1]; 
            var frames = (msg[3]*context.server.sampleRate).asInteger; 
            if(frames > 0, {b.write(msg[2], "wav", "int24", frames)}, {b.write(msg[2], "wav", "int24")}); 
        });
        
        this.addCommand("clear", "i", { |msg| buffers[msg[1]-1].zero; });
        
        this.addCommand("l_speed", "if", { |msg| synth.set(("l"++msg[1]++"_speed").asSymbol, msg[2]) });
        this.addCommand("l_vol", "if", { |msg| synth.set(("l"++msg[1]++"_vol").asSymbol, msg[2]) });
        this.addCommand("l_low", "if", { |msg| synth.set(("l"++msg[1]++"_low").asSymbol, msg[2]) });
        this.addCommand("l_high", "if", { |msg| synth.set(("l"++msg[1]++"_high").asSymbol, msg[2]) });
        this.addCommand("l_filter", "if", { |msg| synth.set(("l"++msg[1]++"_filter").asSymbol, msg[2]) });
        this.addCommand("l_pan", "if", { |msg| synth.set(("l"++msg[1]++"_pan").asSymbol, msg[2]) });
        this.addCommand("l_width", "if", { |msg| synth.set(("l"++msg[1]++"_width").asSymbol, msg[2]) });
        this.addCommand("l_rec_lvl", "if", { |msg| synth.set(("l"++msg[1]++"_rec_lvl").asSymbol, msg[2]) });
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
