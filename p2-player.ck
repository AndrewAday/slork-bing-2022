// Filepaths
Paths paths;

// TODO: move all network config to Paths global

Util.print("jakarta p2 player initializing...");
paths.PROCESSING_HOSTNAME => string PROCESSING_HOSTNAME;
paths.PROCESSING_PORT => int PROCESSING_PORT;

// gametrack
GameTrack gt;
gt.init(0);

// get num channels
// print out all arguments
int NUM_CHANNELS;
Util util;
util.STRING_TO_INT[me.arg(0)] => NUM_CHANNELS;

// signal flow
// 2 => int NUM_CHANNELS;
// 6 => int NUM_CHANNELS;
Gain main_gain;
Util.patchToDAC(NUM_CHANNELS, main_gain);


/*==========HID config=========*/
// HID objects
Hid hi;
HidMsg msg;

// which keyboard
paths.KB_NUM => int kbNum;
// 1 => int device;
3 => int trackpadNum;

if( !hi.openKeyboard( kbNum ) ) me.exit();
<<< "keyboard '" + hi.name() + "' ready", "" >>>;


/* ========= Get initialization params from server ========= */
-1 => int playerID;
-1 => int audioID;
-1 => int movieID;
Switchable @ switchableInstruments[4];
-1 => int ACTIVE_INSTRUMENT;

fun int is_low(int id) {
    return (id >= 0 && id <= 2);
}

fun int is_mid(int id) {
    return (id >= 3 && id <= 5);
}

fun int is_high(int id) {
    return (id >= 6 && id <= 8);
}


fun void initialize() {
    OscIn oin;
    OscMsg msg;
    6449 => oin.port;

    /*
        playerID: int
        audioID: int
        movieID: int
    */
    oin.addAddress( "/jakarta/p2/initialize, i i i" );

    // get init info from server
    oin => now;
    while (oin.recv(msg)) {
        msg.getInt(0) => playerID;
        msg.getInt(1) => audioID;
        msg.getInt(2) => movieID;
    }
    // 0 => playerID; 0 => audioID;
    Util.print("Player initialized. playerID: " + playerID + " | audioID: " + audioID + " | movieID: " + movieID);


    // initialize (but not activate) all switchable instruments
    // TODO: add logic for instrument loading based on playerID

    // part 1 instrument
    if (is_low(playerID)) {
        // droner
        Droner droner;
        // TODO: maybe cello here instead? save human voice for end?
        droner.init(
            main_gain, 
            playerID, // player ID
            PROCESSING_HOSTNAME, PROCESSING_PORT, // processing OSC deset
            "./Samples/Drones/male-choir.wav", "./Samples/Drones/female-choir.wav"
        );
        droner @=> switchableInstruments[0];
    } else if (is_mid(playerID)) {
        // nothing, equiv to silence
        Switchable switchable;
        switchable.init(main_gain); 
        switchable @=> switchableInstruments[0];
    } else if (is_high(playerID)) {
        SoundBoard soundboard;
        soundboard.init(main_gain, kbNum, trackpadNum);
        soundboard @=> switchableInstruments[0];
    }

    // P2 everyone gets combulator
    Combulator combulator;
    combulator.init(main_gain, playerID, audioID, movieID, PROCESSING_HOSTNAME, PROCESSING_PORT);
    combulator @=> switchableInstruments[1];

    // P3 shepard + noise
    .002 => float SHEPARD_RATE;
    if (is_low(playerID)) {
        // Shepard DESC
        Shepard shepard;
        if (playerID == 0)
            shepard.init(main_gain, -3, 57, -SHEPARD_RATE);
        else if (playerID == 1)
            shepard.init(main_gain, -7, 53, -SHEPARD_RATE);
        else if (playerID == 2)
            shepard.init(main_gain, -11, 49, -SHEPARD_RATE);
        shepard @=> switchableInstruments[2];
    } else if (is_mid(playerID)) {
        // noiser
        Noiser noiser;
        if (playerID == 3)
            noiser.init(main_gain, Noiser.MODE_LOW);
        else if (playerID == 4)
            noiser.init(main_gain, Noiser.MODE_ALL);
        else if (playerID == 5)
            noiser.init(main_gain, Noiser.MODE_HIGH);
        noiser @=> switchableInstruments[2];
    } else if (is_high(playerID)) {
        // Shepard ASC
        Shepard shepard;
        if (playerID == 6)
            shepard.init(main_gain, 3, 63, SHEPARD_RATE);
        else if (playerID == 7)
            shepard.init(main_gain, 7, 67, SHEPARD_RATE);
        else if (playerID == 8)
            shepard.init(main_gain, 11, 71, SHEPARD_RATE);
        shepard @=> switchableInstruments[2];
    }


    // P4 droners
    P4Droner p4droner;
    if (is_low(playerID)) {
        p4droner.init(
            main_gain, 
            "./Samples/Drones/wtx-1.wav",  // sample
            p4droner.lower_pitches, // pitch set
            1.0  // pitch offset
        );
    } else if (is_mid(playerID)) {
        p4droner.init(
            main_gain, 
            "./Samples/Drones/male-choir.wav",  // sample
            p4droner.middle_pitches, // pitch set
            .5  // pitch offset
        );
    } else if (is_high(playerID)) {
        p4droner.init(
            main_gain, 
            "./Samples/Drones/female-choir.wav",  // sample
            p4droner.upper_pitches, // pitch set
            .5  // pitch offset
        );
    }
    p4droner @=> switchableInstruments[3];

    Util.print("============ALL INSTRUMENTS INITIALIZED============");
}


fun void activeInstrumentHandler() {
    // TODO: control this from server or player keyboards?

    /* int: active instrument idx */
    // oin.addAddress( "/jakarta/active_instrument, i" );

}

fun void switch_instrument(int idx) {
    if (idx == ACTIVE_INSTRUMENT) return;
    if (ACTIVE_INSTRUMENT >= 0 && ACTIVE_INSTRUMENT < switchableInstruments.size())
        switchableInstruments[ACTIVE_INSTRUMENT].deactivate();
    idx => ACTIVE_INSTRUMENT;
    switchableInstruments[ACTIVE_INSTRUMENT].activate();
}

fun void gt_updater() {
    while (true) {
        for (0 => int i; i < switchableInstruments.size(); i++) {
            switchableInstruments[i] @=> Switchable inst;
            if (inst.IS_ACTIVE)
                inst.gt_update(gt);
        }
        15::ms => now;
    }
}

fun void processing_updater() {
    while (true) {
        for (0 => int i; i < switchableInstruments.size(); i++) {
            switchableInstruments[i] @=> Switchable inst;
            if (inst.IS_ACTIVE)
                inst.processing_update(gt);
        }
        40::ms => now;
    }
}

fun void processing_drumhit_listener() {
    OscIn oin;
    OscMsg msg;
    paths.PROCESSING_TO_PLAYER_PORT => oin.port;

    oin.addAddress( "/quickshot/drumhit" );

    // setup sampler
    Sampler sampler;
    sampler.load(
        me.dir() + "/Samples/Taiko/", "E3.wav", Sampler.TYPE_ONESHOT
    );  // TODO: different samples?
    sampler.patch(main_gain);
    
    while (true) {
        oin => now;
        while (oin.recv(msg)) {
            sampler.play();
        }
    }

}

initialize();

// spork updaters
spork ~ processing_updater();
spork ~ gt_updater();

// spork network listeners
spork ~ processing_drumhit_listener();

kb();

fun void kb() {
    // <<< "running kb" >>>;
    while (true) {
        hi => now;

        while (hi.recv(msg)) {
            // <<< msg.which >>>;
            if (!msg.isButtonDown()) continue;

            if (msg.which == Util.KEY_1) {
                switch_instrument(0);
            } else if (msg.which == Util.KEY_2) {
                switch_instrument(1);
            }  else if (msg.which == Util.KEY_3) {
                switch_instrument(2);
            } else if (msg.which == Util.KEY_4) {
                switch_instrument(3);
            }


        }
    }
}






