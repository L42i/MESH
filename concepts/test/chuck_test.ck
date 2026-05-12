// Simple sine wave output example
SinOsc s => dac;    // Connect sine oscillator to DAC
0.5 => s.gain;      // Set volume to 50%
440 => s.freq;      // Set frequency to 440Hz (A4)
5::second => now;   // Play for 1 second