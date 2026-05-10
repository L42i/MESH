@import "granular.ck"

Granular g(me.dir() + "water.wav") => dac;

Event message;
float entropy;

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

fun void main() {
  while (true) {
    message => now;

    (entropy, 0, 1, 0.8, 0.1) => Math.map => g.rate.x;
    (entropy, 0, 1, 1.25, 10) => Math.map => g.rate.y;

    (entropy, 0, 1, 100, 4) => Math.map => g.duration.x;
    (entropy, 0, 1, 200, 50) => Math.map => g.duration.y;
  }
}

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

fun void osc() {
  OscIn oin;

  57120 => oin.port;

  cherr <= "listening for OSC messages over port: " <= oin.port()
        <= "..." <= IO.newline();

  oin.listenAll();

  OscMsg msg;

  while (true) {
    oin => now;

    while (msg => oin.recv) {
      if (msg.address != "/entropy") continue;
      for (int n; n < msg.numArgs(); n++) {
        n => msg.getFloat => entropy;
        message.broadcast();
      }
    }
  }
}

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

spork ~ osc();
spork ~ main();

g.noteOn();

eon => now;