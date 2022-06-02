/*
Granular synthesis + comb filtering instrument for P2

Left: granulator
    - z: grain pos + field_gain
    - x:
Right: comb filter 
    - height sets comb filter gain
    - width sets comb filter adsr gain
    - either height or width lerps comb feedback between .90 and .98

9 gametraks total
Each gametrak
- plays 2 notes, sent from chuck server
- controls granulated video playback on 1 tile
- has 1 playerID

*/

public class Combulator extends Switchable {
    "P2 Combulator" => this.NAME;
    Paths paths; // filepaths

    /* ============== signal flow ============== */
    

    // main gains
    Gain field_gain; Gain comb_gain; Gain main_gain;
    0 => field_gain.gain => comb_gain.gain;
    1 => main_gain.gain;

    // envelope follower
    comb_gain => EnvFollower envFollower => blackhole;

    // mod effects
    Chorus chorus => NRev reverb => main_gain => this.switch_gain; // outlet
    // rev settings
    .15 => reverb.mix;
    // chorus settings
    .8 => chorus.mix;
    .2 => chorus.modFreq;
    .07 => chorus.modDepth;

    // connect gains to mod effects
    field_gain => reverb;  // field recording goes through rev only
    comb_gain => chorus;  // comb filter goes through chorus + rev

    /* ======== comb filter setup ======== */
    KSChord ksChord;
    ksChord => ADSR comb_adsr => comb_gain;  // connect to gain

    comb_adsr.keyOn(); // default open.

    ksChord.init(2);  // for now, try 2 notes per gametrak
    0. => ksChord.feedback; // no feedback

    
    /* ========= Granulator setup (TODO: move to server initialization) ========= */
    create_granulator("./Samples/Drones/male-choir.wav", comb_adsr) @=> Granulator instrument_gran0;
    create_granulator("./Samples/Drones/male-choir.wav", comb_adsr) @=> Granulator instrument_gran1;
    spork ~ instrument_gran0.cycle_pos();
    spork ~ instrument_gran1.cycle_pos();
    // TODO: normalize gains on samples
    // TODO: crossfade between held drone and pulsed kschord
        // or sustain kschord and pulse instrument? discuss w/ tesss.
    4 => instrument_gran0.lisa.gain => instrument_gran1.lisa.gain;

    Granulator @ field_granulator; // initialized in this.init(...)

    fun Granulator create_granulator(string filepath, UGen @ out) {
        Granulator drone;
        drone.init(filepath, out);

        //   spork ~ drone.cycle_pos();
        spork ~ this.switchable_granulator(drone);

        return drone;
    }

    /* ========= networked params ========= */
    false => int GETTING_NETWORKED_GRAIN_POS;  // true if receiving networked grain pos, else false
    int playerID; int audioID; int movieID;  // TODO: keep this info on server? doesn't need to be duplicated across players
    string PROCESSING_HOSTNAME;
    int PROCESSING_PORT;
    OscOut xmit;


    fun void init(
        UGen @ out,
        int playerID, int audioID, int movieID,
        string processing_hostname, int processing_port
    ) {
        this.init(out); // call parent, setup underlying Switchable logic 

        playerID => this.playerID;
        audioID => this.audioID;
        movieID => this.movieID;

        // network processing sender
        processing_hostname => this.PROCESSING_HOSTNAME;
        processing_port => this.PROCESSING_PORT;
        this.xmit.dest( this.PROCESSING_HOSTNAME, this.PROCESSING_PORT );
        
        // initialize field granulator
            // connect to comb filter
        create_granulator(paths.AUDIO_FILES[audioID], this.ksChord) @=> field_granulator;
            // also connect through dry 
        field_granulator.connect(field_gain);

        // spork OSC handlers
        // OSC handlers
        spork ~ audioFileHandler();  // networked audio source changes
        spork ~ combFilterPitcher(); // comb filter pitch
        spork ~ granulatorPositioner();  // listener for networked grain position
        spork ~ combFilterPulser(Util.bpmToQtNote(312)); // comb filter adsr pulse


    }

    fun dur get_field_grain_size(float x) {
        return Util.remap(-1., 1., 15, 500, x)::ms; 
    }

    fun float get_grain_rate(float y) {
        return Util.remap(-1., 1., .4, 2.5, y);
    }

    .5 => float Z_MAX;
    fun void gt_update(GameTrack @ gt) {  // To be called in while() loop 
        // <<< "combulator gt_update" >>>;
        fieldGranulatorController(gt);  // control granulation params
        combFilterController(gt);  // control comb filter params
    }

    fun void fieldGranulatorController(GameTrack @ gt) {
        gt.curAxis[gt.LZ] => float z; // between [0, 1]

        if (z < gt.Z_DEADZONE) {
            0 => field_gain.gain;
            // 0 => this.field_granulator.lisa.gain;
            return;
        }

        // calculate as percentage of maximum
        Util.invLerp01(gt.Z_DEADZONE, Z_MAX, z) => float z_perc;

        // set granulation position (TODO: add pos randomization?)
        if (!GETTING_NETWORKED_GRAIN_POS)
            z_perc => this.field_granulator.GRAIN_POSITION;
        
        // set grain play rate
        get_grain_rate(gt.curAxis[gt.LX]) => this.field_granulator.GRAIN_PLAY_RATE;
        // set grain size
        get_field_grain_size(gt.curAxis[gt.LY]) => this.field_granulator.GRAIN_LENGTH;
        // set granulator gain
        z_perc => field_gain.gain;
        // z_perc => this.field_granulator.lisa.gain;
    }


    // comb controller config
    .5 => float COMB_MAX_Z; // z position at max feedback, max gain
    .98 => float MAX_FEEDBACK;
    .90 => float MIN_FEEDBACK;
    170. => float MAX_WIDTH;  // hand width at max adsr gain
    fun void combFilterController(GameTrack @ gt) {
        gt.curAxis[gt.RZ] => float z;

        if (z < gt.Z_DEADZONE) {
            0 => comb_gain.gain;
            return;
        }

        // calculate as percentage of maximum
        Util.invLerp01(gt.Z_DEADZONE, COMB_MAX_Z, z) => float z_perc;

        // set comb gain
        z_perc => comb_gain.gain;

        // set comb filter feedback
            // TODO: map through logistic function, because feedback >.9 is much more sensitive
        Util.lerp(MIN_FEEDBACK, MAX_FEEDBACK, z_perc) => float feedback;
        feedback => ksChord.feedback;
        // Util.print("kschord feedback: " + feedback);

        // set adsr gain
        Util.remap01(0, MAX_WIDTH, .1, 1, gt.GetXZPlaneHandDist()) => float width_percentage;
            // (1 - width_percentage) => comb_adsr.sustainLevel;
            // cross between drone and pulse?
            // width_percentage => comb_adsr.sustainLevel;
            // width_percentage * 5::second => comb_adsr.releaseTime;
        width_percentage => comb_adsr.gain;
    }

    /*=========OSC Receivers=========*/

    fun void combFilterPitcher() {
        OscIn oin;
        OscMsg msg;
        6449 => oin.port;

        oin.addAddress( "/jakarta/p2/comb_filter_notes, i, i" );

        while (true) {
            oin => now;
            while (oin.recv(msg)) {
                [msg.getInt(0), msg.getInt(1)] @=> int nextChord[];
                nextChord => this.ksChord.tune;

                // set instrumental pitch
                Std.mtof(nextChord[0]) / Std.mtof(60) => instrument_gran0.GRAIN_PLAY_RATE;
                Std.mtof(nextChord[1]) / Std.mtof(60) => instrument_gran1.GRAIN_PLAY_RATE;

                // Util.print("chord change: ");
                // Util.print(nextChord);
            }
        }
    }

    // handler for networked grain pos messages
    fun void granulatorPositioner() {
        OscIn oin;
        OscMsg msg;
        6449 => oin.port;

        oin.addAddress( "/jakarta/p2/grain_position, f" );

        while (true) {
            oin => now;
            while (oin.recv(msg)) {
                msg.getFloat(0) => float grain_pos;
                if (grain_pos < 0) {
                    false => GETTING_NETWORKED_GRAIN_POS;
                } else {
                    true => GETTING_NETWORKED_GRAIN_POS;
                    grain_pos => this.field_granulator.GRAIN_POSITION;
                }
            }
        }
    }

    // handler for syncing audio file and movie file idx
    fun void audioFileHandler() {
        OscIn oin;
        OscMsg msg;
        6449 => oin.port;

        /*
            audioID: int
            movieID: int 
        */
        oin.addAddress( "/jakarta/p2/audio_file_idx, i, i" );

        while (true) {
            oin => now;
            while (oin.recv(msg)) {
                msg.getInt(0) => int newAudioIdx;
                msg.getInt(1) => this.movieID;
                if (newAudioIdx == audioID) continue;  // nothing to do

                // else: reload lisa
                // TODO: redesign this. 
                Util.print("reloading lisa from " + paths.AUDIO_FILES[audioID] + " to " + paths.AUDIO_FILES[newAudioIdx]);
                newAudioIdx => this.audioID;
                Util.print("not reloading for now. clips. TODO: redesign");
                // paths.AUDIO_FILES[audioID] => granulator.reload;

                // TODO: reload causes clipping. implement cross-fade between 2 granulators. 
            }
        }
    }

    // networked-triggered pulse
    fun void combFilterPulser(dur decay) {
        // TODO: give the option to transition between sustained chord and pulsed chord
        // set envelope
        comb_adsr.set(
            20::ms,
            decay,
            0.2,  // TODO should this be 0 instead?
            0::ms
        );

        OscIn oin;
        OscMsg msg;
        6449 => oin.port;

        oin.addAddress( "/jakarta/p2/comb_filter_pulse" );

        while (true) {
            oin => now;
            while (oin.recv(msg)) {
                comb_adsr.keyOn();
            }
        }
    }

    // for processing sender:
    /*
    check if this.activated, then send. else continue.
    processing network messages are sent on a different timescale
    than gt_update, so control needs to be separated
    */

    // send processing granulation info
    /*
    playerID: int
    movieID: int
    grainPos: float
    grainRate: float
    grainSize: float (in ms)
    gain: float
    */
    -1 => float last_gain;
    -1 => float last_movieID;
    5/255. => float GAIN_THRESHOLD;
    fun void processing_update(GameTrack @ gt) {
        // calculate gain
        field_gain.gain() * .25 + comb_adsr.gain() * .75 => float gain;
        Math.max(0, gain) => gain;

        if (
            movieID == last_movieID && 
            Std.fabs(gain - last_gain) < GAIN_THRESHOLD
        ) {
            return; // nothing changed, don't clog network
        }
        gain => last_gain;
        movieID => last_movieID;

        xmit.start("/p2/player_to_processing");
        xmit.add(playerID); // playerID
        xmit.add(movieID);
        xmit.add(field_granulator.GRAIN_POSITION); // between [0,1]
        xmit.add(field_granulator.GRAIN_PLAY_RATE);
        xmit.add(field_granulator.GRAIN_LENGTH / ms); // (in ms)

        xmit.add(
            // 5 * follower.value() + (field_gain.gain() / 1.8)
            gain
        ); // (in ms)
        xmit.send();
    }
}