import oscP5.*;
import netP5.*;

OscP5 osc;
float[] params = new float[8];          // raw parameters (0–1)
float[] smoothed = new float[8];        // smoothed params

float angle = 0;

void setup() {
  fullScreen(P2D);
  colorMode(HSB, 1.0);
  background(0);
  
  osc = new OscP5(this, 9001);          // listen on port 9001
}

void draw() {
  // fade background
  float fade = map(smoothed[6], 0, 1, 0.01, 0.3);
  fill(0, fade);
  noStroke();
  rect(0, 0, width, height);

  translate(width/2, height/2);

  // rotation speed
  float rotSpeed = map(smoothed[0], 0, 1, 0.001, 0.1);
  angle += rotSpeed;

  // line thickness
  strokeWeight(map(smoothed[3], 0, 1, 0.5, 8));
  
  // base shape size
  float baseSize = map(smoothed[1], 0, 1, 50, 1000);

  // noise scale
  float nscale = map(smoothed[4], 0, 1, 0.001, 0.02);

  // number of shapes
  int count = int(map(smoothed[5], 0, 1, 3, 50));

  // hue
  float h = smoothed[2];
  stroke(h, 1, 1, 0.7);
  noFill();

  // symmetry toggle
  boolean mirror = smoothed[7] > 0.5;

  // draw shapes
  pushMatrix();
  rotate(angle);

  for (int i = 0; i < count; i++) {
    float a = TWO_PI * i / count;
    float r = baseSize + noise(i * nscale, frameCount * 0.01) * 200;

    float x = cos(a) * r;
    float y = sin(a) * r;

    ellipse(x, y, 20, 20);

    if (mirror) {
      ellipse(-x, y, 20, 20);
      ellipse(x, -y, 20, 20);
      ellipse(-x, -y, 20, 20);
    }
  }
  popMatrix();

  // smooth params
  for (int i=0; i<8; i++) {
    smoothed[i] = lerp(smoothed[i], params[i], 0.1);
  }
}

// OSC input handler
void oscEvent(OscMessage msg) {
  if (msg.checkAddrPattern("/motion10_10_10_11")==true) {
    params[0] = msg.get(0).floatValue();  // 0–1
  }
  if (msg.checkAddrPattern("/motion10_10_10_12")==true) {
    params[1] = msg.get(0).floatValue();  // 0–1
  }
  if (msg.checkAddrPattern("/motion10_10_10_13")==true) {
    params[2] = msg.get(0).floatValue();  // 0–1
  }
  if (msg.checkAddrPattern("/motion10_10_10_14")==true) {
    params[3] = msg.get(0).floatValue();  // 0–1
  }
  if (msg.checkAddrPattern("/motion10_10_10_15")==true) {
    params[4] = msg.get(0).floatValue();  // 0–1
  }
  if (msg.checkAddrPattern("/motion10_10_10_16")==true) {
    params[5] = msg.get(0).floatValue();  // 0–1
  }
  if (msg.checkAddrPattern("/motion10_10_10_17")==true) {
    params[6] = msg.get(0).floatValue();  // 0–1
  }
  if (msg.checkAddrPattern("/motion10_10_10_18")==true) {
    params[7] = msg.get(0).floatValue();  // 0–1
  }
}
