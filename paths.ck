/*
Used to hold global constants
*/
public class Paths {
    /* ========HID config ============== */
    0 => int KB_NUM;

    /* ========network config ============== */
    "azaday.local" => string PROCESSING_HOSTNAME;
    6450 => int PROCESSING_PORT;
    [
        "localhost"
        // "gelato.local",
        // "udon.local",
        // "spam.local",
        // "nachos.local",
        // "lasagna.local",
        // "meatloaf.local",
        // "donut.local",
        // "kimchi.local"
        // "chowder.local"
        // "Peanutbutter.local",
        // "udon.local",
        // "quinoa.local",
        // "vindaloo.local",
        // "Tess"
    ] @=> string CHUCK_HOSTNAMES[];

    6449 => int CHUCK_PORT;  // chuck server to chuck players
    6451 => int PROCESSING_TO_PLAYER_PORT; // players listen here for processing events


    [
        "./Samples/Field/thunder.wav",
        "./Samples/Field/birds.wav",
        "./Samples/Field/bumblebees.wav",
        "./Samples/Field/wind.wav",
        "./Samples/Field/frozen-pond.wav"
    ] @=> string AUDIO_FILES[];

    [ // TODO: update to actual mp4s
        // good
        // "good/clouds.mp4",
        "good/beijing-aerial-still.mp4",
        "good/coaster.mp4",
        "good/feetwalking.mp4",
        "good/merrygoround.mp4",
        "good/gaming-crowds.mp4",
        "good/beijing-night-traffic.mp4",
        "good/beijing-3-shot.mp4",
        "good/hongkong-crowds2.mp4",
        "good/hongkong-building.mp4",
        "good/fireworks-nologo.mp4",
        // bad
        "bad/behemoth-forge-1.mp4",
        "bad/behemoth-forge-2.mp4",
        "bad/behemoth-forge-3.mp4",
        "bad/deforestation1.mp4",
        "bad/deforestation2.mp4",
        "bad/deforestation3.mp4",
        "bad/rivers-drying-2-shot.mp4",
        "bad/mining-explosion.mp4",
        "bad/behemoth-mine.mp4",
        "bad/wind-turbine.mp4",
        "bad/behemoth-factory.mp4" 
    ] @=> string MOVIE_FILES[];

    // [] @=> string DRONE_FILES[];
}

Paths paths;