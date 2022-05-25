/* 
TODO: change cycle_pos LFO to triangle wave
*/

/*==========Network Setup=========*/
[
    "localhost"
    // "Tess"
] @=> string hostnames[];

6449 => int port;

// sender object
hostnames.size() => int NUM_RECEIVERS;
OscOut xmits[NUM_RECEIVERS];

// aim the transmitter at destination
for (0 => int i; i < NUM_RECEIVERS; i++) {
    xmits[i].dest( hostnames[i], port );
}

/*==========HID config=========*/
// HID objects
Hid hi;
HidMsg msg;

// which keyboard
0 => int device;
// 1 => int device;

if( !hi.openKeyboard( device ) ) me.exit();
<<< "keyboard '" + hi.name() + "' ready", "" >>>;


/*==========Pitch Content=========*/
// A major scale
57 => int A; 59 => int B; 61 => int Cs; 62 => int D; 64 => int E; 66 => int Fs; 68 => int Gs;

[
  [Fs - 24, B - 12],
  [B - 12, Fs - 12],
  [Cs - 12, Fs - 12],
  [Fs - 24, Cs - 12],
  [D - 24, A - 12],
  [A - 12, E - 12],
  [Cs - 12, Fs - 12],
  [Fs - 24, Cs - 12],
  [E - 24, A - 12],
  [D - 24, A - 12],
  [A - 12, D - 12]
] @=> int lowerChords[][];

[
  [D, D, A + 12],
  [D, E, A + 12],
  [E, A + 12, A + 12],
  [E, A + 12, B + 12],
  [E, Fs, Gs],  // 5 
  [E, Fs, Gs],  
  [Fs, Gs, A + 12],
  [Fs, Gs, A + 12],  // 8
  [Cs, Fs, Gs],
  [Fs, Gs, A + 12],
  [E, Fs, A + 12]

] @=> int middleChords[][];

[
    [D + 12, E + 12, A + 24, D + 24],
    [D + 12, E + 12, A + 24, D + 24],
    [E + 12, A + 24, A + 24, E + 24],
    [E + 12, A + 24, B + 24, E + 24],
    [B + 12, B + 12, E + 12, B + 24],  // 5
    [B + 12, Cs + 12, E + 12, B + 24],  // 6
    [Cs + 12, Fs + 12, A + 24, Cs + 24],  // 7
    [B + 12, Cs + 12, Fs + 12, A + 24],  // 8
    [A + 12, B + 12, E + 12, Gs + 24],  // 9
    [Gs, A + 12, E + 12, A + 24],  // 10
    [Fs, A + 12, E + 12, A + 24]  // 11

] @=> int upperChords[][];

int CHORDS[0][0];

// construct entire chord
for (0 => int i; i < lowerChords.size(); i++) {
    CHORDS << Util.concat(Util.concat(lowerChords[i], middleChords[i]), upperChords[i]);
}

Util.print(CHORDS);


/*==========Globals=========*/
Paths paths;

0 => int MOVIE_IDX;  // global movie file
0 => int AUDIO_IDX; // global audio file (used when global grain pos is enabled)
0 => int CHORD_IDX;  // position in chord sequence
TriOsc lfo => blackhole;
.8 => float SCRUB_PERCENTAGE;  // what portion of the audio file do we scan across?

SndBuf buffys[0];
// load audio file buffys
for (0 => int i; i < paths.AUDIO_FILES.size(); i++) {
    SndBuf buffy;
    paths.AUDIO_FILES[i] => buffy.read;
    0 => buffy.rate;
    buffys << buffy;
}
syncLFO(AUDIO_IDX);

fun void syncLFO(int idx) {
    // update lfo period
    2 * SCRUB_PERCENTAGE * buffys[idx].length() => lfo.period;  
    // reset phase to start from 0
    .75 => lfo.phase;
}

// change global audio file
fun void changeAudioFile(int idx) {
    if (idx == AUDIO_IDX) return;
    if (idx < 0) {
        idx + paths.AUDIO_FILES.size() => idx;
    }
    idx % paths.AUDIO_FILES.size() => idx;
    idx => AUDIO_IDX;

    syncLFO(AUDIO_IDX);
    Util.print("new audio idx: " + AUDIO_IDX);
}

fun void changeChordIdx(int idx) {
    if (idx == CHORD_IDX) return;
    if (idx < 0) {
        idx + CHORDS.size() => idx;
    }
    idx % CHORDS.size() => idx;
    idx => CHORD_IDX;
    Util.print("new chord idx: " + CHORD_IDX);
}

fun void changeMovieFile(int idx) {
    if (idx == MOVIE_IDX) return;
    while (idx < 0) {
        idx + paths.MOVIE_FILES.size() => idx;
    }
    idx % paths.MOVIE_FILES.size() => idx;
    idx => MOVIE_IDX;

    Util.print("new movie idx: " + MOVIE_IDX + " | file: " + paths.MOVIE_FILES[MOVIE_IDX]);
}

/*==========OSC Senders=========*/

/*
    playerID: int
    audioID: int
*/
fun void initialize() {
    while (true) {
        for (0 => int i; i < NUM_RECEIVERS; i++) {
            xmits[i].start("/jakarta/p2/initialize");
            xmits[i].add(i); // playerID
            xmits[i].add(i % paths.AUDIO_FILES.size());
            xmits[i].add(i % paths.MOVIE_FILES.size());
            xmits[i].send();
        }
        1::second => now;  // continually send, but receiver only needs to receive once.
    }
} spork ~ initialize();

/*
    midiNote0: int
    midiNote1: int
*/
fun void combFilterPitchSender() {
    // TODO: make this multicast?
    while (true) {
        CHORDS[CHORD_IDX] @=> int chord[];
        for (0 => int i; i < NUM_RECEIVERS; i++) {
            chord[i % chord.size()] => int midiNote0;
            chord[(i + 1) % chord.size()] => int midiNote1;

            xmits[i].start("/jakarta/p2/comb_filter_notes");
            xmits[i].add(midiNote0);
            xmits[i].add(midiNote1);
            xmits[i].send();
        }
        20::ms => now;
    }
} spork ~ combFilterPitchSender();


/*
grainPos: float 
*/
false => int CYCLE_POS_ENABLED;
fun void grainPositionSender() {
    while (true) {
        10::ms => now;
        -1 => float grainPos;
        if (CYCLE_POS_ENABLED)
            (.5 + (SCRUB_PERCENTAGE/2.0) * lfo.last()) => grainPos;

        for (0 => int i; i < NUM_RECEIVERS; i++) {
            xmits[i].start("/jakarta/p2/grain_position");
            xmits[i].add(grainPos);
            xmits[i].send();
        }
    }
} spork ~ grainPositionSender();


/*
audioIdx: idx of global audio file
movieIdx: idx of global movie file
*/
false => int SYNC_AUDIO_FILES_ENABLED;
fun void audioFileSender() {
    while (true) {
        10::ms => now;
        if (!SYNC_AUDIO_FILES_ENABLED) continue;  // don't send msg

        for (0 => int i; i < NUM_RECEIVERS; i++) {
            xmits[i].start("/jakarta/p2/audio_file_idx");
            xmits[i].add(AUDIO_IDX);
            xmits[i].add(MOVIE_IDX);
            xmits[i].send();
        } 
    }
} spork ~ audioFileSender();

/* sends pulse timing */
312 => float PULSE_BPM;
false => int COMB_PULSE_ENABLED;
fun void combPulseSender() {
    while (true) {
        Util.bpmToQtNote(PULSE_BPM) => dur pulse_dur;

        if (!COMB_PULSE_ENABLED) {
            pulse_dur => now;
            continue;
        }

        for (0 => int i; i < NUM_RECEIVERS; i++) {
            xmits[i].start("/jakarta/p2/comb_filter_pulse");
            xmits[i].send();
        } 
        pulse_dur => now;
    }
} spork ~ combPulseSender();

/* ========= Keyboard controls ========= */

// syncs/desyncs players
false => int PLAYERS_SYNCHRONIZED;
fun void toggleSynchronize() {
    // toggle
    !PLAYERS_SYNCHRONIZED => PLAYERS_SYNCHRONIZED;

    // enable network synchronizers
    PLAYERS_SYNCHRONIZED => COMB_PULSE_ENABLED;
    PLAYERS_SYNCHRONIZED => SYNC_AUDIO_FILES_ENABLED;
    PLAYERS_SYNCHRONIZED => CYCLE_POS_ENABLED;

    if (PLAYERS_SYNCHRONIZED) {  // synchronize!
        syncLFO(AUDIO_IDX);  // reset LFO to start from 0
    } else {  // desync
        // not implemented, will only add if necessary. 
        // re-randomize audio file assignments, disable stuff...
        Util.printErr("player desync not fully implemented");
    }

    Util.print("players synchronized: " + PLAYERS_SYNCHRONIZED);
}


fun void kb() {
    while (true) {
        hi => now;

        while (hi.recv(msg)) {
            <<< msg.which >>>;
            if (!msg.isButtonDown()) continue;

            if (msg.which == Util.KEY_SPACE) {
                toggleSynchronize();
            } else if (msg.which == Util.KEY_LEFT) {
                changeAudioFile(AUDIO_IDX - 1);
                changeChordIdx(CHORD_IDX - 1);
            } else if (msg.which == Util.KEY_RIGHT) {
                changeAudioFile(AUDIO_IDX + 1);
                changeChordIdx(CHORD_IDX + 1);
            } else if (msg.which == Util.KEY_A) {
                changeMovieFile(MOVIE_IDX - 1);
                changeChordIdx(CHORD_IDX - 1);
            } else if (msg.which == Util.KEY_D) {
                changeMovieFile(MOVIE_IDX + 1);
                changeChordIdx(CHORD_IDX + 1);
            }
            //TODO: add controls to randomize audio/video/chord?
                // maybe would work with Tess fast cut section?
            // could this be more flushed out as an instrument itself?
                // more control over which players are assigned which videos, what notes?
            /*
                ideas:
                    - have # chords and # videos be relative prime, so we get a cyclic process that hits every possible video/chord combination
                    - should GRAIN_OVERLAP be 1? or at least less than 8?
                    - should we have random jitter in grain fire?
                    - comb filter sound isn't consisted enough, need to double with drone instrumental
                        - electronic (basal, energy, replicant)
                        - male/female voice
            */
        }
    }
}

kb();