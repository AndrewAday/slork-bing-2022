// static helper fns

public class Util {  

    fun static void patchToDAC(int num_chan, UGen @ u) {
        for (int i; i < num_chan; i++) {
            u => dac.chan(i);
        }
    }

    fun static float getFS() {  // get sample rate
        return 1::second / 1::samp;
    }

    /* ============ Casting ================ */

    int STRING_TO_INT[0];
    0 => STRING_TO_INT["0"];
    1 => STRING_TO_INT["1"];
    2 => STRING_TO_INT["2"];
    6 => STRING_TO_INT["6"];

    /* ============ Timing ================ */

    // this synchronizes to period
    fun static void synchronize(dur T) {
        T - (now % T) => now;
    }

    fun static dur bpmToQtNote(float bpm) {
        return (60. / (bpm))::second;
    }

    /* ============ Pitch/Freq ============ */
        // JI Intervals
    16./15. => static float m2;
    9./8. => static float M2;
    6./5. => static float m3;
    5.0/4 => static float M3;
    4.0/3 => static float P4;
    45.0/32.0 => static float Aug4;
    3.0/2.0 => static float P5;
    8./5. => static float m6;
    5.0/3 => static float M6;
    16.0/9.0 => static float m7;
    15.0/8 => static float M7;

    // returns 5-limit JI frequencies for chromatic scale starting on a given tonic
    fun static float[] toChromaticScale(float tonic) {
        return [
            tonic,
            tonic * m2,
            tonic * M2,
            tonic * m3,
            tonic * M3,
            tonic * P4,
            tonic * Aug4,
            tonic * P5,
            tonic * m6,
            tonic * M6,
            tonic * m7,
            tonic * M7
        ];
    }

    // MIDI notes
    60 => static int C;
    61 => static int Cs => static int Db;
    62 => static int D;
    63 => static int Ds => static int Eb;
    64 => static int E;
    65 => static int F;
    66 => static int Fs => static int Gb;
    67 => static int G;
    68 => static int Gs => static int Ab;
    69 => static int A;
    70 => static int As => static int Bb;
    71 => static int B;

    /* ============ Vector Math ============ */

    fun static int approx(float a, float b) {  // float equality
        return Std.fabs(a - b) < .00001;
    }

    fun static int approxWithin(float a, float b, float c) {  // diff < c
        return Std.fabs(a - b) < c;
    }


    /* ============ Interpolators ============ */
    fun static float lerp(float a, float b, float t) {
        return a + t * (b - a);
    }

    fun static time timeLerp(time a, time b, float t) {
        return a + t * (b - a);
    }

    fun static float invLerp(time a, time b, time c) {
        return (c-a) / (b-a);
    }

    fun static float invLerp(float a, float b, float c) {
        return (c-a) / (b-a);
    }

    // remaps c from [a,b] to range [x,y]
    fun static float remap(float a, float b, float x, float y, float c) {
        return lerp(x, y, invLerp(a,b,c));
    }

    fun static float remap(time a, time b, float x, float y, time c) {
        return lerp(x, y, invLerp(a,b,c));
    }

    fun static float clamp01(float f) {
        return Math.max(.0, Math.min(f, .99999));
    }

    fun static float remap01(float a, float b, float x, float y, float c) {
        return clamp01(remap(a, b, x, y, c));
    }

    fun static float lfo(float freq) {
        return Math.sin(2*pi*freq*(now/second));
    }

    /* ============ Printers ============ */
    fun static void printLerpProgress(float t) {  // t in [0, 1]
        (t * 10) $ int => int T;
        "S[" @=> string output;
        repeat(T) {
            "=" +=> output;
        }
        repeat (10-T) {
            " " +=> output;
        }
        "]E" +=> output;
        <<< output >>>;
    }

    fun static void print(string s) {
        chout <= s <= IO.newline();
    }

    fun static void printErr(string s) {
        cherr <= s <= IO.newline();
    }

    // returns n copies of str
    fun static string multString(int times, string str) {
        str => string orig;
        for (0 => int i; i < times; i++) {
        orig +=> str;
        }
        return str;
    }

    /* ====Array Management==== */

    fun static void swap(int arr[], int i, int j) {
        arr[i] => int tmp;
        arr[j] => arr[i];
        tmp => arr[j];
    }

    fun static int partition(int arr[], int low, int high) {
        low - 1 => int i;
        arr[high] => int pivot;

        for (low => int j; j < high; j++) {
        if (arr[j] <= pivot) {
            i++;
            swap(arr, i, j);
        }
        }
        i++;
        swap(arr, i, high);
        return i;
    }

    fun static void quick_sort(int arr[], int low, int high) {
        if (arr.cap() == 1) { return; }

        if (low < high) {
        partition(arr, low, high) => int pivot;
        quick_sort(arr, low, pivot-1);
        quick_sort(arr, pivot+1, high);
        }
    }

    /* return an array of n random values between 0 and max, sorted */
    fun static int[] rand_n_arr(int n, int max) {
        int arr[n+1];
        for (0 => int i; i < arr.cap(); i++) {
        Math.random2(1, max-1) => arr[i];
        }
        0 => arr[0]; max => arr[arr.cap()-1];
        quick_sort(arr, 0, arr.cap()-1);
        return arr;
    }

    // returns a + b
    fun static int[] concat(int a[], int b[]) {
        a @=> int ret[];
        for (0 => int i; i < b.size(); i++) {
            ret << b[i];
        }
        return ret;
    }

    fun static void print(int a[]) {
        "" => string ret;
        for (0 => int i; i < a.size(); i++) {
            (a[i] + " ") +=> ret;
        }
        Util.print(ret);
    }

    fun static void print(int a[][]) {
        for (0 => int i; i < a.size(); i++)
            Util.print(a[i]);
    }

    /* ========== Midi Helper Functions ========== */

    fun static void connectMidiPort(MidiOut @ mout, int midi_port) {
        if (!mout.open(midi_port)) {
        me.exit();
        } else {
        <<< "connected to midi port " + midi_port >>>;
        }
    }

    /* Note: channels are counted starting at 1, not 0 */
    fun static MidiMsg getMidiNoteOff(int channel, int note) {
        MidiMsg msg;
        128 + (channel - 1) => msg.data1;
        note => msg.data2;
        return msg;
    }

    fun static MidiMsg getMidiNoteOn(int channel, int note, int velocity) {
        MidiMsg msg;
        144 + (channel - 1) => msg.data1;
        note => msg.data2;
        velocity => msg.data3;
        return msg;
    }

    fun static MidiMsg getMidiClock() {
        MidiMsg msg;
        248 => msg.data1;
        return msg;
    }


    /*
    x0: horizontal offset
    L: Maximum value
    k: slope gradation
    */
    fun static float logistic(float x, float x0, float L, float k) {
        return (L / (1 + Math.exp((-1. * k) * (x - x0))));
    }

    // returns array of first n fibonacci numbers
    fun static int[] fib(int n) {
        int arr[n];
        1 => arr[1];
        for (2 => int i; i < n; i++) {
            arr[i-1] + arr[i-2] => arr[i];
        }
        return arr;
    }

    /* =========== Keycodes =========== */
    2 => static int KEY_DELETE;
    44 => static int KEY_SPACE; 
    45 => static int KEY_DASH;
    46 => static int KEY_EQUAL;
    54 => static int KEY_COMMA;
    55 => static int KEY_PERIOD;
    79 => static int KEY_RIGHT;
    80 => static int KEY_LEFT;
    81 => static int KEY_DOWN;
    82 => static int KEY_UP;
    47 => static int KEY_LB;
    48 => static int KEY_RB;
    56 => static int KEY_SLASH;
    225 => static int KEY_LEFT_SHIFT;
    29 => static int KEY_Z;
    22 => static int KEY_S;
    27 => static int KEY_X;
    7 => static int KEY_D;
    6 => static int KEY_C;
    9 => static int KEY_F;
    25 => static int KEY_V;
    10 => static int KEY_G;
    5 => static int KEY_B;
    11 => static int KEY_H;
    24 => static int KEY_U;
    16 => static int KEY_M;
    4 => static int KEY_A;
    51 => static int KEY_COLON;
    52 => static int KEY_APPOSTROPHE;
    40 => static int KEY_ENTER;

}   

Util util;