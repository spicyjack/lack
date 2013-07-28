#!/bin/sh

# script to set up a machine with the basics

# TODO 
# - set up linuxlogo by sed'ing /etc/inittab and doing 'telinit q'
# - set up lode-lat1u-16 font in /etc/console-tools/config
# - set up sources.list with contrib and non-free debian archives
# - add nice header blocks in between sections
# - split up sections into either shell functions or separate files that can be
# run sysvinit style

PACKAGE_LIST="mercurial linuxlogo screen stow sudo ssh vim ctags wget less"
DOWNLOAD_URL="http://purl.portaboom.com/project_pkgs/"
RC_TARBALL_FILE="rcfiles.tar"
SPLASHSCREEN_FILE="sunspot_swedish-640x480.xpm.gz"
GRUB_DIR=/boot/grub

# external programs
APT_GET=$(which apt-get)
CP=$(which cp)
CHMOD=$(which chmod)
LN=$(which ln)
MKTEMP=$(which mktemp)
MV=$(which mv)
RM=$(which rm)
RMDIR=$(which rmdir)
TAR=$(which tar)
WGET=$(which wget)

# first, make sure we have an up-to-date package list
$APT_GET update
$APT_GET --yes upgrade 

# install the packages needed to run a basic system
$APT_GET --yes install $PACKAGE_LIST

# create a working directory and go to it
TEMPDIR=$($MKTEMP -d /tmp/setup.XXXX)
echo "TEMPDIR is $TEMPDIR"
cd $TEMPDIR
echo "Current directory is now $PWD"

# get the .rcfiles tarball and install
$WGET --http-user=speak --http-password=friend $DOWNLOAD_URL/$RC_TARBALL_FILE

if [ -e $RC_TARBALL_FILE ]; then

    $TAR -xvf $RC_TARBALL_FILE
    $MV -v .bashrc .vimrc .dir_colors .ssh ~
    $CHMOD 700 ~/.ssh/
    $MV lode-lat1u-16.psf /usr/share/consolefonts/
    $MV sunspot_swedish-640x480.xpm.gz /boot/grub/
    $LN -s $GRUB_DIR/menu.lst /etc/grub.cfg
    # copy the default file out of the way
    if [ -e /etc/linux_logo.conf ]; then
        $MV /etc/linux_logo.conf /etc/linux_logo.conf.orig
    fi
    $MV linux_logo.conf /etc
# get the splashscreen image and install
    cd $GRUB_DIR

    if [ ! -h splash.xpm.gz ]; then
        ln -s $SPLASHSCREEN_FILE splash.xpm.gz
    fi 

    cd /
    $RM $TEMPDIR/rcfiles.tar
    $RMDIR $TEMPDIR
fi # if [ -e $RC_TARBALL_FILE ]; then

# go home and exit
cd ~
exit 0
