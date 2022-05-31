class VideoLoader {
  private PApplet that;
  
  private final String[] p1Paths = {
    "p1/clouds.mp4",
    "p1/grandcanyon.mp4",
    "p1/grass.mp4",
    "p1/lava2.mp4",
    "p1/mountain.mp4",
    "p1/sunflower.mp4",
  };
  
  
  private final String[] p2Paths = {
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
   
   private final String[] quickshotPaths = {
     "good/clouds.mp4",
     "bad/behemoth-forge-1-2.mp4",
     "good/beijing-aerial-still.mp4",
     "bad/behemoth-forge-2.mp4",
   };
   
   private final String[] endPaths = {
     "quickshot/waves.mp4",
     "quickshot/window-rain.mp4"
   };
   
   // p1 vars
   public Movie switcher[] = new Movie[2];
   public boolean prevLeft = false;
   
   private ArrayList<Movie> p1Movies = new ArrayList<Movie>();
   private ArrayList<Movie> p2Movies = new ArrayList<Movie>();
   private ArrayList<Movie> quickshotMovies = new ArrayList<Movie>();
   private ArrayList<Movie> endMovies = new ArrayList<Movie>();
   
   private int p2Idx = 0;
   private int quickshotIdx = 0;
   private int endIdx = 0;
   
   private Movie m;
   
   
   public VideoLoader(PApplet that) {
     this.that = that;
     loadVideos();
     this.switcher[0] = p1Movies.get(0);
     this.switcher[1] = p1Movies.get(1);
     this.m = p1Movies.get(0);
   }
   
   private void loadVideos() {
     for (int i = 0; i < p1Paths.length; i++) {
       this.p1Movies.add(new Movie(that, p1Paths[i]));
     }
     for (int i = 0; i < p2Paths.length; i++) {
       this.p2Movies.add(new Movie(that, p2Paths[i]));
     }
     for (int i = 0; i < quickshotPaths.length; i++) {
       this.quickshotMovies.add(new Movie(that, quickshotPaths[i]));
     }
     for (int i = 0; i < endPaths.length; i++) {
       this.endMovies.add(new Movie(that, endPaths[i]));
     }
   }
   
   public Movie stepMovie(MOVIEPHASE which) {
     if (m != null) {
       m.stop();
     }
     if (which == MOVIEPHASE.P2) {    
       m = p2Movies.get(p2Idx % p2Movies.size());
       p2Idx += 1;
     } else if (which == MOVIEPHASE.QUICKSHOT) {
       m = quickshotMovies.get(quickshotIdx % quickshotMovies.size());
       quickshotIdx += 1;
     } else if (which == MOVIEPHASE.END) {
       m = endMovies.get(endIdx % endMovies.size());
       endIdx += 1;
     }
     m.loop();
     return m;
   }
   
   public Movie setMovie(MOVIEPHASE which, int idx) {
     Movie newMovie = null;
     if (which == MOVIEPHASE.P2) {   
       if (p2Idx == idx) {
         return m;
       }
       p2Idx = idx;
       newMovie = p2Movies.get(p2Idx % p2Movies.size());
     } else if (which == MOVIEPHASE.QUICKSHOT) {
       if (quickshotIdx == idx) {
         return m;
       }
       quickshotIdx = idx;
       newMovie = quickshotMovies.get(quickshotIdx % quickshotMovies.size());
     } else if (which == MOVIEPHASE.END) {
       if (endIdx == idx) {
         return m;
       }
       endIdx = idx;
       newMovie = endMovies.get(endIdx % endMovies.size());
     }
     if (m != null) {
       m.stop();
     }
     m = newMovie;
     m.loop();
     return m;
   }
   
   public Movie getMovie() {
     return m;
   }
   
   public int numMovies() {
     return p2Movies.size();
   }
   
   public void p1QueueRight() {
    Movie curr = switcher[0];
    while (true) {
      int r = int(random(p1Movies.size()));
      Movie next = p1Movies.get(r);
      if (!curr.filename.equals(next.filename)) {
        println("next: " + next.filename);
        switcher[1].stop();
        next.loop();
        switcher[1] = next;
        break;
      }
    }
   }
   
   public void p1QueueLeft() {
    Movie curr = switcher[1];
    while (true) {
      int r = int(random(p1Movies.size()));
      Movie next = p1Movies.get(r);
      if (!curr.filename.equals(next.filename)) {
        println("next: " + next.filename);
        switcher[0].stop();
        next.loop();
        switcher[0] = next;
        break;
      }
    }
   }
   
   public void exitP1() {
     switcher[0].stop();
     switcher[1].stop();
   }
}
