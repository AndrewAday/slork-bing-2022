// name: drone.ck
// desc: gametrak instrument w good drone 
//
// author: Tess Rinaldo (trinaldo@ccrma.stanford.edu)
// date: spring 2022

// gametrack
GameTrack gt;
gt.init(0);

2 => int NUM_CHANNELS;
// 6 => int NUM_CHANNELS;
Gain main_gain;
.5 => main_gain.gain;
Util.patchToDAC(NUM_CHANNELS, main_gain);

NRev rev => Echo e1 => Echo e2 => main_gain;
Gain ll_voice_gain => rev;
Gain lr_voice_gain => rev;
Gain rl_voice_gain => rev;
Gain rr_voice_gain => rev;

rev => main_gain;

.5 => rev.mix;

.0 => ll_voice_gain.gain;
.0 => lr_voice_gain.gain;
.0 => rl_voice_gain.gain;
.0 => rr_voice_gain.gain;

// voice pitch set
.5*.925 => float F; // use this F for granulator. playback rate.
/* 141 => float F; // use this F for setting exact freq  */
[  // TODO: make harmonic territory more spicy
  // --- higher voices --- 0 - 6
  F * (3/2.) * 2,  // G
  F * Util.Aug4 * 2, // F#
  F * (5./4) * (2.), // E
  F * (2.),  // C
  F * (15./8),  // B
  F * (5/3.),  // A
  F * (3/2.),  // G

  // --- lower voices --- 7 - 12
  F * (5./4), // E
  F * (9/8.),  // D
  F * (5/3.) * (1/2.),  // A
  F * (3/4.),  // G
  F * (2/3.),  // F
  F * (1/2.)  // C
] @=> float pitch_set_orig[];

[  // want: F, G, A#, C, D#
  // pentatonic on E flat
  F * (5./4), // E
  F * (9/8.),  // D
  F * (5/3.) * (1/2.),  // A
  F * (3/4.),  // G
  F * (2/3.),  // F
  F * (1/2.)  // C
] @=> float pitch_set[];

[  // want: F, G, A#, C, D#
  (5./4), // E
  (9/8.),  // D
  (5/3.) * (1/2.),  // A
  (3/4.),  // G
  (2/3.),  // F
  (1/2.)  // C
] @=> float pitch_set_drone[];

[ 
  F * (5./4) * (1/2.), // E
  F * (9/8.) * (1/2.),  // D
  F * (5/3.) * (1/2.) * (1/2.),  // A
  F * (3/4.) * (1/2.),  // G
  F * (2/3.) * (1/2.),  // F
  F * (1/2.) * (1/2.)  // C
] @=> float pitch_set_low[];

[
  F * (3/2.) * 2,  // G
  F * (5./4) * (2.), // E
  F * (2.),  // C
  F * (2.) * (9./8),  // D
  F * (15./8),  // B
  F * (5/3.),  // A
  F * (3/2.)  // G
] @=> float cMaj_hexachord[];

[
  // F * (1/2.) * (3/2.) * 2,  // G
  F * (1/2.) * (5./4) * (2.), // E
  F * (1/2.) * (2.),  // C
  F * (1/2.) * (2.) * (9./8),  // D
  // F * (1/2.) * (15./8),  // B
  F * (1/2.) * (5/3.),  // A
  F * (1/2.) * (3/2.)  // G
] @=> float cMaj_hexachord_low[];

0 => int counter;

fun void assign_voice_freqs(
int which, 
Granulator @ voice1, 
Granulator @ voice2, 
float freqs[]
) {
  voice1.GRAIN_PLAY_RATE => float rate;
  while (Util.approx(rate, voice1.GRAIN_PLAY_RATE)) {
    freqs[Math.random2(0, freqs.cap()-1)] => rate;
    // freqs[counter % freqs.cap()] => rate;

  }
  rate => voice2.GRAIN_PLAY_RATE;
}


fun Granulator create_granulator(string filepath, string type, UGen @ out) {
  Granulator drone;
  drone.init(filepath, out);
  spork ~ drone.granulate();
  // spork ~ drone.cycle_pos();
  return drone;
}


// left left joystick
create_granulator("./Samples/Drones/male-choir.wav", "drone", ll_voice_gain) @=> Granulator ll_voice;
// left right joystick
create_granulator("./Samples/Drones/male-choir.wav", "drone", lr_voice_gain) @=> Granulator lr_voice;

// right left joystick
create_granulator("./Samples/Drones/female-choir.wav", "drone", rl_voice_gain) @=> Granulator rl_voice;
// right right joystick
create_granulator("./Samples/Drones/female-choir.wav", "drone", rr_voice_gain) @=> Granulator rr_voice;

// granulator config
10::ms => lr_voice.GRAIN_LENGTH;
10::ms => ll_voice.GRAIN_LENGTH;
10::ms => rr_voice.GRAIN_LENGTH;
10::ms => rl_voice.GRAIN_LENGTH;

.0 => float GT_Z_DEADZONE;
.0 => float Z_BEGIN_VOICE;
0.05 => float Z_VOICE_MAX;

-1. => float X_BEGIN_VOICE;
1. => float X_VOICE_MAX;

fun void init_voices(float pitches_left[], float pitches_right[]) {
  // left
  assign_voice_freqs(gt.LZ, ll_voice, lr_voice, pitches_left);
  assign_voice_freqs(gt.LZ, lr_voice, ll_voice, pitches_left);

  // right
  assign_voice_freqs(gt.RZ, rl_voice, rr_voice, pitches_right);
  assign_voice_freqs(gt.RZ, rr_voice, rl_voice, pitches_right);
}


0 => int prev_side; // 0 left 1 right
fun void play(int x, int y, int z, 
  Granulator @ ll_voice,
  Granulator @ lr_voice, 
  Gain @ ll_voice_gain, 
  Gain @ lr_voice_gain,
  float pitchSet[] ) {
  while (true) {
    // moved to left
    if (Util.approxWithin(gt.curAxis[x], -1, 0.05) && prev_side == 1) {
      assign_voice_freqs(gt.LZ, ll_voice, lr_voice, pitchSet);
      0 => prev_side;
    }
    // moved to right
    if (Util.approxWithin(gt.curAxis[x], 1, 0.05) && prev_side == 0) {
      assign_voice_freqs(gt.LZ, lr_voice, ll_voice, pitchSet);
      1 => prev_side;
    }

    Util.clamp01(Util.remap(X_BEGIN_VOICE, X_VOICE_MAX, 0, 1, gt.curAxis[x])) => float temp;
    // <<< temp >>>;
    // (1 - temp) * 2 => voice_gain.gain;
    (1 - temp)  * Util.remap(Z_BEGIN_VOICE, Z_VOICE_MAX, 0, 1, gt.curAxis[z]) => ll_voice_gain.gain;
    temp  * Util.remap(Z_BEGIN_VOICE, Z_VOICE_MAX, 0, 1, gt.curAxis[z]) => lr_voice_gain.gain;
    // (1 - temp) => ll_voice_gain.gain;

    // lerp voice grain length
    Util.remap(0, Z_VOICE_MAX, 100, 500, gt.curAxis[z])::ms => ll_voice.GRAIN_LENGTH;
    Util.remap(0, Z_VOICE_MAX, 100, 500, gt.curAxis[z])::ms => lr_voice.GRAIN_LENGTH;
    // <<< voice_gain.gain() >>>;
    20::ms => now;
  }
  
}

spork ~ init_voices(cMaj_hexachord_low, cMaj_hexachord_low);
spork ~ play(gt.LX, gt.LY, gt.LZ, ll_voice, lr_voice, ll_voice_gain, lr_voice_gain, cMaj_hexachord_low);
spork ~ play(gt.RX, gt.RY, gt.RZ, rl_voice, rr_voice, rl_voice_gain, rr_voice_gain, cMaj_hexachord_low);
// spork ~ play(gt.RX, gt.RY, gt.RZ, lr_voice, lr_voice_gain);



while (true) {
  10::ms => now;
}
