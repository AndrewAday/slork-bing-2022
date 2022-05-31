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


public class SoundBoard extends Switchable {
    "SoundBoard" => this.NAME;
    /* signal flow */
    Gain mainGain => this.switch_gain;


    Sampler @ samplers[256];  // a sampler for every possible keycode

    fun void init(UGen @ out, int kbNum, int mouseNum) {
        this.init(out); // parent switchable

        // register samples
        registerSamples();
        // start soundboard
        startSoundBoard(kbNum, mouseNum);
    }

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
        // spork ~ _mousepadListener(mouseNum);

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

            if (!this.IS_ACTIVE) {
                continue;
            }

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
            if (!this.IS_ACTIVE) {
                20::ms => now;
                continue;
            }

            hi => now;
            while (hi.recv(msg)) {
                if (msg.isButtonDown() && msg.which == Util.KEY_TAB) {
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

    fun void registerSamples() {
        // QWERTY row -- oneshot bird
        registerSample(20, me.dir() + "/Samples/Bird/", "annas-hummingbird-oneshot.wav", Sampler.TYPE_ONESHOT);
        registerSample(26, me.dir() + "/Samples/Bird/", "chestnut-backed-chickadee-oneshot.wav", Sampler.TYPE_ONESHOT);
        registerSample(8, me.dir() + "/Samples/Bird/", "house-finch-oneshot.wav", Sampler.TYPE_ONESHOT);
        registerSample(21, me.dir() + "/Samples/Bird/", "house-sparrow-oneshot.wav", Sampler.TYPE_ONESHOT);
        registerSample(23, me.dir() + "/Samples/Bird/", "red-winged-blackbird-oneshot.wav", Sampler.TYPE_ONESHOT);
        registerSample(28, me.dir() + "/Samples/Bird/", "robin-oneshot.wav", Sampler.TYPE_ONESHOT);
        registerSample(24, me.dir() + "/Samples/Bird/", "song-sparrow-oneshot.wav", Sampler.TYPE_ONESHOT);

        // ASDFG row  -- conts bird
        registerSample(4, me.dir() + "/Samples/Bird/", "annas-hummingbird.wav", Sampler.TYPE_CONTS);
        registerSample(22, me.dir() + "/Samples/Bird/", "chestnut-backed-chickadee.wav", Sampler.TYPE_CONTS);
        registerSample(7, me.dir() + "/Samples/Bird/", "house-finch.wav", Sampler.TYPE_CONTS);
        registerSample(9, me.dir() + "/Samples/Bird/", "house-sparrow.wav", Sampler.TYPE_CONTS);
        registerSample(10, me.dir() + "/Samples/Bird/", "red-winged-blackbird.wav", Sampler.TYPE_CONTS);
        registerSample(11, me.dir() + "/Samples/Bird/", "robin.wav", Sampler.TYPE_CONTS);
        registerSample(13, me.dir() + "/Samples/Bird/", "song-sparrow.wav", Sampler.TYPE_CONTS);

        // ZXCVB row  -- conts field
        registerSample(29, me.dir() + "/Samples/Field/", "footsteps-on-grass.wav", Sampler.TYPE_CONTS);
        registerSample(27, me.dir() + "/Samples/Field/", "creek.wav", Sampler.TYPE_CONTS);
        registerSample(6, me.dir() + "/Samples/Field/", "spring-rain.wav", Sampler.TYPE_CONTS);
        registerSample(25, me.dir() + "/Samples/Field/", "wind.wav", Sampler.TYPE_CONTS);
        registerSample(5, me.dir() + "/Samples/Field/", "crickets.wav", Sampler.TYPE_CONTS);
        registerSample(17, me.dir() + "/Samples/Field/", "bumblebees.wav", Sampler.TYPE_CONTS);

    }
}




