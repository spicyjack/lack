#!/bin/sh

# $Id: install.sh,v 1.7 2007-01-18 05:28:06 brian Exp $
# Copyright (c)2007 by Brian Manning (elspicyjack at gmail dot com)

# A script to run all of the action scripts that are used to build a Project
# Naranja system

# for support with this script, please use the Project Naranja mailing list
# at http://groups.google.com/group/project-naranja

# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place, Suite 330, Boston, MA  02111-1307 USA

# make Ctrl-C exit the script? maybe only during debugging...
if [ ! $DEBUG ]; then
	trap '' 2
fi

# some scriptwide defaults
BOX_HEIGHT=10
BOX_WIDTH=60
# where's 'dialog'?  Note that 'whiptail' is not a 100% substitute, as some of
# it's switches are different from dialog's switches
DIALOG=$(which dialog)
# the path to all of the action scripts
#INSTALLER_PATH="/etc/pn-installer"
INSTALLER_PATH="."

# total number of scripts that have the pattern S*.sh
TOTAL_SCRIPTS=$(/bin/ls ${INSTALLER_PATH}/S*.sh | wc \
	| awk '{print $1}' | tr -d '\n')
RUN_SCRIPT=$(/bin/ls S*.sh | head -n 1 | tr -d '\n')
CURR_SCRIPT_NUM=1
FINISHED=0

# some common functions
ok_dialog () {
    # grab the dialog parameters from the argument list
    local TITLE=$1
    local BACKTITLE=$2
    local OK_LABEL=$3
    local MSG_TXT=$4
    $DIALOG --ok-label "$OK_LABEL" --backtitle "$BACKTITLE" --title "$TITLE" \
        --msgbox "$MSG_TXT" $BOX_HEIGHT $BOX_WIDTH
} # ok_dialog ()

### BEGIN MAIN SCRIPT ###
# display the intro screen
ok_dialog "Welcome!" "Project Naranja Installer" "Next" \
    "Please hit the <ENTER> key to start the install process"
# stay in a loop until all of the action scripts have been run and FINISHED is
# set to true
while [ $FINISHED -eq 0 ]; do
    echo "sourcing $RUN_SCRIPT"
    source $RUN_SCRIPT
    echo "running action"
    action $TOTAL_SCRIPTS $CURR_SCRIPT_NUM
    ACTION_STATUS=$?
    echo "action returned $ACTION_STATUS"
    # figure out what the previous and next scripts are, just in case they are
    # needed
    unset PREV_SCRIPT
    unset CURR_SCRIPT
    unset NEXT_SCRIPT
    # Loop through all the action scripts; get the previous action script or
    # the next action script, depending on what action the user wants to do
    for SEARCH_SCRIPT in S*.sh; do
        # if the search script matches the current script, don't modify
        # LAST_SCRIPT, instead go around the loop one more time, and figure out
        # what NEXT_SCRIPT is
        echo "search script is $SEARCH_SCRIPT"
        echo "current script number is $CURR_SCRIPT_NUM"
        if [ $SEARCH_SCRIPT == $RUN_SCRIPT ]; then
            # set CURR_SCRIPT; this lets the loop know that we only need one
            # more pass
            if [ ! $CURR_SCRIPT ]; then
                CURR_SCRIPT=$SEARCH_SCRIPT

            fi
        elif [ $CURR_SCRIPT ]; then
            # we've already found the current script, we need the NEXT_SCRIPT
            NEXT_SCRIPT=$SEARCH_SCRIPT
            # break out of this for loop
            break
        else
            # haven't found CURR_SCRIPT yet; save this SEARCH_SCRIPT as
            # PREV_SCRIPT, go around the loop again
            PREV_SCRIPT=$SEARCH_SCRIPT
        fi
    done # for SCRIPT in pg-installer/*.sh; do
    # if the last action exited via the YES/OK button, it would have returned a
    # status code of '0'
    if [ $ACTION_STATUS -eq 0 ]; then
        if [ $NEXT_SCRIPT ]; then
            # go on to the next script
            RUN_SCRIPT=$NEXT_SCRIPT
            CURR_SCRIPT_NUM=$(($CURR_SCRIPT_NUM + 1))
        elif [ ! $NEXT_SCRIPT ]; then
            # we're out of scripts to run; we're done with the installer
            FINISHED=1
            break
        fi
    elif [ $ACTION_STATUS -eq 1 -o $ACTION_STATUS -eq -1 ]; then
        # user hit ESC or Back; go back a script
        RUN_SCRIPT=$PREV_SCRIPT
        CURR_SCRIPT_NUM=$(($CURR_SCRIPT_NUM - 1))
    fi # if [ $ACTION_STATUS -eq 0 ];
done # while [ $FINISHED -eq 0 ];

# one more dialog to show users we're done
ok_dialog "Finished!" "Project Naranja Installer" "Exit" \
    "Hit the <ENTER> key to exit the installer"

exit 0
# fin
