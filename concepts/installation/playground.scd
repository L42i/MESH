// random_hot_cold_player.scd

s.waitForBoot({

    // --------------------------------------
    // CONFIG
    // --------------------------------------
    // Base path that contains "hot" and "cold" folders
    ~basePath = "/home/student/Desktop/MESH/media/PLAYGROUND";  // <-- adjust if needed

    // Simple looper SynthDef (mono file → stereo out)
    SynthDef(\looper, { |out = 0, bufnum = 0, amp = 0.8|
        var sig;
        sig = PlayBuf.ar(
            numChannels: 1,      // change to 2 if your files are stereo
            bufnum: bufnum,
            rate: 1,
            loop: 0,
            doneAction: 2
        );
        sig = sig * amp;
        Out.ar(out, sig ! 2);    // duplicate to stereo
    }).add;

    // --------------------------------------
    // MAIN LOOP
    // --------------------------------------
    ~playRandomLoop = Routine {
        var hotCold, fileIndex, fullPath, buffer;

        inf.do {
            // Pick either "hot" or "cold"
            hotCold = ["hot", "cold"].choose;

            // Pick random number 0..7
            fileIndex = (0..7).choose;

            // Build full path:  "/base/hot/3.wav"
            fullPath = ~basePath ++ hotCold ++ "/" ++ fileIndex.asString ++ ".wav";

            ("Selected folder: " ++ hotCold).postln;
            ("Selected file: " ++ fileIndex.asString ++ ".wav").postln;
            ("Full path: " ++ fullPath).postln;

            // Load buffer
            buffer = Buffer.read(s, fullPath);
            s.sync;

            // Play once using SynthDef 'looper'
            Synth(\looper, [
                \bufnum, buffer.bufnum,
                \amp, 0.8
            ]);

            // Wait for file duration
            buffer.duration.wait;

            // Free buffer
            buffer.free;
        };
    };

    // Start the routine
    ~playRandomLoop.play;
});
