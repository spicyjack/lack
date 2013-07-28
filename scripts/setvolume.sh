#!/bin/sh
# $Id: setvolume.sh,v 1.3 2009-08-10 08:38:58 brian Exp $
# Copyright (c)2009 by Brian Manning (elspicyjack at gmail dot com)
# PLEASE DO NOT E-MAIL THE AUTHOR ABOUT THIS SOFTWARE
# The proper venue for questions is the Propaganda mailing list at:
# http://groups.google.com/group/psas or <psas@groups.google.com>
#
# set the volume level on the Master and PCM mixer channels

### MAIN SCRIPT ###
# what's my name?
SCRIPTNAME=$(/usr/bin/basename $0)
# exit status
EXIT=0
# what to set the volume to
VOL_LEVEL="80%"
# which channels to set the volume on
ALSA_CHANNELS="Master PCM"
# mute all channels? 0=no, 1=yes
MUTE_ALL=0

# set quiet mode by default, needs to be set prior to the getops call
VERBOSE=0

### SCRIPT SETUP ###
TEMP=$(/usr/bin/getopt -o hvl:c:m \
    --long help,verbose,level:,channels:,mute \
    -n '${SCRIPTNAME}' -- "$@")

# if getopts exited with an error code, then exit the script
#if [ $? -ne 0 -o $# -eq 0 ] ; then
if [ $? != 0 ] ; then
    echo "Run '${SCRIPTNAME} --help' to see script options" >&2
    exit 1
fi

# Note the quotes around `$TEMP': they are essential!
# read in the $TEMP variable
eval set -- "$TEMP"

# read in command line options and set appropriate environment variables
# if you change the below switches to something else, make sure you change the
# getopts call(s) above
ERRORLOOP=1
while true ; do
    case "$1" in
        -h|--help) # show the script options
        cat <<-EOF

    ${SCRIPTNAME} [options]

    SCRIPT OPTIONS
    -h|--help       Displays this help message
    -v|--verbose    Nice pretty output messages

    -l|--level      Volume level to set on the MASTER/PCM mixer channels
    -c|--channels   Names of ALSA channels to set the volume on (MASTER/PCM)
    -m|--mute       Mute all channels

EOF
        exit 0;;
        -v|--verbose) # output pretty messages
            VERBOSE=1
            shift;;
        -m|--mute) # mute all channels
            MUTE_ALL=1
            shift;;
        -l|--level) # volume level to set on MASTER/PCM channels
            VOL_LEVEL=$2
            ERRORLOOP=$(($ERRORLOOP - 1));
            shift 2;;
        -c|--channels) # channels to set the volume on
            CHANNELS=$2
            ERRORLOOP=$(($ERRORLOOP - 1));
            shift 2;;
        --) shift; # delimiter for other options (not used)
            break;;
    esac
    # exit if we loop across getopts too many times
    ERRORLOOP=$(($ERRORLOOP + 1))
    if [ $ERRORLOOP -gt 4 ]; then
        echo "ERROR: too many getopts passes;"
        echo "Maybe you have a getopt option with no branch?"
        echo "Last option parsed was: ${1}"
        exit 1
    fi # if [ $ERROR_LOOP -gt 3 ];

done

### begin script body
# use the default channels if the user didn't pass any in
if [ "x$CHANNELS" == "x" ]; then
    CHANNELS=$ALSA_CHANNELS
fi # if [ "x$CHANNELS" == "x" ];

# kill all copies of this script?
if [ "x$VOL_LEVEL" != "x" ]; then
    PERCENT_CHECK=$(echo $VOL_LEVEL | grep -c '%$')
    if [ $PERCENT_CHECK -eq 0 ]; then
        VOL_LEVEL="${VOL_LEVEL}%"
    fi
    # enumerate over all of the mixer channels, set them to the same level
    for MIX_CHANNEL in $(echo ${CHANNELS});
    do
        # verbose amixer output?
        if [ $VERBOSE -eq 1 ]; then
            AMIXER_CMD="/usr/bin/amixer set"
            echo "Mixer command: ${AMIXER_CMD} set ${MIX_CHANNEL} ${VOL_LEVEL}"
        else
            AMIXER_CMD="/usr/bin/amixer -q set"
        fi
        # run the actual command
        if [ $MUTE_ALL -eq 1 ]; then
            $AMIXER_CMD "${MIX_CHANNEL}" $VOL_LEVEL off
        else
            $AMIXER_CMD "${MIX_CHANNEL}" $VOL_LEVEL on
        fi # if [ $MUTE_ALL -eq 1 ]
        if [ $? -ne 0 ]; then
            echo "ERROR: amixer exited with status ${?}" >&2
        fi
    done # for MIX_CHANNEL in $(echo ${CHANNELS})
fi # if [ "x$VOL_LEVEL" != "x" ]

exit ${EXIT}

### BEGIN LICENCE
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; version 2 dated June, 1991.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program;  if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111, USA.
### END LICENSE

# vi: set ft=sh sw=4 ts=4:
# end of line
