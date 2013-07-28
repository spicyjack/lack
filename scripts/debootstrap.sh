#!/bin/sh

# script to run debootstrap
ROOT_VOL="/mnt/rootvol"
BASEDEBS="/tmp/basedebs.tar.bz2"
MOUNTPT=$(mountpoint $ROOT_VOL)

check_debootstrap () {
    STATUS=$1
    if [ $STATUS ]; then
        echo "debootstrap exited with a non-zero status!"
        exit 1
    else 
        exit 0
    fi
}


# MOUNTPT will be '0' if ROOT_VOL is a mount point, and 1 otherwise
if [ ! $MOUNTPT ]; then
    # $ROOT_VOL is a mount point
    if [ -r $BASEDEBS ]; then
        # use a local version of basedebs
        /usr/sbin/debootstrap --arch i386 --unpack-tarball $BASEDEBS \
            woody $ROOT_VOL
        check_debootstrap $?
    else
        # try downloadiing it; a local version doesn't exist
        /usr/sbin/debootstrap --arch i386 woody $ROOT_VOL \
            http://ftp.us.debian.org/debian
        check_debootstrap $?
    fi
else
    echo "Hmm. Looks like $ROOT_VOL is not mounted"
    exit 1
fi
