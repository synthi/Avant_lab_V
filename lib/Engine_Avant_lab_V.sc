// lib/Engine_Avant_lab_V.sc | Version 1.80
// RELEASE v1.80:
// 1. VISUAL FIX: Fixed "Vanishing Pointer" during Overdub.
//    Logic updated to distinguish First Pass (Rec=1, Play=0) from Overdub (Rec=1, Play=1).
//    Overdub now correctly sends positive position pointers instead of negative time.
// 2. REPORTING: "Negative Pointer" Strategy maintained for First Pass.
// 3. TUNING: fb_comp_curve starts at 1.00.

Engine_Avant_lab_V : CroneEngine {
    var <synth_voice, <synth_loopers;
    var <buf1, <buf2, <buf3, <buf4;
    var <dummy_buf;
    
    // Internal Bridge Buses
    var <b_core, <b_aux, <b_analysis; 
    
    // External Control/Audio Buses
    var <amp_bus_l, <amp_bus_r, <bands_bus, <pos_bus, <gr_bus;
    var <tape_fb_bus, <aux_return_bus;
    var <track_out_buses;
    
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

        // 2. BUS ALLOCATION (EXTERNAL)
        amp_bus_l = Bus.control(context.server);
        amp_bus_r = Bus.control(context.server);
        bands_bus = Bus.control(context.server, 16);
        pos_bus = Bus.control(context.server, 4);
        gr_bus = Bus.control(context.server); 
        
        tape_fb_bus = Bus.audio(context.server, 2);
        aux_return_bus = Bus.audio(context.server, 2);
        
        track_out_buses = { Bus.audio(context.server, 2) } ! 4;

        // 3. BUS ALLOCATION (INTERNAL BRIDGE)
        b_core = Bus.audio(context.server, 8); // 4 stereo pairs
        b_aux = Bus.audio(context.server, 2);  // Aux return
        b_analysis = Bus.control(context.server, 16); // Spectral data

        context.server.sync;

        // 4. OSC BRIDGE
        osc_bridge = OSCFunc({ |msg|
            NetAddr("127.0.0.1", 10111).sendMsg("/avant_lab_v/visuals", *msg.drop(3));
        }, '/avant_lab_v/visuals', context.server.addr).fix;

        // -----------------------------------------------------------
        // SYNTH 1: AVANT_VOICE (Generator, FX, FilterBank)
        // -----------------------------------------------------------
        SynthDef(\Avant_Voice, {
            |in_bus=0, bus_core_out=0, bus_aux_in=0, bus_analysis_out=0,
             tape_fb_bus_idx=0,
             fb_amt=0, global_q=1, xfeed_amt=0, 
             reverb_mix=1, reverb_time=1.5, reverb_damp=10000,
             input_amp=1, noise_amp=0, noise_type=0,
             ping_active=0, ping_mode=0, ping_amp=0, ping_timbre=0, ping_jitter=0, ping_rate=1,
             t_seq=0, t_manual=0,
             rm_freq=100, rm_wave=0, rm_mix=0, rm_instability=0, rm_drive=0,
             pre_hpf=20, pre_lpf=20000, stabilizer=0, spread=0, swirl_depth=0, swirl_rate=0.1, 
             filter_mix=1, fader_lag=0.05, filter_drift=0,
             lfo_depth=0, lfo_rate=0.1, lfo_min_db= -60,
             tape_mix=1, tape_time=0, tape_fb=0, tape_sat=0, tape_wow=0, tape_flutter=0, tape_erosion=0,
             system_dirt=0|

            // --- VARS ---
            var input, noise, ping, source, local, input_sum, tap_clean;
            var noise_L, noise_R;
            var hiss_vol, hum_vol, dust_dens, dust_vol, dust_sig, dirt_sig;
            var trig_int_sig, trig_seq_sig, trig_man_sig, auto_trig, master_trig, ping_env;
            var aux_feedback_in;
            var shared_wow, shared_flutter, shared_mod, shared_dust_trig, shared_dropout_env;
            var tape_proc, tape_out, sig_main_tape, tap_post_tape;
            var rm_drift, rm_osc, rm_carrier, rm_stereo;
            var bank_in, bank_out, sig_filters, tap_post_filter;
            var sum_l, sum_r;
            var sig_post_reverb, wet_reverb, final_signal, tap_post_reverb;
            var init_freqs = [50, 75, 110, 150, 220, 350, 500, 750, 1100, 1600, 2200, 3600, 5200, 7500, 11000, 15000];
            var asym_sat = { |sig| (sig + 0.2).tanh - 0.2 };
            var pre_hpf_lag, pre_lpf_lag;

            // --- DSP ---
            pre_hpf_lag = Lag.kr(pre_hpf, 0.1);
            pre_lpf_lag = Lag.kr(pre_lpf, 0.1);
            
            aux_feedback_in = InFeedback.ar(bus_aux_in, 2).tanh;

            // Noise
            noise_L = Select.ar(noise_type, [PinkNoise.ar, WhiteNoise.ar*0.5, Crackle.ar(1.9), Latch.ar(WhiteNoise.ar, Dust.ar(LFNoise1.kr(0.3).exprange(5, 50)))*0.4, LFNoise1.ar(500)*0.7, Dust2.ar(LFNoise1.kr(0.3).exprange(300, 2000))*0.9]);
            noise_R = Select.ar(noise_type, [PinkNoise.ar, WhiteNoise.ar*0.5, Crackle.ar(1.9), Latch.ar(WhiteNoise.ar, Dust.ar(LFNoise1.kr(0.3).exprange(5, 50)))*0.4, LFNoise1.ar(500)*0.7, Dust2.ar(LFNoise1.kr(0.3).exprange(300, 2000))*0.9]);
            noise = [noise_L, noise_R] * noise_amp * 0.6;
            noise = LeakDC.ar(noise).tanh;

            // Dirt
            hiss_vol = (system_dirt.pow(0.75)) * 0.03;
            hum_vol = (system_dirt.pow(3)) * 0.015;
            dust_dens = LinLin.kr(system_dirt, 0.11, 1.0, 0.05, 11);
            dust_vol = LinExp.kr(system_dirt, 0.11, 1.0, 0.01, 0.5);
            dust_sig = [Decay2.ar(Dust.ar(dust_dens), 0.001, 0.01)*PinkNoise.ar(1), Decay2.ar(Dust.ar(dust_dens), 0.001, 0.01)*PinkNoise.ar(1)] * dust_vol * (system_dirt > 0.11);
            dirt_sig = ([PinkNoise.ar(hiss_vol), PinkNoise.ar(hiss_vol)] + [SinOsc.ar(50, 0, hum_vol), SinOsc.ar(50, 0, hum_vol)] + dust_sig) * 0.5;

            // Input
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
            input_sum = source + (local * fb_amt * 0.6); 
            tap_clean = input_sum;
            input_sum = LeakDC.ar(input_sum + dirt_sig);

            // Tape Echo
            shared_wow = OnePole.kr(LFNoise2.kr(Rand(0.5, 2.0)) * tape_wow * 0.005, 0.95);
            shared_flutter = LFNoise1.kr(15) * tape_flutter * 0.0005;
            shared_mod = shared_wow + shared_flutter;
            shared_dust_trig = Dust.kr(tape_erosion * 15);
            shared_dropout_env = Decay.kr(shared_dust_trig, 0.1);
            
            tape_proc = input_sum + (HPF.ar(InFeedback.ar(tape_fb_bus_idx, 2), 40) * tape_fb); 
            
            tape_out = tape_proc.collect({ |chan|
                 var dt = (Lag.kr(tape_time, 0.5) + 0.01 + shared_mod).clip(0, 2.0);
                 var sig = DelayC.ar(chan, 2.0, dt);
                 var head_bump = BPeakEQ.ar(sig, 100, 1.0, tape_sat * 3.0);
                 var drive = 1.0 + (tape_sat * 3.0);
                 var comp_gain = 1.0 / (1.0 + (tape_sat * 1.8));
                 sig = (asym_sat.(head_bump * drive) * comp_gain);
                 sig = LeakDC.ar(sig);
                 sig = LPF.ar(sig, LinExp.kr(1.0 - tape_erosion, 0.001, 1.0, 9000, 20000));
                 sig = HPF.ar(sig, LinExp.kr(tape_erosion, 0.001, 1.0, 110, 110));
                 sig * (1.0 - (shared_dropout_env * tape_erosion).clip(0, 0.9));
            });
            
            Out.ar(tape_fb_bus_idx, Limiter.ar(tape_out, 0.95));
            
            sig_main_tape = (input_sum * (1.0 - tape_mix)) + (tape_out * tape_mix);
            tap_post_tape = sig_main_tape;

            // Ring Mod
            rm_drift = (LFNoise2.kr(0.1) * 0.02 * rm_instability) + (LFNoise1.kr(10) * 0.005 * rm_instability);
            rm_osc = Select.ar(rm_wave.min(1), [SinOsc.ar(rm_freq * (1+rm_drift)), LFPulse.ar(rm_freq * (1+rm_drift))]);
            rm_carrier = (rm_osc * 1.5).tanh + (PinkNoise.ar(0.005 * rm_instability));
            rm_stereo = [sig_main_tape[0].tanh * rm_carrier, sig_main_tape[1].tanh * rm_carrier] * 2.5;
            rm_stereo = Slew.ar(rm_stereo, 4000, 4000);
            bank_in = HPF.ar(LPF.ar([(sig_main_tape[0] * (1.0 - rm_mix)) + (rm_stereo[0] * rm_mix), (sig_main_tape[1] * (1.0 - rm_mix)) + (rm_stereo[1] * rm_mix)], pre_lpf_lag), pre_hpf_lag);
            bank_in = LeakDC.ar(bank_in);

            // Filter Bank
            sum_l = 0.0; sum_r = 0.0;
            16.do({ |i|
                var key_g = ("g" ++ i).asSymbol; var key_f = ("f" ++ i).asSymbol;
                var db = Lag3.kr(NamedControl.kr(key_g, -60.0), fader_lag);
                var amp = db.dbamp;
                var f = NamedControl.kr(key_f, init_freqs[i.clip(0,15)], 0.05) * (1 + (LFNoise2.kr(0.05+(i*0.02)).range(0.9,1.1) * filter_drift * 0.06));
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
                var aa_l, aa_r;
                
                band_l = band_l.tanh; band_r = band_r.tanh;
                aa_l = Amplitude.kr(band_l, 0.01, 0.24); aa_r = Amplitude.kr(band_r, 0.01, 0.24);
                band_l = band_l * (1.0 - ((aa_l - 0.25).max(0) * stabilizer * 2.0).distort);
                band_r = band_r * (1.0 - ((aa_r - 0.25).max(0) * stabilizer * 2.0).distort);
                
                Out.kr(bus_analysis_out + i, (aa_l + aa_r) * 0.5);
                
                sum_l = sum_l + (band_l * amp * jitter * 2.8);
                sum_r = sum_r + (band_r * amp * jitter * 2.8);
            });
            bank_out = [LeakDC.ar(asym_sat.(sum_l)), LeakDC.ar(asym_sat.(sum_r))];
            sig_filters = (bank_in * (1.0 - filter_mix)) + (bank_out * filter_mix);
            tap_post_filter = sig_filters;

            // Reverb
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

            // Output to Core Bus (8 channels)
            Out.ar(bus_core_out, [tap_clean[0], tap_clean[1], tap_post_tape[0], tap_post_tape[1], tap_post_filter[0], tap_post_filter[1], tap_post_reverb[0], tap_post_reverb[1]]);
        }).add;

        // -----------------------------------------------------------
        // SYNTH 2: AVANT_LOOPERS (Tape Decks, Master, Visuals)
        // -----------------------------------------------------------
        SynthDef(\Avant_Loopers, {
            |out_bus=0, bus_core_in=0, bus_aux_out=0, bus_analysis_in=0,
             buf1=0, buf2=0, buf3=0, buf4=0,
             t1_bus=0, t2_bus=0, t3_bus=0, t4_bus=0,
             main_src_sel=3, main_mon=0.833,
             comp_thresh=0.5, comp_ratio=2.0, comp_drive=0.0,
             bass_focus_mode=0, limiter_ceil=0.0, balance=0.0,
             gonio_source=1,
             // Track Params
             l1_rec=0, l1_play=0, l1_vol=0, l1_speed=1, l1_start=0, l1_end=1, l1_src=0, l1_dub=0.5, l1_aux=0, l1_deg=0, l1_brake=0, l1_rec_lvl=0, l1_length=60, l1_seek_pos=0, t_l1_seek_trig=0,
             l2_rec=0, l2_play=0, l2_vol=0, l2_speed=1, l2_start=0, l2_end=1, l2_src=0, l2_dub=0.5, l2_aux=0, l2_deg=0, l2_brake=0, l2_rec_lvl=0, l2_length=60, l2_seek_pos=0, t_l2_seek_trig=0,
             l3_rec=0, l3_play=0, l3_vol=0, l3_speed=1, l3_start=0, l3_end=1, l3_src=0, l3_dub=0.5, l3_aux=0, l3_deg=0, l3_brake=0, l3_rec_lvl=0, l3_length=60, l3_seek_pos=0, t_l3_seek_trig=0,
             l4_rec=0, l4_play=0, l4_vol=0, l4_speed=1, l4_start=0, l4_end=1, l4_src=0, l4_dub=0.5, l4_aux=0, l4_deg=0, l4_brake=0, l4_rec_lvl=0, l4_length=60, l4_seek_pos=0, t_l4_seek_trig=0,
             l1_low=0, l1_high=0, l1_filter=0.5, l1_pan=0, l1_width=1,
             l2_low=0, l2_high=0, l2_filter=0.5, l2_pan=0, l2_width=1,
             l3_low=0, l3_high=0, l3_filter=0.5, l3_pan=0, l3_width=1,
             l4_low=0, l4_high=0, l4_filter=0.5, l4_pan=0, l4_width=1|

            // --- VARS ---
            var core_in, tap_clean, tap_post_tape, tap_post_filter, tap_post_reverb;
            var loop_outputs_sum, loop_aux_sum;
            var synth_buffers, track_buses;
            var l_rec_arr, l_play_arr, l_vol_arr, l_speed_arr, l_start_arr, l_end_arr, l_src_arr, l_dub_arr, l_aux_arr, l_deg_arr, l_brake_arr, l_rec_lvl_arr, l_length_arr, l_seek_p_arr, l_seek_t_arr;
            var l_low_arr, l_high_arr, l_filter_arr, l_pan_arr, l_width_arr;
            var pointers = Array.fill(4, { DC.kr(0) });
            var master_out, monitor_signal, main_mon_amp;
            var bf_freq, bf_mono, bf_highs;
            var driven_sig, master_glue, gr_sig;
            var gonio_sig, bands_read;
            var trig_visuals;
            var trk1_in, trk2_in, trk3_in, trk4_in;

            // --- DSP ---
            core_in = In.ar(bus_core_in, 8);
            tap_clean = [core_in[0], core_in[1]];
            tap_post_tape = [core_in[2], core_in[3]];
            tap_post_filter = [core_in[4], core_in[5]];
            tap_post_reverb = [core_in[6], core_in[7]];

            loop_outputs_sum = Silent.ar(2);
            loop_aux_sum = Silent.ar(2);
            
            synth_buffers = [buf1, buf2, buf3, buf4];
            track_buses = [t1_bus, t2_bus, t3_bus, t4_bus];
            
            // Track Inputs (Feedback from other tracks)
            trk1_in = InFeedback.ar(t1_bus, 2); 
            trk2_in = InFeedback.ar(t2_bus, 2); 
            trk3_in = InFeedback.ar(t3_bus, 2); 
            trk4_in = InFeedback.ar(t4_bus, 2);
            
            l_rec_arr = [l1_rec, l2_rec, l3_rec, l4_rec]; l_play_arr = [l1_play, l2_play, l3_play, l4_play];
            l_vol_arr = [l1_vol, l2_vol, l3_vol, l4_vol]; l_speed_arr = [l1_speed, l2_speed, l3_speed, l4_speed];
            l_start_arr = [l1_start, l2_start, l3_start, l4_start]; l_end_arr = [l1_end, l2_end, l3_end, l4_end];
            l_src_arr = [l1_src, l2_src, l3_src, l4_src]; l_dub_arr = [l1_dub, l2_dub, l3_dub, l4_dub];
            l_aux_arr = [l1_aux, l2_aux, l3_aux, l4_aux]; l_deg_arr = [l1_deg, l2_deg, l3_deg, l4_deg];
            l_brake_arr = [l1_brake, l2_brake, l3_brake, l4_brake]; l_rec_lvl_arr = [l1_rec_lvl, l2_rec_lvl, l3_rec_lvl, l4_rec_lvl];
            l_length_arr = [l1_length, l2_length, l3_length, l4_length]; l_seek_p_arr = [l1_seek_pos, l2_seek_pos, l3_seek_pos, l4_seek_pos];
            l_seek_t_arr = [t_l1_seek_trig, t_l2_seek_trig, t_l3_seek_trig, t_l4_seek_trig];
            l_low_arr = [l1_low, l2_low, l3_low, l4_low]; l_high_arr = [l1_high, l2_high, l3_high, l4_high];
            l_filter_arr = [l1_filter, l2_filter, l3_filter, l4_filter]; l_pan_arr = [l1_pan, l2_pan, l3_pan, l4_pan];
            l_width_arr = [l1_width, l2_width, l3_width, l4_width];

            4.do({ |i|
                var b_idx, bus_idx;
                var gate_rec, gate_play;
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
                var gate_ar, rec_timer, is_first_pass, ptr_norm, neg_time;
                var gate_play_ar; // [v1.80] Added variable for Audio Rate Play Gate

                b_idx = synth_buffers[i];
                bus_idx = track_buses[i];

                gate_rec = Lag.kr(l_rec_arr[i], 0.1); 
                gate_play = Lag.kr(l_play_arr[i], 0.1); 

                brake_idx = (l_brake_arr[i] * 4).round;
                brake_mod = Select.kr(brake_idx, [1.0, 1.0, 1.0, 0.5, 0.0]);
                brake_mod = Lag3.kr(brake_mod, 0.3);
                lfo_mod = Select.kr(brake_idx, [1.0, LFNoise2.kr(2).range(0.95, 1.05), LFNoise2.kr(8).range(0.88, 1.12), LFNoise2.kr(4).range(0.95, 1.05), 1.0]);
                lfo_lag_time = Select.kr(brake_idx, [0.1, 0.25, 0.1, 0.05, 0.05]);
                lfo_mod = Lag.kr(lfo_mod, lfo_lag_time);
                rate_slew = Lag.kr(l_speed_arr[i], 0.05) * brake_mod * lfo_mod; 
                
                // [PHYSICS 1] Drag Flutter
                deg_curve = l_deg_arr[i].pow(4.0); 
                flutter_mod = Select.kr(l_deg_arr[i] > 0.4, [
                    LinLin.kr(l_deg_arr[i], 0.0, 0.4, 0.0, 0.002),
                    Select.kr(l_deg_arr[i] > 0.6, [
                        LinLin.kr(l_deg_arr[i], 0.4, 0.6, 0.002, 0.02),
                        Select.kr(l_deg_arr[i] > 0.8, [
                            LinLin.kr(l_deg_arr[i], 0.6, 0.8, 0.02, 0.06),
                            LinLin.kr(l_deg_arr[i], 0.8, 1.0, 0.06, 0.10)
                        ])
                    ])
                ]);
                final_rate = rate_slew * (1.0 - OnePole.ar(LFNoise2.ar(4+(i*1.5)).range(0, flutter_mod), 0.5));
                
                organic_brake_hpf = LinExp.kr(rate_slew.abs + 0.001, 0.001, 1.0, 250, 10);
                organic_brake_hpf = Lag.kr(organic_brake_hpf, 0.1);
                flux_gain = (rate_slew.abs * 5.0).clip(0, 1).pow(3);
                
                loop_len_samps = l_length_arr[i].max(0.001) * SampleRate.ir;
                start_pos = Lag.kr(l_start_arr[i], 0.1) * loop_len_samps;
                end_pos = (Lag.kr(l_end_arr[i], 0.1) * loop_len_samps).max(start_pos + 10);
                
                // [PHASOR CALCULATION]
                ptr = Phasor.ar(l_seek_t_arr[i], final_rate * BufRateScale.kr(b_idx), start_pos, end_pos, l_seek_p_arr[i] * loop_len_samps);
                
                // [REPORTING v1.80] "Negative Pointer" Strategy with Overdub Fix
                // 1. Convert Control Gates to Audio Rate for logic
                gate_ar = K2A.ar(l_rec_arr[i]);
                gate_play_ar = K2A.ar(l_play_arr[i]); // [v1.80] Added
                
                // 2. Measure duration (resets on start, counts seconds)
                rec_timer = Sweep.ar(gate_ar, gate_ar);
                
                // 3. Determine if we are in "First Pass" (Create Mode)
                // [v1.80 FIX]: First Pass = Recording (1) AND NOT Playing (0).
                // This prevents Overdub (Rec=1, Play=1) from triggering the negative pointer.
                is_first_pass = (gate_ar > 0.5) * (gate_play_ar < 0.5);
                
                // 4. Select what to send to Lua via 'pointers'
                ptr_norm = A2K.kr(ptr / loop_len_samps);
                neg_time = A2K.kr(rec_timer.neg);
                
                pointers[i] = Select.kr(A2K.kr(is_first_pass), [ptr_norm, neg_time]);
                
                play_sig = BufRd.ar(2, b_idx, ptr, 1, 2);
                
                // [PHYSICS] DEGRADE FILTERS
                deg_lpf = Select.kr(l_deg_arr[i] > 0.5, [
                    LinExp.kr(l_deg_arr[i], 0.0, 0.5, 17000, 12000),
                    LinExp.kr(l_deg_arr[i], 0.5, 1.0, 12000, 4000)
                ]);
                play_sig = LPF.ar(LPF.ar(play_sig, deg_lpf), deg_lpf);
                
                corrosion_am = 1.0 - (LFNoise2.kr(8 + (i*2)).unipolar * l_deg_arr[i] * 0.6);
                play_sig = play_sig * corrosion_am;
                loop_ero = LinLin.kr(l_deg_arr[i], 0.4, 1.0, 0.0, 0.5).max(0);
                loop_dust_trig = Dust.kr(loop_ero * 15);
                loop_dropout_env = Decay.kr(loop_dust_trig, 0.1);
                loop_gain_loss = (loop_dropout_env * loop_ero).clip(0, 0.9);
                play_sig = play_sig * (1.0 - loop_gain_loss);
                
                // [PHYSICS 2] S-Curve Saturation
                sat_drive = Select.kr(l_deg_arr[i] > 0.2, [
                    DC.kr(1.0),
                    Select.kr(l_deg_arr[i] > 0.5, [
                        LinLin.kr(l_deg_arr[i], 0.2, 0.5, 1.0, 1.5),
                        Select.kr(l_deg_arr[i] > 0.85, [
                            LinLin.kr(l_deg_arr[i], 0.5, 0.85, 1.5, 3.0),
                            LinLin.kr(l_deg_arr[i], 0.85, 1.0, 3.0, 4.5)
                        ])
                    ])
                ]);
                play_sig = Select.ar(l_deg_arr[i] < 0.2, [
                    (play_sig * sat_drive).tanh,
                    play_sig 
                ]);
                
                dynamic_cutoff = (rate_slew.abs * 20000).clip(10, 20000);
                play_sig = LPF.ar(play_sig, dynamic_cutoff);
                
                sig_out = play_sig; 
                in = Select.ar(l_src_arr[i], [tap_clean, tap_post_tape, tap_post_filter, tap_post_reverb, trk1_in, trk2_in, trk3_in, trk4_in]);
                
                // [GAIN COMPENSATION]
                deg_idx = (l_deg_arr[i] * 20).round;
                // [v1.80] Updated table: First 3 values are 1.00 for Unity Gain
                fb_comp_curve = Select.kr(deg_idx, [
                    1.00, 1.00, 1.00, 1.05, 1.05, 
                    0.99, 0.97, 0.95, 0.93, 0.93,
                    0.94, 0.88, 0.85, 0.83, 0.80,
                    0.74, 0.64, 0.59, 0.48, 0.39, 0.33
                ]);
                
                // [DYNAMIC STABILIZER]
                amp_det = Amplitude.kr(play_sig, 0.0005, 0.3);
                dyn_stab = 1.0 - (amp_det.max(0.8) - 0.8 * 0.7).clip(0, 0.6);
                
                // [STOP SAFETY]
                safe_fb = Select.kr(gate_play < 0.5, [fb_comp_curve * dyn_stab, DC.kr(1.0)]);
                
                write_sig = (play_sig * l_dub_arr[i] * safe_fb) + (in * l_rec_lvl_arr[i].dbamp * gate_rec);
                BufWr.ar(write_sig, b_idx, ptr);
                
                output_sig = sig_out * gate_play; 
                
                // [PHYSICS 3] Tone vs Speed
                tape_physics_cutoff = LinExp.ar(final_rate.abs.max(0.01), 0.25, 1.0, 6000, 17000).clip(1000, 20000);
                output_sig = LPF.ar(output_sig, tape_physics_cutoff);
                
                deg_hpf = Select.kr(l_deg_arr[i] > 0.5, [
                    LinExp.kr(l_deg_arr[i], 0.0, 0.5, 10, 60),
                    LinExp.kr(l_deg_arr[i], 0.5, 1.0, 60, 100)
                ]);
                output_sig = HPF.ar(output_sig, deg_hpf);
                
                output_sig = HPF.ar(output_sig, organic_brake_hpf);
                output_sig = output_sig * flux_gain;
                
                // Klangfilm EQ
                sat_low = output_sig.squared * 0.2 * l_low_arr[i].max(0);
                output_sig = (output_sig + sat_low).distort; 
                output_sig = BLowShelf.ar(output_sig, 60, 0.6, l_low_arr[i]);
                output_sig = BHiShelf.ar(output_sig, 10000, 0.6, l_high_arr[i]);
                slew_val = LinExp.kr(l_high_arr[i].max(0), 0, 12, 20000, 2000); 
                output_sig = Slew.ar(output_sig, slew_val, slew_val).sin;
                
                c_lpf = l_filter_arr[i].min(0.5) * 2; c_hpf = (l_filter_arr[i] - 0.5).max(0) * 2;
                output_sig = LPF.ar(output_sig, LinExp.kr(c_lpf, 0, 1, 20, 20000));
                output_sig = HPF.ar(output_sig, LinExp.kr(c_hpf, 0, 1, 20, 20000));
                output_sig = (output_sig * (1.0 + (l_low_arr[i].abs.max(l_high_arr[i].abs) / 18.0).squared)).tanh;
                
                mid = (output_sig[0] + output_sig[1]) * 0.5; side = (output_sig[0] - output_sig[1]) * 0.5;
                output_sig = Balance2.ar(mid + (side * l_width_arr[i]), mid - (side * l_width_arr[i]), l_pan_arr[i]);
                
                Out.ar(bus_idx, output_sig);
                loop_outputs_sum = loop_outputs_sum + (output_sig * LinLin.kr(l_vol_arr[i], 0, 1, -60, 12).dbamp * (l_vol_arr[i] > 0.001));
                loop_aux_sum = loop_aux_sum + (output_sig * l_aux_arr[i]);
            });
            
            Out.ar(bus_aux_out, loop_aux_sum);

            monitor_signal = Select.ar(main_src_sel, [tap_clean, tap_post_tape, tap_post_filter, tap_post_reverb]);
            master_out = monitor_signal + loop_outputs_sum;
            
            main_mon_amp = LinLin.kr(main_mon, 0, 1, -60, 12).dbamp * (main_mon > 0.001);

            // Bass Focus
            bf_freq = Select.kr(bass_focus_mode.clip(1, 3), [50, 100, 200]); 
            bf_mono = LPF.ar(LPF.ar((master_out[0] + master_out[1]) * 0.5, bf_freq), bf_freq);
            bf_highs = [HPF.ar(HPF.ar(master_out[0], bf_freq), bf_freq), HPF.ar(HPF.ar(master_out[1], bf_freq), bf_freq)];
            master_out = Select.ar(bass_focus_mode > 0, [master_out, bf_highs + (bf_mono ! 2)]);
            
            driven_sig = master_out * comp_drive.dbamp;
            master_glue = Compander.ar(driven_sig, driven_sig, comp_thresh.dbamp, 1.0, 1.0/comp_ratio, 0.01, 0.1);
            gr_sig = (Peak.kr(driven_sig, Impulse.kr(20)) - Peak.kr(master_glue, Impulse.kr(20))).max(0);
            
            master_out = Limiter.ar(Balance2.ar(master_glue[0], master_glue[1], balance).tanh, limiter_ceil.dbamp) * main_mon_amp;
            
            // [FIX v1.4] Correct variable name for Gonio
            gonio_sig = Select.ar(gonio_source, [tap_post_reverb, master_out]);
            
            // Visuals
            bands_read = 16.collect({ |i| In.kr(bus_analysis_in + i) });
            trig_visuals = Impulse.kr(60);
            SendReply.kr(trig_visuals, '/avant_lab_v/visuals', [
                Mix(LagUD.kr(Peak.kr(gonio_sig[0], Impulse.kr(30)), 0, 0.1)), 
                Mix(LagUD.kr(Peak.kr(gonio_sig[1], Impulse.kr(30)), 0, 0.1)), 
                Mix(LagUD.kr(gr_sig.sum, 0, 0.1)), 
                pointers[0], pointers[1], pointers[2], pointers[3], 
                bands_read
            ].flat);
            
            Out.ar(out_bus, master_out);
        }).add;

        context.server.sync;
        
        // INSTANTIATE SPLIT SYNTHS
        synth_voice = Synth.new(\Avant_Voice, [
            \in_bus, context.in_b,
            \out_bus, context.out_b,
            \bus_core_out, b_core.index,
            \bus_aux_in, b_aux.index,
            \bus_analysis_out, b_analysis.index,
            \tape_fb_bus_idx, tape_fb_bus.index
        ], context.xg, \addToHead);
        
        synth_loopers = Synth.new(\Avant_Loopers, [
            \out_bus, context.out_b,
            \bus_core_in, b_core.index,
            \bus_aux_out, b_aux.index,
            \bus_analysis_in, b_analysis.index,
            \buf1, buf1, \buf2, buf2, \buf3, buf3, \buf4, buf4,
            \t1_bus, track_out_buses[0].index, \t2_bus, track_out_buses[1].index,
            \t3_bus, track_out_buses[2].index, \t4_bus, track_out_buses[3].index
        ], context.xg, \addToTail);

        // COMMANDS MAPPING
        // Voice Commands
        this.addCommand("feedback", "f", { |msg| synth_voice.set(\fb_amt, msg[1]); });
        this.addCommand("global_q", "f", { |msg| synth_voice.set(\global_q, msg[1]); });
        this.addCommand("cross_feed", "f", { |msg| synth_voice.set(\xfeed_amt, msg[1]); });
        this.addCommand("input_amp", "f", { |msg| synth_voice.set(\input_amp, msg[1]); });
        this.addCommand("noise_amp", "f", { |msg| synth_voice.set(\noise_amp, msg[1]); });
        this.addCommand("noise_type", "f", { |msg| synth_voice.set(\noise_type, msg[1]); });
        this.addCommand("reverb_mix", "f", { |msg| synth_voice.set(\reverb_mix, msg[1]); });
        this.addCommand("reverb_time", "f", { |msg| synth_voice.set(\reverb_time, msg[1]); });
        this.addCommand("reverb_damp", "f", { |msg| synth_voice.set(\reverb_damp, msg[1]); });
        this.addCommand("pre_hpf", "f", { |msg| synth_voice.set(\pre_hpf, msg[1]); });
        this.addCommand("pre_lpf", "f", { |msg| synth_voice.set(\pre_lpf, msg[1]); });
        this.addCommand("stabilizer", "f", { |msg| synth_voice.set(\stabilizer, msg[1]); });
        this.addCommand("spread", "f", { |msg| synth_voice.set(\spread, msg[1]); });
        this.addCommand("swirl_depth", "f", { |msg| synth_voice.set(\swirl_depth, msg[1]); });
        this.addCommand("swirl_rate", "f", { |msg| synth_voice.set(\swirl_rate, msg[1]); });
        this.addCommand("filter_mix", "f", { |msg| synth_voice.set(\filter_mix, msg[1]); });
        this.addCommand("system_dirt", "f", { |msg| synth_voice.set(\system_dirt, msg[1]); });
        this.addCommand("filter_drift", "f", { |msg| synth_voice.set(\filter_drift, msg[1]); });
        this.addCommand("fader_lag", "f", { |msg| synth_voice.set(\fader_lag, msg[1]); });
        this.addCommand("lfo_depth", "f", { |msg| synth_voice.set(\lfo_depth, msg[1]); });
        this.addCommand("lfo_rate", "f", { |msg| synth_voice.set(\lfo_rate, msg[1]); });
        this.addCommand("lfo_min_db", "f", { |msg| synth_voice.set(\lfo_min_db, msg[1]); });
        this.addCommand("ping_sequence", "f", { |msg| synth_voice.set(\t_seq, 1); });
        this.addCommand("ping_manual", "f", { |msg| synth_voice.set(\t_manual, 1); });
        this.addCommand("ping_active", "f", { |msg| synth_voice.set(\ping_active, msg[1]); });
        this.addCommand("ping_mode", "f", { |msg| synth_voice.set(\ping_mode, msg[1]); }); 
        this.addCommand("ping_amp", "f", { |msg| synth_voice.set(\ping_amp, msg[1]); });
        this.addCommand("ping_rate", "f", { |msg| synth_voice.set(\ping_rate, msg[1]); }); 
        this.addCommand("ping_jitter", "f", { |msg| synth_voice.set(\ping_jitter, msg[1]); });
        this.addCommand("ping_timbre", "f", { |msg| synth_voice.set(\ping_timbre, msg[1]); });
        this.addCommand("rm_drive", "f", { |msg| synth_voice.set(\rm_drive, msg[1]); }); 
        this.addCommand("rm_freq", "f", { |msg| synth_voice.set(\rm_freq, msg[1]); });
        this.addCommand("rm_wave", "f", { |msg| synth_voice.set(\rm_wave, msg[1]); });
        this.addCommand("rm_mix", "f", { |msg| synth_voice.set(\rm_mix, msg[1]); });
        this.addCommand("rm_instability", "f", { |msg| synth_voice.set(\rm_instability, msg[1]); });
        this.addCommand("tape_sat", "f", { |msg| synth_voice.set(\tape_sat, msg[1]); });
        this.addCommand("tape_wow", "f", { |msg| synth_voice.set(\tape_wow, msg[1]); });
        this.addCommand("tape_flutter", "f", { |msg| synth_voice.set(\tape_flutter, msg[1]); });
        this.addCommand("tape_erosion", "f", { |msg| synth_voice.set(\tape_erosion, msg[1]); });
        this.addCommand("tape_time", "f", { |msg| synth_voice.set(\tape_time, msg[1]); });
        this.addCommand("tape_fb", "f", { |msg| synth_voice.set(\tape_fb, msg[1]); });
        this.addCommand("tape_brake", "f", { |msg| synth_voice.set(\tape_brake, msg[1]); });
        this.addCommand("tape_mix", "f", { |msg| synth_voice.set(\tape_mix, msg[1]); });
        this.addCommand("band_gain", "if", { |msg| synth_voice.set(("g" ++ msg[1]).asSymbol, msg[2]); });
        this.addCommand("band_freq", "if", { |msg| synth_voice.set(("f" ++ msg[1]).asSymbol, msg[2]); });

        // Looper Commands
        this.addCommand("l1_config", "ffffffffffff", { |msg| synth_loopers.set(\l1_rec, msg[1], \l1_play, msg[2], \l1_vol, msg[3], \l1_speed, msg[4], \l1_start, msg[5], \l1_end, msg[6], \l1_src, msg[7], \l1_dub, msg[8], \l1_aux, msg[9], \l1_deg, msg[10], \l1_brake, msg[11], \l1_length, msg[12]); });
        this.addCommand("l2_config", "ffffffffffff", { |msg| synth_loopers.set(\l2_rec, msg[1], \l2_play, msg[2], \l2_vol, msg[3], \l2_speed, msg[4], \l2_start, msg[5], \l2_end, msg[6], \l2_src, msg[7], \l2_dub, msg[8], \l2_aux, msg[9], \l2_deg, msg[10], \l2_brake, msg[11], \l2_length, msg[12]); });
        this.addCommand("l3_config", "ffffffffffff", { |msg| synth_loopers.set(\l3_rec, msg[1], \l3_play, msg[2], \l3_vol, msg[3], \l3_speed, msg[4], \l3_start, msg[5], \l3_end, msg[6], \l3_src, msg[7], \l3_dub, msg[8], \l3_aux, msg[9], \l3_deg, msg[10], \l3_brake, msg[11], \l3_length, msg[12]); });
        this.addCommand("l4_config", "ffffffffffff", { |msg| synth_loopers.set(\l4_rec, msg[1], \l4_play, msg[2], \l4_vol, msg[3], \l4_speed, msg[4], \l4_start, msg[5], \l4_end, msg[6], \l4_src, msg[7], \l4_dub, msg[8], \l4_aux, msg[9], \l4_deg, msg[10], \l4_brake, msg[11], \l4_length, msg[12]); });
        
        this.addCommand("l1_seek", "f", { |msg| synth_loopers.set(\l1_seek_pos, msg[1], \t_l1_seek_trig, 1); });
        this.addCommand("l2_seek", "f", { |msg| synth_loopers.set(\l2_seek_pos, msg[1], \t_l2_seek_trig, 1); });
        this.addCommand("l3_seek", "f", { |msg| synth_loopers.set(\l3_seek_pos, msg[1], \t_l3_seek_trig, 1); });
        this.addCommand("l4_seek", "f", { |msg| synth_loopers.set(\l4_seek_pos, msg[1], \t_l4_seek_trig, 1); });

        this.addCommand("l_speed", "if", { |msg| synth_loopers.set(("l" ++ msg[1] ++ "_speed").asSymbol, msg[2]); });
        this.addCommand("l_vol", "if", { |msg| synth_loopers.set(("l" ++ msg[1] ++ "_vol").asSymbol, msg[2]); });
        this.addCommand("l_low", "if", { |msg| synth_loopers.set(("l" ++ msg[1] ++ "_low").asSymbol, msg[2]); });
        this.addCommand("l_high", "if", { |msg| synth_loopers.set(("l" ++ msg[1] ++ "_high").asSymbol, msg[2]); });
        this.addCommand("l_filter", "if", { |msg| synth_loopers.set(("l" ++ msg[1] ++ "_filter").asSymbol, msg[2]); });
        this.addCommand("l_pan", "if", { |msg| synth_loopers.set(("l" ++ msg[1] ++ "_pan").asSymbol, msg[2]); });
        this.addCommand("l_width", "if", { |msg| synth_loopers.set(("l" ++ msg[1] ++ "_width").asSymbol, msg[2]); });
        this.addCommand("l_rec_lvl", "if", { |msg| synth_loopers.set(("l" ++ msg[1] ++ "_rec_lvl").asSymbol, msg[2]); });

        this.addCommand("main_mon", "f", { |msg| synth_loopers.set(\main_mon, msg[1]); });
        this.addCommand("gonio_source", "i", { |msg| synth_loopers.set(\gonio_source, msg[1]); });
        this.addCommand("main_source", "i", { |msg| synth_loopers.set(\main_src_sel, msg[1]); }); 
        this.addCommand("comp_thresh", "f", { |msg| synth_loopers.set(\comp_thresh, msg[1]); });
        this.addCommand("comp_ratio", "f", { |msg| synth_loopers.set(\comp_ratio, msg[1]); });
        this.addCommand("comp_drive", "f", { |msg| synth_loopers.set(\comp_drive, msg[1]); }); 
        this.addCommand("bass_focus", "i", { |msg| synth_loopers.set(\bass_focus_mode, msg[1]); });
        this.addCommand("limiter_ceil", "f", { |msg| synth_loopers.set(\limiter_ceil, msg[1]); });
        this.addCommand("balance", "f", { |msg| synth_loopers.set(\balance, msg[1]); });
        
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
        
        this.addCommand("clear", "i", { |msg| buffers[msg[1]-1].zero; });
    }

    free {
        osc_bridge.free; 
        synth_voice.free; 
        synth_loopers.free;
        amp_bus_l.free; amp_bus_r.free; bands_bus.free;
        tape_fb_bus.free; aux_return_bus.free; pos_bus.free;
        gr_bus.free; 
        track_out_buses.do(_.free);
        buf1.free; buf2.free; buf3.free; buf4.free; dummy_buf.free;
        b_core.free; b_aux.free; b_analysis.free;
    }
}
