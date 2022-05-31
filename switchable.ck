/*
Switchable instrument base class.

Usage:
    init() to connect to outlet
    activate() to enable instrument
    deactivate() to disable

*/

public class Switchable {
    UGen @ out;  // outlet 
    Gain switch_gain;  // local main gain
    0 => switch_gain.gain;  // default silent

    // for smooth gain interpolation
    Envelope target_gain_env => blackhole;  
    0 => target_gain_env.value;
    1000::ms => target_gain_env.duration;

    false => int IS_ACTIVE;
    "base_switchable" => string NAME;


    fun void init(UGen @ out) {
        out @=> this.out;
        spork ~ gain_interpolator();
    }

    fun void activate() {
        if (IS_ACTIVE) return;
        // connect to outlet
        switch_gain => this.out;

        // set target gain
        1 => target_gain_env.target;

        true => IS_ACTIVE;

        Util.print("=============" + NAME + " activated==========");
    }

    fun void deactivate() {
        if (!IS_ACTIVE) return;
        Util.print(NAME + " deactivating...please hold...");
        // set target gain
        0 => target_gain_env.target;

        // wait for silence
        1.5::second => now;

        // disconnect (chuck no longer ticks UGens)
        switch_gain =< this.out;

        false => IS_ACTIVE;
        Util.print("=============" + NAME + " deactivated==========");
    }

    // abstract--override in child instruments. 
    // Call at desired rate to update instrument params according to gt values
    fun void gt_update(GameTrack @ gt) {
        // <<< "base switchable gt_update" >>>;
    }

    // abstract--override in child instruments. 
    // Call at desired rate to send data to processing 
    fun void processing_update(GameTrack @ gt) {
        // <<< "base switchable processing_update" >>>;
    }

    // smoothly ramps switch_gain, prevents popping on activate/deactivate
    fun void gain_interpolator() {
        while (true) {
            target_gain_env.value() => this.switch_gain.gain;
            // <<< switch_gain.gain() >>>;

            1::ms => now;
        }
    } 

    // only granulates when this.IS_ACTIVE
    fun void switchable_granulator(Granulator @ drone) {
        while (true) {
            if (this.IS_ACTIVE) {
                drone.fireGrain();
            }
            drone.get_grain_overlap() => now;
        }
    }
}

class Test extends Switchable {
    SinOsc s => this.switch_gain;
}

// unit_test();

fun void unit_test() {
    Test t;
    t.init(dac);

    <<< "activating" >>>;
    t.activate(); 
    1::second => now;

    <<< "deactivating" >>>;
    t.deactivate();
}

