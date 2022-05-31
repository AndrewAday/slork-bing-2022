class VideoLoader {
  private PApplet that;
  
  private final String[] p1Paths = {
    "p1/lake-shooting-stars.mp4",
    "p1/night-thunderstorm.mp4",
    "p1/northern-lights.mp4",
    "p1/orange-clouds-timelapse.mp4",
    "p1/rock-stars-timelapse.mp4",
    "p1/joshuatree-landscape.mp4",
    "p1/joshuatree-stars.mp4"
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
   }; // TODO add quickshot paths from quickshot.pde
   
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
   private ArrayList<ArrayList<Movie>> movies = new ArrayList<ArrayList<Movie>>();
   
   private int[] movieIdxs = {0, 0, 0, 0};
   
   private Movie m;
   private float movieSpeed = 1;
   
   
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
     this.movies.add(p1Movies);
     this.movies.add(p2Movies);
     this.movies.add(quickshotMovies);
     this.movies.add(endMovies);
     println("movies loaded");
   }
   
   public Movie stepMovie(MOVIEPHASE which) {
     if (m != null) {
       m.stop();
     }
     
     int movieIdx = movieIdxs[which.ordinal()];
     var movieList = movies.get(which.ordinal());
     m = movieList.get(movieIdx % movieList.size());
     movieIdxs[which.ordinal()] += 1;
     
     println("stepping new movie: " + m.filename);
     
     movieSpeed = 1;
     m.loop();
     return m;
   }
   
   public Movie setMovie(MOVIEPHASE which, int movieIdx) {
     if (movieIdxs[which.ordinal()] == movieIdx)
       return m;  // already playing, do nothing
      
     if (m != null)
       m.stop();
     
     var movieList = movies.get(which.ordinal());
     m = movieList.get(movieIdx % movieList.size());
     movieIdxs[which.ordinal()] = movieIdx;
     
    println("setting new movie: " + m.filename);
     
     movieSpeed = 1;
     m.loop();
     return m;
   }
   
   public Movie getMovie() {
     m.loop();
     
     // on beijing night traffic video only this doesn't work???
     if (movieSpeed < 0 && m.time() < 1) {
      m.speed(1);
      movieSpeed = 1;
      
     } else if (m.duration() - m.time() < .5) {
      m.speed(-1.0);
      movieSpeed = -1;
     }
     
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

  public void initP1() {
    this.switcher[0].loop();
    this.switcher[1].loop();
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