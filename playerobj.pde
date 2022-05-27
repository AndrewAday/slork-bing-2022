class Player {
   private int id;
   private int audioID;
   public float gain;
   
   private Movie m;
   
   private PApplet that;
   
   private final String[] moviePaths = {
     // good
     "good/clouds.mp4",
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
     "bad/behemoth-forge-1-2.mp4",
     "bad/behemoth-forge-2.mp4",
     "bad/behemoth-forge-3.mp4",
     "bad/deforestation1.mp4",
     "bad/deforestation2.mp4",
     "bad/deforestation3.mp4",
     "bad/rivers-drying-2-shot.mp4",
     "bad/mining-explosion.mp4",
     "bad/behemoth-mine.mp4",
     "bad/wind-turbine.mp4",
     "bad/behemoth-factory.mp4", 
   };
   
   public Player(PApplet that, int id) {
     this.id = id;
     this.audioID = -1;
     this.that = that;
     this.m = null;
   }
   
   public boolean isNotInitialized() {
     return this.audioID < 0 || this.m == null;
   }
   
   public void setAudioID(int id) {
     if (this.audioID == id) {
       return;
     }
     this.audioID = id;
     if (m != null) {
       m.stop();
     }
     m = new Movie(that, moviePaths[id % moviePaths.length]);
     m.loop();
     
   }
   
   public Movie getMovie() {
     return this.m;
   }
   
}
