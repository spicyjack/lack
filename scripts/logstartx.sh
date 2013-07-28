#!/bin/sh

# script to run startx and log it's output to a file

sh -x /usr/bin/startx > /tmp/startx.log 2>&1
