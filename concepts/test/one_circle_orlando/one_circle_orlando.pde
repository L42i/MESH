import oscP5.*;
import netP5.*;

OscP5 osc;
NetAddress dest;

Mover mover;

int ID = int(random(10000));   // randomly set ID --> each PI needs a distinct random ID

void setup() {
  size(600,600);
  blendMode(SCREEN);

  osc = new OscP5(this, 9000);     // local OSC port
  dest = new NetAddress("10.10.10.24", 9001);  

  mover = new Mover();
}

void draw() {
  background(0);

  mover.update();
  mover.display();

  sendOSC();
}

void sendOSC() {
  OscMessage msg = new OscMessage("/circle");

  msg.add(red(mover.baseColor));
  msg.add(green(mover.baseColor));
  msg.add(blue(mover.baseColor));
  msg.add(mover.radius);
  msg.add(mover.pos.x);
  msg.add(mover.pos.y);
  msg.add(ID);
  osc.send(msg, dest);
}

class Mover {
  PVector pos;
  PVector vel;
  color baseColor;
  float radius;

  Mover() {
    pos = new PVector(random(width), random(height));
    vel = PVector.random2D().mult(random(1.5, 4.0));
    baseColor = color(random(60, 255), random(60, 255), random(60, 255));
    radius = random(40, 100);
  }

  void update() {
    pos.add(vel);

    if (pos.x < radius/2 || pos.x > width - radius/2) vel.x *= -1;
    if (pos.y < radius/2 || pos.y > height - radius/2) vel.y *= -1;
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
