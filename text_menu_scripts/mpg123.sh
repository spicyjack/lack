#!/bin/sh
# !DESC-EN!60!mpg123!Start/stop/configure the MPG123 MP3 player

# format of the description line:
# !token and language!script name!script description
# note that the keyword 'DESC' is grepped for, so it must be exact

# $Id: mpg123.sh,v 1.1 2009-07-23 08:30:56 brian Exp $
# Copyright (c)2009 by Brian Manning (elspicyjack at gmail dot com)
# PLEASE DO NOT E-MAIL THE AUTHOR ABOUT THIS SOFTWARE
# The proper venue for questions is the Propaganda mailing list at:
# http://groups.google.com/group/psas or <psas@groups.google.com>
#
# shell script that presents a menu to the user so they can do stuff

# directory to search for other sub-scripts, or scripts that will be presented
# to the user from this ѕcript
SEARCH_DIR=$PWD

### MAIN SCRIPT ###
# what's my name?
SCRIPTNAME=$(basename $0)
# path to the perl binary
# PID of mpg123
MPG123_PID="/var/run/mpg123.pid"
# our PID
RUN_MPG123_PID="/var/run/run_mpg123.pid"
# what we're listening to
STREAM_URL="http://localhost:8000/propaganda"

# set quiet mode by default, needs to be set prior to the getops call
QUIET=1

### FUNCTIONS ###
parse_dialog () {
    ACTION=$(cat /tmp/dialog.exit | tr -d '\n')
    case "$ACTION" in
        "Start") # start mpg123
            /bin/sh /etc/scripts/run_mpg123.sh --url $STREAM_URL &
            dialog --infobox "Starting mpg123 $STREAM_URL" 5 70
            sleep 2
            ;;
        "Stop") # stop mpg123
            /bin/kill -TERM $(/bin/cat $RUN_MPG123_PID)
            /bin/kill -TERM $(/bin/cat $MPG123_PID)
            /bin/rm $MPG123_PID
            /bin/rm $RUN_MPG123_PID
            ;;
        "Change URL") # change the URL, confirm restarting mpg123
            :
            ;;
        "Main Menu") # return to the main menu
            exit 0
            ;;
    esac

    # re-launch this script so it's status updates
    exec /bin/sh /etc/menuitems/mpg123.sh
}
### SCRIPT SETUP ###
TEMP=$(/usr/bin/getopt -o hpqv: \
    --long help,prompt,quiet,verbose: -n '${SCRIPTNAME}' -- "$@")

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
	-q|--quiet      No script output (unless an error occurs)
    -p|--prompt     Don't prompt after each output run
    NOTE: Long switches do not work with BSD systems (GNU extension)

EOF
		exit 0;;		
		-q|--quiet)	# don't output anything (unless there's an error)
						QUIET=1
						shift;;
        -v|--verbose) # output pretty messages
                        QUIET=0
                        shift;;
        -o|--option) # a month was passed in
                        OPTION=$2; ERRORLOOP=$(($ERRORLOOP - 1));
                        shift 2;;
		--) shift; break;;
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


### SCRIPT MAIN LOOP ###

# get the current status of mpg123
if [ -e $MPG123_PID ]; then
    MPG123_STATUS="Running, PID is $(cat $MPG123_PID)"
    START_TIME="mpg123 started: $(stat -c '%y' $MPG123_PID)\n"
    MPG123_ACTION="Stop"
    MPG123_DESC="Stop the current mpg123 process"
else 
    MPG123_STATUS="Not running"
    START_TIME="\n"
    MPG123_ACTION="Start"
    MPG123_DESC="Start mpg123, connected to 'Current Stream URL'"
fi

dialog --nocancel --backtitle "Propaganda: mpg123" \
--title "mpg123 Status/Options" \
--menu "Current mpg123 status: $MPG123_STATUS\n\
Current Stream URL: $STREAM_URL\n\
$START_TIME\n\
\n" 12 70 3 \
"Main Menu" "Return to the main menu" \
"$MPG123_ACTION" "$MPG123_DESC" \
2> /tmp/dialog.exit
#"Change URL" "Change stream URL (Requires restart)" \
#echo "dialog exit code was: ${?}"
#echo "menu choice was $(cat /tmp/dialog.exit)"

# parse_dialog will either call itself again, or exit to the main menu
parse_dialog
#exit $?

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
