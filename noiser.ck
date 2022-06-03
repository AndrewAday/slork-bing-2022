/*
Noise instrument for part2 fast-cut section

Modes:
    HIGH: noise is high-passed, and fills out high freqs
    LOW: noise is low-passed, fills out low-freqs
    ALL: unfiltered white noise
    

Controls:
    Gametrak avg Z value controls noise gain, and filter cutoff

To initialize:
    init(out, mode);
    activate();
    while (true) {gt_update(); ...}

*/

public class Noiser extends Switchable {
    "noiser" => this.NAME;

    Noise noise; 0 => noise.gain;
    LPF lowpass; HPF highpass;

    2 => lowpass.Q => highpass.Q;  // TODO: test different resonances
    
    // mode enums
    0 => static int MODE_HIGH;
    1 => static int MODE_LOW;
    2 => static int MODE_ALL;

    // filter thresholds



    -1 => int ACTIVE_MODE;

    fun void init(UGen @ out, int mode) {
        this.init(out);  // parent init

        mode => ACTIVE_MODE;


        // TODO: higher Q?
        if (mode == MODE_HIGH) {
            noise => highpass => lowpass => this.switch_gain;
            2560 => lowpass.freq;
            2560 => highpass.freq;
        } else if (mode == MODE_LOW) {
            noise => lowpass => highpass => this.switch_gain;
            160 => lowpass.freq;
            160 => highpass.freq;
        } else if (mode == MODE_ALL) {
            // no filtering, straight out
            this.noise => this.switch_gain;
        }
    }

    .5 => float AVG_Z_MAX;
    fun void gt_update(GameTrack @ gt) {
        // <<< "noiser gt_update" >>>;
        gt.GetAvgZ() => float avg_z; // between [0, 1]

        if (avg_z < gt.Z_DEADZONE) {
            0 => noise.gain;
            return;
        }

        // calculate as percentage of maximum
        Util.invLerp01(gt.Z_DEADZONE, AVG_Z_MAX, avg_z) => float z_perc;

        // lerp noise gain
        z_perc => noise.gain;

        // lerp filter cutoffs
        if (ACTIVE_MODE == MODE_HIGH) {
            // raise LPF
            Util.lerp(2560, 18000, z_perc) => lowpass.freq;
        } else if (ACTIVE_MODE == MODE_LOW) {
            // lower HPF
            Util.lerp(160, 10, z_perc) => highpass.freq;
        }
    }
}


fun void unit_test() {
    GameTrack gt;
    gt.init(0);

    Noiser n;
    n @=> Switchable s;

    // n.init(dac, MODE_ALL);
    // n.init(dac, MODE_LOW);
    n.init(dac, Noiser.MODE_HIGH);
    n.activate();  // turn switch on

    while (true) {
        s.gt_update(gt);  // calls noiser's gt_update! nice!
        20::ms => now;
    }
}
