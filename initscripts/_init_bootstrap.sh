#!/bin/sh

# Copyright (c)2003 Brian Manning (brian at portaboom dot com)
# PLEASE DO NOT E-MAIL THE AUTHOR ABOUT THIS SOFTWARE
# The proper venue for questions is the LACK mailing list at:
# http://groups.google.com/group/linuxack or <linuxack@googlegroups.com>
#
# License terms at the bottom of this file

# System bootstrapping script for stand-alone systems, i.e. you will
# switch_root and exec /sbin/init in the new root partition.
#
# This script will
# 1) boot the system
# 2) Run the symlinked scripts in /etc/boot in SYSV init order
# 3) The scripts in /etc/boot are supposed to do things like mount encrypted
# volumes or mount the root partition from an LVM volume (if LVM volume is
# passed in from /proc/cmdline)
# 4) The call to switch_root that is run at the end of this script should
# transfer control to the /sbin/init binary found on that freshly-mounted
# filesystem.

# begin busybox setup; from here on down, you need to use the full path to
# busybox, along with the name of the module you want to run, as the busybox
# symlinks don't exist (yet)

# also, if you add binaries to the image that would live in the same place as a
# busybox applet (example, losetup binary and losetup busybox applet), then you
# need to use the full path to the binary in any script called from here, as
# the busybox applet will be run if there is no path to the binary

# TODO
# - detect if the script output is going to a serial console or not, and adjust
# calls to colorize() accordingly
# - create a script parameter called $LOG_COMMAND, and have $LOG_COMMAND be
# either the 'tee' command or a cat command; this will allow the script to
# print the command output to the screen or a logfile and the screen at the
# same time

## EXPORTS
# set a serial port for use in the subscripts for writing output so users
# connected to serial console can see what's happening
# FIXME sed/awk this out of /proc/cmdline, the 'console' tags
export SERIAL_PORT="/dev/ttyS0"
# path to busybox
export BB="/bin/busybox"
# log file to write messages to
export DEBUG_LOG="/var/log/debug.log"

# source the common functions script.  this is where things like colorize(),
# check_exit_status(), want_shell() and file_parse() is coming from
export LACK_FUNCTIONS="/etc/scripts/lack_functions.sh"
source $LACK_FUNCTIONS

# show the header first
$BB clear
colorize_nl $S_INFO "=== Begin :PROJECT_NAME: /init script: PID is ${$} ==="

# are we debugging?
if [ $DEBUG ]; then
    colorize_nl $S_INFO "=== DEBUG environment variable currently: $DEBUG ==="
    # yep, we are;
    # set up enough of the environment (filesystems, mice, keyboards) so
    # that the user can respond to questions we ask of them :)
    # FIXME abstract this into a loop by loading all of the names of the below
    # scripts into a variable; the variable can also be used later on by
    # grepping for the names of scripts that have already been run so that you
    # don't run them again
    $BB sh /etc/init.d/loadfont start
    $BB sh /etc/init.d/remount-rootfs start
    $BB sh /etc/init.d/bb-install start
    $BB sh /etc/init.d/procfs start
    $BB sh /etc/init.d/sysfs start
    $BB sh /etc/init.d/udev start
    $BB sh /etc/init.d/usb-modules start
    #$BB sh /etc/init.d/syslogd start
    #$BB sh /etc/init.d/klogd start
    # touch the debug flag file so these scripts don't run again later on
    touch /var/log/debug.env.state
    colorize_nl $S_INFO "=== dumping shell environment to debug.state  ==="
    set > /var/log/debug.env.state
    # since we just mounted /proc, we can also test to see if we want pauses
    # in the init scripts
    # do we want to stop in between scripts?
    file_parse "/proc/cmdline" "pause"
    export PAUSE_PROMPT=$PARSED
    colorize_nl $S_INFO "DEBUG environment variable exists and is not empty;"
    colorize_nl $S_INFO "Prompts will be given at different times to allow"
    colorize_nl $S_INFO "for halting the startup process in order to drop"
    colorize_nl $S_INFO "to a shell."
    colorize_nl $S_INFO "init scripts will log to $DEBUG_LOG."
    want_shell
fi # if [ "x$DEBUG" != "x" ];

# see if a "stop" script was specified
file_parse "/proc/cmdline" "stopscript"
STOPSCRIPT=$PARSED

# this will run all of the start scripts in order
# HINT: if you want to run init here, instead of exec'ing switch_root below,
# then add bbinit to your initscript list in your <project>_base.txt file
for INITSCRIPT in /etc/start/*; do
    if [ "x$DEBUG" = "x" ]; then
        # no debugging, the default
        sh $INITSCRIPT start 2>>$DEBUG_LOG
    else
        # debugging, turn on sh -x
        colorize_nl $S_TIP "- Running 'sh -x $INITSCRIPT start'"
        sh -x $INITSCRIPT start 2>&1 >> $DEBUG_LOG
    fi
    # was a pause asked for?
    pause_prompt
    ACTUAL_INITSCRIPT=$(readlink -n -f $INITSCRIPT)
    if [ "x$ACTUAL_INITSCRIPT" == "x$STOPSCRIPT" ]; then
        exec /etc/init.d/run-program start
    fi
done

# the run-program script needs to be exec'ed to pass PID=1 to init
file_parse "/proc/cmdline" "run" # returns any parsed data as $PARSED
RUN_PROG=$PARSED
if [ "x$RUN_PROG" != "x" ]; then
    colorize_nl $S_TIP "init: all scripts in /etc/start have been run"
    colorize_nl $S_TIP "init: 'run=???' requested on the command line"
    colorize_nl $S_TIP "init: exec()'ing 'run-program' script"
    exec /etc/init.d/run-program start
else
    colorize_nl $S_TIP "init: 'run=' parameter not specified on command line;"
    colorize_nl $S_TIP "init: continuing with the boot process"
fi

# this will run all of the stop scripts in order to prep before exec'ing the
# system's init binary
for INITSCRIPT in /etc/stop/*; do
    sh $INITSCRIPT stop
done

colorize_nl $S_INFO "=== End :PROJECT_NAME: /init script ==="
colorize_nl $S_TIP "- Running switch_root from initramfs ${PWD}"

# one more last chance to pause and view output
pause_prompt # pause=X on /proc/cmdline
want_shell # DEBUG=X on /proc/cmdline

# switch_root will delete all of the files in the current tmpfs filesystem,
# then mount the actual root filesystem where the tmpfs filesystem used to be;
# we have to use exec() here so switch_root inherits the PID of 1
exec switch_root -c /dev/console /mnt/rootvol /sbin/init
# we lost busybox builtins when we unmounted /proc; do this the long way
if [ $? -gt 0 ]; then colorize_nl $S_FAILURE "switch_root failed!"
    # call check_exit_status with a non-zero status code; this will cause the
    # script to exit to a shell; don't prompt the user if they want to
    # continue, once we go past here, we'll get a kernel panic
    check_exit_status 1 "switch_root"
fi

## END INIT SCRIPT!
# once we get past here, the system's /sbin/init binary should have taken
# over, or the kernel has panic'ed

### begin license
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

# vi: set shiftwidth=4 tabstop=4 filetype=sh :
# конец!
