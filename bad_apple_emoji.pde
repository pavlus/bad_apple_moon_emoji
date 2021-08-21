import processing.video.*; //<>//

/**
 Some ideas: 
 > add multithreading for mapping frames too moons (split into regions, feed into ExecutorService, await, draw, swap buffers);
 > make background color change with average scene brightness; 
 > use less moons, but make them move, too look like a ballroom from above;
 > also make them scale dynamically;
 **/

Movie video;

/**========= Configuration ===========**/
static final int BW_THRESHOLD = 127;
static final color BG_COLOR = 67;
static final int TILE_WIDTH = 24, TILE_HEIGHT = 24;
//static final int TILE_WIDTH = 8, TILE_HEIGHT = 8;
static final String THEME = "twi";
//static final String THEME = "noto";

static final boolean START_IMMEDIATELY = true;

static final boolean DUMP_FRAMES = true;
static final boolean DEBUG = false;
void settings() {
  size(960, 720);
  //size(1440, 1080);
  //size(1920, 1440);
}
/**===================================**/

String[] moon_names = new String[]{
  "full", 
  "waning_gibbous", 
  "last_quarter", 
  "waning_crescent", 
  "new", 
  "waxing_crescent", 
  "first_quarter", 
  "waxing_gibbous"
};

PImage[] moons;
PImage[] hashToTile = new PImage[16];

int xSize, ySize;
int tileWidth, tileHeight;

PGraphics[] buff = new PGraphics[2];
Object lock = new Object();
volatile boolean started = false;

void setup() {
  frameRate(30.0);  
  background(BG_COLOR);
  moons = new PImage[moon_names.length];
  for (int i = 0; i < moon_names.length; ++i) {
    String path = dataFile(THEME + "/"  + moon_names[i] + ".png").toString();
    if (DEBUG) println(path);

    PImage tmp = loadImage(path);
    tmp.resize(TILE_WIDTH, TILE_HEIGHT);
    // tmp.resize(tmp.width / 11, tmp.height / 11);
    moons[i] = tmp;
  }

  initTileMapping();

  tileWidth = moons[0].width; 
  tileHeight = moons[0].height;
  xSize = width / tileWidth; 
  ySize = height / tileHeight;
  println("It's gonna be " + xSize + " by " + ySize +" field, so " + (xSize * ySize) + " moons in total!");
  buff[0] = createGraphics(width, height);
  buff[1] = createGraphics(width, height);

  video = new Movie(this, dataFile("ba.mp4").toString());
  if (START_IMMEDIATELY) {
    started = true;
    video.play();
  }
}


void draw() {
  if (!started) return;
  synchronized(lock) {
    image(buff[1], 0, 0);
    if (DUMP_FRAMES) saveFrame("frames/####.tiff");
  }

  if (DEBUG) image(video, 0, 0, 96, 72);
}

void movieEvent(Movie m) {
  m.read();
  m.loadPixels();
  PGraphics buf = buff[0]; 
  buf.beginDraw();
  buf.background(BG_COLOR);
  int xStep = m.width / xSize, yStep = m.height / ySize;

  // walk around pixels corresponding to tiles and get their "hashes", hash is 4-bits number
  // tile is split horizontally into 4 vertical regions, if region average color is brighter than middle gray
  // then corresponding bit of the hash is set to 1, otherwise it's 0.
  for (int j = 0; j < ySize * yStep - 1; j += yStep) for (int i = 0; i < xSize * xStep; i += xStep) {
    int step = xStep / 4;
    byte hash = 0;
    hash |= brighterThanGray(m.pixels, m.width, i, j, i + step, j + yStep) << 3;
    hash |= brighterThanGray(m.pixels, m.width, i + step, j, i + step * 2, j + yStep) << 2;
    hash |= brighterThanGray(m.pixels, m.width, i + step * 2, j, i + step * 3, j + yStep) << 1;
    hash |= brighterThanGray(m.pixels, m.width, i + step * 3, j, i + xStep, j + yStep) << 0;

    buf.image(hashToTile[hash], i / xStep * tileWidth, j / yStep * tileHeight);
  }
  buf.endDraw();
  synchronized(lock) {
    PGraphics tmp = buff[1];
    buff[1] = buff[0];
    buff[0] = tmp;
  }
}


// 1 for true, 0 for false.
int brighterThanGray(int[] pixels, int width, int xStart, int yStart, int xEnd, int yEnd) {
  return avgBrightness(pixels, width, xStart, yStart, xEnd, yEnd) > BW_THRESHOLD ? 1 : 0;
}

int avgBrightness(int[] pixels, int width, int xStart, int yStart, int xEnd, int yEnd) {
  int sum = 0;
  int count = (xEnd - xStart) * (yEnd - yStart);

  for (int i = xStart; i < xEnd; ++i) for (int j = yStart; j < yEnd; ++j) {
    try {
      sum += brightness(pixels[width*j + i]);
    } 
    catch (IndexOutOfBoundsException ioobe) {
      println("x = " + i + "; y = " + j);
      throw ioobe;
    }
  }
  return sum / count;
}

void keyPressed() {
  if (!started && key == ' ') {
    started = true;
    video.play();
  }
}

void initTileMapping() {
  hashToTile[unbinary("1111")] = moons[0];
  hashToTile[unbinary("0110")] = moons[0]; // approximation: exaggregated dot
  hashToTile[unbinary("1110")] = moons[1];
  hashToTile[unbinary("1101")] = moons[1]; // approximation: misplaced hole
  hashToTile[unbinary("1100")] = moons[2];
  hashToTile[unbinary("1010")] = moons[2]; // approximation: merged hole
  hashToTile[unbinary("1000")] = moons[3];
  hashToTile[unbinary("0100")] = moons[3]; // approximation: merged hole
  hashToTile[unbinary("0000")] = moons[4];
  hashToTile[unbinary("1001")] = moons[4]; // approximation: exaggregated hole
  hashToTile[unbinary("0001")] = moons[5];
  hashToTile[unbinary("0010")] = moons[5]; // approximation: merged hole
  hashToTile[unbinary("0011")] = moons[6];
  hashToTile[unbinary("0101")] = moons[6]; // approximation: merged hole
  hashToTile[unbinary("0111")] = moons[7];
  hashToTile[unbinary("1011")] = moons[7]; // approximation: misplaced hole
}
