import oscP5.*;
import netP5.*;

OscP5 osc;

HashMap<Integer, PVector> positions = new HashMap<Integer, PVector>();
HashMap<Integer, Integer> colors = new HashMap<Integer, Integer>();
HashMap<Integer, Float> radii = new HashMap<Integer, Float>();

void setup() {
  size(600,600);
  blendMode(SCREEN);

  osc = new OscP5(this, 9001);
}

void draw() {
  background(0);

  // Lines between circles
  for (Integer id1 : positions.keySet()){
    for (Integer id2 : positions.keySet()){
      PVector pos1 = positions.get(id1);
      PVector pos2 = positions.get(id2);
      color col1 = colors.get(id1);
      color col2 = colors.get(id2);
      
      float d = dist(pos1.x, pos1.y,
                     pos2.x, pos2.y);

      if (d < 200) {
        float a = map(d, 0, 200, 180, 0);
        color c = lerpColor(col1, col2, 0.5);

        stroke(red(c), green(c), blue(c), a);
        strokeWeight(5);
       line(pos1.x, pos1.y,
             pos2.x, pos2.y);
      }
    }
  }

  // Circles
  noStroke();
  for (Integer id : positions.keySet()){
    drawCircle(id);
  }
}
 


void drawCircle(int id) {
  PVector pos = positions.get(id);
  color col = colors.get(id);
  float radius = radii.get(id);
  
  float d = dist(pos.x, pos.y, width/2, height/2);

  float a = map(d, 0, max(width, height)/2, 255, 40);
  a = constrain(a, 40, 255);

  noStroke();
  for (int i = 5; i > 0; i--) {
    float t = i / 5.0;
    fill(red(col), green(col), blue(col), a * t);
    float r = radius * t;
    ellipse(pos.x, pos.y, r, r);
  }
}


// Receive OSC
void oscEvent(OscMessage msg) {
  println("received messaged!");
  if (msg.checkAddrPattern("/circle")) {
    int redVal = int(msg.get(0).floatValue());
    int greenVal = int(msg.get(1).floatValue());
    int blueVal = int(msg.get(2).floatValue());
    float radius = msg.get(3).floatValue();
    float x = msg.get(4).floatValue();
    float y = msg.get(5).floatValue();
    int id = msg.get(6).intValue();
  
    colors.put(id, color(redVal,greenVal, blueVal));
    positions.put(id, new PVector(x,y));
    radii.put(id, radius);
    
  }
}
