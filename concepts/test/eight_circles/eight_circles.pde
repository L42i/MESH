// 8 bouncing, color-combining circles
// Brightness fades with distance from center

int N = 8;
Mover[] movers;

void setup() {
  size(800, 600);
  //smooth();
  blendMode(SCREEN); // overlapping colors combine nicely
  movers = new Mover[N];
  for (int i = 0; i < N; i++) {
    movers[i] = new Mover();
  }
}

void draw() {
  background(0);
  
    for (int i = 0; i < N; i++) {
    for (int j = i + 1; j < N; j++) {
      float d = dist(movers[i].pos.x, movers[i].pos.y,
                     movers[j].pos.x, movers[j].pos.y);
      if (d < 200) {
        // Alpha fades with distance
        float a = map(d, 0, 200, 180, 0);
        // Color = mid blend between both circles
        color c = lerpColor(movers[i].baseColor, movers[j].baseColor, 0.5);
        stroke(red(c), blue(c), green(c), a);
        strokeWeight(5);
        line(movers[i].pos.x, movers[i].pos.y, movers[j].pos.x, movers[j].pos.y);
      }
    }
    }
    
  for (Mover m : movers) {
    m.update();
    m.display();
  }
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

    // Bounce off edges
    if (pos.x < radius/2 || pos.x > width - radius/2) vel.x *= -1;
    if (pos.y < radius/2 || pos.y > height - radius/2) vel.y *= -1;
  }

  void display() {
    // Distance from screen center
    float d = dist(pos.x, pos.y, width/2, height/2);

    // Map distance to brightness (closer = brighter)
    float a = map(d, 0, max(width, height)/2, 255, 30);
    a = constrain(a, 100, 255);

    noStroke();
    for (int i = 5; i > 0; i--) {
  fill(red(baseColor), green(baseColor), blue(baseColor), a * (i / 5.0));
  ellipse(pos.x, pos.y, radius * i/5.0, radius * i/5.0);
    }
  }
}
