// global float variable (to be observed by Unity)
public class EnvFollower extends Chugraph {
    float FOLLOWER_VALUE;

    // patch
    inlet => Gain g => OnePole p => outlet;
    // square the input
    inlet => g;
    // multiply
    3 => g.op;

    // set filter pole position (between 0 and 1)
    // NOTE: this controls how smooth the output is
    // closer to 1 == smoother but less responsive
    // closer to 0 == more jumpy but also more responsive
    0.93 => p.pole;

    // follow!
    spork ~ follow();

    fun void pole(float pole_val) {
        pole_val => p.pole;
    }

    fun float value() {
        return FOLLOWER_VALUE;
    }

    fun void follow() {
        // loop on
        while( true )
        {
            // copy the follower output to global
            Math.pow(p.last(), 1/3.) => FOLLOWER_VALUE;

            // check for threshold
            if( p.last() > 0.01 ) {}
            
            // rate to check
            20::ms => now;
            // <<< FOLLOWER_VALUE >>>;
        }
    }
}
