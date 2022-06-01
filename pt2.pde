//----------------------------------------------------------------------------
// name: playmovie.pde
// desc: playing a video controlled by OSC
//       for Tess and Andrew (and anyone else working with video in
//       in Processing + ChucK)
//
// to play: run this with playmovie.ck
//
// author: Ge Wang (https://ccrma.stanford.edu/~ge/)
// date: Winter 2022
//----------------------------------------------------------------------------
 
import oscP5.*;
import netP5.*;
import processing.video.*;

// OSC object
OscP5 oscP5;
NetAddress remoteLocation;


// display tiles
final int nTilesW = 3;
final int nTilesL = 3;
final int nPlayers = nTilesW * nTilesL;

int screenTileW;
int screenTileH;

int fadeStartTime = 0;
int fadeDuration = 3000;


public enum TILEMODE {FULLSCREEN, TILED, CROPPED};
TILEMODE tileMode = TILEMODE.FULLSCREEN;


public enum MOVIEPHASE { P1, P2, QUICKSHOT, END, NONE };
MOVIEPHASE phase = MOVIEPHASE.NONE;

ArrayList<Player> players = new ArrayList<Player>();
Quickshot qs;
VideoLoader vl;

// keep track of x-axis of gametrak for drone
float droneX = .5;

void initPlayers() {
  for (int i = 0; i < nPlayers; i++) {
    players.add(new Player(i));
  }
}



void settings() {
  // window size
  size(1400, 800);
  //size(1400, 800, P2D); // p2d and p3d renderers brick
  //fullScreen();
}

// set up
void setup()
{
  //colorMode(HSB, width, height, 100);
  // frame rate
  //frameRate(24);
  frameRate(48);
  background(0);
  
  // volume (tho this doesn't seem to work unless repeated below)
  //myMovie.volume(0);
  vl = new VideoLoader(this);
  while(vl.numMovies() == 0) delay(2);
  initPlayers();
  
 
  /* start oscP5, listening for incoming messages at port 6450 */
  oscP5 = new OscP5(this, 6450);
  
  /* myRemoteLocation is a NetAddress. a NetAddress takes 2 parameters,
   * an ip address and a port number. myRemoteLocation is used as parameter in
   * oscP5.send() when sending osc packets to another computer, device, 
   * application. usage see below. for testing purposes the listening port
   * and the port of the remote location address are the same, hence you will
   * send messages back to this sketch.
   */
  //remoteLocation = new NetAddress("azaday.local", 6450);
  // TODO: multicast this
  remoteLocation = new NetAddress("224.0.0.1", 6451); // TODO: move to networt config constants
  qs = new Quickshot(remoteLocation, oscP5, vl);
  screenTileW =  width / nTilesW;
  screenTileH = height / nTilesL;
}


void toGrayscale(PImage img) {
  //loadPixels();
  img.loadPixels();
  for (int  x = 0; x < img.height; x ++ ) {
    for (int  y = 0; y < img.width; y ++ ) {
      
      int loc = y + x*img.width;
      float r = red(img.pixels[loc]);
      float g = green(img.pixels[loc]);
      float b = blue(img.pixels[loc]);
  
      float gray = 0.21 * r + 0.72 * g + 0.07 * b;
      img.pixels[loc] = color(gray);
    }
  }
  //updatePixels();
}

// draw next frame
void draw()
{
  
  Movie m = vl.getMovie();
  if (m == null) {
    println("movie is null");
    return;
  }
  switch (phase) {
    case P1:
      //println("handling p1");
      // move to left
      if (!vl.prevLeft && Util.approxWithin(droneX, 0, 0.1)) {
        
        vl.prevLeft = true;
        vl.p1QueueRight();
        println("moved left, next right " + vl.switcher[1].filename);
      }
      // move to right
      if (vl.prevLeft && Util.approxWithin(droneX, 1, 0.1)) {
        
        vl.prevLeft = false;
        vl.p1QueueLeft();
        println("moved right, next left " + vl.switcher[0].filename);
      }
      tint(255, int(255*(1 - droneX)));
      image(vl.switcher[0], 0, 0, width, height);
      
      tint(255, int(255*(droneX)));
      image(vl.switcher[1], 0, 0, width, height);
    
      break;
    case P2:
      //println("handling p2");
      //background(0);
      PImage img = m.get();
      if (tileMode == TILEMODE.FULLSCREEN) {
        //println(m.filename);
        tint(255, 255);
        image(m, 0, 0, width, height);

        //draw gray on top 
          // halves the framerate
        
        //var grayscaleAlpha = 255 * max(0, 1 - players.get(0).gain);
        //if (grayscaleAlpha > 10) {
        //  img.filter(GRAY);
        //  tint(255, grayscaleAlpha);
        //  image(img, 0, 0, width, height);
        //}
        
        
        return;
      }
      // get position of movie based on player ID
      //image(img, 0, 0, width, height);
      background(0);
      for (int i = 0; i < players.size(); i++) {
        
        // set tint
        Player currPlayer = players.get(i % 1);
        var alpha = max(100, 255*currPlayer.gain);
        println("alpha: " + alpha);
        tint(255, alpha);  // this method doesn't drop frames
        
        int xPos = i / nTilesW;
        int yPos = i % nTilesL;
        
        if (tileMode == TILEMODE.TILED) {
          // tile entire img
          image(img, screenTileW*xPos, screenTileH*yPos, screenTileW, screenTileH);
        } else if (tileMode == TILEMODE.CROPPED) {
          int imgTileW = img.width / nTilesW;
          int imgTileH = img.height / nTilesL;
          // tile cropped
          image(img.get(imgTileW*xPos, imgTileH*yPos, imgTileW, imgTileH), screenTileW*xPos, screenTileH*yPos, screenTileW, screenTileH);
        }
      }
      tint(255, 255);  // return to normal opacity
      break;
    case QUICKSHOT:
      //println("handling p3");
      /* ideas
        - set playhead to random pos each time
        - play clips in reverse?? like going back in time ?
          - maybe have this as a keycode option press 'R'
      */
      float delay = qs.initialDelay * qs.delayRate;
      if (delay < 0.1) {
        background(255);
        return;
      }
      //else if (delay <= 0.2) {
      //  if (qs.getImg() == null || frameCount % qs.frameDelay == 0) {
      //    qs.queueImg();
      //  }
        
      //  image(qs.getImg(), 0, 0, width, height);
      //  return;
      //}
      
      // PImage mov = m.get();
      // image(mov, 0, 0, width, height);

      image(m, 0, 0, width, height);
      
      //image(m, 0, 0, width, height);
      //mov.filter(GRAY);
      //toGrayscale(mov);
      //tint(255, 200);
      //image(mov, 0, 0, width, height);
      if (delay > 0.1 && m.time() > delay) {
        qs.queueVideo();
      }
      break;
    case END:
      //println("handling p4");
      float fader = map( millis() - fadeStartTime, 0, fadeDuration, 0, 255);
      fader = constrain(fader, 0, 255);
      tint(255, fader);
      image(m.get(0, 0, m.width, m.height - 100), 0, 0, width, height);
      break;
    default:
      background(0);
      break;
  }
}

void movieEvent(Movie m)
{
  //println("movie event:" + m.filename);
  //TODO: ping pong the movie back and forth, like lfo
  m.read();
}


// handles incoming OSC messages
void oscEvent(OscMessage msg)
{
    /* check if the typetag is the right one. */
    // print("### received an osc message.");
    switch (phase) {
      case P1:
        if (msg.checkAddrPattern("/gametrak"))
          droneX = msg.get(0).floatValue();
          //println(droneX);
        break;
      case P2:
        if (msg.checkAddrPattern("/p2/player_to_processing")) {
          int playerID = msg.get(0).intValue();
          int movieID = msg.get(1).intValue();
          float gain = msg.get(5).floatValue();
          
           println("playerID: " + playerID + ", gain:" + gain + ", movie:" + movieID);
          if (playerID == 0) {
            vl.setMovie(MOVIEPHASE.P2, movieID);
          }
          Player currPlayer = players.get(playerID);
          currPlayer.gain = min(gain * 3 , 1);
        }
        break;
      default:
        break;
    }
}

void keyPressed() {
  if (key != '1') {
    vl.exitP1();
    // reset tint
    tint(255, 255);
  }
  if (key == 'q') {
    println("=========== TILED ============");
    tileMode = TILEMODE.TILED;
  }
  else if (key == 'w') {
    println("=========== CROPPED ============");
    tileMode = TILEMODE.CROPPED;
  }
  else if (key == 'e') {
    println("=========== FULLSCREEN ============");
    tileMode = TILEMODE.FULLSCREEN;
  }
  else if (key == '1') {
    println("=========== ENTERING PART 1 ============");
    phase = MOVIEPHASE.P1;
    vl.initP1();  // start looping
  }
  else if (key == '2') {
    println("=========== ENTERING PART 2 ============");
    phase = MOVIEPHASE.P2;
  }
  else if (key == '3') {
    println("=========== ENTERING QUICK ============");
    phase = MOVIEPHASE.QUICKSHOT;
    qs.queueVideo();
  }
  else if (key == '4') {
    // trigger cross fade in last shot
    println("Fading to final");
    fadeStartTime = millis();
    vl.stepMovie(MOVIEPHASE.END);
    phase = MOVIEPHASE.END;
  }
  else if (keyCode == DOWN) {
    println("faster shot: " + qs.initialDelay * qs.delayRate);
    qs.delayRate -= 0.08;
  }
  else if (keyCode == UP) {
    println("slower shot: " + qs.initialDelay * qs.delayRate);
    qs.delayRate += 0.08;
  }
}
