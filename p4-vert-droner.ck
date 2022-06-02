/*
Drone instrument for P4.
*/

public class P4Droner extends Switchable {
    "Part 4 Droner" => this.NAME;

    /*=======Signal flow=========*/
    Gain l_voice_gain; Gain r_voice_gain;
    Gain main_gain;
    // mod effects 
    Chorus chorus => NRev rev => Echo e1 => Echo e2 => main_gain => this.switch_gain;
    l_voice_gain => chorus; 0 => l_voice_gain.gain;
    r_voice_gain => chorus; 0 => r_voice_gain.gain;

    // patch both rev and echo to main_gain.
    // patching rev allows the undelayed signal to pass through
    rev => main_gain;
    .5 => rev.mix;

    // echo settings
    .75::second => e1.max => e1.delay;
    1.5::second => e2.max => e2.delay;
    .8 => e1.gain;
    .6 => e2.gain;

    // chorus settings
    .8 => chorus.mix;
    .2 => chorus.modFreq;
    .07 => chorus.modDepth;

    // granulators
    Granulator @ l_voice; Granulator @ r_voice;
    [false, false] @=> int in_voice_region[];

    /*========Pitch sets=========*/
    // voice pitch set
    1.0 => float play_rate_offset; // shifts all pitches by this amount

    [   // A - E - B - F#
        2 * (15./8),  // B
        2 * (5/3.),  // A
        // (3/2.) * 2,  // G
        Util.Aug4 * 2, // F#
        (5./4) * (2.), // E
        // (2.) * (135/128),  // C#
        // (2.),  // C
        (15./8),  // B
        (5/3.)  // A
        // (3/2.)  // G
    ] @=> float upper_pitches[];

    [   // G - D - A - E
        (5/2.),  // E
        (9/4.),  // D
        (5/3.) * (1/2.),  // A
        (3/2.),  // G
        // Util.Aug4, // F#
        (5./4), // E
        (9/8.),  // D
        // (1.),  // C
        (5/3.) * (1/2.),  // A
        (3/4.)  // G
        // (2/3.) // F
        // (1.0/2) // C
    ] @=> float middle_pitches[];

    [  // F - C - G - D
        // --- lower voices --- 7 - 12
        (5./4), // E
        (9/8.),  // D
        (1.0), // C
        // (8/9.), // Bb
        (5/3.) * (1/2.),  // A
        (3/4.),  // G
        (2/3.),  // F
        // (3/5.),  // Eb
        (9/8.) * (1/2.),  // D
        (1/2.)  // C
    ] @=> float lower_pitches[];

    float pitch_set[];

    fun void assign_voice_freq(Granulator @ voice, float pitch_set[]) {
        voice.GRAIN_PLAY_RATE => float rate;
        while (Util.approx(rate, voice.GRAIN_PLAY_RATE))
            pitch_set[Math.random2(0, pitch_set.size()-1)] => rate;
        rate => voice.GRAIN_PLAY_RATE;
        <<< rate >>>;
    }

    fun void init(
        UGen @ out, string sample_path, float pitch_set[], float play_rate_offset
    ) {
        this.init(out);

        play_rate_offset => this.play_rate_offset;
        pitch_set @=> this.pitch_set;

        create_granulator(sample_path, l_voice_gain) @=> this.l_voice;
        create_granulator(sample_path, r_voice_gain) @=> this.r_voice;

        assign_voice_freq(l_voice, pitch_set);
        assign_voice_freq(r_voice, pitch_set);
        play_rate_offset => l_voice.GRAIN_SCALE_DEG => r_voice.GRAIN_SCALE_DEG;
        
        // TODO: do this?
        10::ms => r_voice.GRAIN_LENGTH;
        10::ms => l_voice.GRAIN_LENGTH;
    }

    fun Granulator create_granulator(string filepath, UGen @ out) {
        Granulator drone;
        drone.init(filepath, out);
        spork ~ this.switchable_granulator(drone);

        return drone;
    }

    .27 => float Z_BEGIN_VOICE;
    .48 => float Z_VOICE_MAX;
    fun void gt_update(GameTrack @ gt) {
        voice_controller(gt, 0, gt.LZ, l_voice, l_voice_gain);
        voice_controller(gt, 1, gt.RZ, r_voice, r_voice_gain);
    }

    fun void voice_controller(
        GameTrack @ gt, int which, int z,
        Granulator @ voice, Gain @ voice_gain
    ) {
        gt.curAxis[z] => float cur_z;
        if (cur_z < gt.Z_DEADZONE) {
            0 => voice_gain.gain;
            return;
        }

        // set grain pos
        Util.clamp01(gt.invLerp(gt.Z_DEADZONE, Z_VOICE_MAX, cur_z)) => float z_perc;
        z_perc * .5 => voice.GRAIN_POSITION; 
        
        if (cur_z >= gt.Z_DEADZONE && cur_z < Z_BEGIN_VOICE) {
            // just the faintest whisper...
            Util.remap01(gt.Z_DEADZONE, Z_BEGIN_VOICE, 0, .02, cur_z) => voice_gain.gain;

            if (in_voice_region[which]) {
                // exiting voice region
                false => in_voice_region[which];
                <<< "reassigning" , z >>>;
                assign_voice_freq(voice, pitch_set);
            }
        } else if (cur_z >= Z_BEGIN_VOICE) { // voice region
            true => in_voice_region[which];
            2 * Util.remap01(Z_BEGIN_VOICE, Z_VOICE_MAX, .02, 1, cur_z) => voice_gain.gain;

            // lerp voice grain length
            Util.remap(Z_BEGIN_VOICE, Z_VOICE_MAX, 10, 500, cur_z)::ms => voice.GRAIN_LENGTH;
        }
    }
}

// unit_test();

fun void unit_test() {
  // gametrack
  GameTrack gt;
  gt.init(0);

  P4Droner droner;

  // upper voice
//   droner.init(
//     dac, 
//     "./Samples/Drones/female-choir.wav",  // sample
//     droner.upper_pitches, // pitch set
//     .5  // pitch offset
//   );

  // middle voice
  droner.init(
    dac, 
    "./Samples/Drones/male-choir.wav",  // sample
    droner.middle_pitches, // pitch set
    .5  // pitch offset
  );

  // lower voice
//   droner.init(
//     dac, 
//     "./Samples/Drones/wtx-1.wav",  // organ
//     droner.lower_pitches, // pitch set
//     1.0  // pitch offset
//   );

  droner.activate();

  while (true) { 
    droner.gt_update(gt);
    10::ms => now; 
  }

}