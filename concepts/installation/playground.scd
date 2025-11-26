// random_hot_cold_player.scd

s.waitForBoot({

    // --------------------------------------
    // CONFIG
    // --------------------------------------
    ~basePath = "/home/student/Desktop/media/PLAYGROUND";  // no trailing slash

    // Simple looper SynthDef
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
    // MAIN LOOP
    // --------------------------------------
    ~playRandomLoop = Routine {
        var folder, fileIndex, fullPath, buffer;

        inf.do {

            // Pick "hot" or "cold" randomly
            folder = ["hot", "cold"].choose;

            // Pick random number 0..7
            fileIndex = (0..7).choose;

            // Build full path
            fullPath = ~basePath ++ "/" ++ folder ++ "/" ++ fileIndex.asString ++ ".wav";

            ("Folder chosen: " ++ folder).postln;
            ("File chosen: " ++ fileIndex.asString ++ ".wav").postln;
            ("Full path: " ++ fullPath).postln;

            // Load
            buffer = Buffer.read(s, fullPath);
            s.sync;

            // Play
            Synth(\looper, [
                \bufnum, buffer.bufnum,
                \amp, 0.8
            ]);

            // Wait
            buffer.duration.wait;

            // Free
            buffer.free;
        };
    };

    // Start routine
    ~playRandomLoop.play;
});
