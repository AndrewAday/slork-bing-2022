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


enum TILEMODE {FULLSCREEN, TILED, CROPPED, QUICKSHOT, END};
TILEMODE tileMode = TILEMODE.FULLSCREEN;

public enum MOVIEPHASE { P2, QUICKSHOT, END };

ArrayList<Player> players = new ArrayList<Player>();
Quickshot qs;
VideoLoader vl;

void initPlayers() {
  for (int i = 0; i < nPlayers; i++) {
    players.add(new Player(i));
  }
}



void settings() {
  // window size
  size(1400, 800);
  //size(1400, 800, P2D);
  fullScreen();
}

// set up
void setup()
{
  //colorMode(HSB, width, height, 100);
  // frame rate
  frameRate(24);
  background(0);
  
  // volume (tho this doesn't seem to work unless repeated below)
  //myMovie.volume(0);
  vl = new VideoLoader(this);
  vl.loadVideos();
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
  remoteLocation = new NetAddress("localhost", 12000);
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
  if (tileMode == TILEMODE.FULLSCREEN) {
    image(m, 0, 0, width, height);
    return;
  }
  else if (tileMode == TILEMODE.END) {
    float fader = map( millis() - fadeStartTime, 0, fadeDuration, 0, 255);
    fader = constrain(fader, 0, 255);
    tint(255, fader);
    image(m.get(0, 0, m.width, m.height - 100), 0, 0, width, height);
    return;
  }
  else if (tileMode == TILEMODE.QUICKSHOT) {
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
    PImage mov = m.get();
    image(mov, 0, 0, width, height);
    //mov.filter(GRAY);
    //toGrayscale(mov);
    //tint(255, 200);
    //image(mov, 0, 0, width, height);
    if (delay > 0.1 && m.time() > delay) {
      qs.queueVideo();
    }
    return;
  }
  background(0);
  // get position of movie based on player ID
  for (int i = 0; i < players.size(); i++) {
    Player currPlayer = players.get(i % 1);
    //tint(255, 255*currPlayer.gain);
    int xPos = i / nTilesW;
    int yPos = i % nTilesL;
    final PImage img = m.get();
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
}

void movieEvent(Movie m)
{
  m.read();
}


// handles incoming OSC messages
void oscEvent(OscMessage theOscMessage)
{
    /* check if the typetag is the right one. */
    // print("### received an osc message.");
    int playerID = theOscMessage.get(0).intValue();
    int audioID = theOscMessage.get(1).intValue();
    float gain = theOscMessage.get(5).floatValue();
    
    //println("playerID: " + playerID + ", gain:" + gain + ", movie:" + audioID);
    if (playerID == 0) {
      vl.setMovie(MOVIEPHASE.P2, audioID);
    }
    Player currPlayer = players.get(playerID);
    currPlayer.gain = min(gain * 3 , 1);
    return;
}

void keyPressed() {
  if (key == '1') {
    tileMode = TILEMODE.TILED;
  }
  else if (key == '2') {
    tileMode = TILEMODE.CROPPED;
  }
  else if (key == '3') {
    tileMode = TILEMODE.FULLSCREEN;
  }
  else if (key == '4') {
    tileMode = TILEMODE.QUICKSHOT;
    qs.queueVideo();
  }
  else if (key == '5') {
    // trigger cross fade in last shot
    println("Fading to final");
    fadeStartTime = millis();
    vl.stepMovie(MOVIEPHASE.END);
    tileMode = TILEMODE.END;
  }
  else if (keyCode == DOWN) {
    println("faster shot: " + qs.initialDelay * qs.delayRate);
    qs.delayRate -= 0.08;
  }
}
