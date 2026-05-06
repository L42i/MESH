(
// ================================================================
// STATIC LIVE INPUT GRANULAR SYNTHESIS — MONO OUTPUT
// Input:  hardware input 0
// Output: hardware output 0 only
//
// Run with:
// sclang input_granular_static_mono.scd
// ================================================================


// ----------------------------
// STATIC PARAMETERS
// Edit these before running.
// ----------------------------

~inputChannel = 0;
~outputChannel = 0;

~grainRate = 80;
~grainDur = 0.12;
~amp = 0.25;
~wet = 1.0;          // 0 = dry input, 1 = fully granular


// ----------------------------
// SERVER SETTINGS
// ----------------------------

s.options.numInputBusChannels = 2;
s.options.numOutputBusChannels = 2;
s.options.memSize = 8192 * 16;

s.boot;

s.waitForBoot({

	SynthDef(\staticInputGranularMono, {
		var input;
		var trig;
		var grains;
		var dry;
		var sig;

		// Read mono hardware input.
		input = SoundIn.ar(~inputChannel);

		// Static grain trigger density.
		trig = Dust.kr(~grainRate);

		// Mono granular processing.
		grains = GrainIn.ar(
			numChannels: 1,
			trigger: trig,
			dur: ~grainDur,
			in: input,
			pan: 0,
			envbufnum: -1,
			maxGrains: 512
		);

		dry = input;

		// Static dry/wet blend.
		sig = XFade2.ar(
			dry,
			grains,
			~wet.linlin(0, 1, -1, 1)
		);

		// Basic safety filtering and limiting.
		sig = LeakDC.ar(sig);
		sig = HPF.ar(sig, 30);
		sig = Limiter.ar(sig * ~amp, 0.9);

		// Mono output to hardware output 0.
		Out.ar(~outputChannel, sig);

	}).add;

	s.sync;

	~gran = Synth(\staticInputGranularMono);

	CmdPeriod.doOnce({
		if(~gran.notNil) {
			~gran.free;
		};
		"Static granular input synth stopped.".postln;
	});

	"----------------------------------------------------".postln;
	"Static live input granular synthesis running.".postln;
	("Input channel: " ++ ~inputChannel).postln;
	("Output channel: " ++ ~outputChannel).postln;
	("Amp: " ++ ~amp).postln;
	("Grain rate: " ++ ~grainRate).postln;
	("Grain duration: " ++ ~grainDur).postln;
	("Wet mix: " ++ ~wet).postln;
	"Press CmdPeriod / Ctrl+. to stop.".postln;
	"----------------------------------------------------".postln;

});
)