// Kill any leftover scsynth before starting fresh
Server.killAll;

// Now the real script:
s.waitForBoot {

    // --------------------------------------
    // CONFIG
    // --------------------------------------
    var threshold = 0.5;

    var folder, fileIndex, fullPath, buffer;

    ~basePath       = "/home/student/Desktop/media/PLAYGROUND";  // no trailing slash
    ~lastEntropy    = 0.0;
    ~burstPlayer    = nil;   // current burst synth (for info if you need it)
    ~lastBurstBuf   = nil;   // last burst buffer (optional cleanup)

    // --------------------------------------
    // BASE: hot/cold looper (same as your working script)
    // --------------------------------------
    SynthDef(\looper, { |out = 0, bufnum = 0, amp = 0.8|
        var sig;
        sig = PlayBuf.ar(
            numChannels: 1,
            bufnum: bufnum,
            rate: 1,
            loop: 0,
            doneAction: 2
        );
        Out.ar(out, (sig * amp) ! 2);
    }).add;

    // --------------------------------------
    // BURST PLAYER: ONE-SHOT (NO LOOP), PLAYS FULL FILE
    // --------------------------------------
    SynthDef(\burstPlayer, { |out = 0, bufnum = 0, amp = 0.8|
        var sig;
        sig = PlayBuf.ar(
            numChannels: 1,
            bufnum: bufnum,
            rate: 1,
            loop: 0,        // one-shot
            doneAction: 2   // free synth when file ends
        );
        Out.ar(out, sig * amp ! 2);
    }).add;

    s.sync;

    // --------------------------------------
    // HOT/COLD LOOP (unchanged logic)
    // --------------------------------------
    ~playRandomLoop = Routine {
        inf.do {
            folder    = ["Hot", "Cold"].choose;
            fileIndex = (0..7).choose;
            fullPath  = ~basePath ++ "/" ++ folder ++ "/" ++ fileIndex.asString ++ ".wav";

            ("[BASE] Folder chosen: " ++ folder).postln;
            ("[BASE] File chosen: "   ++ fileIndex.asString ++ ".wav").postln;
            ("[BASE] Full path: "     ++ fullPath).postln;

            buffer = Buffer.read(s, fullPath);
            s.sync;

            Synth(\looper, [\bufnum, buffer.bufnum, \amp, 0.8]);

            buffer.duration.wait;
            buffer.free;
        };
    };

    ~playRandomLoop.play;

    "READY: hot/cold base + entropy-triggered one-shot Bursts (no preload)".postln;

    // --------------------------------------
    // OSC LISTENER for /entropy → trigger Bursts
    // --------------------------------------
    OSCdef(\entropyFromPython, { |msg|
        var entropy = msg[1].asFloat;
        var prev    = ~lastEntropy;

        ~lastEntropy = entropy;

        ("Entropy: " ++ entropy).postln;

        // ---------------------------
        // RISING EDGE: < 0.5 → ≥ 0.5
        // ---------------------------
        // One trigger per "high" episode
        if (prev < threshold and: { entropy >= threshold }) {
            var burstIndex, burstPath;

            // Pick random 0..7
            burstIndex = (0..7).choose;
            burstPath  = ~basePath ++ "/Bursts/" ++ burstIndex.asString ++ ".wav";

            ("[BURST] Triggering " ++ burstIndex.asString ++ ".wav").postln;
            ("[BURST] Path: "       ++ burstPath).postln;

            // Async load; when ready, play the full burst ONCE
            Buffer.read(s, burstPath, action: { |burstBuf|

                ("[BURST] Loaded " ++ burstPath).postln;

                // Optional: free previous buffer to avoid piling up
                if (~lastBurstBuf.notNil) {
                    ~lastBurstBuf.free;
                };
                ~lastBurstBuf = burstBuf;

                // Fire a one-shot burst; NO fade-out, plays full file
                ~burstPlayer = Synth(\burstPlayer, [
                    \bufnum,  burstBuf.bufnum,
                    \amp,     0.8
                ]);
            });
        };

        // -----------------------------
        // FALLING EDGE: ≥ 0.5 → < 0.5
        // -----------------------------
        // We *don’t* stop or fade the burst; just log & re-arm.
        if (prev >= threshold and: { entropy < threshold }) {
            "[BURST] Entropy < threshold → re-armed for next trigger".postln;
        };

    }, '/entropy');  // uses sclang's default port 57120
};
