static public class Util {

  static boolean approxWithin(float a, float b, float c) {  // diff < c
    return abs(a - b) < c;
  }
}
