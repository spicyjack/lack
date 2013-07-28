#!/bin/sh
# $Id: runtop.sh,v 1.3 2009-08-10 08:38:58 brian Exp $
# Copyright (c)2009 by Brian Manning (elspicyjack at gmail dot com)
# PLEASE DO NOT E-MAIL THE AUTHOR ABOUT THIS SOFTWARE
# The proper venue for questions is the Propaganda mailing list at:
# http://groups.google.com/group/antlinux or <antlinux@groups.google.com>
#
# set the volume level on the Master and PCM mixer channels

source /etc/ant_functions.sh

### MAIN SCRIPT ###
# what's my name?
SCRIPTNAME=$(/usr/bin/basename $0)
# exit status
EXIT=0
# delay in seconds before starting
START_DELAY=15
# delay in seconds between top updates
TOP_DELAY=3

# set quiet mode by default, needs to be set prior to the getops call
VERBOSE=0

### SCRIPT SETUP ###
TEMP=$(/usr/bin/getopt -o hvs:t: \
    --long help,verbose,start-delay:,top-delay \
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
    -h|--help         Displays this help message
    -v|--verbose      Nice pretty output messages

    -s|--start-delay  Delay in seconds prior to starting 'top'
    -t|--top-delay    Delay in seconds between updates once 'top' is running

EOF
		exit 0;;		
        -v|--verbose) # output pretty messages
            VERBOSE=1
            shift;;
        -s|--start-delay) # Delay in seconds prior to starting 'top'
            START_DELAY=$2
            ERRORLOOP=$(($ERRORLOOP - 1));
            shift 2;;
        -t|--top-delay) # Delay in seconds between updates once 'top' runs
            TOP_DELAY=$2
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
#colorize_nl $S_INFO "Just about to run the 'top' program..."
#TEXT="You can switch to other consoles using the F keys"
#colorize_nl $S_INFO "$TEXT on the keyboard."
#colorize_nl $S_INFO "Note: if you exit 'top', it will automatically restart!"
#/bin/sleep $START_DELAY
/usr/bin/top -d $TOP_DELAY

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
