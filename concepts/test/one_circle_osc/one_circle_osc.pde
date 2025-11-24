import oscP5.*;
import netP5.*;

OscP5 osc;
NetAddress dest;

Mover mover;

int ID = int(random(10000));   // random ID for each Pi

void setup() {
  size(600,600);
  blendMode(SCREEN);

  osc = new OscP5(this, 9000);     // listen on port 9000

  mover = new Mover();
}

void draw() {
  background(0);

  mover.display();
}

// --------------------- OSC RECEIVE ---------------------
void oscEvent(OscMessage msg) {
  if (msg.checkAddrPattern("/motion") && msg.checkTypetag("ff")) {

    float normX = msg.get(0).floatValue();   // 0–1
    float normY = msg.get(1).floatValue();   // 0–1

    // scale to screen
    float mappedX = normX * width;
    float mappedY = normY * height;

    mover.pos.set(mappedX, mappedY);
  }
}

// --------------------- Circle Class ---------------------
class Mover {
  PVector pos;
  color baseColor;
  float radius;

  Mover() {
    pos = new PVector(width/2, height/2);   // start in center
    baseColor = color(random(60, 255), random(60, 255), random(60, 255));
    radius = random(40, 100);
  }

  void display() {
    float d = dist(pos.x, pos.y, width/2, height/2);
    float a = map(d, 0, max(width, height)/2, 255, 40);
    a = constrain(a, 40, 255);

    noStroke();
    for (int i = 5; i > 0; i--) {
      float t = i / 5.0;
      fill(red(baseColor), green(baseColor), blue(baseColor), a * t);
      float r = radius * t;
      ellipse(pos.x, pos.y, r, r);
    }
  }
}
