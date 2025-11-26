// play_wav.scd
// Usage: sclang play_wav.scd /path/to/file.wav

var path    = thisProcess.argv[0];  // assuming you call: sclang play_wav.scd /path/to/file.wav
var outname = '/home/student/Desktop/Recordings/'  ++ Date.localtime.stamp;

s.waitForBoot {

	var buf;

    buf = Buffer.read(s, path);
    s.sync;


	////////////////////////////////////////////
	// The Playback Synth
    ////////////////////////////////////////////

	{
        var sig = PlayBuf.ar(
            numChannels: buf.numChannels,
            bufnum: buf.bufnum,
            rate: 1,
            loop: 0,       // loop forever
            doneAction: 1
        );
        Out.ar(0, sig);
    }.play;


	////////////////////////////////////////////
	// The PassThrough Synth
    ////////////////////////////////////////////

	{
		Out.ar(0,Mix.ar(SoundIn.ar([0,1])));
	}.play;

    "Started playing...".postln;

	s.record(path: outname, numChannels:1, bus: s.options.numOutputBusChannels);

	/* commented the wait + auto exit
    buf.duration.wait;
    "Done.".postln;
    buf.free;
    0.exit;
	*/

};
