public class GameTrack {
  /* ======== state ======== */
  // HID objects
  Hid trak;
  HidMsg msg;

  // timestamps
  time lastTime;
  time currTime;

  // previous axis data
  float lastAxis[6];
  // current axis data
  float curAxis[6];

  // controller labels
  0 => int LEFT; 1 => int RIGHT;

  // axis indices
  0 => int LX; 1 => int LY; 2 => int LZ;
  3 => int RX; 4 => int RY; 5 => int RZ;
  32 => int HIST_SIZE;  // num of past axis states we save

  // circular buffer of axis data history
  float axisHistory[HIST_SIZE][6];
  // circular buffer head
  0 => int axisHead;

  // button
  false => int buttonDown;
  false => int buttonToggle;

  /* ======== Events ======== */
  /*
   TODO: add events that fire on 
   - z hits 0
   - button pressed
  */

  Event buttonPressEvent;
    

  /* ======== calibration ======== */
  // axis offsets
  0.0 => float LZOff;
  0.0 => float RZOff;

  // z axis deadzone
  .03 => static float Z_DEADZONE;

  // angle mapping  (0 degrees is straight up)
  40.0 => float ANGLE_MAX;
  275.0 => float CABLE_LENGTH;  // 275cm length of fishing line


  /* ====== FUNCTIONS ====== */
  // TODO: move these to static util class
  fun float lerp(float a, float b, float t) {
    return a + t * (b - a);
  }

  fun float invLerp(time a, time b, time c) {
    return (c-a) / (b-a);
  }

  fun float invLerp(float a, float b, float c) {
    return (c-a) / (b-a);
  }

  fun float mag(float pos[]) {
    return Math.sqrt(pos[0]*pos[0] + pos[1]*pos[1]);
  }

  fun float squared_mag2(float pos[]) {  // fast than sqrt
    return (pos[0]*pos[0] + pos[1]*pos[1]);
  }

  fun float dist(float a[], float b[]) {
    return mag([a[0] - b[0], a[1] - b[1]]);
  }

  fun float squared_dist2(float a[], float b[]) {
    return this.squared_mag2([a[0] - b[0], a[1] - b[1]]);
  }

  // remaps c from range [a,b] to range [x, y]
  fun float remap(float a, float b, float x, float y, float c) {
    return lerp(x, y, invLerp(a, b, c));
  }

  fun float axis(int i) {
    return this.axisHistory[axisHead][i];
  }

  fun void print()
  {
      /* <<< "LH:", this.axis(0),this.axis(1),this.axis(2), "      RH: ", this.axis(3),this.axis(4),this.axis(5) >>>; */
      <<< ":", this.curAxis[0],this.curAxis[1],this.curAxis[2], "       RH: ", this.curAxis[3],this.curAxis[4],this.curAxis[5] >>>;
  }

  fun void init(int deviceNum) {
    // open joystick 0, exit on fail
    if( !trak.openJoystick( deviceNum ) ) me.exit();

    // print
    <<< "joystick '" + trak.name() + "' ready", "" >>>;

    spork ~ this.gametrak();
    // calibrateZ();
  }

  // computes Z offsets so z axis is 0 at rest
  fun void calibrateZ() {
    /* 1::second => now; */
    0.0 => float LZSum;
    0.0 => float RZSum;

    // gather 10 samples over .5 seconds
    repeat (10) {
      100::ms => now;
      this.curAxis[LZ] +=> LZSum;
      this.curAxis[RZ] +=> RZSum;
    }

    LZSum / 10.0 => this.LZOff;
    RZSum / 10.0 => this.RZOff;

    <<< "calibrated. LZOff: ", LZOff, "  RZOff: ", RZOff >>>;
  }

  // track gametrack state
  fun void gametrak()
  {
      false => int axisChanged;
      while( true )
      {
          // wait on HidIn as event
          this.trak => now;

          // messages received
          while( this.trak.recv( this.msg ) )
          {
              // joystick axis motion
              if( this.msg.isAxisMotion() )
              {
                  // conts axis motion
                  if( msg.which >= 0 && msg.which < 6 )
                  {
                      // check if fresh
                      if( now > this.currTime )
                      {
                          // inc buffer head
                          axisHead++;
                          axisHead % HIST_SIZE => axisHead; // wrap around

                          // time stamp
                          this.currTime => this.lastTime;
                          // set
                          now => this.currTime;
                      }

                      // save last
                      this.curAxis[msg.which] => this.lastAxis[msg.which];

                      // the z axes map to [0,1], others map to [-1,1]
                      if (msg.which != LZ && msg.which != RZ) { // set x and y axis
                        /* msg.axisPosition => this.axisHistory[this.axisHead][msg.which]; */
                        msg.axisPosition => this.curAxis[msg.which];
                      }
                      else { // set z axis
                          Math.max(
                            0.0,
                            getZ(msg.which, msg.axisPosition) - Z_DEADZONE
                          ) => this.curAxis[msg.which];
                      }
                  }
              }

              // joystick button down
              else if( msg.isButtonDown() )
              {
                  if (!buttonDown) {
                    !buttonToggle => buttonToggle;
                    buttonPressEvent.broadcast();
                    <<< "button press broadcast!" >>>;
                  }
                  true => this.buttonDown;
                  <<< "button", msg.which, "down" >>>;
              }

              // joystick button up
              else if( msg.isButtonUp() )
              {
                  false => this.buttonDown;
                  <<< "button", msg.which, "up" >>>;
              }
          }
      }
  }

  fun float getZ(int which, float pos) {
    (1 - ((pos + 1) / 2)) => float z;
    if (which == LZ) {
      this.LZOff -=> z;
    } else {
      this.RZOff -=> z;
    }
    return z;
  }

  // returns estimated 2d pos of hand projected onto the XZ plane
  // TODO: can we do 3d pos using spherical coords?
  fun float[] getXPos(int hand) {
    float xAxis, zAxis;
    if (hand == this.LEFT) {
      this.curAxis[LX] => xAxis;
      this.curAxis[LZ] => zAxis;
    } else {
      this.curAxis[RX] => xAxis;
      this.curAxis[RZ] => zAxis;
    }

    // scale z axis to real units, in cm
    remap(0, 1, 0, CABLE_LENGTH, zAxis) => zAxis;
    remap(-1, 1, -35, 35, xAxis) => float theta;

    // deadzone for theta
    /* if (Std.fabs(theta) < 5) { 0 => theta; } */
    /* <<< theta >>>; */
    // convert theta to rad
    0.0174533 *=> theta;

    return [zAxis * Math.sin(theta), zAxis * Math.cos(theta)];
  }

  fun float GetXZPlaneHandDist() {
    this.getXPos(this.LEFT) @=> float LHPos[];
    this.getXPos(this.RIGHT) @=> float RHPos[];

    return this.dist(LHPos, RHPos);
  }

  fun float GetXZPlaneHandDistSquared() {
    this.getXPos(this.LEFT) @=> float LHPos[];
    this.getXPos(this.RIGHT) @=> float RHPos[];

    return this.squared_dist2(LHPos, RHPos);
  }

  fun float GetCombinedZ() {
    return this.curAxis[LZ] + this.curAxis[RZ];
  }

  fun float GetAvgZ() {
      return GetCombinedZ() * .5;
  }

  fun float GetMaxZ() {
      return Math.max(curAxis[LZ], curAxis[RZ]);
  }

}



/* Unit Tests */
/*
GameTrack gt;
gt.init(0);  // also sporks tracker

while (true) {
  gt.print();
  gt.getXPos(gt.LEFT) @=> float leftXPos[];
  gt.getXPos(gt.RIGHT) @=> float rightXPos[];
  <<< "(", leftXPos[0], leftXPos[1], ")     ||     (", rightXPos[0], rightXPos[1], ")" >>>;
  <<< gt.GetXZPlaneHandDist() >>>;
  100::ms => now;
}
*/
