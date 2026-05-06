(
// ================================================================
// MESH RECEIVER MODE WITH PARAMETER DISPLAY GUI
// Run this same script on every receiver Pi:
//
// 10.10.10.12 through 10.10.10.18
//
// Receives:
// /mesh/params amp pitch texture
// /mesh/start
// /mesh/stop
// ================================================================


// ----------------------------
// NETWORK CONFIG
// ----------------------------

~oscPort = 57120;
thisProcess.openUDPPort(~oscPort);


// ----------------------------
// LOCAL STATE
// ----------------------------

~currentAmp = 0.0;
~currentPitch = 0.5;
~currentTexture = 0.5;
~isRunning = false;
~lastSenderIP = "none";
~lastUpdateTime = "none";


// ----------------------------
// SERVER CONFIG
// ----------------------------

s.options.numOutputBusChannels = 2;
s.options.numInputBusChannels = 2;

s.boot;

s.waitForBoot({

	Routine({

		// ----------------------------
		// LOCAL SYNTHESIS ENGINE
		// ----------------------------

		SynthDef(\meshSimpleLocalEngine, {
			|out = 0,
			amp = 0.0,
			pitch = 0.5,
			texture = 0.5|

			var ampMapped;
			var freq;
			var cutoff;
			var density;
			var trig;
			var env;
			var tone;
			var noise;
			var sig;
			var textureSmoothed;

			ampMapped = Lag.kr(
				amp.clip(0, 1).linlin(0, 1, 0.0, 0.4),
				0.1
			);

			freq = Lag.kr(
				pitch.clip(0, 1).linexp(0, 1, 80, 1000),
				0.2
			);

			textureSmoothed = Lag.kr(
				texture.clip(0, 1),
				0.2
			);

			cutoff = textureSmoothed.linexp(0, 1, 300, 8000);
			density = textureSmoothed.linexp(0, 1, 0.3, 20);

			trig = Dust.kr(density);

			env = Decay2.kr(
				trig,
				0.005,
				textureSmoothed.linlin(0, 1, 0.7, 0.06)
			);

			tone = Mix.ar(
				VarSaw.ar(
					freq * [1, 1.005, 1.5],
					0,
					[0.4, 0.3, 0.2]
				)
			) * 0.25;

			noise = BPF.ar(
				PinkNoise.ar(0.45),
				cutoff,
				0.25
			);

			sig = XFade2.ar(
				tone,
				noise,
				textureSmoothed.linlin(0, 1, -0.8, 0.8)
			);

			sig = RLPF.ar(
				sig,
				cutoff,
				0.25
			);

			sig = sig * (0.35 + env);

			sig = FreeVerb.ar(
				sig,
				mix: textureSmoothed.linlin(0, 1, 0.05, 0.45),
				room: 0.8,
				damp: 0.4
			);

			sig = LeakDC.ar(sig);
			sig = Limiter.ar(sig * ampMapped, 0.9);

			Out.ar(out, sig ! 2);
		}).add;

		s.sync;

		~synth = Synth(\meshSimpleLocalEngine);

		~synth.set(
			\amp, ~currentAmp,
			\pitch, ~currentPitch,
			\texture, ~currentTexture
		);

		~synth.run(false);


		// ----------------------------
		// GUI UPDATE FUNCTION
		// ----------------------------

		~updateGUI = {
			var mappedPitch;

			mappedPitch = ~currentPitch.clip(0, 1).linexp(0, 1, 80, 1000);

			{
				if(~ampSlider.notNil) {
					~ampSlider.value_(~currentAmp);
					~pitchSlider.value_(~currentPitch);
					~textureSlider.value_(~currentTexture);

					~ampValue.string_(~currentAmp.round(0.001).asString);
					~pitchValue.string_(~currentPitch.round(0.001).asString);
					~textureValue.string_(~currentTexture.round(0.001).asString);

					~mappedPitchValue.string_(mappedPitch.round(0.1).asString ++ " Hz");

					~senderValue.string_(~lastSenderIP);
					~lastUpdateValue.string_(~lastUpdateTime);

					if(~isRunning) {
						~statusValue.string_("RUNNING");
						~statusValue.background_(Color.green);
					} {
						~statusValue.string_("STOPPED");
						~statusValue.background_(Color.red);
					};
				};
			}.defer;
		};


		// ----------------------------
		// GUI
		// ----------------------------

		{
			var win;
			var y0;

			win = Window("MESH Receiver Monitor", Rect(100, 100, 520, 360));
			win.front;
			win.alwaysOnTop_(true);

			win.onClose = {
				"Receiver GUI closed. Audio and OSC are still running.".postln;
			};

			StaticText(win, Rect(20, 15, 480, 25))
				.string_("MESH Receiver Monitor")
				.font_(Font("Arial", 18, true))
				.align_(\center);

			StaticText(win, Rect(20, 45, 480, 20))
				.string_("Listening for /mesh/params amp pitch texture on UDP port " ++ ~oscPort)
				.font_(Font("Arial", 11))
				.align_(\center);

			y0 = 90;

			StaticText(win, Rect(25, y0, 90, 22))
				.string_("Amp")
				.font_(Font("Arial", 13, true));

			~ampSlider = Slider(win, Rect(120, y0, 260, 22));
			~ampSlider.value_(~currentAmp);
			~ampSlider.enabled_(false);

			~ampValue = StaticText(win, Rect(395, y0, 80, 22));
			~ampValue.string_(~currentAmp.round(0.001).asString);
			~ampValue.align_(\center);

			y0 = y0 + 45;

			StaticText(win, Rect(25, y0, 90, 22))
				.string_("Pitch")
				.font_(Font("Arial", 13, true));

			~pitchSlider = Slider(win, Rect(120, y0, 260, 22));
			~pitchSlider.value_(~currentPitch);
			~pitchSlider.enabled_(false);

			~pitchValue = StaticText(win, Rect(395, y0, 80, 22));
			~pitchValue.string_(~currentPitch.round(0.001).asString);
			~pitchValue.align_(\center);

			y0 = y0 + 45;

			StaticText(win, Rect(25, y0, 90, 22))
				.string_("Texture")
				.font_(Font("Arial", 13, true));

			~textureSlider = Slider(win, Rect(120, y0, 260, 22));
			~textureSlider.value_(~currentTexture);
			~textureSlider.enabled_(false);

			~textureValue = StaticText(win, Rect(395, y0, 80, 22));
			~textureValue.string_(~currentTexture.round(0.001).asString);
			~textureValue.align_(\center);

			y0 = y0 + 50;

			StaticText(win, Rect(25, y0, 150, 22))
				.string_("Mapped pitch:")
				.font_(Font("Arial", 12, true));

			~mappedPitchValue = StaticText(win, Rect(180, y0, 150, 22));
			~mappedPitchValue.string_("none");

			y0 = y0 + 30;

			StaticText(win, Rect(25, y0, 150, 22))
				.string_("Last sender:")
				.font_(Font("Arial", 12, true));

			~senderValue = StaticText(win, Rect(180, y0, 250, 22));
			~senderValue.string_(~lastSenderIP);

			y0 = y0 + 30;

			StaticText(win, Rect(25, y0, 150, 22))
				.string_("Program Running:")
				.font_(Font("Arial", 12, true));

			~lastUpdateValue = StaticText(win, Rect(180, y0, 250, 22));
			~lastUpdateValue.string_(~lastUpdateTime);

			y0 = y0 + 35;

			StaticText(win, Rect(25, y0, 150, 30))
				.string_("Status:")
				.font_(Font("Arial", 14, true));

			~statusValue = StaticText(win, Rect(180, y0, 150, 30));
			~statusValue.string_("STOPPED");
			~statusValue.align_(\center);
			~statusValue.background_(Color.red);
			~statusValue.font_(Font("Arial", 14, true));

			~updateGUI.value;

		}.defer;


		// ----------------------------
		// OSC RECEIVERS
		// ----------------------------

		OSCdef(\meshParams, {
			|msg, time, addr, recvPort|

			if(msg.size >= 4) {
				~currentAmp = msg[1].asFloat.clip(0, 1);
				~currentPitch = msg[2].asFloat.clip(0, 1);
				~currentTexture = msg[3].asFloat.clip(0, 1);

				~lastSenderIP = addr.ip;
				~lastUpdateTime = Main.elapsedTime.round(0.01).asString ++ " sec";

				if(~synth.notNil) {
					~synth.set(
						\amp, ~currentAmp,
						\pitch, ~currentPitch,
						\texture, ~currentTexture
					);
				};

				~updateGUI.value;

				(
					"Received from " ++ addr.ip ++
					" | amp: " ++ ~currentAmp.round(0.001) ++
					" pitch: " ++ ~currentPitch.round(0.001) ++
					" texture: " ++ ~currentTexture.round(0.001)
				).postln;
			} {
				"Warning: /mesh/params expected amp pitch texture.".postln;
				msg.postln;
			};

		}, "/mesh/params", recvPort: ~oscPort);


		OSCdef(\meshStart, {
			|msg, time, addr, recvPort|

			~isRunning = true;
			~lastSenderIP = addr.ip;
			~lastUpdateTime = Main.elapsedTime.round(0.01).asString ++ " sec";

			if(~synth.notNil) {
				~synth.run(true);
			};

			~updateGUI.value;
			"Received /mesh/start".postln;

		}, "/mesh/start", recvPort: ~oscPort);


		OSCdef(\meshStop, {
			|msg, time, addr, recvPort|

			~isRunning = false;
			~lastSenderIP = addr.ip;
			~lastUpdateTime = Main.elapsedTime.round(0.01).asString ++ " sec";

			if(~synth.notNil) {
				~synth.run(false);
			};

			~updateGUI.value;
			"Received /mesh/stop".postln;

		}, "/mesh/stop", recvPort: ~oscPort);


		// ----------------------------
		// CLEANUP
		// ----------------------------

		CmdPeriod.doOnce({
			OSCdef(\meshParams).free;
			OSCdef(\meshStart).free;
			OSCdef(\meshStop).free;

			if(~synth.notNil) {
				~synth.free;
			};
		});


		// ----------------------------
		// STARTUP PRINTS
		// ----------------------------

		"Receiver ready with GUI.".postln;
		("Listening on UDP port " ++ ~oscPort).postln;
		"Waiting for conductor messages...".postln;

	}).play(AppClock);

});
)