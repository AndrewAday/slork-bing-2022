class VideoLoader {
  private PApplet that;
  
  private final String[] p1Paths = {
    "p-one/dunes.mp4",
    "p-one/fog.mp4",
    "p-one/lake-stars.mp4",
    "p-one/northern-lights.mp4",
    "p-one/orange-clouds.mp4",
    "p-one/rock-stars.mp4",
    "p-one/stars-thunderstorm.mp4",
    "p-one/stars-timelapse.mp4",
    "p-one/stars-trees.mp4",
    "p-one/thunderstorm-far.mp4",
    "p-one/joshuatree-landscape.mp4",
    "p-one/joshuatree-single.mp4"
  };
  
  
  private final String[] p2Paths = {
      // good
     "p-two/good/beijing-aerial-still-looped.mp4",
     "p-two/good/coaster-fast.mp4",
     "p-two/good/feetwalking.mp4",
     "p-two/good/merrygoround-looped.mp4",
     "p-two/good/gaming-convention-looped.mp4",
     "p-two/good/beijing-night-traffic-looped.mp4",
     "p-two/good/beijing-3-shot-looped.mp4",
     "p-two/good/hongkong-crowds2-looped.mp4",
     "p-two/good/hongkong-building.mp4",
     "p-two/good/fireworks-nologo.mp4",
     // bad
     "p-two/bad/behemoth-forge-1-2.mp4",
     "p-two/bad/behemoth-forge-2.mp4",
     "p-two/bad/behemoth-forge-3.mp4",
     "p-two/bad/deforestation-looped.mp4",
     "p-two/bad/rivers-drying-2-shot.mp4",
     "p-two/bad/mining-explosion.mp4",
     "p-two/bad/behemoth-mine.mp4",
     "p-two/bad/driving.mp4",
     "p-two/bad/construction.mp4",
     "p-two/bad/wind-turbine.mp4",
     "p-two/bad/behemoth-factory-looped.mp4",
   };
   
   private final String[] quickshotPaths = {
     "p-two/bad/behemoth-forge-1-2.mp4",
     "p-two/good/beijing-aerial-still-looped.mp4",
     
     "p-two/bad/behemoth-forge-2.mp4",
     "p-two/good/coaster.mp4",
     
     "p-two/bad/behemoth-forge-3.mp4",
     "p-two/good/feetwalking.mp4",
     
     "p-two/bad/deforestation-all.mp4",
     "p-two/good/merrygoround-looped.mp4",
     
     "p-two/bad/rivers-drying-2-shot.mp4",
     "p-two/good/gaming-crowds.mp4",
     
     "p-two/bad/mining-explosion.mp4",
     "p-two/good/beijing-night-traffic-looped.mp4",
     
     "p-two/bad/behemoth-mine.mp4",
     "p-two/good/beijing-3-shot-looped.mp4",
     
     "p-two/bad/driving.mp4",
     "p-two/good/hongkong-crowds2-looped.mp4",
         
     "p-two/bad/wind-turbine.mp4",
     "p-two/good/hongkong-building.mp4",
     
     "p-two/bad/behemoth-factory-looped.mp4",
     "p-two/good/fireworks-nologo.mp4",
     
     // TODO: add another good/ to pair with construction.mp4
     
     "quickshot/deer.mp4",
     "quickshot/deer-mounted.mp4",
     "quickshot/water-overflowing.mp4",
     "quickshot/dry-cracks.mp4",
     "quickshot/lemon.mp4",
     "quickshot/forge.mp4",
     "quickshot/slot-machine.mp4",
     "quickshot/queen-bullet.mp4",
     "quickshot/bullet-bill.mp4",
     "quickshot/excavator.mp4",
   }; // TODO add quickshot paths from quickshot.pde
   
   private final String[] endPaths = {
     "p-four/window-rain.mp4",
     "p-four/water-walk.mp4",
    //  "p-four/pool.mp4",
    //  "p-four/olive-tree.mp4",
    //  "p-four/train-side-view.mp4",
    //  "p-four/trees-and-clouds.mp4",
     "p-four/waves.mp4",
     
   };
   
   // p1 vars
   public Movie switcher[] = new Movie[2];
   public boolean prevLeft = false;
   
   private ArrayList<Movie> p1Movies = new ArrayList<Movie>();
   private ArrayList<Movie> p2Movies = new ArrayList<Movie>();
   private ArrayList<Movie> quickshotMovies = new ArrayList<Movie>();
   private ArrayList<Movie> endMovies = new ArrayList<Movie>();
   private ArrayList<ArrayList<Movie>> movies = new ArrayList<ArrayList<Movie>>();
   
   public int[] movieIdxs = {0, 0, 0, 0};
   
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
     var movieList = movies.get(which.ordinal());
     Movie next_m = movieList.get(movieIdx % movieList.size());
     movieIdxs[which.ordinal()] = movieIdx;
     
     if (next_m == m) {
       println("no need to set, movie identical");
       return m;
     }
     
     //if (movieIdxs[which.ordinal()] == movieIdx)
     //  return m;  // already playing, do nothing
      
     if (m != null)
       m.stop();
     
     m = next_m;
     movieIdxs[which.ordinal()] = movieIdx;
     
    println("setting new movie: " + m.filename);
     
     movieSpeed = 1;
     m.loop();
     return m;
   }
   
   public int getMovieIdx(MOVIEPHASE which) {
     return movieIdxs[which.ordinal()];
   }
   
   public Movie getMovie() {
     m.loop();
     
     // on beijing night traffic video only this doesn't work???
     //if (movieSpeed < 0 && m.time() < 1) {
     // m.speed(1);
     // movieSpeed = 1;
      
     //} else if (m.duration() - m.time() < .5) {
     // m.speed(-1.0);
     // movieSpeed = -1;
     //}
     
     return m;
   }

    public void initP1() {
    this.switcher[0].loop();
    this.switcher[1].loop();
  }

   public void p1QueueRight() {
    // Movie curr = switcher[0];
    // while (true) {
    //   int r = int(random(p1Movies.size()));
    //   Movie next = p1Movies.get(r);
    //   if (!curr.filename.equals(next.filename)) {
    //     println("next: " + next.filename);
    //     switcher[1].stop();
    //     next.speed(.5);
    //     next.loop();
        
    //     switcher[1] = next;
    //     break;
    //   }
    // }
    int movieIdx = movieIdxs[MOVIEPHASE.P1.ordinal()];
    var movieList = movies.get(MOVIEPHASE.P1.ordinal());
    switcher[1].stop();
    switcher[1] = movieList.get(movieIdx % movieList.size());
   }


   public void p1QueueLeft() {
    // Movie curr = switcher[1];
    // while (true) {
    //   int r = int(random(p1Movies.size()));
    //   Movie next = p1Movies.get(r);
    //   if (!curr.filename.equals(next.filename)) {
    //     println("next: " + next.filename);
    //     switcher[0].stop();
    //     next.speed(.5);
    //     next.loop();
        
    //     switcher[0] = next;
    //     break;
    //   }
    // }
    int movieIdx = movieIdxs[MOVIEPHASE.P1.ordinal()];
    var movieList = movies.get(MOVIEPHASE.P1.ordinal());
    switcher[0].stop();
    switcher[0] = movieList.get(movieIdx % movieList.size());
   }
   
   public void exitP1() {
     switcher[0].stop();
     switcher[1].stop();
   }

    public int numMovies() {
      return p1Movies.size();
    }
}