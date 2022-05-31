public class Granulator {

  // overall volume
  1 => float MAIN_VOLUME;
  // grain duration base
  500::ms => dur GRAIN_LENGTH;
  // how much overlap when firing
  8 => float GRAIN_OVERLAP;
  // 1 => float GRAIN_OVERLAP;
  // factor relating grain duration to ramp up/down time
  .5 => float GRAIN_RAMP_FACTOR;
  // playback rate
  1 => float GRAIN_PLAY_RATE;
  0 => float GRAIN_PLAY_RATE_OFF;
  1. => float GRAIN_SCALE_DEG;
  1. =>  float RATE_MOD;  // for samples not on "C"

  // for seq voices only. offset by p4 or p5
  [1/2., 2/3., 3/4., 1., 4/3., 3/2., 2.] @=> float SEQ_OFFSETS[];
  3 => int seq_off_idx;

  // grain position (0 start; 1 end)
  .05 => float GRAIN_POSITION;
  // grain position goal (for interp)
  GRAIN_POSITION => float GRAIN_POSITION_GOAL;
  // grain position randomization
  .001 => float GRAIN_POSITION_RANDOM;
  // grain jitter (0 == periodic fire rate)
  // 1 => float GRAIN_FIRE_RANDOM;
  0 => float GRAIN_FIRE_RANDOM;

  // max lisa voices
  30 => int LISA_MAX_VOICES;
  string sample;

  0 => int MUTED;
  float SAVED_GAIN;

  /* SndBuf @ buffy; */
  LiSa @ lisa;
  PoleZero @ blocker;
  NRev @ reverb;
  ADSR @ adsr;  
  
  // for cycle pos
  TriOsc lfo => blackhole;
  .8 => float scrub_percentage;


  fun void init(string filepath, string type) {
    // messy i know...
    if (filepath == "lamonte.wav") {
      16/15. => RATE_MOD;
    }
    // load file into a LiSa (use one LiSa per sound)
    filepath => this.sample;
    if (type == "field") {
      this.load("Samples/Field/"+filepath) @=> this.lisa;
    } else {
      this.load("Samples/Drones/"+filepath) @=> this.lisa;
    }

    PoleZero p @=> this.blocker;
    NRev r @=> this.reverb;
    ADSR e @=> this.adsr;
    // reverb mix
    .05 => this.reverb.mix;
    // pole location to block DC and ultra low frequencies
    .99 => this.blocker.blockZero;

    // patch it
    if (type == "sequencer") {
      this.lisa.chan(0) => this.blocker => this.adsr => this.reverb => dac;
    } else if (type == "drone" || type == "field") {
      this.lisa.chan(0) => this.blocker => this.reverb => dac;
    }
  }

  fun void init(string filepath, UGen @ out) {
    // load file into a LiSa (use one LiSa per sound)
    filepath => this.sample;
    this.load(filepath) @=> this.lisa;

    PoleZero p @=> this.blocker;
    // NRev r @=> this.reverb;
    // ADSR e @=> this.adsr;

    // reverb mix
    // .05 => this.reverb.mix;

    // pole location to block DC and ultra low frequencies
    .99 => this.blocker.blockZero;

    // patch it
    this.lisa.chan(0) => this.blocker => out;
  }

  fun void connect(UGen @ out) {
    this.blocker => out;
  }

  fun void init(string filepath) {
    this.init(filepath, "drone");
  }

  fun void spork_interp() {
    spork ~ interp( .025, 5::ms );
  }

  // interp  TODO: interp the drone pitch?
  fun void interp( float slew, dur RATE )
  {
      while( true )
      {
          // interp grain position
          (this.GRAIN_POSITION_GOAL - this.GRAIN_POSITION)*slew + this.GRAIN_POSITION => this.GRAIN_POSITION;
          // interp rate
          RATE => now;
      }
  }

  fun void cycle_pos() {  // cycles pos back and forth across sample
    2 * scrub_percentage * this.lisa.duration() => lfo.period;  
    // TODO: lfo should be a triangle wave
    while (true) {
      (.5 + (this.scrub_percentage/2.0) * this.lfo.last()) => this.GRAIN_POSITION;
      20::ms => now;
    }
  }

  fun void granulate() {
    while( true ) {
      // fire a grain
      fireGrain();
      // amount here naturally controls amount of overlap between grains
      GRAIN_LENGTH / GRAIN_OVERLAP + Math.random2f(0,GRAIN_FIRE_RANDOM)::ms => now;
    }
  }

  fun dur get_grain_overlap() {
      return GRAIN_LENGTH / GRAIN_OVERLAP + Math.random2f(0,GRAIN_FIRE_RANDOM)::ms;
  }

  fun void mute() {
    <<< "muting" >>>;
    1 => this.MUTED;
    if (this.lisa.gain() < .01) { return; }
    this.lisa.gain() => SAVED_GAIN;
    0 => this.lisa.gain;
  }

  fun void mute(dur du) {
    <<< "muting" >>>;
    1 => this.MUTED;
    if (this.lisa.gain() < .01) { return; }
    this.lisa.gain() => SAVED_GAIN;
    now + du => time later;
    while (now < later) {
      ((later - now) / du) => this.lisa.gain;
      10::ms => now;
    }
  }

  fun void unmute(dur du) {
    <<< "unmuting" >>>;
    0 => this.MUTED;
    if (this.lisa.gain() > .01) { return; }
    now + du => time later;
    while (now < later) {
      SAVED_GAIN * (1 - ((later - now) / du)) => this.lisa.gain;
      10::ms => now;
    }
  }



  // fire!
  fun void fireGrain()
  {
      // grain length
      GRAIN_LENGTH => dur grainLen;
      // ramp time
      GRAIN_LENGTH * GRAIN_RAMP_FACTOR => dur rampTime;
      // play pos
      GRAIN_POSITION + Math.random2f(0,GRAIN_POSITION_RANDOM) => float pos;
      // a grain
      if( this.lisa != null && pos >= 0 )
          spork ~ grain(pos * this.lisa.duration(), grainLen, rampTime, rampTime,
          GRAIN_PLAY_RATE, GRAIN_PLAY_RATE_OFF, GRAIN_SCALE_DEG);
  }

  // grain sporkee
  fun void grain(dur pos, dur grainLen, dur rampUp, dur rampDown, float rate, float off, float deg )
  {
      // get a voice to use
      this.lisa.getVoice() => int voice;

      // if available
      if( voice > -1 )
      {
          // set rate

          this.lisa.rate( voice, RATE_MOD * rate * Math.pow(2, off) * deg ); // TODO: modify rate by offset here
          // set playhead
          this.lisa.playPos( voice, pos );
          // ramp up
          this.lisa.rampUp( voice, rampUp );
          // wait
          (grainLen - rampUp) => now;
          // ramp down
          this.lisa.rampDown( voice, rampDown );
          // wait
          rampDown => now;
      }
  }



  // load file into a LiSa
  fun LiSa load(string filename) {
    // sound buffer
    SndBuf buffy;
    // load it
    filename => buffy.read;

    // new LiSa
    LiSa lisa;
    // set duration
    buffy.samples()::samp => lisa.duration;

    // transfer values from SndBuf to LiSa
    for( 0 => int i; i < buffy.samples(); i++ )
    {
        // args are sample value and sample index
        // (dur must be integral in samples)
        lisa.valueAt( buffy.valueAt(i  * buffy.channels()), i::samp );
        // if (i % 10 == 0) {1::samp => now;}  // BUG FIX: stop the clicking, give time to dump buffer
        // if (i % 20 == 0) {1::samp => now;}  // try to load twice as fast
    }

    // set LiSa parameters
    lisa.play( false );
    lisa.loop( false );
    lisa.maxVoices( LISA_MAX_VOICES );

    return lisa;
  }

  // reload different sample into lisa
    // repeated code, i know :(
  fun void reload(string filepath) {
    // if (filepath == "lamonte.wav") {
    //   16/15. => RATE_MOD;  // shift up a halfstep
    // }
    // if (filepath == "tuvan.wav") {
    //   9/8. => RATE_MOD;  // shift up a wholestep
    // }

    filepath => this.sample;

    SndBuf buffy;
    filepath => buffy.read;

    // clear lisa buffer
    this.lisa.clear();
   
    // set duration
    buffy.samples()::samp => lisa.duration;
    // transfer values from SndBuf to LiSa
    for( 0 => int i; i < buffy.samples(); i++ )
    {
        // args are sample value and sample index
        // (dur must be integral in samples)
        lisa.valueAt( buffy.valueAt(i  * buffy.channels()), i::samp );
        // if (i % 10 == 0) {1::samp => now;}  // BUG FIX: stop the clicking, give time to dump buffer
        // if (i % 1000 == 0) {1::samp => now;}  // try to load twice as fast
    }

    // reset the cycle lfo period
    set_cycle_lfo_period();
  }

  fun void set_cycle_lfo_period() {
    // 2 * number of seconds in scrub region
    2 * scrub_percentage * this.lisa.duration() => lfo.period;  
  }

  // print
  fun void print() {
    // values
    <<< "pos:", GRAIN_POSITION, "random:", GRAIN_POSITION_RANDOM,
        "rate:", GRAIN_PLAY_RATE, "size:", GRAIN_LENGTH/second,
        "overlap: ", GRAIN_OVERLAP
    >>>;
    // advance time
    100::ms => now;
  }

}


// unit tests
/* fun void unit_test()
{
"drones/basal-1.wav" => string filepath;
Granulator gran;
gran.init(filepath);

<<< gran.lisa.duration() / second >>>;
gran.print();
gran.spork_interp();
spork ~ gran.cycle_pos();
spork ~ gran.granulate();
20::second => now;
<<< "muting" >>>;
gran.mute();
gran.unmute();
} */

/* unit_test(); */
