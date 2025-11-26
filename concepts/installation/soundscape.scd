#!/usr/bin/env sclang

s.waitForBoot {

    // ---------------------------------
    // CONFIG
    // ---------------------------------
    var numSounds = 8;
    var threshold = 0.5;
    var fadeTime = 0.5; // seconds for fade in/out
    var distLow = 0.5;
    var distHigh = 0.75;

    // Path to media folder next to this .scd file
    ~mediaPath = PathName(thisProcess.nowExecutingPath).pathOnly ++ "media/";

    // Load 0.wav .. 7.wav
    ~buffers = Array.fill(numSounds, { |i|
        var filePath = ~mediaPath ++ (i.asString ++ ".wav");
        ("Loading " ++ filePath).postln;
        Buffer.read(s, filePath);
    });

    // Synth with: amp fade, distortion, delay
    SynthDef(\entropyLooper, { |out=0, buf=0, amp=0.0, lagTime=0.5, dist=0.0, delayMix=0.0|
        var sig, clean, drive, distSmooth, delaySmooth, delayed;

        clean = PlayBuf.ar(
            numChannels: 1,
            bufnum: buf,
            rate: 1,
            loop: 1,
            doneAction: 0
        );

        // Smooth amp
        clean = clean * Lag.kr(amp, lagTime);

        // Smooth distortion
        distSmooth = Lag.kr(dist, 0.3);
        drive = tanh(clean * (1 + distSmooth * 9)); // more gain with higher dist

        // Clean→dist crossfade
        sig = (1 - distSmooth) * clean + distSmooth * drive;

        // Smooth delay mix
        delaySmooth = Lag.kr(delayMix, 0.3);

        // Delay block (adjust delay time if you want)
        delayed = CombL.ar(sig, maxdelaytime: 0.5, delaytime: 0.33, decaytime: 2);

        // Delay mix
        sig = ((1 - delaySmooth) * sig) + (delaySmooth * delayed);

        Out.ar(out, sig ! 2);
    }).add;

    s.sync;

    // STATE
    ~currentIndex = 0;
    ~lastEntropy = 0.0;

    ~player = Synth(\entropyLooper, [
        \buf, ~buffers[0].bufnum,
        \amp, 0.0,
        \lagTime, fadeTime,
        \dist, 0.0,
        \delayMix, 0.0
    ]);

    "Ready. Listening for /entropy with fade, distortion, delay & sound switching."
    .postln;

    // ---------------------------------
    // OSC receiver for /entropy
    // ---------------------------------
    OSCdef(\entropyFromPython, { |msg|
        var entropy = msg[1].asFloat;
        var prev = ~lastEntropy;
        var dist, delayAmt;

        ~lastEntropy = entropy;

        ("Entropy: " ++ entropy).postln;

        // ----- DISTORTION mapping 0.5–0.75 → 0–1 -----
        dist = ((entropy - distLow) / (distHigh - distLow)).clip(0, 1);
        ~player.set(\dist, dist);

        // ----- DELAY mapping also 0.5–0.75 → 0–1 -----
        delayAmt = ((entropy - distLow) / (distHigh - distLow)).clip(0, 1);
        ~player.set(\delayMix, delayAmt);

        ("Distortion: " ++ dist ++ " | Delay Mix: " ++ delayAmt).postln;

        // Rising edge over 0.5 → switch sound + fade in
        if (prev < threshold and: { entropy >= threshold }) {
            ~currentIndex = (~currentIndex + 1) % numSounds;
            ("Switching to " ++ ~currentIndex ++ ".wav (fade in)").postln;
            ~player.set(\buf, ~buffers[~currentIndex].bufnum, \amp, 0.7);
        };

        // Falling edge below 0.5 → fade out
        if (prev >= threshold and: { entropy < threshold }) {
            "Entropy below threshold → fade out".postln;
            ~player.set(\amp, 0.0);
        };

    }, '/entropy', recvPort: 57120);
};
