//array with key codes, for MacBook anyhow
[ 	
    [30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 45, 46, 42],	//1234... row
    [20, 26, 8, 21, 23, 28, 24, 12, 18, 19, 47, 48, 49],	//qwer... row
    [4, 22, 7, 9, 10, 11, 13, 14, 15, 51, 52],		//asdf... row
    [29, 27, 6, 25, 5, 17, 16, 54, 55, 56]   		//zxcv... row
] @=> int row[][];

// scale
[Util.C, Util.D, Util.E, Util.G, Util.A, Util.B] @=> int scale[]; 

int keyToPitch_table[256];
Event noteOffs[256];

//tune them strings in 5ths
tuneString(3, 0, scale, -2);
tuneString(2, 0, scale, -1);
tuneString(1, 0, scale, 0);
tuneString(0, 0, scale, 1);

startInstrument();


//our big array of pitch values, indexed by ASCII value
//this function takes each row and tunes it in half steps, based
//on whatever fundamental pitch note specified
fun void tuneString(int whichString, int scaleIdx, int scale[], int octaveOff) {
	
	for (0 => int i; i < row[whichString].cap(); i++) {
        if (scaleIdx >= scale.size()) {
            0 => scaleIdx; // wrap around
            1 +=> octaveOff;
        }

        scale[scaleIdx] + (12 * octaveOff) => keyToPitch_table[row[whichString][i]];
        1 +=> scaleIdx;

		<<<row[whichString][i], keyToPitch_table[row[whichString][i]]>>>;
	}
	
}


fun void keysound(float freq, Gain @ g, Event noteOff) {
	// SinOsc sine => ADSR envelope => dac;
	// envelope.set(20::ms, 25::ms, 0.1, 150::ms);

    // BeeThree org => g;

    Envelope env => g;
    20::ms => env.duration;

    FM @ org;

    if (freq > 260.0 * 4.9/8.) {
        KrstlChr choir => env;
        choir.opAM(0,0.4);
        choir.opAM(2,0.4);
        choir.opADSR(0, 0.1, 2, 0.6, 1);
        Math.random2f(1.5,1.6) => choir.lfoSpeed;
        // choir.opADSR(1, 0.1, 2, 0.6, 0.1);
        // choir.opADSR(2, 0.1, 2, 0.6, 0.1);

        // for some reason it's a fifth lower?
        1.5 *=> freq;

        choir @=> org;
    } else {
        HnkyTonk hnky => env;
        hnky.opAM(0, 0.04);
        Math.random2f(3.95,5.05) => hnky.lfoSpeed;
        hnky.opADSR(0, 0.1, 2, 1, 1);

        hnky @=> org;
    }

    .25 => org.gain;
    freq => org.freq;
	
	// org.keyOn();
    env.keyOn();
    1 => org.noteOn;

	noteOff => now;
	// org.keyOff();
    0 => org.noteOff;

	3::second => now;
	
	// org =< g;
    env =< g;
}


fun void startInstrument() {
    Hid hi;
    HidMsg msg;

    0 => int deviceNum;
    hi.openKeyboard( deviceNum ) => int deviceAvailable;
    if ( deviceAvailable == 0 ) me.exit();
    <<< "keyboard '", hi.name(), "' ready" >>>;

    /* signal flow */
    2 => int NUM_CHANNELS;
    Gain g => JCRev r => Echo e => Echo e2 => Gain mainGain;
    .5 => g.gain;
    r => mainGain;
    Util.patchToDAC(NUM_CHANNELS, mainGain);



    // set delays
    500::ms => e.max => e.delay;
    1000::ms => e2.max => e2.delay;
    // set gains
    .7 => e.gain;
    .4 => e2.gain;
    .15 => r.mix;

    // keyboard events
    while (true) {
        hi => now;
        
        while( hi.recv( msg ) )
        {
            if( msg.isButtonDown() )  // key on
            {
                <<< "down:", msg.which >>>;
                    
                keyToPitch_table[ msg.which ] => Std.mtof => float freq;			
                // need to scale by major 3rd for some reason?
                4.9/8. *=> freq;
                spork ~ keysound(freq, g, noteOffs[msg.which] );
            }
            
            else  // key off
            {
                <<< "up:", msg.which >>>;
                    
                noteOffs[ msg.which ].signal();
            }
        }
    }
}
