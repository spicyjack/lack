#!/bin/sh

# script to set up a machine with an xserver

PACKAGE_LIST="xserver-xorg-core x11-xserver-utils fluxbox mrxvt 
    gnome-terminal libgtk2-perl xinit libconfig-inifiles-perl"

# external programs
APT_GET=$(which apt-get)

# first, make sure we have an up-to-date package list
$APT_GET update
$APT_GET --yes upgrade 

# install the packages needed to run a basic system
$APT_GET --yes install $PACKAGE_LIST

# exit
exit 0
