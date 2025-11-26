(
// Boot the server
s.boot;

// --------------------------------------
// CONFIG
// --------------------------------------
~basePath = '/home/student/Desktop/MESH/media/';
// Your folders must be: /hot/ and /cold/
// And inside each: 0.wav ... 7.wav

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
        fullPath = (~basePath ++ hotCold ++ "/" ++ fileIndex.asString ++ ".wav");

        ("Selected folder: " ++ hotCold).postln;
        ("Selected file: " ++ fileIndex.asString ++ ".wav").postln;
        ("Full path: " ++ fullPath).postln;

        // Load buffer
        buffer = Buffer.read(s, fullPath);
        s.sync;

        // Play once using your SynthDef 'looper'
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
)
