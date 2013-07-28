#!/bin/sh

# spoof the debian program 'tempfile'
TEMPFILE=$(/bin/busybox mktemp -t)
/bin/busybox cat /etc/inittab > $TEMPFILE

if [ $? -eq 0 ]; then
    echo $TEMPFILE
    exit 0
else
    exit 1
fi

