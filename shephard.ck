/*
Shepard tone instrument for part2 fast-cut section

Controls:
    Gametrak avg (OR max) Z value controls gain

To initialize:
    init(out, midi_pitch, rate);
    activate();
    while (true) {gt_update(); ...}

Adapted from: https://chuck.stanford.edu/doc/examples/deep/shepard.ck


*/

public class Shepard extends Switchable {
    "Shepard" => this.NAME;

    // mean for normal intensity curve
    60 => float MU => float INITIAL_MU;
    // standard deviation for normal intensity curve
    42 => float SIGMA;
    // normalize to 1.0 at x==MU
    1 / Math.gauss(MU, MU, SIGMA) => float SCALE;
    // increment per unit time (use negative for descending)
    .004 => float INC;


    // starting pitches (in MIDI note numbers, octaves apart)
    [ 12.0, 24, 36, 48, 60, 72, 84, 96, 108 ] @=> float pitches[];
    // number of tones
    pitches.size() => int N;
    // bank of tones
    PulseOsc tones[N];

    // overall gain
    LPF lowpass => Gain shepard_gain => this.switch_gain; 
    20000 => lowpass.freq;
    1.0 / N => float SHEPARD_MAX_GAIN; 
    0 => shepard_gain.gain;

    // connect oscillators to gain
    for( int i; i < N; i++ ) { tones[i] => lowpass; }

    /*
        out: outlet UGen
        offset: shifts starting midi pitch to 60+offset
            - keep between [-12,+12]
        midi_pitch_center: mean frequency for gaussian gain distribution
    */
    fun void init(UGen @ out, int offset, int midi_pitch_center, float rate) {
        this.init(out);  // parent

        // update rate
        rate => this.INC;

        // update pitch center
        midi_pitch_center => this.MU => this.INITIAL_MU;

        // update scaling factor
        1 / Math.gauss(MU, MU, SIGMA) => this.SCALE;

        // update pitch array
        for (0 => int i; i < pitches.size(); i++)
            offset +=> pitches[i];
        
        // pwm square waves
        for (0 => int i; i < tones.size(); i++) {
            Math.random2f(1.0/8, 1.0/11) => float wf;  // pulse width mod rate
            Math.random2f(1.0/7, 1.0/5) => float lf;  // low pass cutoff mod rate
            spork ~ pwm(i, tones[i], lowpass, wf, lf);
        }

        // spork the player that applies gaussian to pitches
        spork ~ player();
        


        <<< "shepard initialized" >>>;

    }

    fun void pwm(int idx, PulseOsc @ p, LPF @ l, float wf, float lf) {
        .4 => float pwmDepth;
        400 => float fcBase;
        .85 => float fcDepth;
        while (true) {
            // mod pulse width
            // if (idx % 2 == 0) {  // only do every other, too expensive
                .5 + pwmDepth * Util.lfo(wf) => p.width;
            // }

            // mod filter cutoff
            // fcBase + (fcDepth * fcBase) * Util.lfo(lf) => l.freq;

            10::ms => now;
        }
    }

    fun void player() {
        while( true )
        {
            for( int i; i < N; i++ )
            {
                // set frequency from pitch
                pitches[i] => Std.mtof => tones[i].freq;
                // compute loundess for each tone
                Math.gauss( pitches[i], MU, SIGMA ) * SCALE => float intensity;
                // map intensity to amplitude
                intensity*96 => Math.dbtorms => tones[i].gain;
                // increment pitch
                INC +=> pitches[i];
                // wrap (for positive INC)
                if( pitches[i] > 120 ) 108 -=> pitches[i];
                // wrap (for negative INC)
                else if( pitches[i] < 12 ) 108 +=> pitches[i];
            }
            
            // advance time
            2::ms => now;
        }
    }

    .5 => float Z_MAX;
    fun void gt_update(GameTrack @ gt) {
        // <<< "shepard gt update" >>>;
        // gt.GetAvgZ() => float z; 
        gt.GetMaxZ() => float z;

        if (z < gt.Z_DEADZONE) {
            return;
        }

        // calculate as percentage of maximum
        Util.invLerp01(gt.Z_DEADZONE, Z_MAX, z) => float z_perc;  // range [0,1]

        // lerp gain between [0, 1.0/tones.size()]
        Util.lerp(0, SHEPARD_MAX_GAIN, z_perc) => this.shepard_gain.gain;

        // map z axis to pitch center MU
        if (this.INC > 0) {  // for incrementers: MU increases 60 --> 80
            Util.lerp(this.INITIAL_MU, 84, z_perc) => this.MU;
        } else if (this.INC < 0) {  // for bass: MU decreases --> 24
            Util.lerp(this.INITIAL_MU, 24, z_perc) => this.MU;
        }
        
        // TODO: should we lowpass/highpass the sound? and map z_perc to filter cutoff?
            // how to do this for incr vs decr pitch?
        
        // TODO: accelerate rate? if we want to preserve aug triad, this needs to 
        // be down synchronously, via server.
            // but maybe it's okay to go out of sync and lose the exact harmonic structure
    }

    
    
    
    
    // normal function for loudness curve
    // NOTE: chuck-1.3.5.3 and later: can use Math.gauss() instead
    // fun float gauss( float x, float mu, float sd )
    // {
    //     return (1 / (sd*Math.sqrt(2*pi))) 
    //         * Math.exp( -(x-mu)*(x-mu) / (2*sd*sd) );
    // }
}

// unit_test();

fun void unit_test() {
    Shepard s;
    s.init(dac, 0, 36, -.002);
    s.activate();
    spork ~ s.player();
    while (true) {
        1::ms => now;
    }
}