#!/bin/bash

killall jackd

jackd -a a -d alsa -d hw:Gen -r 48000 -p 128 &