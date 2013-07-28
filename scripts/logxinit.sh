#!/bin/sh

# script to run startx and log it's output to a file

/usr/bin/xinit /usr/bin/xterm > /tmp/xinit.log 2>&1
