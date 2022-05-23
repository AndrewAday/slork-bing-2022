/*
// keyboard control (also see kb() below):
//       <-- z axis --> = grain position
//       <--- y axis ---> = grain rate / tuning
//       <---x axis---> = grain size
*/

// gametrack
GameTrack gt;
gt.init(0);

// signal flow
2 => int NUM_CHANNELS;
// 6 => int NUM_CHANNELS;
Gain main_gain;
Util.patchToDAC(NUM_CHANNELS, main_gain);


Gain l_field_gain; Gain l_voice_gain;
Gain r_field_gain; Gain r_voice_gain;

Chorus l_chorus, r_chorus; 
NRev rev => Echo e1 => Echo e2 => main_gain;
l_chorus => rev; r_chorus => rev;

// patch both rev and echo to main_gain.
// patching rev allows the undelayed signal to pass through
rev => main_gain;

// echo settings
.75::second => e1.max => e1.delay;
1.5::second => e2.max => e2.delay;
.8 => e1.gain;
.6 => e2.gain;

NRev field_rev => main_gain;

// rev settings
.01 => field_rev.mix; // TODO: have rev? do we want contrast wet vocal / dry field, or both wet?
.5 => rev.mix;

// chorus settings
.8 => l_chorus.mix => r_chorus.mix;
.2 => l_chorus.modFreq => r_chorus.modFreq;
.07 => l_chorus.modDepth => r_chorus.modDepth;

// l_field_gain => main_gain;
// r_field_gain => main_gain;
l_field_gain => field_rev;
r_field_gain => field_rev;

l_voice_gain => l_chorus;
r_voice_gain => r_chorus;

.0 => l_field_gain.gain; .0 => l_voice_gain.gain;
.0 => r_field_gain.gain; .0 => r_voice_gain.gain;

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

// TODO: add ending with hard-coded, networked chord progression?
// TODO: comb filter the field recordings?
// TODO: get more samples!!!
// TODO: try walking in circle choreo!

// left joystick
create_granulator("./Samples/Field/thunder.wav", "field", l_field_gain) @=> Granulator l_granulator;
// create_granulator("./Samples/Field/birds.wav", "field", l_field_gain) @=> Granulator l_granulator;
// create_granulator("./Samples/Field/bumblebees.wav", "field", l_field_gain) @=> Granulator l_granulator;
// create_granulator("./Samples/Field/frozen-pond.wav", "field", l_field_gain) @=> Granulator l_granulator;

create_granulator("./Samples/Drones/male-choir.wav", "drone", l_voice_gain) @=> Granulator l_voice;

// right joystick
create_granulator("./Samples/Field/beach-with-people.wav", "field", r_field_gain) @=> Granulator r_granulator;
// create_granulator("./Samples/Field/spring-rain.wav", "field", r_field_gain) @=> Granulator r_granulator;
// create_granulator("./Samples/Field/footsteps-on-grass.wav", "field", r_field_gain) @=> Granulator r_granulator;
// create_granulator("./Samples/Field/wind.wav", "field", r_field_gain) @=> Granulator r_granulator;

create_granulator("./Samples/Drones/female-choir.wav", "drone", r_voice_gain) @=> Granulator r_voice;

// granulator config
10::ms => r_voice.GRAIN_LENGTH;
10::ms => l_voice.GRAIN_LENGTH;
assign_voice_freqs(gt.RZ, r_voice);
assign_voice_freqs(gt.LZ, l_voice);

10::ms => l_granulator.GRAIN_LENGTH;
10::ms => r_granulator.GRAIN_LENGTH;


fun Granulator create_granulator(string filepath, string type, UGen @ out) {
  Granulator drone;
  drone.init(filepath, out);

//   gain => drone.lisa.gain;
//   off => drone.GRAIN_PLAY_RATE_OFF;
//   deg => drone.GRAIN_SCALE_DEG;

  // spork ~ drone.cycle_pos();
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
  return Util.remap(-1., 1., 5, 25, x)::ms; 
}

fun dur get_voice_grain_size(float z) {
  return Util.remap(0, .5, 10, 500, z)::ms;
}

fun float get_grain_rate(float y) {
  return Util.remap(-1., 1., .5, 2.0, y);
}

fun float get_grain_gain(float z) {
  return Util.clamp01(Util.remap(0, .5, 1, 0, z));
}

// controls granular synthesis mapping to gametrak, + cross fade to voice
GT_Z_DEADZONE => float Z_DEADZONE_CUTOFF;
.27 => float Z_BEGIN_VOICE;
.48 => float Z_VOICE_MAX;
fun void field_voice_crossfader( 
  int x, int y, int z, 
  Granulator @ granulator, Gain @ field_gain,
  Granulator @ voice, Gain @ voice_gain,
  Chorus @ chorus
) {
  false => int in_voice_region;
  while (true) {
    // update granulator positions
    get_grain_pos(gt.curAxis[z]) => granulator.GRAIN_POSITION;
    get_grain_rate(gt.curAxis[y]) => granulator.GRAIN_PLAY_RATE;
    get_field_grain_size(gt.curAxis[x]) => granulator.GRAIN_LENGTH;


    // lerp gain between field recording and voice
    // z axis silent deadzone
    if (gt.curAxis[z] < Z_DEADZONE_CUTOFF) {
      0 => voice_gain.gain;
      0 => field_gain.gain;
      // Util.clamp01(Util.remap(0, Z_DEADZONE_CUTOFF, 0, 0, gt.curAxis[z])) => field_gain.gain;
    } else if (gt.curAxis[z] >= Z_DEADZONE_CUTOFF && gt.curAxis[z] < Z_BEGIN_VOICE) {
      // map field gain from  [cutoff, begin_voice] --> [0, 1]
      Util.clamp01(Util.remap(Z_DEADZONE_CUTOFF, Z_BEGIN_VOICE, 0, 1, gt.curAxis[z])) => field_gain.gain;
      // <<< field_gain.gain() >>>;
      // hold field sample at gain = 1, voice at gain = 0
      if (in_voice_region) {
        // exiting voice region
        false => in_voice_region;
        <<< "reassigning" , z >>>;
        assign_voice_freqs(z, voice);
      }
    } else { // voice region
      // at z = 0, r_field_gain = 1, r_voice_gain = 0
      // at z = .5, r_field_gain = 0, r_voice_gain = 1
      true => in_voice_region;
      Util.clamp01(Util.remap(Z_BEGIN_VOICE, Z_VOICE_MAX, 1, 0, gt.curAxis[z])) => field_gain.gain;
      (1 - field_gain.gain()) * 2 => voice_gain.gain;

      // lerp voice grain length
      Util.remap(0, Z_VOICE_MAX, 10, 500, gt.curAxis[z])::ms => voice.GRAIN_LENGTH;
 
      if (gt.curAxis[z] >= Z_VOICE_MAX) {
        // TODO: add slight tremolo, vibrato?

        // chorus tremolo
          // update: sounds awful lol
        // Util.remap(-1, 1, 0, 1, gt.curAxis[y]) => chorus.modDepth;
        // Util.remap(-1, 1, 0, 4, gt.curAxis[x]) => chorus.modFreq;

      }
      

      // TODO: lerp target pitch?
    }
    
    // lerp voice grain length from 10::ms --> 500::ms
    
    // gt.print();
    10::ms => now;
  }
}

// right joy controls
spork ~ field_voice_crossfader(gt.RX, gt.RY, gt.RZ, r_granulator, r_field_gain, r_voice, r_voice_gain, r_chorus);
// left joy controls
spork ~ field_voice_crossfader(gt.LX, gt.LY, gt.LZ, l_granulator, l_field_gain, l_voice, l_voice_gain, l_chorus);

while (true) {
  10::ms => now;
}
