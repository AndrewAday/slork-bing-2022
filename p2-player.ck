/*
Networked combulator player + receiver


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

Processing sees 9 gametraks, not 9*2!
This let's us use more gametraks = more hemis = more sound
*/

Util.print("jakarta p2 player initializing...");
"Tess.local" => string PROCESSING_HOSTNAME;
6450 => int PROCESSING_PORT;

// Filepaths
Paths paths;

// gametrack
GameTrack gt;
gt.init(0);

// get num channels
// print out all arguments
int NUM_CHANNELS;
Util util;
util.STRING_TO_INT[me.arg(0)] => NUM_CHANNELS;

// signal flow
// 2 => int NUM_CHANNELS;
// 6 => int NUM_CHANNELS;
Gain main_gain;
Util.patchToDAC(NUM_CHANNELS, main_gain);



Gain l_field_gain; Gain l_comb_gain;

// envelope follower
l_comb_gain => EnvFollower envFollower => blackhole;

Chorus l_chorus;

NRev rev => main_gain;  // TODO: maybe swap with basic delay line?
l_chorus => rev; 

// patch rev to main_gain.
// patching rev allows the undelayed signal to pass through
rev => main_gain;

NRev field_rev => main_gain;

// rev settings
.15 => field_rev.mix; // TODO: have rev? do we want contrast wet vocal / dry field, or both wet?
.15 => rev.mix;

// chorus settings
.8 => l_chorus.mix; // => r_chorus.mix;
.2 => l_chorus.modFreq; // => r_chorus.modFreq;
.07 => l_chorus.modDepth; // => r_chorus.modDepth;

l_field_gain => field_rev;

l_comb_gain => l_chorus;

.0 => l_field_gain.gain; .0 => l_comb_gain.gain;

/* ======== comb filter setup ======== */
KSChord l_ksChord;
l_ksChord => ADSR l_comb_adsr => l_comb_gain;  // connect to gain
// ADSR l_comb_adsr => l_comb_gain;  // connect to gain

l_comb_adsr.keyOn(); // default open.

    // for now, try 2 notes per gametrak
l_ksChord.init(2); 
0. => l_ksChord.feedback; // no feedback

/* ========= Instrumental setup (TODO: move to server initialization) ========= */
create_granulator("./Samples/Drones/male-choir.wav", l_comb_adsr) @=> Granulator instrument_gran0;
create_granulator("./Samples/Drones/male-choir.wav", l_comb_adsr) @=> Granulator instrument_gran1;
spork ~ instrument_gran0.cycle_pos();
spork ~ instrument_gran1.cycle_pos();
// TODO: normalize gains on samples
// TODO: crossfade between held drone and pulsed kschord
    // or sustain kschord and pulse instrument? discuss w/ tesss.
4 => instrument_gran0.lisa.gain => instrument_gran1.lisa.gain;

/* ========= Get initialization params from server ========= */

-1 => int playerID;
-1 => int audioID;
-1 => int movieID;
Granulator @ l_granulator;
fun void initialize() {
    OscIn oin;
    OscMsg msg;
    6449 => oin.port;

    /*
        playerID: int
        audioID: int
        movieID: int
    */
    oin.addAddress( "/jakarta/p2/initialize, i i i" );

    // get init info from server
    oin => now;
    while (oin.recv(msg)) {
        msg.getInt(0) => playerID;
        msg.getInt(1) => audioID;
        msg.getInt(2) => movieID;
    }
    // 0 => playerID; 0 => audioID;
    Util.print("Player initialized. playerID: " + playerID + " | audioID: " + audioID + " | movieID: " + movieID);

    // initialize left joystick
    create_granulator(paths.AUDIO_FILES[audioID], l_ksChord) @=> l_granulator;
    l_granulator.connect(l_field_gain); // dry, no comb filtering
}

initialize();  // assign playerID and audioID


fun Granulator create_granulator(string filepath, UGen @ out) {
    Granulator drone;
    drone.init(filepath, out);

    //   spork ~ drone.cycle_pos();
    spork ~ drone.granulate();

    return drone;
}

/*========== Gametrack granulation control fns ========*/
.015 => float GT_Z_DEADZONE;
1.0 => float GT_Z_COMPRESSION;

// TODO: try adding grain position randomization?
fun float get_grain_pos(float z) {  // maps z to [0,1]
    return Math.max(0, ( z - GT_Z_DEADZONE ));
    // Math.max(0, ( z - GT_Z_DEADZONE )) * GT_Z_COMPRESSION + Math.random2f(0,.0001) => float pos;
}

fun dur get_field_grain_size(float x) {
    return Util.remap(-1., 1., 15, 500, x)::ms; 
}

fun dur get_voice_grain_size(float z) {
    return Util.remap(0, .5, 10, 500, z)::ms;
}

fun float get_grain_rate(float y) {
    return Util.remap(-1., 1., .4, 2.5, y);
}

fun float get_grain_gain(float z) {
    return Util.clamp01(Util.remap(0, .5, 1, 0, z));
}

// controls granular synthesis mapping to gametrak, + cross fade to voice
GT_Z_DEADZONE => float Z_DEADZONE_CUTOFF;
false => int GETTING_NETWORKED_GRAIN_POS;  // true if receiving networked grain pos, else false
fun void granulatorController( 
    int x, int y, int z, 
    Granulator @ granulator, 
    Gain @ field_gain,  // dry gain
    KSChord @ ksChord
    // TODO: add more mod effects? rev / delay / distortion / chorus / Lowpass ...
) {
    .5 => float Z_MAX;


    while (true) {
        if (!GETTING_NETWORKED_GRAIN_POS)
            get_grain_pos(gt.curAxis[z]) => granulator.GRAIN_POSITION;
        
        get_grain_rate(gt.curAxis[x]) => granulator.GRAIN_PLAY_RATE;
        get_field_grain_size(gt.curAxis[y]) => granulator.GRAIN_LENGTH;
        // granulator.print();

        // z axis silent deadzone
        if (gt.curAxis[z] < Z_DEADZONE_CUTOFF) {
            0 => field_gain.gain;
        } else {
            Util.remap01(Z_DEADZONE_CUTOFF, Z_MAX, 0, 1, gt.curAxis[z]) => field_gain.gain;
            // TODO: add instrumental drone source? E.g. voice or electronic drone
        } 
        10::ms => now;
    }
}

fun void combFilterController(
    int z, KSChord @ ksChord, Gain @ comb_gain, ADSR @ comb_adsr
) {
    // controller config
    .5 => float COMB_MAX_Z; // z position at max feedback, max gain
    .98 => float MAX_FEEDBACK;
    .90 => float MIN_FEEDBACK;
    170. => float MAX_WIDTH;  // hand width at max adsr gain
    

    while (true) {
        gt.curAxis[z] => float cur_z;
        Util.remap01(Z_DEADZONE_CUTOFF, COMB_MAX_Z, 0, 1, cur_z) => float z_percentage;

        // set comb gain
        z_percentage => comb_gain.gain;

        // set comb filter feedback
            // TODO: map through logistic function, because feedback >.9 is much more sensitive
        Util.lerp(MIN_FEEDBACK, MAX_FEEDBACK, z_percentage) => float feedback;
        feedback => ksChord.feedback;
        // Util.print("kschord feedback: " + feedback);

        // set adsr gain
        Util.remap01(0, MAX_WIDTH, .1, 1, gt.GetXZPlaneHandDist()) => float width_percentage;
            // (1 - width_percentage) => comb_adsr.sustainLevel;
            // cross between drone and pulse?
            // width_percentage => comb_adsr.sustainLevel;
            // width_percentage * 5::second => comb_adsr.releaseTime;
        width_percentage => comb_adsr.gain;

        10::ms => now;
    }
}


/*=========OSC Receivers=========*/

fun void combFilterPitcher(KSChord @ ksChord) {
    OscIn oin;
    OscMsg msg;
    6449 => oin.port;

    oin.addAddress( "/jakarta/p2/comb_filter_notes, i, i" );

    while (true) {
        oin => now;
        while (oin.recv(msg)) {
            [msg.getInt(0), msg.getInt(1)] @=> int nextChord[];
            nextChord => ksChord.tune;

            // set instrumental pitch
            Std.mtof(nextChord[0]) / Std.mtof(60) => instrument_gran0.GRAIN_PLAY_RATE;
            Std.mtof(nextChord[1]) / Std.mtof(60) => instrument_gran1.GRAIN_PLAY_RATE;


            // Util.print("chord change: ");
            // Util.print(nextChord);
        }
    }
}

// handler for networked grain pos messages
fun void granulatorPositioner(
    Granulator @ granulator
) {
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
                grain_pos => granulator.GRAIN_POSITION;
            }
        }
    }
}

// handler for syncing audio file and movie file idx
fun void audioFileHandler(
    Granulator @ granulator
) {
    OscIn oin;
    OscMsg msg;
    6449 => oin.port;

    oin.addAddress( "/jakarta/p2/audio_file_idx, i, i" );

    while (true) {
        oin => now;
        while (oin.recv(msg)) {
            msg.getInt(0) => int newAudioIdx;
            msg.getInt(1) => movieID;
            if (newAudioIdx == audioID) continue;  // nothing to do

            // else: reload lisa
            Util.print("reloading lisa from " + paths.AUDIO_FILES[audioID] + " to " + paths.AUDIO_FILES[newAudioIdx]);
            newAudioIdx => audioID;
            paths.AUDIO_FILES[audioID] => granulator.reload;

            // TODO: reload causes clipping. implement cross-fade between 2 granulators. 
        }
    }
}

// networked-triggered pulse
fun void combFilterPulser(ADSR @ comb_adsr, dur decay) {
    // TODO: give the option to transition between sustained chord and pulsed chord
    // set envelope
    comb_adsr.set(
        20::ms,
        decay,
        0.2,  // should this be 0 instead?
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
            // pulse_on => now;
            // comb_adsr.keyOff();
            // pulse_off => now;
        }
    }
}

// send processing granulation info
/*
playerID: int
movieID: int
grainPos: float
grainRate: float
grainSize: float (in ms)
gain: float
*/
fun void processingSender(
    Granulator @ granulator,
    EnvFollower @ follower,
    Gain @ field_gain,
    ADSR @ comb_adsr
) {

    OscOut xmit;
    xmit.dest( PROCESSING_HOSTNAME, PROCESSING_PORT );

    while (true) {
        xmit.start("/jakarta/p2/player_to_processing");
        xmit.add(playerID); // playerID
        xmit.add(movieID);
        xmit.add(granulator.GRAIN_POSITION); // between [0,1]
        xmit.add(granulator.GRAIN_PLAY_RATE);
        xmit.add(granulator.GRAIN_LENGTH / ms); // (in ms)

        field_gain.gain() * .25 + comb_adsr.gain() * .75 => float gain;
        Math.max(0, gain - .1) => gain;
        xmit.add(
            // 5 * follower.value() + (field_gain.gain() / 1.8)
            gain
        ); // (in ms)
        xmit.send();
        10::ms => now;
    }
}



/*=======Final Setup=======*/

// left joy controls granulator
spork ~ granulatorController(gt.LX, gt.LY, gt.LZ, l_granulator, l_field_gain, l_ksChord);

// right joy controls comb filter
spork ~ combFilterController(gt.RZ, l_ksChord, l_comb_gain, l_comb_adsr);

// OSC handlers
spork ~ audioFileHandler(l_granulator);  // networked audio source changes
spork ~ combFilterPitcher(l_ksChord); // comb filter pitch
spork ~ granulatorPositioner(l_granulator);  // listener for networked grain position

312 => float PULSE_BPM;
Util.bpmToQtNote(PULSE_BPM) => dur pulse_dur;
spork ~ combFilterPulser(l_comb_adsr, pulse_dur); // comb filter adsr pulse

// processing sender
spork ~ processingSender(l_granulator, envFollower, l_field_gain, l_comb_adsr);

while (true) {
  1::second => now;
}
