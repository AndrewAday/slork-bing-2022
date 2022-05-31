public class Sampler {
    LiSa lisa;
    SndBuf sndbuf;
    PoleZero p;
    Event playContsOffEvent;

    string sample;

    0 => static int TYPE_ONESHOT;
    1 => static int TYPE_CONTS;
    int type;
    
    false => int loaded;
    0::ms => dur lastContsPlayPos;

    // patch lisa to out
    fun void patch(UGen @ out) {
        .99 => p.blockZero;
        lisa.chan(0) => p => out;
    }

    // load sample into lisa
    fun void load(string path, string filename, int type) {
        if (loaded) {
            <<< "error: sampler already loaded, reloading not handled" >>>;
            return;
        }

        filename => this.sample;
        type => this.type;
        path + filename => sndbuf.read;

        // <<< "channels: ", sndbuf.channels() >>>;

        sndbuf.samples()::samp => lisa.duration;
        for (0 => int i; i < sndbuf.samples(); i++) {
            lisa.valueAt(sndbuf.valueAt(i  * sndbuf.channels()), i::samp );
        }
        lisa.play(false);
        lisa.loop(false);
        lisa.maxVoices(25);  // max number of concurrent samples

        true => loaded;

        <<< "loaded: ", sample >>>;
    }

    fun int _tryGetVoice() {
        if (!loaded) {
            <<< "error: trying to play lisa before loading sample" >>>; 
            return -1; 
        }

        lisa.getVoice() => int voice;
        if (voice < 0) {
            <<< "cannot play sample, hit max voice threshold: ", lisa.maxVoices() >>>;
            return -1;
        }

        return voice;
    }

    // fire a sample once, to play from start to finish
    fun void playOneshot() {
        _tryGetVoice() => int voice;
        if (voice < 0) return;

        500::ms => dur rampDownDur;


        lisa.loop(voice, false);
        lisa.playPos(voice, 0::ms); 
        lisa.rate(voice, 1); // set playrate

        lisa.play(voice, true);
        lisa.duration() - rampDownDur => now;
        lisa.rampDown(voice, rampDownDur);
    }

    // loops sample as long as key is held down
    fun void playContinuous() {
        2::second => dur RAMP_TIME;

        // _tryGetVoice() => int voice;
        // if (voice < 0) return;

        0 => int voice; // always use the same voice

        lisa.loop(voice, true);
        lisa.playPos(voice, this.lastContsPlayPos);
        lisa.rate(voice, 1);

        lisa.rampUp(voice, RAMP_TIME);

        playContsOffEvent => now; // wait for key off

        lisa.rampDown(voice, RAMP_TIME);
        lisa.playPos(voice) => this.lastContsPlayPos;  // save where we left off

        // <<< lisa.playPos(voice) / Util.getFS() >>>;
        // lisa.loop(voice, false); // turn off looping to free voice
    }

    fun void play() {
        Util.print("\n    playing: " + this.sample + "\n");
        if (type == TYPE_CONTS) {
            spork ~ playContinuous();
        } else if (type == TYPE_ONESHOT) {
            spork ~ playOneshot();
        }
    }

    fun void stop() {  // only applies to conts samples
        if (this.type == TYPE_CONTS) {
            Util.print("\n    stopping: " + this.sample + "\n");
            playContsOffEvent.broadcast();
        }
    }
}