//----------------------------------------------------------------------------
// name: playmovie.ck
// desc: a simple controller for playmovie.pde (Processing) over OSC
//       for Tess and Andrew and anyone else working with
//       interactive video in Processing + ChucK!
//
// to play: run gt with playmovie.pde
//
// author: Ge Wang (https://ccrma.stanford.edu/~ge/)
// date: Winter 2022
//----------------------------------------------------------------------------
 
// destination host name
"localhost" => string hostname;
// destination port number
12000 => int port;

// check command line
if( me.args() ) me.arg(0) => hostname;
if( me.args() > 1 ) me.arg(1) => Std.atoi => port;

// sender object
OscOut xmit;

// aim the transmitter at destination
xmit.dest( hostname, port );

GameTrack gt;
gt.init(0);

0. => float Z_MIN;
1. => float Z_MAX;

-1. => float X_MIN;
1. => float X_MAX;

-1. => float Y_MIN;
1. => float Y_MAX;

float prevDur;
now => time nextSendTime;

fun float gtToPlayhead() {
  return Util.remap(Z_MIN, 0.3, 0, 1, gt.curAxis[gt.LZ]);
  // return Util.remap(Y_MIN, Y_MAX, 0.0, 1, gt.curAxis[gt.LY]);
}

fun float gtToRate() {
  return Util.remap(X_MIN, X_MAX, 0.2, 5.0, gt.curAxis[gt.LX]);
}

fun float gtToDuration() {
  
  // return Util.remap(Z_MIN, Z_MAX, 100, 800, gt.curAxis[gt.LZ]);
  return Util.remap(Y_MIN, Y_MAX, 100, 2000, gt.curAxis[gt.LY]);
}

fun int sendReady() {
  // <<< nextSendTime >>>;
  // <<< now >>>;
  if (now >= nextSendTime) {
    
    // update next send time
    now + gtToDuration()::ms => nextSendTime;
    return 1;
  }
  now + gtToDuration()::ms => time possSendTime;
  if ( nextSendTime - possSendTime >= 50::ms ) {
    now + gtToDuration()::ms => nextSendTime;
    return 1;
  }
  return 0;
}

// infinite time loop
while( true )
{
    10::ms => now;
    // do we send this message?
    if (sendReady() == 0) {
      continue;
    }

    // start the message...
    xmit.start( "/foo/playmovie" );
    
    // add player ID
    1 => xmit.add;
    
    // add playhead percentage (float)
    0.3 => xmit.add;
    // gtToPlayhead() => xmit.add;

    // add rate (float)
    0.5 => xmit.add;
    // gtToRate() => xmit.add;

    // <<< "LH: ", gt.curAxis[0],gt.curAxis[1],gt.curAxis[2],\
    // "      RH: ", gt.curAxis[3],gt.curAxis[4],gt.curAxis[5] >>>;
    
    // send it
    xmit.send();

    // advance time
    // 0.5::second => now;
    gtToDuration() => float t;

    <<< "dur: " + t >>>;
    // 10::ms => now;
}
