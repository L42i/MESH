(
// ================================================================
// COMPLETE MESH PEER-TO-PEER OSC EXAMPLE — 8 PIS
//
// Run this same script on every Pi:
//
// 10.10.10.11
// 10.10.10.12
// 10.10.10.13
// 10.10.10.14
// 10.10.10.15
// 10.10.10.16
// 10.10.10.17
// 10.10.10.18
//
// Each Pi:
// - detects its own IP address
// - sends its local state to every other Pi
// - receives state from every other Pi
// - displays all node states in a GUI
// - runs a local synth influenced by the other nodes
//
// OSC message format:
//
// /mesh/node/state nodeID activity pitch texture seq time
//
// ================================================================


// ------------------------------------------------
// NETWORK CONFIG
// ------------------------------------------------

~oscPort = 57120;

// All 8 Pis in the complete mesh.
~allIPs = (11..18).collect { |n|
	"10.10.10.%".format(n);
};

// Leave as nil for automatic IP detection.
// If automatic detection fails, manually set this on each Pi.
// Example:
// ~myIPOverride = "10.10.10.11";
~myIPOverride = nil;

// How often each Pi broadcasts its state.
~sendHz = 10;

// If a peer has not sent for this many seconds, it is inactive.
~peerTimeout = 2.0;


// ------------------------------------------------
// DETECT THIS PI'S IP ADDRESS
// ------------------------------------------------

~myIP = "10.10.10.18";

if(~myIP.isNil) {
	Error("Could not detect this Pi's IP address. Set ~myIPOverride manually.").throw;
};

~myNodeID = ~myIP.split($.).last.asInteger;


// ------------------------------------------------
// BUILD PEER LIST
// ------------------------------------------------

~peers = ~allIPs.reject { |ip|
	ip == ~myIP;
}.collect { |ip|
	var nodeID;

	nodeID = ip.split($.).last.asInteger;

	(
		ip: ip,
		nodeID: nodeID,
		addr: NetAddr(ip, ~oscPort)
	);
};


// ------------------------------------------------
// OPEN OSC PORT
// ------------------------------------------------

thisProcess.openUDPPort(~oscPort);


// ------------------------------------------------
// LOCAL STATE
// ------------------------------------------------

~localActivity = 0.25;

// Give each Pi a slightly different starting pitch.
~localPitch = (~myNodeID - 11).linlin(0, 7, 0.15, 0.85);

~localTexture = 0.5;

~seq = 0;


// ------------------------------------------------
// REMOTE PEER STATE
// ------------------------------------------------

~peerStates = Dictionary.new;

~peerMeanActivity = 0.0;
~peerMaxActivity = 0.0;
~activePeerCount = 0;


// ------------------------------------------------
// COMPUTE AGGREGATE PEER STATE
// ------------------------------------------------

~computePeerAggregate = {
	var now;
	var activeStates;
	var vals;

	now = Main.elapsedTime;

	activeStates = ~peerStates.values.select { |st|
		(now - st[\lastTime]) < ~peerTimeout;
	};

	vals = activeStates.collect { |st|
		st[\activity];
	};

	~activePeerCount = vals.size;

	if(vals.size > 0) {
		~peerMeanActivity = vals.sum / vals.size;
		~peerMaxActivity = vals.maxItem;
	} {
		~peerMeanActivity = 0.0;
		~peerMaxActivity = 0.0;
	};
};


// ------------------------------------------------
// SERVER SETTINGS
// ------------------------------------------------

s.options.numInputBusChannels = 2;
s.options.numOutputBusChannels = 2;
s.options.memSize = 8192 * 16;

s.boot;

s.waitForBoot({

	Routine({

		// ------------------------------------------------
		// LOCAL SYNTH
		// ------------------------------------------------

		SynthDef(\meshPeerSynth, {
			|out = 0,
			localActivity = 0.25,
			localPitch = 0.5,
			localTexture = 0.5,
			peerMean = 0.0,
			peerMax = 0.0,
			peerCount = 0|

			var amp;
			var freq;
			var cutoff;
			var density;
			var trig;
			var env;
			var tone;
			var noise;
			var sig;

			amp = Lag.kr(
				localActivity.clip(0, 1).linlin(0, 1, 0.0, 0.35),
				0.2
			);

			// Local pitch sets the base frequency.
			// Peer activity pushes the pitch slightly upward.
			freq = Lag.kr(
				localPitch.clip(0, 1).linexp(0, 1, 80, 900)
				*
				(1 + (peerMax.clip(0, 1) * 0.35)),
				0.2
			);

			// Local texture controls brightness.
			// Peer mean activity opens the filter.
			cutoff = Lag.kr(
				(
					localTexture.clip(0, 1).linexp(0, 1, 300, 6000)
					*
					(1 + (peerMean.clip(0, 1) * 1.5))
				).clip(150, 12000),
				0.2
			);

			// More active peers make this node more rhythmically active.
			density = Lag.kr(
				localTexture.clip(0, 1).linexp(0, 1, 0.5, 12)
				+
				(peerCount.clip(0, 7) * 0.75)
				+
				(peerMean.clip(0, 1) * 12),
				0.2
			);

			trig = Dust.kr(density);

			env = Decay2.kr(
				trig,
				0.005,
				localTexture.clip(0, 1).linlin(0, 1, 0.5, 0.05)
			);

			tone = Mix.ar(
				SinOsc.ar(
					freq * [1, 1.5, 2.01],
					0,
					[0.25, 0.12, 0.08]
				)
			);

			noise = BPF.ar(
				PinkNoise.ar(0.4),
				cutoff,
				0.25
			);

			sig = XFade2.ar(
				tone,
				noise,
				localTexture.clip(0, 1).linlin(0, 1, -0.8, 0.8)
			);

			sig = RLPF.ar(sig, cutoff, 0.25);

			// Pulse articulation.
			sig = sig * (0.3 + env);

			// Peer activity increases reverb.
			sig = FreeVerb.ar(
				sig,
				peerMean.clip(0, 1).linlin(0, 1, 0.05, 0.45),
				0.8,
				0.4
			);

			sig = LeakDC.ar(sig);
			sig = HPF.ar(sig, 30);
			sig = Limiter.ar(sig * amp, 0.9);

			// Mono output to hardware output 0.
			Out.ar(out, sig);

		}).add;

		s.sync;

		~synth = Synth(\meshPeerSynth, [
			\out, 0,
			\localActivity, ~localActivity,
			\localPitch, ~localPitch,
			\localTexture, ~localTexture,
			\peerMean, ~peerMeanActivity,
			\peerMax, ~peerMaxActivity,
			\peerCount, ~activePeerCount
		]);


		// ------------------------------------------------
		// UPDATE SYNTH
		// ------------------------------------------------

		~updateSynth = {
			if(~synth.notNil) {
				~synth.set(
					\localActivity, ~localActivity,
					\localPitch, ~localPitch,
					\localTexture, ~localTexture,
					\peerMean, ~peerMeanActivity,
					\peerMax, ~peerMaxActivity,
					\peerCount, ~activePeerCount
				);
			};
		};


		// ------------------------------------------------
		// SEND STATE TO ALL PEERS
		// ------------------------------------------------

		~sendState = {
			~seq = ~seq + 1;

			~peers.do { |peer|
				peer[\addr].sendMsg(
					"/mesh/node/state",
					~myNodeID,
					~localActivity,
					~localPitch,
					~localTexture,
					~seq,
					Main.elapsedTime
				);
			};
		};


		// ------------------------------------------------
		// GUI UPDATE FUNCTION
		// ------------------------------------------------

		~updateGUI = {
			{
				var now;

				now = Main.elapsedTime;

				if(~localActivitySlider.notNil) {
					~localActivityValue.string_(~localActivity.round(0.001).asString);
					~localPitchValue.string_(~localPitch.round(0.001).asString);
					~localTextureValue.string_(~localTexture.round(0.001).asString);

					~aggregateValue.string_(
						"peer mean: " ++ ~peerMeanActivity.round(0.001)
						++ "    peer max: " ++ ~peerMaxActivity.round(0.001)
						++ "    active peers: " ++ ~activePeerCount
					);

					~peers.do { |peer, i|
						var st;
						var age;

						st = ~peerStates[peer[\nodeID]];

						if(st.notNil) {
							age = now - st[\lastTime];

							~peerActivitySliders[i].value_(st[\activity]);
							~peerPitchSliders[i].value_(st[\pitch]);
							~peerTextureSliders[i].value_(st[\texture]);

							~peerTextValues[i].string_(
								"activity "
								++ st[\activity].round(0.001)
								++ " | pitch "
								++ st[\pitch].round(0.001)
								++ " | texture "
								++ st[\texture].round(0.001)
								++ " | age "
								++ age.round(0.01)
								++ " sec"
							);
						} {
							~peerActivitySliders[i].value_(0);
							~peerPitchSliders[i].value_(0);
							~peerTextureSliders[i].value_(0);
							~peerTextValues[i].string_("no message yet");
						};
					};
				};
			}.defer;
		};


		// ------------------------------------------------
		// GUI
		// ------------------------------------------------

		{
			var win;
			var y;

			win = Window(
				"MESH Peer Node " ++ ~myNodeID,
				Rect(100, 100, 760, 590)
			);

			win.front;
			win.alwaysOnTop_(true);

			StaticText(win, Rect(20, 12, 720, 24))
				.string_("Complete MESH Peer Node")
				.font_(Font("Arial", 18, true))
				.align_(\center);

			StaticText(win, Rect(20, 40, 720, 20))
				.string_(
					"This node: " ++ ~myIP
					++ "    Node ID: " ++ ~myNodeID
					++ "    OSC port: " ++ ~oscPort
				)
				.align_(\center);

			y = 80;

			StaticText(win, Rect(20, y, 720, 22))
				.string_("LOCAL PARAMETERS SENT TO ALL OTHER PIS")
				.font_(Font("Arial", 13, true));

			y = y + 35;

			StaticText(win, Rect(25, y, 90, 22))
				.string_("Activity");

			~localActivitySlider = Slider(win, Rect(120, y, 330, 22));
			~localActivitySlider.value_(~localActivity);

			~localActivityValue = StaticText(win, Rect(465, y, 80, 22));
			~localActivityValue.string_(~localActivity.round(0.001).asString);

			~localActivitySlider.action_({ |sl|
				~localActivity = sl.value;
				~sendState.value;
				~updateSynth.value;
				~updateGUI.value;
			});

			y = y + 35;

			StaticText(win, Rect(25, y, 90, 22))
				.string_("Pitch");

			~localPitchSlider = Slider(win, Rect(120, y, 330, 22));
			~localPitchSlider.value_(~localPitch);

			~localPitchValue = StaticText(win, Rect(465, y, 80, 22));
			~localPitchValue.string_(~localPitch.round(0.001).asString);

			~localPitchSlider.action_({ |sl|
				~localPitch = sl.value;
				~sendState.value;
				~updateSynth.value;
				~updateGUI.value;
			});

			y = y + 35;

			StaticText(win, Rect(25, y, 90, 22))
				.string_("Texture");

			~localTextureSlider = Slider(win, Rect(120, y, 330, 22));
			~localTextureSlider.value_(~localTexture);

			~localTextureValue = StaticText(win, Rect(465, y, 80, 22));
			~localTextureValue.string_(~localTexture.round(0.001).asString);

			~localTextureSlider.action_({ |sl|
				~localTexture = sl.value;
				~sendState.value;
				~updateSynth.value;
				~updateGUI.value;
			});

			y = y + 45;

			~aggregateValue = StaticText(win, Rect(20, y, 720, 22));
			~aggregateValue.string_("peer mean: 0.0    peer max: 0.0    active peers: 0");
			~aggregateValue.font_(Font("Arial", 12, true));

			y = y + 40;

			StaticText(win, Rect(20, y, 720, 22))
				.string_("REMOTE PEER PARAMETERS RECEIVED FROM OTHER PIS")
				.font_(Font("Arial", 13, true));

			y = y + 30;

			StaticText(win, Rect(155, y, 90, 18))
				.string_("Activity")
				.align_(\center);

			StaticText(win, Rect(250, y, 90, 18))
				.string_("Pitch")
				.align_(\center);

			StaticText(win, Rect(345, y, 90, 18))
				.string_("Texture")
				.align_(\center);

			y = y + 22;

			~peerActivitySliders = Array.newClear(~peers.size);
			~peerPitchSliders = Array.newClear(~peers.size);
			~peerTextureSliders = Array.newClear(~peers.size);
			~peerTextValues = Array.newClear(~peers.size);

			~peers.do { |peer, i|
				var rowY;

				rowY = y + (i * 38);

				StaticText(win, Rect(25, rowY, 120, 22))
					.string_("Node " ++ peer[\nodeID] ++ "  " ++ peer[\ip]);

				~peerActivitySliders[i] = Slider(win, Rect(155, rowY, 90, 22));
				~peerActivitySliders[i].enabled_(false);

				~peerPitchSliders[i] = Slider(win, Rect(250, rowY, 90, 22));
				~peerPitchSliders[i].enabled_(false);

				~peerTextureSliders[i] = Slider(win, Rect(345, rowY, 90, 22));
				~peerTextureSliders[i].enabled_(false);

				~peerTextValues[i] = StaticText(win, Rect(450, rowY, 290, 22));
				~peerTextValues[i].string_("no message yet");
			};

			~updateGUI.value;

		}.defer;


		// ------------------------------------------------
		// OSC RECEIVE FROM ALL PEERS
		// ------------------------------------------------

		OSCdef(\meshPeerState, {
			|msg, time, addr, recvPort|

			var senderID;
			var activity;
			var pitch;
			var texture;
			var seq;
			var senderTime;

			if(msg.size >= 7) {
				senderID = msg[1].asInteger;

				// Ignore messages from self, if any arrive.
				if(senderID != ~myNodeID) {
					activity = msg[2].asFloat.clip(0, 1);
					pitch = msg[3].asFloat.clip(0, 1);
					texture = msg[4].asFloat.clip(0, 1);
					seq = msg[5].asInteger;
					senderTime = msg[6].asFloat;

					~peerStates[senderID] = (
						ip: addr.ip,
						activity: activity,
						pitch: pitch,
						texture: texture,
						seq: seq,
						senderTime: senderTime,
						lastTime: Main.elapsedTime
					);

					~computePeerAggregate.value;
					~updateSynth.value;
					~updateGUI.value;

					(
						"Received from node "
						++ senderID
						++ " at "
						++ addr.ip
						++ " | activity "
						++ activity.round(0.001)
						++ " pitch "
						++ pitch.round(0.001)
						++ " texture "
						++ texture.round(0.001)
					).postln;
				};
			} {
				"Warning: malformed /mesh/node/state message".postln;
				msg.postln;
			};

		}, "/mesh/node/state", recvPort: ~oscPort);


		// ------------------------------------------------
		// PERIODIC SEND TASK
		// ------------------------------------------------

		~sendTask = Task({
			inf.do {
				~sendState.value;
				(1 / ~sendHz).wait;
			};
		}).play(AppClock);


		// ------------------------------------------------
		// PERIODIC GUI / TIMEOUT REFRESH
		// ------------------------------------------------

		~guiTask = Task({
			inf.do {
				~computePeerAggregate.value;
				~updateSynth.value;
				~updateGUI.value;
				0.25.wait;
			};
		}).play(AppClock);


		// ------------------------------------------------
		// CLEANUP
		// ------------------------------------------------

		CmdPeriod.doOnce({
			if(~sendTask.notNil) {
				~sendTask.stop;
			};

			if(~guiTask.notNil) {
				~guiTask.stop;
			};

			OSCdef(\meshPeerState).free;

			if(~synth.notNil) {
				~synth.free;
			};

			"Complete mesh peer stopped.".postln;
		});


		// ------------------------------------------------
		// STARTUP PRINTS
		// ------------------------------------------------

		"----------------------------------------------------".postln;
		"Complete 8-node MESH peer started.".postln;
		("This node IP: " ++ ~myIP).postln;
		("This node ID: " ++ ~myNodeID).postln;
		("OSC port: " ++ ~oscPort).postln;
		"Sending to peers:".postln;

		~peers.do { |peer|
			("  node " ++ peer[\nodeID] ++ " at " ++ peer[\ip]).postln;
		};

		"".postln;
		"OSC message format:".postln;
		"/mesh/node/state nodeID activity pitch texture seq time".postln;
		"----------------------------------------------------".postln;

	}).play(AppClock);
});
)