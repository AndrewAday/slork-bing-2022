class VideoLoader {
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
   
   private ArrayList<Movie> p2Movies = new ArrayList<Movie>();
   private ArrayList<Movie> quickshotMovies = new ArrayList<Movie>();
   private ArrayList<Movie> endMovies = new ArrayList<Movie>();
   
   private int p2Idx = 0;
   private int quickshotIdx = 0;
   private int endIdx = 0;
   
   private Movie m;
   
   
   public VideoLoader(PApplet that) {
     this.that = that;
     this.m = null;
   }
   
   public void loadVideos() {
     for (int i = 0; i < moviePaths.length; i++) {
       this.p2Movies.add(new Movie(that, moviePaths[i]));
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
}
