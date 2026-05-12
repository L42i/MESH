// play_wav.scd
// Usage: sclang play_wav.scd /path/to/file.wav

s.waitForBoot {

    s.sync;


	////////////////////////////////////////////
	// The PassThrough Synth
    ////////////////////////////////////////////

	{
		Out.ar(0,Mix.ar(SoundIn.ar([0,1])));
	}.play;

    "Started playing...".postln;

	/* commented the wait + auto exit
    buf.duration.wait;
    "Done.".postln;
    buf.free;
    0.exit;
	*/

};
