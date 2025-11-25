// play_wav.scd
// Usage: sclang play_wav.scd /path/to/file.wav

var path = thisProcess.argv[0];  // assuming you call: sclang play_wav.scd /path/to/file.wav

path.postln;

s.waitForBoot {
    var buf;

    buf = Buffer.read(s, path);
    s.sync;

    {
        var sig = PlayBuf.ar(
            numChannels: buf.numChannels,
            bufnum: buf.bufnum,
            rate: 1,
            loop: 1,       // loop forever
            doneAction: 0   // don't auto-free
        );
        Out.ar(0, sig);
    }.play;

    "Started looping...".postln;
    // DO NOT wait buf.duration, DO NOT free, DO NOT exit.
};
