/*

Birdcalls:
- American Robin
- Sparrows
    - Song Sparrow
    - House Sparrow
- chestnut-backed chickadee 
- House Finch
- Anna's Humming Bird
- Northern Mockingbird
- Doves
    - Mourning Dove
    - Eurasian Collared Dove
- Western Scrub Jay
- Red-winged blackbird


Questions
- what is Lisa.bi() ?
*/

class Sampler {
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

class SoundBoard {
    /* signal flow */
    Gain mainGain;


    Sampler @ samplers[256];  // a sampler for every possible keycode

    fun void patch(UGen @ out) {
        mainGain => out;
    }

    // registers sample at path to the given keycode
    fun void registerSample(int keyCode, string path, string filename, int type) {
        if (samplers[keyCode] != null) {
            <<< "error sampler already exists at key: ", keyCode >>>;
            return;
        }

        Sampler sampler;
        sampler.load(path, filename, type);
        sampler.patch(mainGain);
        sampler @=> samplers[keyCode];
    }

    // begin listening to keyboard input
    fun void startSoundBoard(int kbNum, int mouseNum) {

        spork ~ _keyboardListener(kbNum);
        spork ~ _mousepadListener(mouseNum);

        1::second => now;
        Util.print("~~~~~ soundboard ready! ~~~~~"); 
        Util.print("Press <TAB> to print docs"); 
    }


    fun void play(int keyCode) {
        if (samplers[keyCode] == null) {
            <<< keyCode, " not loaded" >>>;
            return;
        }

        samplers[keyCode].play();
    }

    fun void stop(int keyCode) {
        if (samplers[keyCode] == null) {
            return;
        }

        samplers[keyCode].stop();
    }

    fun void _mousepadListener(int mouseNum) {
        Hid hi;
        HidMsg msg;

        // open mouse 0, exit on fail
        if( !hi.openMouse( mouseNum ) ) me.exit();

        <<< "mousepad found" >>>; 

        // infinite event loop
        while( true )
        {
            // wait on HidIn as event
            hi => now;

            // messages received
            while( hi.recv( msg ) )
            {
                // mouse motion
                if( msg.isMouseMotion() )
                {
                    // axis of motion
                    if( msg.deltaX ) {
                    }
                    else if( msg.deltaY ) {
                        Math.max(0, (-(msg.deltaY * .001) + mainGain.gain())) => mainGain.gain;
                        <<< mainGain.gain() >>>;
                    }
                }
                
                // mouse button down
                else if( msg.isButtonDown() )
                {
                    // <<< "mouse button", msg.which, "down" >>>;
                }
                
                // mouse button up
                else if( msg.isButtonUp() )
                {
                    // <<< "mouse button", msg.which, "up" >>>;
                }

                // mouse wheel motion (requires chuck 1.2.0.8 or higher)
                else if( msg.isWheelMotion() )
                {
                    // axis of motion
                    // if( msg.deltaX )
                    // {
                    //     <<< "mouse wheel:", msg.deltaX, "on x-axis" >>>;
                    // }            
                    // else if( msg.deltaY )
                    // {
                    //     <<< "mouse wheel:", msg.deltaY, "on y-axis" >>>;
                    // }
                }
            }
        }

    }

    fun void _keyboardListener(int deviceNum) {
        Hid hi;
        HidMsg msg;

        if (hi.openKeyboard(deviceNum) == 0) {
            me.exit();
        }

        <<< "keyboard found" >>>;

        while (true) {
            hi => now;
            while (hi.recv(msg)) {
                if (msg.isButtonDown() && msg.which == 43) {
                    printDocs();
                    continue;
                }
                if (msg.isButtonDown()) {  // key on
                    // <<< "down:", msg.which >>>;
                    play(msg.which);
                }
                else {  // key off
                    // <<< "up:", msg.which >>>;
                    stop(msg.which);
                }
            }
        }
    }

    //array with key codes, for MacBook anyhow
    [ 	

    // [30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 45, 46, 42],	//1234... row
    [20, 26, 8, 21, 23, 28, 24, 12, 18, 19, 47, 48, 49],	//qwer... row
    [4, 22, 7, 9, 10, 11, 13, 14, 15, 51, 52],		//asdf... row
    [29, 27, 6, 25, 5, 17, 16, 54, 55, 56]   		//zxcv... row

    ]   @=> int ROWS[][];

    [
        "QWERTY... samples (ONESHOT -- press to play)", 
        "ASDFG... samples (CONTS -- press to play, lift to stop)",
        "ZXCVB... samples (CONTS)"
    ] @=> string rowNames[];

    fun void printDocs() {
        for (0 => int i; i < ROWS.size(); i++) {
            Util.print("\n==================" + rowNames[i] + "==================");
            for (0 => int j; j < ROWS[i].size(); j++) {
                if (samplers[ROWS[i][j]] == null)
                    break;
                Util.print("  " + j + ":  " + samplers[ROWS[i][j]].sample);
            }
        }

    }
}

SoundBoard sb;

// QWERTY row -- oneshot bird
sb.registerSample(20, me.dir() + "/Samples/Bird/", "annas-hummingbird-oneshot.wav", Sampler.TYPE_ONESHOT);
sb.registerSample(26, me.dir() + "/Samples/Bird/", "chestnut-backed-chickadee-oneshot.wav", Sampler.TYPE_ONESHOT);
sb.registerSample(8, me.dir() + "/Samples/Bird/", "house-finch-oneshot.wav", Sampler.TYPE_ONESHOT);
sb.registerSample(21, me.dir() + "/Samples/Bird/", "house-sparrow-oneshot.wav", Sampler.TYPE_ONESHOT);
sb.registerSample(23, me.dir() + "/Samples/Bird/", "red-winged-blackbird-oneshot.wav", Sampler.TYPE_ONESHOT);
sb.registerSample(28, me.dir() + "/Samples/Bird/", "robin-oneshot.wav", Sampler.TYPE_ONESHOT);
sb.registerSample(24, me.dir() + "/Samples/Bird/", "song-sparrow-oneshot.wav", Sampler.TYPE_ONESHOT);

// ASDFG row  -- conts bird
sb.registerSample(4, me.dir() + "/Samples/Bird/", "annas-hummingbird.wav", Sampler.TYPE_CONTS);
sb.registerSample(22, me.dir() + "/Samples/Bird/", "chestnut-backed-chickadee.wav", Sampler.TYPE_CONTS);
sb.registerSample(7, me.dir() + "/Samples/Bird/", "house-finch.wav", Sampler.TYPE_CONTS);
sb.registerSample(9, me.dir() + "/Samples/Bird/", "house-sparrow.wav", Sampler.TYPE_CONTS);
sb.registerSample(10, me.dir() + "/Samples/Bird/", "red-winged-blackbird.wav", Sampler.TYPE_CONTS);
sb.registerSample(11, me.dir() + "/Samples/Bird/", "robin.wav", Sampler.TYPE_CONTS);
sb.registerSample(13, me.dir() + "/Samples/Bird/", "song-sparrow.wav", Sampler.TYPE_CONTS);

// ZXCVB row  -- conts field
sb.registerSample(29, me.dir() + "/Samples/Field/", "footsteps-on-grass.wav", Sampler.TYPE_CONTS);
sb.registerSample(27, me.dir() + "/Samples/Field/", "creek.wav", Sampler.TYPE_CONTS);
sb.registerSample(6, me.dir() + "/Samples/Field/", "spring-rain.wav", Sampler.TYPE_CONTS);
sb.registerSample(25, me.dir() + "/Samples/Field/", "wind.wav", Sampler.TYPE_CONTS);
sb.registerSample(5, me.dir() + "/Samples/Field/", "crickets.wav", Sampler.TYPE_CONTS);
sb.registerSample(17, me.dir() + "/Samples/Field/", "bumblebees.wav", Sampler.TYPE_CONTS);

// start soundboard
sb.startSoundBoard(0, 3);
sb.patch(dac);

while (true) {
    10::ms => now;
}



