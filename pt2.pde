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
NetAddress myRemoteLocation;


// display tiles
final int nTilesW = 3;
final int nTilesL = 3;
final int nPlayers = nTilesW * nTilesL;

int screenTileW;
int screenTileH;


enum TILEMODE {FULLSCREEN, TILED, CROPPED};
TILEMODE tileMode = TILEMODE.TILED; 

ArrayList<Player> players = new ArrayList<Player>();

void initPlayers() {
  for (int i = 0; i < nPlayers; i++) {
    players.add(new Player(this, i));
  }
}



// set up
void setup()
{
  // window size
  size(1400, 800);
  fullScreen();
  // frame rate
  frameRate(60);
  
  // volume (tho this doesn't seem to work unless repeated below)
  //myMovie.volume(0);
  
  initPlayers();
 
  /* start oscP5, listening for incoming messages at port 12000 */
  oscP5 = new OscP5(this, 6450);
  
  /* myRemoteLocation is a NetAddress. a NetAddress takes 2 parameters,
   * an ip address and a port number. myRemoteLocation is used as parameter in
   * oscP5.send() when sending osc packets to another computer, device, 
   * application. usage see below. for testing purposes the listening port
   * and the port of the remote location address are the same, hence you will
   * send messages back to this sketch.
   */
  //myRemoteLocation = new NetAddress("127.0.0.1", 12000);
  screenTileW =  width / nTilesW;
  screenTileH = height / nTilesL;
}


// draw next frame
void draw()
{
  background(0);
  if (tileMode == TILEMODE.FULLSCREEN) {
    if(players.get(0).isNotInitialized()) {
      return;
    }
    Movie m = players.get(0).getMovie();
    image(m, 0, 0, width, height);
    return;
  }
  // get position of movie based on player ID
  for (int i = 0; i < players.size(); i++) {
    Player currPlayer = players.get(i);
    if(currPlayer.isNotInitialized()) {
      continue;
    }
    Movie m = currPlayer.getMovie();
    //while (m.height == 0) delay(1);
    //tint(255, 255*currPlayer.gain);
    int xPos = i / nTilesW;
    int yPos = i % nTilesL;
    //println("x: " + xPos + ", y: " + yPos);
    final PImage img = m.get();
    //println("coords: " + imgW*xPos + ", " + imgH*yPos);
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

// can be used to send OSC
void mousePressed()
{
}

// handles incoming OSC messages
void oscEvent(OscMessage theOscMessage)
{
    // print("### received an osc message.");
    /* check if the typetag is the right one. */
    // print("### received an osc message.");
    // get playerID
    int playerID = theOscMessage.get(0).intValue();
    // audioID
    int audioID = theOscMessage.get(1).intValue();
    // get the playhead (by percentage)
    //float playhead = theOscMessage.get(2).floatValue();
    // get the playback rate
    float rate = theOscMessage.get(3).floatValue();
    
    float gain = theOscMessage.get(5).floatValue();
    
    //println("playerID: " + playerID + ", playhead: " + playhead + ", rate: " + rate + ", gain:" + gain + ", movie:" + audioID);
    
    Player currPlayer = players.get(playerID);
    currPlayer.gain = min(gain * 3 , 1);
    currPlayer.setAudioID(audioID);
    
    // seek to percentage
    //m.jump(playhead * m.duration());
    // set playback rate
    
    //currPlayer.getMovie().speed(rate*2);
    
    // silence the audio (if we want to use our own, e.g., from ChucK)
    //myMovie.volume(0);
    // done
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
}
