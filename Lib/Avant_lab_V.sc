// Engine_Avant_lab_V.sc | Version 95.2
// FIX: Main Monitor Range Expanded (-60dB to +12dB)

Engine_Avant_lab_V : CroneEngine {
    var <synth;
    var <amp_bus_l, <amp_bus_r, <bands_bus, <tape_fb_bus, <aux_return_bus, <pos_bus;
    var <track_out_buses; 
    var <buf1, <buf2, <buf3, <buf4;
    var <dummy_buf;
    var <osc_bridge, <norns_addr;

    alloc {
        var buffers;

        buf1 = Buffer.alloc(context.server, context.server.sampleRate * 60.0, 2);
        buf2 = Buffer.alloc(context.server, context.server.sampleRate * 60.0, 2);
        buf3 = Buffer.alloc(context.server, context.server.sampleRate * 60.0, 2);
        buf4 = Buffer.alloc(context.server, context.server.sampleRate * 60.0, 2);
        dummy_buf = Buffer.alloc(context.server, 44100, 2);
        
        buffers = [buf1, buf2, buf3, buf4];

        amp_bus_l = Bus.control(context.server);
        amp_bus_r = Bus.control(context.server);
        bands_bus = Bus.control(context.server, 16);
        pos_bus = Bus.control(context.server, 4);
        
        tape_fb_bus = Bus.audio(context.server, 2);
        aux_return_bus = Bus.audio(context.server, 2);
        
        track_out_buses = { Bus.audio(context.server, 2) } ! 4;

        norns_addr = NetAddr("127.0.0.1", 10111);

        SynthDef(\avant_lab_v_synth, {
            |out_bus=0, in_bus=0, buf1=0, buf2=0, buf3=0, buf4=0, dummy_buf=0,
             tape_fb_bus_idx=0, aux_return_bus_idx=0, bus_l_idx=0, bus_r_idx=0, bands_bus_base=0, pos_bus_base=0,
             t1_bus=0, t2_bus=0, t3_bus=0, t4_bus=0,
             gonio_source=1|

            // --- GLOBAL VARIABLES ---
            var noise, input, source, local, input_sum, ping, ping_env; 
            var fb_amt=\fb_amt.kr(0), global_q=\global_q.kr(1), xfeed_amt=\xfeed_amt.kr(0), reverb_mix=\reverb_mix.kr(1);
            var input_amp=\input_amp.kr(1), noise_amp=\noise_amp.kr(0), noise_type=\noise_type.kr(0);
            var ping_active=\ping_active.kr(0), ping_mode=\ping_mode.kr(0), ping_amp=\ping_amp.kr(0), ping_timbre=\ping_timbre.kr(0), ping_jitter=\ping_jitter.kr(0), ping_rate=\ping_rate.kr(1);
            var t_seq=\t_seq.tr(0), t_manual=\t_manual.tr(0);
            var rm_freq=\rm_freq.kr(100), rm_wave=\rm_wave.kr(0), rm_mix=\rm_mix.kr(0), rm_inst=\rm_instability.kr(0), rm_drive=\rm_drive.kr(0);
            
            var raw_pre_hpf=\pre_hpf.kr(20);
            var raw_pre_lpf=\pre_lpf.kr(20000);
            var pre_hpf, pre_lpf; 
            
            var stabilizer=\stabilizer.kr(0), spread=\spread.kr(0), filter_mix=\filter_mix.kr(1), fader_lag=\fader_lag.kr(0.05);
            var lfo_depth=\lfo_depth.kr(0), lfo_rate=\lfo_rate.kr(0.1), lfo_min_db=\lfo_min_db.kr(-60);
            var tm_mix=\tape_mix.kr(1), tm_time=\tape_time.kr(0), tm_fb=\tape_fb.kr(0), tm_sat=\tape_sat.kr(0), tm_wow=\tape_wow.kr(0), tm_flut=\tape_flutter.kr(0), tm_ero=\tape_erosion.kr(0);
            
            var system_dirt=\system_dirt.kr(0);
            var filter_drift=\filter_drift.kr(0);
            var main_mon=\main_mon.kr(0.833); // Default approx 0dB
            
            var l_rec = [\l1_rec.kr(0), \l2_rec.kr(0), \l3_rec.kr(0), \l4_rec.kr(0)];
            var l_play = [\l1_play.kr(0), \l2_play.kr(0), \l3_play.kr(0), \l4_play.kr(0)];
            var l_vol = [\l1_vol.kr(0), \l2_vol.kr(0), \l3_vol.kr(0), \l4_vol.kr(0)];
            var l_speed = [\l1_speed.kr(1), \l2_speed.kr(1), \l3_speed.kr(1), \l4_speed.kr(1)];
            var l_start = [\l1_start.kr(0), \l2_start.kr(0), \l3_start.kr(0), \l4_start.kr(0)];
            var l_end = [\l1_end.kr(1), \l2_end.kr(1), \l3_end.kr(1), \l4_end.kr(1)];
            var l_src = [\l1_src.kr(0), \l2_src.kr(0), \l3_src.kr(0), \l4_src.kr(0)];
            var l_dub = [\l1_dub.kr(0.5), \l2_dub.kr(0.5), \l3_dub.kr(0.5), \l4_dub.kr(0.5)];
            var l_aux = [\l1_aux.kr(0), \l2_aux.kr(0), \l3_aux.kr(0), \l4_aux.kr(0)];
            var l_deg = [\l1_deg.kr(0), \l2_deg.kr(0), \l3_deg.kr(0), \l4_deg.kr(0)];
            var l_xfade = [\l1_xfade.kr(0.05), \l2_xfade.kr(0.05), \l3_xfade.kr(0.05), \l4_xfade.kr(0.05)];
            var l_brake = [\l1_brake.kr(0), \l2_brake.kr(0), \l3_brake.kr(0), \l4_brake.kr(0)];
            
            var l_low = [\l1_low.kr(0), \l2_low.kr(0), \l3_low.kr(0), \l4_low.kr(0)];
            var l_high = [\l1_high.kr(0), \l2_high.kr(0), \l3_high.kr(0), \l4_high.kr(0)];
            var l_filter = [\l1_filter.kr(0.5), \l2_filter.kr(0.5), \l3_filter.kr(0.5), \l4_filter.kr(0.5)];
            var l_pan = [\l1_pan.kr(0), \l2_pan.kr(0), \l3_pan.kr(0), \l4_pan.kr(0)];
            var l_width = [\l1_width.kr(1), \l2_width.kr(1), \l3_width.kr(1), \l4_width.kr(1)];
            
            var l_seek_t = [\l1_seek_t.tr(0), \l2_seek_t.tr(0), \l3_seek_t.tr(0), \l4_seek_t.tr(0)];
            var l_seek_p = [\l1_seek_p.kr(0), \l2_seek_p.kr(0), \l3_seek_p.kr(0), \l4_seek_p.kr(0)];
            
            var synth_buffers = [buf1, buf2, buf3, buf4];
            var track_buses = [t1_bus, t2_bus, t3_bus, t4_bus];
            var init_freqs = [50, 75, 110, 150, 220, 350, 500, 750, 1100, 1600, 2200, 3600, 5200, 7500, 11000, 15000];
            
            var trig_int_sig, trig_seq_sig, trig_man_sig, auto_trig, master_trig;
            var tape_proc, tape_out, bank_in, bank_out, rm_drift, rm_osc, rm_carrier, rm_processed_l, rm_processed_r;
            var sig_main_tape, sig_filters, sig_post_reverb, wet_reverb, final_signal;
            var aux_feedback_in, loop_outputs_sum, loop_aux_sum;
            var tap_clean, tap_post_tape, tap_post_filter, tap_post_reverb;
            var dirt_sig, hiss_vol, hum_vol, dust_dens, dust_sig, dust_vol;
            var master_out, gonio_sig;
            var main_mon_amp; // New variable for expanded gain
            
            var trk1_in = InFeedback.ar(t1_bus, 2);
            var trk2_in = InFeedback.ar(t2_bus, 2);
            var trk3_in = InFeedback.ar(t3_bus, 2);
            var trk4_in = InFeedback.ar(t4_bus, 2);

            // --- AUDIO GRAPH ---
            
            pre_hpf = Lag.kr(raw_pre_hpf, 0.1);
            pre_lpf = Lag.kr(raw_pre_lpf, 0.1);
            
            aux_feedback_in = InFeedback.ar(aux_return_bus_idx, 2).tanh; 
            noise = Select.ar(noise_type, [PinkNoise.ar, WhiteNoise.ar]) * noise_amp * 0.6;
            
            hiss_vol = (system_dirt.squared) * 0.15;
            hum_vol = (system_dirt.pow(5)) * 0.015;
            dust_dens = LinLin.kr(system_dirt, 0.18, 1.0, 0.1, 15);
            dust_sig = Decay2.ar(Dust.ar(dust_dens), 0.001, 0.01) * PinkNoise.ar(1);
            dust_vol = LinLin.kr(system_dirt, 0.18, 1.0, 0.1, 0.6);
            dust_sig = dust_sig * dust_vol * (system_dirt > 0.18);
            dirt_sig = (PinkNoise.ar(hiss_vol) + SinOsc.ar(50, 0, hum_vol) + dust_sig).dup;
            
            input = In.ar(in_bus, 2) * input_amp;
            
            trig_int_sig = Impulse.ar(ping_rate * (1 + (LFNoise2.kr(ping_rate) * ping_jitter * 1.5)).clip(0.1, 40)) * ping_active;
            trig_seq_sig = Trig1.ar(K2A.ar(t_seq), SampleDur.ir);
            trig_man_sig = Trig1.ar(K2A.ar(t_manual), SampleDur.ir);
            auto_trig = Select.ar(ping_mode, [trig_int_sig, trig_seq_sig]);
            master_trig = auto_trig + trig_man_sig;
            SendReply.ar(master_trig, "/ping_pulse", [ping_amp], 1234);
            ping_env = Decay2.ar(master_trig, 0.001, 0.2);
            ping = SelectX.ar(ping_timbre, [LPF.ar(BrownNoise.ar, 200), PinkNoise.ar]) * ping_env * ping_amp;
            
            source = input + noise.dup + ping.dup + aux_feedback_in;
            local = LocalIn.ar(2); 
            input_sum = source + (local * fb_amt);
            tap_clean = input_sum;
            
            input_sum = input_sum + dirt_sig;
            
            tape_proc = input_sum + (InFeedback.ar(tape_fb_bus_idx, 2) * tm_fb);
            tape_out = tape_proc.collect({ |chan|
                 var speed_t = 1.0; 
                 var ms = LagUD.kr(speed_t, 1.0, 0.5);
                 var rate = (ms + (LFNoise2.kr(Rand(0.5, 2.0)) * tm_wow * 0.01) + (LFNoise1.kr(15) * tm_flut * 0.001)).clip(0.1, 2.0);
                 var dt = (Lag.kr(tm_time, 0.5) + 0.01) / rate;
                 var sig = DelayC.ar(chan, 6.0, dt.clip(0, 6.0));
                 var eh = (LinLin.kr(tm_ero, 0, 1, 20000, 6000) * ms).clip(100, 20000);
                 var el = LinLin.kr(tm_ero, 0, 1, 10, 400);
                 sig = LPF.ar(sig, eh); sig = HPF.ar(sig, el);
                 (sig * (1 + (tm_sat * 2))).tanh
            });
            Out.ar(tape_fb_bus_idx, Limiter.ar(tape_out, 0.95));
            sig_main_tape = (input_sum * (1.0 - tm_mix)) + (tape_out * tm_mix);
            tap_post_tape = sig_main_tape;
            
            rm_drift = (LFNoise2.kr(0.1) * 0.02 * rm_inst) + (LFNoise1.kr(10) * 0.005 * rm_inst);
            rm_osc = Select.ar(rm_wave, [SinOsc.ar(rm_freq * (1+rm_drift)), LFTri.ar(rm_freq * (1+rm_drift)), LFPulse.ar(rm_freq * (1+rm_drift)), LFSaw.ar(rm_freq * (1+rm_drift))]);
            rm_carrier = (rm_osc * 1.5).tanh + (PinkNoise.ar(0.005 * rm_inst));
            rm_processed_l = (sig_main_tape[0].tanh * rm_carrier);
            rm_processed_r = (sig_main_tape[1].tanh * rm_carrier);
            bank_in = [(sig_main_tape[0] * (1.0 - rm_mix)) + (rm_processed_l * rm_mix), (sig_main_tape[1] * (1.0 - rm_mix)) + (rm_processed_r * rm_mix)];
            bank_in = HPF.ar(bank_in, pre_hpf); bank_in = LPF.ar(bank_in, pre_lpf);

            bank_out = bank_in.collect({ |chan_sig, chan_idx| 
                var cmix = 0;
                16.do({ |i|
                    var key_g = ("g" ++ i).asSymbol; var key_f = ("f" ++ i).asSymbol;
                    var db = VarLag.kr(NamedControl.kr(key_g, -60.0), fader_lag, warp: \linear);
                    var amp = db.dbamp; 
                    
                    var f = NamedControl.kr(key_f, init_freqs[i.clip(0,15)], 0.05) * (1 + (LFNoise2.kr(0.05+(i*0.02)).range(0.9,1.1) * filter_drift * 0.06));
                    var jitter = LFNoise1.kr(1.0+(i*0.1)).range(1.0-(filter_drift*0.15), 1.0+(filter_drift*0.05));
                    
                    var effective_q = (global_q * LinLin.kr(db, -60, 0, 0.5, 1.2)) / (1.0 + (f/12000));
                    var rq = (1 / (effective_q * LFNoise2.kr(0.2).range(1.0, 1.0-(filter_drift*0.3)))).clip(0.005, 2.0);
                    var band;
                    var band_amp, gain_red;
                    
                    if(i == 0, { band = RLPF.ar(chan_sig, f, rq) }, {
                        if(i == 15, { band = RHPF.ar(chan_sig, f, rq) }, { band = BPF.ar(chan_sig, f, rq) * (2.0 + (effective_q*0.05)); })
                    });
                    
                    band_amp = Amplitude.kr(band, 0.01, 0.1);
                    gain_red = (1.0 - ((band_amp - 0.25).max(0) * stabilizer * 2.0)).clip(0.2, 1.0);
                    band = band * gain_red;

                    Out.kr(bands_bus_base + i, Amplitude.kr(band));
                    cmix = cmix + (band.tanh * amp * (1.0 - (abs(chan_idx - (i%2)) * spread)) * jitter * 2.8);
                });
                cmix;
            });
            sig_filters = (bank_in * (1.0 - filter_mix)) + (bank_out * filter_mix);
            tap_post_filter = sig_filters;
            
            sig_post_reverb = sig_filters; 
            wet_reverb = sig_filters.collect({ |chan, idx|
                var p = chan;
                8.do({ |i| p = AllpassC.ar(p, 0.2, 0.01 + (i*0.003), 1.5 + (idx*0.2)); });
                p;
            });
            final_signal = (sig_filters * (1-reverb_mix)) + (HPF.ar(wet_reverb, 10) * reverb_mix);
            tap_post_reverb = final_signal;

            // --- 3. LOOPERS ENGINE ---
            loop_outputs_sum = Silent.ar(2);
            loop_aux_sum = Silent.ar(2);
            4.do({ |i|
                var b_idx = synth_buffers[i];
                var bus_idx = track_buses[i];
                var gate_rec = l_rec[i]; var gate_play = l_play[i]; var trk_vol = l_vol[i];
                var trk_spd = l_speed[i]; var trk_start = l_start[i]; var trk_end = l_end[i];
                var trk_src = l_src[i]; var trk_dub = l_dub[i]; var trk_aux = l_aux[i]; var trk_deg = l_deg[i];
                var trk_xfade = l_xfade[i];
                var trk_brake = l_brake[i]; 
                
                var trk_low = l_low[i]; var trk_high = l_high[i]; var trk_filter = l_filter[i];
                var trk_pan = l_pan[i]; var trk_width = l_width[i];
                
                var seek_t = l_seek_t[i]; var seek_p = l_seek_p[i];
                var in, rate_slew, wob, ptr, play_sig, rec_sig, cutoff;
                var dynamic_cutoff, output_sig;
                var target_buf;
                var brake_mod, lfo_mod, brake_idx, lfo_lag_time; 
                var start_pos, end_pos, fade_len, dist_start, dist_end, fade_in, fade_out, xfade_gain;
                
                var c_lpf, c_hpf, f_lpf, f_hpf;
                var mid, side, new_l, new_r;
                
                var eq_max_db, sat_drive;
                
                target_buf = Select.kr(gate_rec > 0.1, [dummy_buf, b_idx]);
                
                in = Select.ar(trk_src, [
                    tap_clean, tap_post_tape, tap_post_filter, tap_post_reverb,
                    trk1_in, trk2_in, trk3_in, trk4_in
                ]);
                
                brake_idx = (trk_brake * 4).round;
                brake_mod = Select.kr(brake_idx, [1.0, 1.0, 1.0, 0.5, 0.0]);
                brake_mod = Lag.kr(brake_mod, 0.2);
                lfo_mod = Select.kr(brake_idx, [1.0, LFNoise2.kr(2).range(0.95, 1.05), LFNoise2.kr(8).range(0.88, 1.12), LFNoise2.kr(4).range(0.95, 1.05), 1.0]);
                
                lfo_lag_time = Select.kr(brake_idx, [0.1, 0.25, 0.1, 0.05, 0.05]);
                lfo_mod = Lag.kr(lfo_mod, lfo_lag_time);
                
                rate_slew = Lag.kr(trk_spd, 0.05) * brake_mod * lfo_mod; 
                wob = LFNoise2.kr(0.3+(i*0.1)).range(1.0-(trk_deg*0.04), 1.0+(trk_deg*0.04));
                
                ptr = Phasor.ar(seek_t, rate_slew * wob * BufRateScale.kr(b_idx), 
                                trk_start * BufFrames.kr(b_idx), trk_end * BufFrames.kr(b_idx),
                                seek_p * BufFrames.kr(b_idx));
                
                start_pos = trk_start * BufFrames.kr(b_idx);
                end_pos = trk_end * BufFrames.kr(b_idx);
                fade_len = trk_xfade * SampleRate.ir;
                dist_start = (ptr - start_pos).abs; dist_end = (end_pos - ptr).abs;
                fade_in = (dist_start / fade_len).clip(0, 1); fade_out = (dist_end / fade_len).clip(0, 1);
                xfade_gain = (fade_in.min(fade_out) * 0.5 * pi).sin;
                
                Out.kr(pos_bus_base + i, ptr / BufFrames.kr(b_idx));
                
                play_sig = BufRd.ar(2, b_idx, ptr, 1, 4);
                play_sig = play_sig * xfade_gain;
                
                dynamic_cutoff = (rate_slew.abs * 20000).clip(10, 20000);
                play_sig = LPF.ar(LPF.ar(play_sig, dynamic_cutoff), dynamic_cutoff);
                
                cutoff = LinLin.kr(trk_deg, 0, 1, 20000, 2500);
                play_sig = LPF.ar(play_sig, cutoff);
                
                rec_sig = in + (play_sig * trk_dub);
                rec_sig = LPF.ar(rec_sig, dynamic_cutoff);
                
                BufWr.ar(rec_sig.tanh, target_buf, ptr);
                
                output_sig = play_sig * gate_play.lag(0.05);
                
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
            
            LocalOut.ar(final_signal);
            
            // [FIX] MAIN MONITOR EXPANSION
            // Convert 0-1 input to -60dB to +12dB, then to linear amplitude
            main_mon_amp = LinLin.kr(main_mon, 0, 1, -60, 12).dbamp * (main_mon > 0.001);
            
            master_out = Limiter.ar((final_signal * main_mon_amp) + loop_outputs_sum, 0.95);
            
            Out.ar(aux_return_bus_idx, loop_aux_sum);
            Out.ar(out_bus, master_out);
            
            gonio_sig = Select.ar(gonio_source, [final_signal, master_out]);
            
            Out.kr(bus_l_idx, Amplitude.kr(gonio_sig[0]));
            Out.kr(bus_r_idx, Amplitude.kr(gonio_sig[1]));
        }).add;

        context.server.sync;
        synth = Synth.new(\avant_lab_v_synth, [
            \out_bus, context.out_b, \in_bus, context.in_b,
            \buf1, buf1, \buf2, buf2, \buf3, buf3, \buf4, buf4, \dummy_buf, dummy_buf,
            \tape_fb_bus_idx, tape_fb_bus.index, \aux_return_bus_idx, aux_return_bus.index,
            \bus_l_idx, amp_bus_l.index, \bus_r_idx, amp_bus_r.index,
            \bands_bus_base, bands_bus.index, \pos_bus_base, pos_bus.index,
            \t1_bus, track_out_buses[0].index, \t2_bus, track_out_buses[1].index,
            \t3_bus, track_out_buses[2].index, \t4_bus, track_out_buses[3].index
        ], context.xg);

        this.addPoll("amp_l", { amp_bus_l.getSynchronous });
        this.addPoll("amp_r", { amp_bus_r.getSynchronous });
        16.do({ |i| this.addPoll(("b" ++ i).asString, { context.server.getControlBusValue(bands_bus.index + i) }); });
        4.do({ |i| this.addPoll(("pos" ++ (i+1)).asString, { context.server.getControlBusValue(pos_bus.index + i) }); });

        this.addCommand("buffer_read", "is", { |msg|
            var bufnum = buffers[msg[1]-1];
            if(File.exists(msg[2]), {
                bufnum.zero;
                Buffer.readChannel(context.server, msg[2], 0, bufnum.numFrames, [0, 1], action: { |b|
                    var dur = b.numFrames / context.server.sampleRate;
                    b.copyData(bufnum);
                    b.free;
                    norns_addr.sendMsg("/buffer_info", msg[1], dur);
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
        this.addCommand("pre_hpf", "f", { |msg| synth.set(\pre_hpf, msg[1]); });
        this.addCommand("pre_lpf", "f", { |msg| synth.set(\pre_lpf, msg[1]); });
        this.addCommand("stabilizer", "f", { |msg| synth.set(\stabilizer, msg[1]); });
        this.addCommand("spread", "f", { |msg| synth.set(\spread, msg[1]); });
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
    }

    free {
        osc_bridge.free; synth.free;
        amp_bus_l.free; amp_bus_r.free; bands_bus.free;
        tape_fb_bus.free; aux_return_bus.free; pos_bus.free;
        track_out_buses.do(_.free);
        buf1.free; buf2.free; buf3.free; buf4.free; dummy_buf.free;
    }
}
