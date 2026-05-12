public class Granular extends Chugraph {
  LiSa lisa => outlet;
  true => lisa.loop;
  32 => lisa.maxVoices;

  @(0.2, 5) => vec2 rate;
  @(2, 20) => vec2 duration;
  2::ms => dur ramp;

  Event _keyOn;
  false => int _keyOff;

  spork ~ _play();

  fun void Granular(string filename) {
    SndBuf buf;
    filename => buf.read;

    buf.samples()::samp => lisa.duration;
    for (int i; i < buf.samples(); i++) {
      (i => buf.valueAt, i::samp) => lisa.valueAt;
    }
  }

  fun void grain() {
    lisa.getVoice() => int voice;

    if (voice < 0) return;

    (voice, ramp) => lisa.rampUp;
    (voice, ((0, lisa.duration() / samp) => Math.random2f)::samp) => lisa.playPos;
    (voice, (rate.x, rate.y) => Math.random2f) => lisa.rate;
    ((duration.x, duration.y) => Math.random2f)::ms => now;
    (voice, ramp) => lisa.rampDown;
    ramp => now;
  }

  fun void noteOn() {
    spork ~ _noteOn();
  }

  fun void noteOff() {
    true => _keyOff;
  }

  fun void _noteOn() {
    false => _keyOff;
    _keyOn.broadcast();
  }

  fun void _play() {
    while (true) {
      _keyOn => now;

      while (true) {
        if (_keyOff) {
          false => _keyOff;
          break;
        }

        spork ~ grain();

        ((0, (-duration.x, duration.x) => Math.random2f) => Math.max)::ms + 10 * ramp => now;
      }
    }
  }
}