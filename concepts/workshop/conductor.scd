(
// ================================================================
// MESH CONDUCTOR MODE — INDEPENDENT RECEIVER CONTROLS
// Run on conductor: 10.10.10.11
//
// Controls receivers:
// 10.10.10.12 through 10.10.10.18
//
// Each receiver gets 3 independent controls:
// Amp, Pitch, Texture
// ================================================================

// ----------------------------
// NETWORK CONFIG
// ----------------------------

~oscPort = 57120;

~nodeNums = (12..18);

~nodeIPs = ~nodeNums.collect { |n|
	"10.10.10.%".format(n);
};

~nodes = ~nodeIPs.collect { |ip|
	NetAddr(ip, ~oscPort);
};

// ----------------------------
// PARAMETER STATE
// ----------------------------

~paramNames = ["Amp", "Pitch", "Texture"];

// One state array per receiver:
// [amp, pitch, texture]
~states = Array.fill(~nodes.size, {
	[0.0, 0.5, 0.5]
});

// ----------------------------
// OSC SEND FUNCTIONS
// ----------------------------

~sendOne = { |nodeIndex|
	var vals;

	vals = ~states[nodeIndex];

	~nodes[nodeIndex].sendMsg(
		"/mesh/params",
		vals[0],
		vals[1],
		vals[2]
	);
};

~sendAll = {
	~nodes.size.do { |i|
		~sendOne.value(i);
	};
};

~startOne = { |nodeIndex|
	~nodes[nodeIndex].sendMsg("/mesh/start");
	("Started node " ++ ~nodeIPs[nodeIndex]).postln;
};

~stopOne = { |nodeIndex|
	~nodes[nodeIndex].sendMsg("/mesh/stop");
	("Stopped node " ++ ~nodeIPs[nodeIndex]).postln;
};

~startAll = {
	~nodes.size.do { |i|
		~startOne.value(i);
	};
};

~stopAll = {
	~nodes.size.do { |i|
		~stopOne.value(i);
	};
};

~muteOne = { |nodeIndex|
	~states[nodeIndex][0] = 0.0;
	~sendOne.value(nodeIndex);
};

~resetAll = {
	~states = Array.fill(~nodes.size, {
		[0.0, 0.5, 0.5]
	});

	~sendAll.value;
};

// Re-send all values periodically.
// This helps receivers recover if they miss a UDP message.
~sendInterval = 0.1; // 10 Hz

~senderTask = Task({
	inf.do {
		~sendAll.value;
		~sendInterval.wait;
	};
}).play(AppClock);

// Stop receivers when pressing CmdPeriod.
CmdPeriod.doOnce({
	if(~senderTask.notNil) {
		~senderTask.stop;
	};

	~stopAll.value;
});

// ----------------------------
// GUI
// ----------------------------

{
	var win;
	var sliders;
	var valueLabels;
	var rowY;
	var headerY;
	var startAllButton, stopAllButton, resetAllButton, sendAllButton;

	win = Window("MESH Conductor — Independent Receiver Controls", Rect(100, 100, 950, 455));
	win.front;
	win.alwaysOnTop_(true);

	win.onClose = {
		if(~senderTask.notNil) {
			~senderTask.stop;
		};

		~stopAll.value;
	};

	StaticText(win, Rect(20, 10, 900, 24))
		.string_("MESH Conductor Mode — Independent control for each receiver Pi")
		.font_(Font("Arial", 16));

	StaticText(win, Rect(20, 38, 900, 20))
		.string_("Conductor: 10.10.10.11     Receivers: 10.10.10.12 through 10.10.10.18     OSC Port: 57120")
		.font_(Font("Arial", 11));

	headerY = 75;

	StaticText(win, Rect(20, headerY, 160, 20))
		.string_("Receiver")
		.font_(Font("Arial", 12, true));

	StaticText(win, Rect(195, headerY, 130, 20))
		.string_("Amp")
		.align_(\center)
		.font_(Font("Arial", 12, true));

	StaticText(win, Rect(375, headerY, 130, 20))
		.string_("Pitch")
		.align_(\center)
		.font_(Font("Arial", 12, true));

	StaticText(win, Rect(555, headerY, 130, 20))
		.string_("Texture")
		.align_(\center)
		.font_(Font("Arial", 12, true));

	sliders = Array.fill(~nodes.size, {
		Array.newClear(3)
	});

	valueLabels = Array.fill(~nodes.size, {
		Array.newClear(3)
	});

	~nodes.size.do { |i|
		var y;
		var nodeLabel;
		var startButton, stopButton, muteButton;

		y = 105 + (i * 38);

		nodeLabel = StaticText(win, Rect(20, y, 160, 22));
		nodeLabel.string_("Pi " ++ ~nodeNums[i].asString ++ "  —  " ++ ~nodeIPs[i]);

		3.do { |j|
			var x;
			var slider;
			var valueLabel;

			x = 190 + (j * 180);

			slider = Slider(win, Rect(x, y, 120, 22));
			slider.value_(~states[i][j]);

			valueLabel = StaticText(win, Rect(x + 125, y, 45, 22));
			valueLabel.string_(~states[i][j].round(0.001).asString);
			valueLabel.align_(\center);

			slider.action_({ |sl|
				~states[i][j] = sl.value;
				valueLabel.string_(sl.value.round(0.001).asString);
				~sendOne.value(i);
			});

			sliders[i][j] = slider;
			valueLabels[i][j] = valueLabel;
		};

		startButton = Button(win, Rect(735, y, 55, 22));
		startButton.states_([
			["Start"]
		]);
		startButton.action_({
			~startOne.value(i);
		});

		stopButton = Button(win, Rect(795, y, 55, 22));
		stopButton.states_([
			["Stop"]
		]);
		stopButton.action_({
			~stopOne.value(i);
		});

		muteButton = Button(win, Rect(855, y, 55, 22));
		muteButton.states_([
			["Mute"]
		]);
		muteButton.action_({
			~muteOne.value(i);

			sliders[i][0].value_(0.0);
			valueLabels[i][0].string_("0.0");
		});
	};

	startAllButton = Button(win, Rect(40, 390, 120, 35));
	startAllButton.states_([
		["START ALL"]
	]);
	startAllButton.action_({
		~startAll.value;
	});

	stopAllButton = Button(win, Rect(180, 390, 120, 35));
	stopAllButton.states_([
		["STOP ALL"]
	]);
	stopAllButton.action_({
		~stopAll.value;
	});

	resetAllButton = Button(win, Rect(320, 390, 120, 35));
	resetAllButton.states_([
		["RESET ALL"]
	]);
	resetAllButton.action_({
		~resetAll.value;

		~nodes.size.do { |i|
			3.do { |j|
				sliders[i][j].value_(~states[i][j]);
				valueLabels[i][j].string_(~states[i][j].round(0.001).asString);
			};
		};
	});

	sendAllButton = Button(win, Rect(460, 390, 120, 35));
	sendAllButton.states_([
		["SEND ALL"]
	]);
	sendAllButton.action_({
		~sendAll.value;
		"Sent all current parameter states.".postln;
	});

	StaticText(win, Rect(610, 384, 300, 45))
		.string_("OSC message per receiver:\n/mesh/params amp pitch texture")
		.align_(\center);

}.defer;

"Conductor ready.".postln;
"Sending independent controls to:".postln;
~nodeIPs.do { |ip| ip.postln };
)