// name: drone.ck
// desc: gametrak instrument w good drone 
//
// author: Tess Rinaldo (trinaldo@ccrma.stanford.edu)
// date: spring 2022

// gametrack

public class Droner extends Switchable {
  "P1 Droner" => this.NAME;
  /* ============= signal flow =========== */ 
  Gain main_gain;
  .5 => main_gain.gain;

  NRev rev => Echo e1 => Echo e2 => main_gain => this.switch_gain;  // outlet
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

  // Granulators. initialized in init()
  Granulator @ ll_voice;
  Granulator @ lr_voice;
  Granulator @ rl_voice;
  Granulator @ rr_voice;

  // voice pitch set
  .5=> float F; // use this F for granulator. playback rate.
  [
    // F * (1/2.) * (3/2.) * 2,  // G
    F * (1/2.) * (5./4) * (2.), // E
    F * (1/2.) * (2.),  // C
    F * (1/2.) * (2.) * (9./8),  // D
    // F * (1/2.) * (15./8),  // B
    F * (1/2.) * (5/3.),  // A
    F * (1/2.) * (3/2.)  // G
  ] @=> float cMaj_hexachord_low[];

  /* ========= networked params ========= */
  int playerID;
  string PROCESSING_HOSTNAME;
  int PROCESSING_PORT;
  OscOut xmit;

  // assigns voice2 a different playrate from voice1
  fun void assign_voice_freqs(
    Granulator @ voice1, 
    Granulator @ voice2, 
    float freqs[]
  ) {
    voice1.GRAIN_PLAY_RATE => float rate;
    while (Util.approx(rate, voice1.GRAIN_PLAY_RATE)) {
      freqs[Math.random2(0, freqs.cap()-1)] => rate;
    }
    rate => voice2.GRAIN_PLAY_RATE;
  }

  fun Granulator create_granulator(string filepath, string type, UGen @ out) {
    Granulator drone;
    drone.init(filepath, out);
    // spork ~ drone.granulate();
    spork ~ this.switchable_granulator(drone);
    return drone;
  }


  fun void init_voices(float pitches_left[], float pitches_right[]) {
    // left
    assign_voice_freqs(ll_voice, lr_voice, pitches_left);
    assign_voice_freqs(lr_voice, ll_voice, pitches_left);

    // right
    assign_voice_freqs(rl_voice, rr_voice, pitches_right);
    assign_voice_freqs(rr_voice, rl_voice, pitches_right);
  }

  .0 => float Z_BEGIN_VOICE;
  0.08 => float Z_VOICE_MAX;

  -1. => float X_BEGIN_VOICE;
  1. => float X_VOICE_MAX;

  [0, 0] @=> int prev_side[]; // 0 left 1 right
  fun void play(
    GameTrack @ gt,
    int which,
    int x, int y, int z, 
    Granulator @ ll_voice,
    Granulator @ lr_voice, 
    Gain @ ll_voice_gain, 
    Gain @ lr_voice_gain,
    float pitchSet[] 
  ) {
    // moved to left
    if (Util.approxWithin(gt.curAxis[x], -1, 0.1) && prev_side[which] == 1) {
      assign_voice_freqs(ll_voice, lr_voice, pitchSet);
      0 => prev_side[which];
    }
    // moved to right
    if (Util.approxWithin(gt.curAxis[x], 1, 0.1) && prev_side[which] == 0) {
      assign_voice_freqs(lr_voice, ll_voice, pitchSet);
      1 => prev_side[which];
    }

    Util.clamp01(Util.remap(X_BEGIN_VOICE, X_VOICE_MAX, 0, 1, gt.curAxis[x])) => float temp;
    // <<< temp >>>;
    // (1 - temp) * 2 => voice_gain.gain;
    (1 - temp)  * Util.remap01(gt.Z_DEADZONE, Z_VOICE_MAX, 0, 1, gt.curAxis[z]) => ll_voice_gain.gain;
    temp  * Util.remap01(gt.Z_DEADZONE, Z_VOICE_MAX, 0, 1, gt.curAxis[z]) => lr_voice_gain.gain;
    // (1 - temp) => ll_voice_gain.gain;

    // lerp voice grain length
    Util.remap(0, Z_VOICE_MAX, 100, 500, gt.curAxis[z])::ms => ll_voice.GRAIN_LENGTH;
    Util.remap(0, Z_VOICE_MAX, 100, 500, gt.curAxis[z])::ms => lr_voice.GRAIN_LENGTH;
    // <<< voice_gain.gain() >>>;
  }

  fun void init(
    UGen @ out, int playerID, 
    string processing_hostname, int processing_port,
    string left_sample, string right_sample
  ) {
    this.init(out); // base class
    
    // assign network params
    playerID => this.playerID;
    processing_hostname => this.PROCESSING_HOSTNAME;
    processing_port => this.PROCESSING_PORT;

    // initialize network
    this.xmit.dest( this.PROCESSING_HOSTNAME, this.PROCESSING_PORT );


    // left left joystick
    create_granulator(left_sample, "drone", ll_voice_gain) @=> this.ll_voice;
    // left right joystick
    create_granulator(left_sample, "drone", lr_voice_gain) @=> this.lr_voice;

    // right left joystick
    create_granulator(right_sample, "drone", rl_voice_gain) @=> this.rl_voice;
    // right right joystick
    create_granulator(right_sample, "drone", rr_voice_gain) @=> this.rr_voice;

    // asign initial pitches
    init_voices(cMaj_hexachord_low, cMaj_hexachord_low);
  }

  fun void gt_update(GameTrack @ gt) {
    play(gt, 0, gt.LX, gt.LY, gt.LZ, ll_voice, lr_voice, ll_voice_gain, lr_voice_gain, cMaj_hexachord_low);
    play(gt, 1, gt.RX, gt.RY, gt.RZ, rl_voice, rr_voice, rl_voice_gain, rr_voice_gain, cMaj_hexachord_low);
  }

  fun void processing_update(GameTrack @ gt) {
    // only player 0 sends gametrack info to processing
    if (playerID != 0) return;

    xmit.start( "/gametrak" );
    Util.remap01(-1, 1, 0, 1, gt.curAxis[gt.LX]) => float tmp;
    // <<< tmp >>>;
    tmp => xmit.add;
    xmit.send();

    // <<< "what" >>>;
  }
}

// unit_test();

fun void unit_test() {
  // gametrack
  GameTrack gt;
  gt.init(0);

  Droner droner;
  // TODO: maybe cello here instead? save human voice for end?
  droner.init(
    dac, 
    0, "localhost", 6450,
    "./Samples/Drones/male-choir.wav", "./Samples/Drones/female-choir.wav"
  );
  droner.activate();

  while (true) { 
    droner.gt_update(gt);
    10::ms => now; 
  }
}