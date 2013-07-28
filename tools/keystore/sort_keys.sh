#!/bin/sh

# script to help sort keys
TARGET=/dev/shm/next
if [ ! -d $TARGET ]; then
    mkdir $TARGET
    if [ $? ­ne 0 ]; then
        echo "ERROR: could not create directory $TARGET"
        exit 1
    fi # if [ $? ­ne 0 ]
fi # if [ ! -d $TARGET ]

# run through the list of directories
for DIR in 05Dec2006 naranja-05Dec2006; do
    /bin/ls -t /home/brian/keys/$DIR | /usr/bin/head -n 1000 \
        | /usr/bin/xargs -i -t mv $DIR/{} $TARGET/{}
    /usr/bin/tail -n 500 "${DIR}-keylist.txt" >> $TARGET/keylist.txt
done
