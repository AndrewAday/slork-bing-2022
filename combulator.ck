/*
// gametrak control:
//       <-- z axis --> = grain position
//       <--- y axis ---> = grain rate / tuning
//       <---x axis---> = grain size
*/

// TODO: copy granulator reload sample from harmonic lattices

// gametrack
GameTrack gt;
gt.init(0);

// signal flow
2 => int NUM_CHANNELS;
// 6 => int NUM_CHANNELS;
Gain main_gain;
Util.patchToDAC(NUM_CHANNELS, main_gain);


Gain l_field_gain; Gain l_comb_gain;
Gain r_field_gain; Gain r_comb_gain;

Chorus l_chorus;
Chorus r_chorus; 
// NRev rev => Echo e1 => Echo e2 => main_gain;  // TODO: maybe swap with basic delay line?
  // remove echo for now
NRev rev => main_gain;  // TODO: maybe swap with basic delay line?
l_chorus => rev; 
r_chorus => rev;

// patch both rev and echo to main_gain.
// patching rev allows the undelayed signal to pass through
rev => main_gain;

// echo settings
/*
.75::second => e1.max => e1.delay;
1.5::second => e2.max => e2.delay;
.8 => e1.gain;
.6 => e2.gain;
*/

NRev field_rev => main_gain;

// rev settings
.15 => field_rev.mix; // TODO: have rev? do we want contrast wet vocal / dry field, or both wet?
.15 => rev.mix;

// chorus settings
.8 => l_chorus.mix; // => r_chorus.mix;
.2 => l_chorus.modFreq; // => r_chorus.modFreq;
.07 => l_chorus.modDepth; // => r_chorus.modDepth;

l_field_gain => field_rev;
r_field_gain => field_rev;

// l_field_gain => l_chorus;  // try patching field recording through chorus and echo

l_comb_gain => l_chorus;
r_comb_gain => r_chorus;

.0 => l_field_gain.gain; .0 => l_comb_gain.gain;
.0 => r_field_gain.gain; .0 => r_comb_gain.gain;

// voice pitch set
.5 => float F; // use this F for granulator. playback rate.
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
] @=> float pitch_set[];

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
  [E, E, A + 12],
  [E, A + 12, A + 12],
  [E, B + 12, B + 12],
  [E, Fs, B + 12],
  [Fs, Gs, Cs + 12],
  [Fs, A + 12, Cs + 12],
  [Fs, Gs, B + 12],
  [Cs, Gs, B + 12],
  [Fs, Gs, A + 12],
  [E, Fs, A + 12]

] @=> int upperChords[][];


/* ======== comb filter setup ======== */
KSChord l_ksChord;
KSChord r_ksChord;
l_ksChord => ADSR l_comb_adsr => l_comb_gain;  // connect to gain
r_ksChord => ADSR r_comb_adsr => r_comb_gain;  // connect to gain

l_comb_adsr.keyOn(); // default open.
r_comb_adsr.keyOn(); // default open.

l_ksChord.init(lowerChords[0].size());  // initialize number of voices
r_ksChord.init(upperChords[0].size());  // initialize number of voices
0. => l_ksChord.feedback; // no feedback
0. => r_ksChord.feedback; // no feedback


// left joystick
// create_granulator("./Samples/Field/thunder.wav", "field", ksChord) @=> Granulator l_granulator;
// create_granulator("./Samples/Field/thunder.wav", "field", ksChord) @=> Granulator l_granulator;
// create_granulator("./Samples/Field/birds.wav", "field", ksChord) @=> Granulator l_granulator;
// create_granulator("./Samples/Field/bumblebees.wav", "field", ksChord) @=> Granulator l_granulator;
// create_granulator("./Samples/Field/wind.wav", "field", ksChord) @=> Granulator l_granulator;
// create_granulator("./Samples/Field/frozen-pond.wav", "field", l_field_gain) @=> Granulator l_granulator;
create_granulator("./Samples/Field/thunder.wav", "field", l_ksChord) @=> Granulator l_granulator;
l_granulator.connect(l_field_gain); // dry, no comb filtering

// right joystick
create_granulator("./Samples/Field/frozen-pond.wav", "field", r_ksChord) @=> Granulator r_granulator;
r_granulator.connect(r_field_gain); // dry, no comb filtering

// create_granulator("./Samples/Drones/male-choir.wav", "drone", l_comb_gain) @=> Granulator l_voice;

// create_granulator("./Samples/Field/beach-with-people.wav", "field", r_field_gain) @=> Granulator r_granulator;
// create_granulator("./Samples/Field/spring-rain.wav", "field", r_field_gain) @=> Granulator r_granulator;
// create_granulator("./Samples/Field/footsteps-on-grass.wav", "field", r_field_gain) @=> Granulator r_granulator;
// create_granulator("./Samples/Field/wind.wav", "field", r_field_gain) @=> Granulator r_granulator;

// create_granulator("./Samples/Drones/female-choir.wav", "drone", r_comb_gain) @=> Granulator r_voice;


fun Granulator create_granulator(string filepath, string type, UGen @ out) {
  Granulator drone;
  drone.init(filepath, out);

  spork ~ drone.cycle_pos();  // TODO: copy more accurate cycle_pos from migm
  spork ~ drone.granulate();

  return drone;
}

fun void assign_voice_freqs(int which, Granulator @ voice) {
  voice.GRAIN_PLAY_RATE => float rate;
  if (which == gt.LZ) {  // lower voice
    while (Util.approx(rate, voice.GRAIN_PLAY_RATE))
      pitch_set[Math.random2(7, 12)] => rate;
  } else { // upper voice
    while (Util.approx(rate, voice.GRAIN_PLAY_RATE))
      pitch_set[Math.random2(0, 6)] => rate;
  }
  rate => voice.GRAIN_PLAY_RATE;
}


/*========== Gametrack granulation control fns ========*/
.015 => float GT_Z_DEADZONE;
1.0 => float GT_Z_COMPRESSION;

fun float get_grain_pos(float z) {  // maps z to [0,1]
  return Math.max(0, ( z - GT_Z_DEADZONE ));
  // Math.max(0, ( z - GT_Z_DEADZONE )) * GT_Z_COMPRESSION + Math.random2f(0,.0001) => float pos;
}

fun dur get_field_grain_size(float x) {
  return Util.remap(-1., 1., 5, 30, x)::ms; 
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
fun void field_voice_crossfader( 
  int x, int y, int z, 
  Granulator @ granulator, 
  Gain @ field_gain,  // dry gain
  Gain @ comb_gain, // gain coming through kschord
  KSChord @ ksChord
  // TODO: add more mod effects? rev / delay / distortion / chorus / Lowpass ...
) {
  .27 => float Z_BEGIN_COMB;
  .48 => float Z_COMB_MAX;
  .98 => float MAX_FEEDBACK;
  false => int in_comb_region;

  while (true) {
    // update granulator positions
      // don't update position, now we cycle
    // get_grain_pos(gt.curAxis[z]) => granulator.GRAIN_POSITION;
    
    get_grain_rate(gt.curAxis[x]) => granulator.GRAIN_PLAY_RATE;
    get_field_grain_size(gt.curAxis[y]) => granulator.GRAIN_LENGTH;
    // Util.print("play rate: " + granulator.GRAIN_PLAY_RATE + " |  grain length: " + granulator.GRAIN_LENGTH / 1::ms);


    // z axis silent deadzone
    if (gt.curAxis[z] < Z_DEADZONE_CUTOFF) {
      0 => comb_gain.gain;
      0 => field_gain.gain;
      // Util.clamp01(Util.remap(0, Z_DEADZONE_CUTOFF, 0, 0, gt.curAxis[z])) => field_gain.gain;
    } else if (gt.curAxis[z] >= Z_DEADZONE_CUTOFF && gt.curAxis[z] < Z_BEGIN_COMB) {
      // map field gain from  [cutoff, begin_comb] --> [0, 1]
      Util.remap01(Z_DEADZONE_CUTOFF, Z_BEGIN_COMB, 0, 1, gt.curAxis[z]) => field_gain.gain;

      if (in_comb_region) {
        false => in_comb_region;
      }
    } else { // comb region
      true => in_comb_region;
      Util.remap01(Z_BEGIN_COMB, Z_COMB_MAX, 0, 1, gt.curAxis[z]) => float z_percentage;
      // (gain_level * .5) + .5 => field_gain.gain;  // remap to [1, .5]
        // TODO: should we scale down field gain here?
      z_percentage => comb_gain.gain;

      // Util.print("comb gain: " + comb_gain.gain());
      // Util.print("field gain: " + field_gain.gain());

      // set comb filter feedback
        // TODO: map through logistic function, because feedback >.9 is much more sensitive
      Util.lerp(0, MAX_FEEDBACK, z_percentage) => float feedback;
      feedback => ksChord.feedback;
      // Util.print("kschord feedback: " + feedback);

      // lerp voice grain length
        // TODO: try scaling granulator grain length?
      // Util.remap(0, Z_COMB_MAX, 10, 500, gt.curAxis[z])::ms => voice.GRAIN_LENGTH;

      if (gt.curAxis[z] >= Z_COMB_MAX) {
        // TODO: add instrumental drone source? E.g. voice or electronic drone

        // chorus tremolo
          // update: sounds awful lol
        // Util.remap(-1, 1, 0, 1, gt.curAxis[y]) => chorus.modDepth;
        // Util.remap(-1, 1, 0, 4, gt.curAxis[x]) => chorus.modFreq;

      }
    }
    
    // gt.print();
    10::ms => now;
  }
}

/* currently unused */
fun void combFilterController(int z, KSChord @ ksChord) {
  .5 => float COMB_FEEDBACK_MAX_Z; // z position at max feedback
  .98 => float MAX_FEEDBACK;

  while (true) {
    gt.curAxis[z] => float cur_z;
    Util.remap01(Z_DEADZONE_CUTOFF, COMB_FEEDBACK_MAX_Z, 0, 1, cur_z) => float z_percentage;

    // TODO: map through logistic function, because feedback >.9 is much more sensitive
    Util.lerp(0, MAX_FEEDBACK, z_percentage) => float feedback;
    feedback => ksChord.feedback;
    Util.print("kschord feedback: " + feedback);


    10::ms => now;
  }
}

312 => float PULSE_BPM;
fun void combFilterPitcher(KSChord @ ksChord, ADSR @ comb_adsr, int chords[][]) {
  // -24 => int x;  // octave offset
  // while (true) {
  //   [60, 64, 67, 71, 72, 71, 67, 64] @=> int arp[];
  //   for (int i; i < arp.cap(); i++) {
  //       ksChord.tune( [arp[i]+x] );
  //       200::ms => now;
  //   }
  // }

  0 => int chord_idx;
  chords[chord_idx] => ksChord.tune;

  // pulse the chord
  Util.bpmToQtNote(PULSE_BPM) => dur pulse_dur;
  spork ~ combFilterPulser(comb_adsr, pulse_dur / 2, pulse_dur / 2);
  spork ~ combFilterHandWidth(comb_adsr);

  while (true) {
    gt.buttonPressEvent => now;
    (chord_idx + 1) % chords.size() => chord_idx;
    chords[chord_idx] => ksChord.tune;
    <<< "next chord", chord_idx >>>;
  }
}

// scales adsr gain according to hand width
// pulses more loudly at greater width
fun void combFilterHandWidth(ADSR @ comb_adsr) {
  170 => float MAX_WIDTH;
  while (true) {
    Util.remap01(0, MAX_WIDTH, .1, 1, gt.GetXZPlaneHandDist()) => float width_percentage;
    // (1 - width_percentage) => comb_adsr.sustainLevel;
      // cross between drone and pulse?
    // width_percentage => comb_adsr.sustainLevel;
    // width_percentage * 5::second => comb_adsr.releaseTime;
    
    width_percentage => comb_adsr.gain;
    // <<< comb_adsr.sustainLevel() >>>;
    20::ms => now;
  }

}

fun void combFilterPulser(ADSR @ comb_adsr, dur pulse_on, dur pulse_off) {
  // TODO: map pulse to some parameter, maybe hand width
    // give the option to transition between sustained chord and pulsed chord
  // set envelope
  comb_adsr.set(
    20::ms,
    40::ms,
    .65,
    20::ms
  );
  while (true) {
    comb_adsr.keyOn();
    pulse_on => now;
    comb_adsr.keyOff();
    pulse_off => now;
  }
}


// left joy controls
spork ~ field_voice_crossfader(gt.LX, gt.LY, gt.LZ, l_granulator, l_field_gain, l_comb_gain, l_ksChord);
spork ~ combFilterPitcher(l_ksChord, l_comb_adsr, lowerChords);

// right joy controls
spork ~ field_voice_crossfader(gt.RX, gt.RY, gt.RZ, r_granulator, r_field_gain, r_comb_gain, r_ksChord);
// Util.bpmToQtNote(PULSE_BPM)/2 => now;
spork ~ combFilterPitcher(r_ksChord, r_comb_adsr, upperChords);

while (true) {
  1::second => now;
}
