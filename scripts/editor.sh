#!/bin/sh

if [ $1 ]; then
    /bin/busybox vi $1
else
    /bin/busybox vi
fi

