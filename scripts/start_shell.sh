#!/bin/sh

# script to output a file prior to exec'ing a shell

cat /etc/issue.nogetty
exec /bin/sh
