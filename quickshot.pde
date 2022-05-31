class Quickshot {
   private int imgIdx;
   private Movie m;
   private PImage img;
   private int queueCounter;
   private VideoLoader vl;
   
   // OSC things
   OscP5 oscP5;
   NetAddress remoteLocation;
   
   //public float delay;
   public int frameDelay;
   public float delayRate; 
   
   // duration to display first quickshot video
   final public float initialDelay = 3;
   // each new video is X % as long as the last
   //final private float VID_DELAY_RATE = 0.85;
   // speed up after X frames
   final private int FRAME_DELAY_RATE = 3;

   
   private final String[] imgPaths = {
     "quickshot/img/phones-crowd.jpeg",
     "quickshot/img/chickens.jpg",
     "quickshot/img/cows.jpg",
     "quickshot/img/fire.jpg",
     "quickshot/img/flood.jpg",
     "quickshot/img/vr-group.jpg",
     "quickshot/img/rocket.jpg",     
   };
   
   
   public Quickshot(NetAddress remoteLocation, OscP5 oscP5, VideoLoader vl) {
     this.imgIdx = 0;
     this.m = null;
     this.frameDelay = 4;
     this.queueCounter = 0;
     this.delayRate = 1;
     
     this.vl = vl;
     this.oscP5  = oscP5;
     this.remoteLocation = remoteLocation;
     
   }
   
   public void queueImg() {
     //println("qs img: " + initialDelay * delayRate);
     if (m != null) {
       m.stop();
     }
     PImage temp = loadImage(imgPaths[imgIdx % imgPaths.length]);
     while (temp == null) delay(2);
     img = temp;
     imgIdx += 1;
     queueCounter += 1;
     //delay *= 0.95;
     if (frameDelay > 1 && queueCounter % FRAME_DELAY_RATE == 0) {
       frameDelay -= 1;
     }
   }
   
   public Movie queueVideo() {
     // osc stuff
     OscMessage delayMessage = new OscMessage("/quickshot/drumhit");
     oscP5.send(delayMessage, remoteLocation);
     return vl.stepMovie(MOVIEPHASE.QUICKSHOT);
   }
   
   
   public PImage getImg() {
     return this.img;
   }
}
