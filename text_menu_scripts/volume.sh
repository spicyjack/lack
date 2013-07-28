#!/bin/sh
# !DESC-EN!55!volume!Run/configure a volume control program

# format of the description line:
# !token and language!script name!script description
# note that the keyword 'DESC' is grepped for, so it must be exact

# $Id: volume.sh,v 1.1 2009-07-23 08:30:56 brian Exp $
# Copyright (c)2009 by Brian Manning (elspicyjack at gmail dot com)
# PLEASE DO NOT E-MAIL THE AUTHOR ABOUT THIS SOFTWARE
# The proper venue for questions is the Propaganda mailing list at:
# http://groups.google.com/group/psas or <psas@groups.google.com>
#
# run a volume control program, or choose which volume control program to run

### MAIN SCRIPT ###
# what's my name?
SCRIPTNAME=$(basename $0)
# exit status
EXIT=0

# set quiet mode by default, needs to be set prior to the getops call
QUIET=1

### SCRIPT SETUP ###
TEMP=$(/usr/bin/getopt -o hvo: \
    --long help,verbose,option: -n '${SCRIPTNAME}' -- "$@")

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
    -o|--option     Random option
    NOTE: Long switches do not work with BSD systems (GNU extension)

EOF
		exit 0;;		
		-q|--quiet)	# don't output anything (unless there's an error)
						QUIET=1
						shift;;
        -v|--verbose) # output pretty messages
                        QUIET=0
                        shift;;
        -o|--option) # a long option with an argument
                        OPTION=$2; 
                        ERRORLOOP=$(($ERRORLOOP - 1));
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

RUNONCE_FILE="/var/run/aumix.runonce"
### SCRIPT MAIN LOOP ###
if [ ! -e $RUNONCE_FILE ]; then
    SYS_MSG=$(cat <<MSG
Aumix controls;\n\n\
Use the up and down arrow keys to select a fader, the left and right \
arrow keys to set the level on that fader, and the 'Q' key to quit \
the program.\n\
\n\
This message will only be displayed once per session.
MSG
)
    # FIXME change this to a checkbox, so the user can choose to display the
    # message again or turn it off if they want to
    dialog --backtitle "Propaganda: Aumix Usage Help" \
    --title "Aumix Usage Help" --begin 4 4 --msgbox "$SYS_MSG" 17 70 \
    2> $RUNONCE_FILE
fi
#echo "$SCRIPTNAME exit code was: ${?}"
#sleep 1
/usr/bin/aumix

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
