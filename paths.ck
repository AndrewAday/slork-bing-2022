/*
Used to hold global const paths
*/
public class Paths {
    [
        "./Samples/Field/thunder.wav",
        "./Samples/Field/birds.wav",
        "./Samples/Field/bumblebees.wav",
        "./Samples/Field/wind.wav",
        "./Samples/Field/frozen-pond.wav"
    ] @=> string AUDIO_FILES[];

    [ // TODO: update to actual mp4s
        "./Samples/Field/thunder.wav",
        "./Samples/Field/birds.wav",
        "./Samples/Field/bumblebees.wav",
        "./Samples/Field/wind.wav",
        "./Samples/Field/frozen-pond.wav"
    ] @=> string MOVIE_FILES[];

    // [] @=> string DRONE_FILES[];
}

Paths paths;