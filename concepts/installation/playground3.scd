/////////////////////////////////////////////////////
//  HOT/COLD LOOP + ENTROPY TRIGGER + BROADCAST BURSTS
/////////////////////////////////////////////////////

// 1) Kill any leftover servers
Server.killAll;

// 2) Allow SC to send broadcast packets
NetAddr.broadcastFlag = true;

// 3) Make sure lang port (OSCdef) is open
thisProcess.openUDPPort(57120);
"Lang UDP port: ".post; NetAddr.langPort.postln;

// Clear old defs
OSCdef.freeAll;


/////////////////////////////////////////////////////
//  BOOT SERVER AND START SYSTEM
/////////////////////////////////////////////////////

s.waitForBoot {

    //////////////////////////////////////////
    // CONFIG
    //////////////////////////////////////////
    var threshold, folder, fileIndex, fullPath, buffer;
    threshold = 0.5;

    ~basePath       = "/home/student/Desktop/media/PLAYGROUND";
    ~lastEntropy    = 0.0;

    // Probability: 20% chance to actually play a burst
    ~burstPlayProb  = 0.2;

    // Broadcast to entire 10.10.10.x network
    ~burstTarget = NetAddr("10.10.10.255", 57120);


    //////////////////////////////////////////
    // SYNTHDEFS
    //////////////////////////////////////////

    // Hot/cold loop player
    SynthDef(\looper, { |out = 0, bufnum = 0, amp = 0.8|
        var sig = PlayBuf.ar(1, bufnum, 1.0, loop: 0, doneAction: 2);
        Out.ar(out, (sig * amp)!2);
    }).add;

    // BURST PLAYER WITH STRONG RING MOD
    SynthDef(\burstPlayer, { |out = 0, bufnum = 0, amp = 0.8,
        modFreq = 100, modDepth = 0.0|
        var dry, mod, ring, sig;

        // Base playback (no pitch change)
        dry = PlayBuf.ar(1, bufnum, 1.0, loop: 0, doneAction: 2);

        // Ring modulator
        mod  = SinOsc.ar(modFreq);
        ring = dry * mod;

        // modDepth: 0 → dry, 1 → fully ring-modulated
        // map 0..1 → -1..+1 for XFade2
        sig = XFade2.ar(dry, ring, (modDepth * 2) - 1);

        Out.ar(out, (sig * amp)!2);
    }).add;

    s.sync;


    //////////////////////////////////////////
    // HOT / COLD RANDOM FILE LOOP
    //////////////////////////////////////////

    ~playRandomLoop = Routine {
        inf.do {
            folder    = ["Hot", "Cold"].choose;
            fileIndex = (0..7).choose;
            fullPath  = ~basePath ++ "/" ++ folder ++ "/" ++ fileIndex.asString ++ ".wav";

            ("[BASE] Folder: " ++ folder).postln;
            ("[BASE] File: "   ++ fileIndex).postln;
            ("[BASE] Path: "   ++ fullPath).postln;

            buffer = Buffer.read(s, fullPath);
            s.sync;

            Synth(\looper, [\bufnum, buffer.bufnum, \amp, 0.8]);

            buffer.duration.wait;
            buffer.free;
        };
    };

    ~playRandomLoop.play;

    "READY: Base + Entropy Trigger + Burst Broadcast".postln;


    //////////////////////////////////////////
    // 1) RECEIVE /entropy
    //////////////////////////////////////////

    OSCdef(\entropyFromPython, { |msg|
        var entropy = msg[1].asFloat;
        var prev    = ~lastEntropy;

        ~lastEntropy = entropy;

        ("[ENTROPY] " ++ entropy).postln;

        // Rising edge: trigger burst broadcast
        if (prev < threshold and: { entropy >= threshold }) {
            var burstIndex = (0..16).choose;
            var burstPath  = ~basePath ++ "/Bursts/" ++ burstIndex.asString ++ ".wav";

            ("[BURST SEND] " ++ burstIndex).postln;
            ("[BURST SEND] Path: " ++ burstPath).postln;

            ~burstTarget.sendMsg("/burstPath", burstPath);
        };

        if (prev >= threshold and: { entropy < threshold }) {
            "[BURST SEND] Re-armed".postln;
        };

    }, "/entropy");


    //////////////////////////////////////////
    // 2) RECEIVE /burstPath
    //    → 20% chance to play
    //    → USE LOCAL ENTROPY FOR STRONG RING MOD
    //    → WAIT 0.1–1.0s BEFORE PLAYING
    //////////////////////////////////////////

    OSCdef(\playBurstFromPath, { |msg|
        var burstPath = msg[1].asString;

        ("[BURST RECV] Path: " ++ burstPath).postln;

        Buffer.read(s, burstPath, action: { |buf|
            var localEntropy = ~lastEntropy ? 0.0;
            var modFreq, modDepth, roll;

            // Stronger, more metallic mapping:
            // entropy 0 → 200 Hz, entropy 1 → 6000 Hz
            modFreq  = localEntropy.linexp(0, 1, 200, 6000).clip(200, 6000);

            // Stronger depth:
            // entropy 0 → 0.4, entropy 1 → 1.0 (never completely dry)
            modDepth = localEntropy.linlin(0, 1, 0.4, 1.0).clip(0.4, 1.0);

            // PROBABILITY (20%)
            roll = 1.0.rand;

            ("[BURST MOD] Entropy: " ++ localEntropy
                ++ " → freq: " ++ modFreq
                ++ ", depth: " ++ modDepth).postln;

            ("[BURST PROB] roll: " ++ roll
                ++ ", threshold: " ++ ~burstPlayProb).postln;

            if (roll < ~burstPlayProb) {

                // 🔥 WAIT 0.1–1.0s BEFORE PLAYING
                {
                    (0.1 + 0.9.rand).wait;

                    Synth(\burstPlayer, [
                        \bufnum,   buf.bufnum,
                        \amp,      0.8,
                        \modFreq,  modFreq,
                        \modDepth, modDepth
                    ]);
                }.fork;

            } {
                "[BURST SKIP] (Probability gate)".postln;
            };

        });

    }, "/burstPath");
};
