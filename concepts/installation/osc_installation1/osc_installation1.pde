/*
  VECTOR FIELD SKETCH - Rewritten
  - Reuses PVector objects for performance
  - Smooths OSC inputs
  - Alpha trails instead of clearing every frame
  - Color by velocity / OSC-controlled hue
  - Toggleable flow-field debug visualization
  - Adjustable particle count and speed via OSC/keyboard
  - Port: 9001, OSC addresses: /osc0 ... /osc7

  OSC mapping (recommended):
    /osc0 -> field X offset
    /osc1 -> field Y offset
    /osc2 -> turbulence (noise frequency)
    /osc3 -> rotation bias (radians)
    /osc4 -> field magnitude
    /osc5 -> particle speed limiter
    /osc6 -> color hue (0..1)
    /osc7 -> toggle field display (>0.5 = show)

  */

import oscP5.*;
import netP5.*;

OscP5 oscP5;
float[] oscValues = new float[8];       // raw OSC inputs (0..1)
float[] smOsc = new float[8];          // smoothed OSC inputs

int scl = 25;                          // flow-field cell size
int cols, rows;
PVector[][] field;                     // reused PVectors

ArrayList<Particle> particles = new ArrayList<Particle>();
int particleCount = 800;               // default

boolean showField = false;

// visual settings
float trailAlpha = 18;                 // 0..255 (low = long trails)
float baseHue = 0.6;                   // fallback hue (HSB 0..1)

void settings() {
  size(1000, 700, P2D);
}

void setup() {
  colorMode(HSB, 1.0);
  noCursor();

  oscP5 = new OscP5(this, 9001);

  cols = ceil((float)width / scl);
  rows = ceil((float)height / scl);

  // allocate field and initialize PVectors once
  field = new PVector[cols][rows];
  for (int x = 0; x < cols; x++) {
    for (int y = 0; y < rows; y++) {
      field[x][y] = new PVector(1, 0);
    }
  }

  // initial particles
  for (int i = 0; i < particleCount; i++) particles.add(new Particle());

  // init smoothed osc values
  for (int i = 0; i < 8; i++) smOsc[i] = 0;

  background(1); // white background (HSB brightness=1)
}

void draw() {
  // smooth raw OSC inputs (makes motion less jumpy)
  float smoothAmt = 0.08; // 0 = instant, 1 = never
  for (int i = 0; i < 8; i++) smOsc[i] = lerp(smOsc[i], oscValues[i], smoothAmt);

  // optional: map smOsc into named params for clarity
  float fieldOffsetX = map(smOsc[0], 0, 1, -10, 10);
  float fieldOffsetY = map(smOsc[1], 0, 1, -10, 10);
  float turbulence  = map(smOsc[2], 0, 1, 0.02, 0.5); // noise frequency
  float rotBias     = map(smOsc[3], 0, 1, -PI, PI);
  float fieldMag    = map(smOsc[4], 0, 1, 0.2, 6);
  float particleMax = map(smOsc[5], 0, 1, 0.5, 12);
  float hueCtrl     = smOsc[6];
  boolean fieldToggle = smOsc[7] > 0.5 || showField;

  // trails: draw translucent rect over previous frame
  noStroke();
  fill(1, trailAlpha/255.0); // white with small alpha
  rect(0, 0, width, height);

  // update the vector field efficiently
  float t = millis() * 0.0003; // time component
  float baseX = fieldOffsetX;
  float baseY = fieldOffsetY;

  for (int x = 0; x < cols; x++) {
    float nx = x * turbulence + baseX;
    for (int y = 0; y < rows; y++) {
      float ny = y * turbulence + baseY;

      // noise returns 0..1, map to angle with extra rotation bias
      float n = noise(nx + t, ny + t);
      float angle = n * TWO_PI * (1.0 + smOsc[2] * 3.0) + rotBias;

      float mag = fieldMag;

      // set existing PVector values (reuse alloc'd PVectors)
      PVector v = field[x][y];
      v.x = cos(angle) * mag;
      v.y = sin(angle) * mag;
    }
  }

  // update and draw particles
  strokeWeight(1);
  for (int i = particles.size()-1; i >= 0; i--) {
    Particle p = particles.get(i);
    p.follow(field, scl, cols, rows);
    p.update(particleMax);
    p.edges();
    p.show(hueCtrl);
  }

  // optional field debug overlay
  if (fieldToggle) {
    drawFieldOverlay();
  }
}


// ─────────────────────────────────────────────
// Draw small arrows for the flow field (debug)
// ─────────────────────────────────────────────
void drawFieldOverlay() {
  stroke(0, 0.2);
  pushStyle();
  for (int x = 0; x < cols; x++) {
    for (int y = 0; y < rows; y++) {
      PVector v = field[x][y];
      float px = x * scl + scl * 0.5;
      float py = y * scl + scl * 0.5;

      pushMatrix();
      translate(px, py);
      float h = v.heading();
      rotate(h);
      float len = constrain(v.mag() * 6, 2, scl);
      line(0, 0, len, 0);
      popMatrix();
    }
  }
  popStyle();
}

// ─────────────────────────────────────────────
// Particle class
// ─────────────────────────────────────────────
class Particle {
  PVector pos, vel, acc;
  float maxHistory = 10; // not used, but could store trail

  Particle() {
    pos = new PVector(random(width), random(height));
    vel = PVector.random2D().mult(0.5);
    acc = new PVector();
  }

  void follow(PVector[][] f, int s, int c, int r) {
    int x = int(pos.x / s);
    int y = int(pos.y / s);
    x = constrain(x, 0, c - 1);
    y = constrain(y, 0, r - 1);
    PVector force = f[x][y];
    acc.add(force);
  }

  void update(float speedLimit) {
    vel.add(acc);
    vel.mult(0.975); // damping for smoother motion
    vel.limit(speedLimit);
    pos.add(vel);
    acc.mult(0);
  }

  void edges() {
    if (pos.x > width) pos.x = 0;
    if (pos.x < 0) pos.x = width;
    if (pos.y > height) pos.y = 0;
    if (pos.y < 0) pos.y = height;
  }

  void show(float hueCtrl) {
    float speed = vel.mag();
    float h = (hueCtrl + speed * 0.05) % 1.0; // color varies with speed
    float b = map(speed, 0, 6, 0.6, 1.0);

    stroke(h, 0.8, b, 0.9);
    strokeWeight(map(speed, 0, 6, 0.6, 2.2));
    point(pos.x, pos.y);
  }
}

// ─────────────────────────────────────────────
// Keyboard controls
// ─────────────────────────────────────────────


void reseedParticles() {
  particles.clear();
  for (int i = 0; i < particleCount; i++) particles.add(new Particle());
}

void changeParticleCount(int delta) {
  particleCount = max(0, particleCount + delta);
  int diff = particleCount - particles.size();
  if (diff > 0) {
    for (int i = 0; i < diff; i++) particles.add(new Particle());
  } else if (diff < 0) {
    for (int i = 0; i < -diff; i++) {
      if (particles.size() > 0) particles.remove(particles.size()-1);
    }
  }
}

void oscEvent(OscMessage msg) {
  if (msg.checkAddrPattern("/motion10_10_10_11")==true) {
    oscValues[0] = msg.get(0).floatValue();  // 0–1
  }
  if (msg.checkAddrPattern("/motion10_10_10_12")==true) {
    oscValues[1] = msg.get(0).floatValue();  // 0–1
  }
  if (msg.checkAddrPattern("/motion10_10_10_13")==true) {
    oscValues[2] = msg.get(0).floatValue();  // 0–1
  }
  if (msg.checkAddrPattern("/motion10_10_10_14")==true) {
    oscValues[3] = msg.get(0).floatValue();  // 0–1
  }
  if (msg.checkAddrPattern("/motion10_10_10_15")==true) {
    oscValues[4] = msg.get(0).floatValue();  // 0–1
  }
  if (msg.checkAddrPattern("/motion10_10_10_16")==true) {
    oscValues[5] = msg.get(0).floatValue();  // 0–1
  }
  if (msg.checkAddrPattern("/motion10_10_10_17")==true) {
    oscValues[6] = msg.get(0).floatValue();  // 0–1
  }
  if (msg.checkAddrPattern("/motion10_10_10_18")==true) {
    oscValues[7] = msg.get(0).floatValue();  // 0–1
  }
}
