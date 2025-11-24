// play_wav.scd
// Usage: sclang play_wav.scd /path/to/file.wav


var path = thisProcess.argv[0];

path.postln;


s.waitForBoot(
	{

    var buf, player;


    buf = Buffer.read(s, path);

	s.sync;

    player = {
        var play = PlayBuf.ar(
            numChannels: buf.numChannels,
            bufnum: buf.bufnum,
            rate: 1,
            loop: 0,
            doneAction: 2      // free synth when done
        );
        Out.ar(0, play);
    }.play;

    // stop the whole process once the buffer is done
    buf.duration.wait;
    "Done.".postln;
    buf.free;
    0.exit;
});