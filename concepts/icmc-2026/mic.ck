2::second => dur TIME;
10 => float REPEAT;

(REPEAT + 1) $ int => int N;
ADSR adsrs[N];
LiSa lisas[N];
Gain gains[N];
Gain gains1[N];
Gain gains2[N];
Gain gains3[N];
DelayL delays[N];
NRev nrevs[N];

int playing[N];
int numPlaying;

0.95 => float G;
1 - G => float G2;
0.95 => float G3;

adc => adsrs[0];

for (int i; i < N; i++) {
  adc => lisas[i] => adsrs[i] => nrevs[i] => gains[i] => dac;
  adsrs[i] => gains2[i] => delays[i] => nrevs[i] => dac;
  delays[i] => gains3[i] => delays[i];

  0::ms => delays[i].delay;
  G => gains[i].gain;
  G2 => gains2[i].gain;
  G3 => gains3[i].gain;
  0.1 => nrevs[i].mix;

  100::ms => delays[i].max;

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

  spork ~ play(i);
}

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

fun void modulate() {
  while (true) {
    message => now;
    for (int i; i < N; i++) {
      if (!playing[i]) continue;

      lisas[i] @=> LiSa @ lisa;

      gains[i].gain() / numPlaying => gains[i].gain;
      gains2[i].gain() / numPlaying => gains2[i].gain;

      (entropy, 0, 1, 0.5, 1.5) => Math.map => lisa.rate;
    }
  }
}

fun void delay() {
  float min;
  float max;
  float delay;
  float wait;

  while (true) {
    (entropy, 0, 1, 0, 10) => Math.map => min;
    (entropy, 0, 1, 10, 100) => Math.map => max;

    for (DelayL d : delays) {
      (min, max) => Math.random2f => delay;
      delay::ms => d.delay;
    }

    (entropy, 0, 1, 1000, 100) => Math.map => wait;
    wait::ms => now;
  }
}

fun void play(int i) {
  lisas[i] @=> LiSa @ lisa;
  adsrs[i] @=> ADSR @ adsr;

  true => playing[i];
  1 +=> numPlaying;
  1 => lisa.play;

  adsr.keyOn();
  TIME * REPEAT => now;
  adsr.keyOff();
  adsr.releaseTime() => now;

  0 => lisa.play;
  false => playing[i];
  1 -=> numPlaying;
}

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

fun void main() {
  int i;

  spork ~ record(i, TIME);

  adsrs[0].keyOn();
  TIME - adsrs[0].releaseTime() => now;
  adsrs[0].keyOff();
  adsrs[0].releaseTime() => now;

  adc =< adsrs[0];

  while (true) {
    1 +=> i;
    N %=> i;

    record(i, TIME);
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
spork ~ modulate();
spork ~ delay();

eon => now;