#!/bin/sh

# $Id: lack_functions.sh,v 1.8 2009-08-01 07:06:37 brian Exp $
# Copyright (c)2004 Brian Manning <brian at portaboom dot com>

# PLEASE DO NOT E-MAIL THE AUTHOR ABOUT THIS SOFTWARE
# The proper venue for questions is the LACK mailing list at:
# http://groups.google.com/linuxack or <linuxack.googlegroups.com>

# Essential functions for booting/running a LACK install

# TODO
# - detect whether or not we should be using ANSI color strings or not
# - add a logger using tee, or just write the message to a file somewhere;
# - maybe parse the console kernel boot argument to see if a serial console was
# specified

# color control strings
START="["
END="m"

# some common message strings
SUCCESS=" success."
FAILED=" failed."

# text attributes
NONE=0; BOLD=1; NORM=2; BLINK=5; INVERSE=7; CONCEALED=8

# background colors
B_BLK=40; B_RED=41; B_GRN=42; B_YLW=43
B_BLU=44; B_MAG=45; B_CYN=46; B_WHT=47

# foreground colors
F_BLK=30; F_RED=31; F_GRN=32; F_YLW=33
F_BLU=34; F_MAG=35; F_CYN=36; F_WHT=37

# some shortcuts
S_SUCCESS="${BOLD};${F_GRN};${B_BLK}"
S_FAILURE="${BOLD};${F_RED};${B_BLK}"
S_INFO="${F_BLK};${B_CYN}"
S_TIP="${BOLD};${F_BLU};${B_BLK}"
T_SUCCESS="${BOLD};${F_WHT};${B_GRN}"
T_FAILURE="${BLINK};${F_YLW};${B_RED}"
T_INFO="${INVERSE};${F_WHT};${B_BLU}"
T_TIP="${CONCEALED};${F_BLK};${B_WHT}"

## FUNC: colorize
## ARG:  ANSI shortcut tags or ANSI escape sequences for coloring text
## ARG:  text to colorize and output on STDOUT
## RET:  returns the exit status of the busybox 'echo' builtin
## DESC: Outputs the text passed in as the 2nd argument to STDOUT, *WITHOUT* a
## DESC: newline.  This is good if you have a status message that should be
## DESC: printed on the same line as this message.
colorize () {
    local COLOR=$1
    local MESSAGE=$2
    $BB echo -n "${START}${COLOR}${END}${MESSAGE}${START};${NONE}${END}"
    return $?
} # colorize()

## FUNC: colorize_nl
## ARG:  ANSI shortcut tags or ANSI escape sequences for coloring text
## ARG:  text to colorize and output on STDOUT
## RET:  returns the exit status of the busybox 'echo' builtin
## DESC: Calls colorize(), with the color string/message passed in as
## DESC: arguments, then outputs a newline.  This is good for updating the
## DESC: status of a command that was previously run, or just for updating
## DESC: general staus of the system.
colorize_nl () {
    local COLOR=$1
    local MESSAGE=$2
    colorize "${COLOR}" "${MESSAGE}"
    $BB echo
} # colorize_nl()

## FUNC: dlog
## ARG:  message to write to the debug log
## ENV:  DEBUG_LOG - the location of the debug logfile
## DESC: log a message to the file pointed to by the DEBUG_LOG environment
## DESC: variable; note that if this variable is not set, uses
## DESC: /var/log/debug.log by default.
dlog () {
    local MESSAGE=$1
    if [ "x$DEBUG_LOG" = "x" ]; then
        DEBUG_LOG="/var/log/debug.log"
    fi
    echo $MESSAGE >> $DEBUG_LOG
} # dlog()

## FUNC: pause_prompt
## ENV:  PAUSE_PROMPT - whether or not to pause when this function is called
## DESC: Pause (prompt the user to continue by hitting <ENTER>) when this
## DESC: function is called if the PAUSE_PROMPT variable contains any value
pause_prompt () {
    local ANSWER
    if [ "x${PAUSE_PROMPT}" != "x" ]; then
        echo -n " -PAUSED-  Hit <ENTER> to continue..."
        read ANSWER
    fi # if [ "x${PAUSE_SCRIPT}" != "x" ]; then
} # function script_pause ()

## FUNC: want_shell
## ENV:  PAUSE_PROMPT - whether or not to pause when this function is called
## DESC: Pause (prompt the user to continue by hitting <ENTER>) when this
## DESC: function is called if the PAUSE_PROMPT variable contains any value
want_shell () {
# run a shell (only if $DEBUG is set)
    if [ $DEBUG ]; then
        colorize $S_INFO "Execute debug shell? [Y/n] "
        read ANSWER
        # if neither N nor n... (needs an 'and' -a)
        if [ "x${ANSWER}" != "xn" -a "x${ANSWER}" != "xN" ]; then
            $BB stty sane
            $BB echo; $BB echo
            colorize_nl $S_SUCCESS "Running /bin/sh (NetBSD ash Shell)"
            exec $BB ash
            $BB echo "OOPS! We shouldn't have gotten here"
            exit 1 # shouldn't get here
        fi # if [ "${ANSWER}" = "y" -o "${ANSWER}" = "Y" ];
    fi # if [ $DEBUG ]
} # want_shell()

## FUNC: check_exit_error
## ARG:  EXIT_STATUS - the exit status of the command that was run
## ARG:  COMMAND_MSG - the message to be output if EXIT_STATUS is non-zero
## RET:  Returns EXIT_STATUS
## DESC: Check EXIT_STATUS, and bark if there's an error, otherwise, be silent
check_exit_error () {
    local EXIT_STATUS=$1
    local COMMAND_MSG=$2
    if [ "x${COMMAND_MSG}" == "x" ]; then COMMAND_MSG="unknown command"; fi
    if [ $EXIT_STATUS -gt 0 ]; then
        colorize_nl $S_FAILURE "$FAILED"
        colorize $S_FAILURE "--> Command '${COMMAND_MSG}' failed; exit code: "
        colorize_nl $S_INFO ">${EXIT_STATUS}<"
        # from here, we ask the user if they want a shell, but only if $DEBUG
        # has been set in the main init script
        want_shell
    fi
    return $EXIT_STATUS
} # check_exit_status

## FUNC: check_exit_status
## ARG:  EXIT_STATUS - the exit status of the command that was run
## ARG:  COMMAND_MSG - the message to be output if EXIT_STATUS is non-zero
## RET:  Returns EXIT_STATUS
## DESC: Check EXIT_STATUS, and output 'success' or 'failure' and a newline
## DESC: Note that this is different from check_exit_error, as there will
## DESC: always be output from this function, regardless of whether there
## DESC: was an error or not.
check_exit_status () {
    local EXIT_STATUS=$1
    local COMMAND_MSG=$2
    if [ "x${COMMAND_MSG}" == "x" ]; then COMMAND_MSG="unknown command"; fi
    if [ $EXIT_STATUS -eq 0 ]; then
        colorize_nl $S_SUCCESS "$SUCCESS"
    else
        # so we only have to update this in one place...
        check_exit_error $EXIT_STATUS $COMMAND_MSG
    fi
    return $EXIT_STATUS
} # check_exit_status

## FUNC: file_parse
## ARG:  PARSE_FILE - the name of the file to parse
## ARG:  SEARCH_STRING - the (regex) string to search for in that file
## ENV:  DEBUG - outputs more verbose messages if set
## SETS: PARSED - the string that was parsed out of the file, if any
## DESC: Parses a file, looking for occurances of SEARCH_STRING
file_parse () {
    local PARSE_FILE=$1
    local SEARCH_STRING=$2
    # reset the parsed flag; must do this here instead of inside the for loop,
    # or PARSED will get overwritten with each failure, which could happen
    # after the successful grep
    PARSED=''
    if [ $DEBUG ]; then
        $BB echo "-> file_parse - searching file ${PARSE_FILE}"
        $BB echo "-> file_parse - for search string '${SEARCH_STRING}'";
    fi # if [ $DEBUG ]

    for LINE in $(${BB} cat ${PARSE_FILE}); do
        if [ $DEBUG ]; then $BB echo "  - searching string '${LINE}'"; fi
        $BB echo $LINE | $BB grep "^${SEARCH_STRING}=" > /dev/null
        if [ $? -eq 0 ]; then
            if [ $DEBUG ]; then
                $BB echo "-> found ${SEARCH_STRING} for ${LINE}";
            fi # if [ $DEBUG ]
            PARSED=$(${BB} expr "${LINE}" : '.*=\(.*\)')
            if [ $DEBUG ]; then $BB echo "-> setting PARSED to '${PARSED}'"; fi
            break
        fi
    done
    if [ $DEBUG ]; then echo "-> parsed string is ${PARSED}"; fi
} # file_parse

## FUNC: write_child_pid
## ARG:  CHILD_BINARY - the name of the child process that was run
## ARG:  CHILD_PID - the PID of the child process that was started
## DESC: Writes a file with the name ${CHILD_BINARY}.pid to /var/run
write_child_pid () {
# write a PID file for scripts/programs that don't make their own
    local CHILD_BINARY=$1
    local CHILD_PID=$2
    echo $CHILD_PID > /var/run/${CHILD_BINARY}.pid
} # write_child_pid()

## FUNC: get_pid
## ARG:  BINARY - the name of the program that was run
## SETS: CHILD_PID - the PID of the $BINARY
## DESC: Grabs the PID from a currently running process
get_pid () {
    BINARY=$1
    CHILD_PID=$(/bin/ps | /bin/grep ${BINARY} | /bin/grep -v grep \
        | /usr/bin/awk '{print $1}')
} # get_pid ()

## FUNC: get_hostname
## SETS: HOSTNAME - the contents of the file /etc/hostname
## DESC: Grabs the PID from a currently running process
get_hostname () {
    if [ -e "/etc/hostname" ]; then
        HOSTNAME=$(/bin/cat /etc/hostname)
    else
        colorize_nl $S_FAILURE "ERROR: missing '/etc/hostname' file"
    fi
} # get_hostname ()

## FUNC: get_kernel_version
## SETS: KERNEL_VER_STRING - the full kernel version string (X.X.X)
## SETS: KERNEL_MAJOR - the kernel major version string
## SETS: KERNEL_MINOR - the kernel minor version string
## SETS: KERNEL_PATCH_VERSION - the kernel patch version
## DESC: exports information about the running kernel to the environment
get_kernel_version () {
# grab the kernel version and export it into the environment as shell
# variables
    colorize $TIP "- Determining Linux Kernel Version Number"; echo
    # run uname, cut off everything after the '-' dash character
    KERNEL_VER_STRING=$(/bin/uname -r | /usr/bin/cut -d'-' -f 1)
    # find the major version with cut
    KERNEL_MAJOR=$(/bin/echo $KERNEL_VER_STRING | /usr/bin/cut -d'.' -f 1)
    # find the patchlevel with cut
    KERNEL_MINOR=$(/bin/echo $KERNEL_VER_STRING | /usr/bin/cut -d'.' -f 2)
    # find the sublevel with cut
    KERNEL_PATCH_VERSION=$(/bin/echo $KERNEL_VER_STRING \
        | /usr/bin/cut -d'.' -f 3)
} # get_kernel_version()

# *** begin license blurb ***
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA

# vi: set shiftwidth=4 tabstop=4 filetype=sh :
# конец!
