2 => int N;
ADSR adsrs[N];
LiSa lisas[N];

for (int i; i < N; i++) {
  adc => lisas[i] => adsrs[i] => dac;

  1 => lisas[i].loop;
  (2::second, 0::ms, 1, 2::second) => adsrs[i].set;
}

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Event message;
float entropy;

Event release;

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

fun void record(int i, dur duration) {
  lisas[i] @=> LiSa @ lisa;

  duration => lisa.duration;
  10::ms => lisa.recRamp;

  1 => lisa.record;
  duration => now;
  0 => lisa.record;
}

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

fun void modulate(int i) {
  lisas[i] @=> LiSa @ lisa;

  while (true) {
    message => now;
    (entropy, 0, 1, 0.8, 1.5) => Math.map => lisa.rate;
  }
}

fun void play(int i) {
  lisas[i] @=> LiSa @ lisa;
  adsrs[i] @=> ADSR @ adsr;

  1 => lisa.play;
  adsr.keyOn();
  spork ~ modulate(i) @=> Shred modulator;
  release => now;
  adsr.keyOff();
  adsr.releaseTime() => now;
  0 => lisa.play;
}

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

fun void main() {
  int i;
  while (true) {
    release.broadcast();
    spork ~ play(i);
    1 +=> i;
    N %=> i;
    spork ~ record(i, 10::second);

    10::second => now;
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

eon => now;