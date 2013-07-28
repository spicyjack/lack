#!/bin/sh

if [ $1 ]; then
    /bin/busybox ls -l --color=auto $1
else
    /bin/busybox ls --color=auto
fi

