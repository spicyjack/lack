#!/bin/sh

# script to start X as user 'lack', with some extra housekeeping stuff

HOME_DIR="/home/lack"
STARTX="/usr/bin/startx"

# see if we even want to run X
# BOOTCHEAT nox - Don't start XWindows
if [ $(/bin/grep -c nox /proc/cmdline) -eq 0 ]; then
    # yep, run X; now do we want a normal or debug session?
    # check for either debugging or explicit xterm call
    # BOOTCHEAT wm=[DEBUG|xterm] - Start X with an xterm window
    if [ $(/bin/egrep -c "wm=[DEBUG|xterm]" /proc/cmdline) -gt 0 ]; then
        # debug session
        cat $HOME_DIR/xsession | sed "s/^#\(exec xterm.*\)$/\1/" \
            > $HOME_DIR/.xsession
    # BOOTCHEAT wm=flwm - Start X with flwm as the window manager
    elif [ $(/bin/egrep -c "wm=flwm" /proc/cmdline) -gt 0 ]; then
        # run flwm
        cat $HOME_DIR/xsession | sed "s/^#\(exec flwm.*\)$/\1/" \
            > $HOME_DIR/.xsession
    # BOOTCHEAT wm=windowlab - Start X with windowlab as the window manager
    elif [ $(/bin/egrep -c "wm=windowlab" /proc/cmdline) -gt 0 ]; then
        # run windowlab
        cat $HOME_DIR/xsession | sed "s/^#\(exec windowlab.*\)$/\1/" \
            > $HOME_DIR/.xsession
    else
        # normal session with the Gtk2-Perl script greeter
        cat $HOME_DIR/xsession | sed "s/^#\(exec perl.*\)$/\1/" \
            > $HOME_DIR/.xsession
    fi # if [ $(/bin/egrep -c "wm=[DEBUG|xterm]" /proc/cmdline) -gt 0 ]

    # set the xsession file to be owned by lack.lack
    chmod 755 $HOME_DIR/.xsession
    chown lack.lack $HOME_DIR/.xsession

    # see if the user wants a different screen resolution
    # BOOTCHEAT [rez|res|resolution|X|x]=[1024x768|800x600|xdefault]
    # BOOTCHEAT - X resolution
    if [ $(/bin/egrep -c "rez|res|resolution|X|x" /proc/cmdline) -eq 0 ]; then
        if [ $(/bin/grep -c "=xdefault" /proc/cmdline) -gt 0 ]; then
            # create an empty xorg.conf file; this will let X
            # use whatever resolution that it feels like using
            touch /etc/X11/xorg.conf
        elif [ $(/bin/grep -c "=1024x768" /proc/cmdline) -gt 0 ]; then
            cat /etc/X11/xorg.conf.orig | sed 's/#\(Modes "1024x768"\)/\1/' \
                > /etc/X11/xorg.conf
        elif [ $(/bin/grep -c "=800x600" /proc/cmdline) -gt 0 ]; then
            cat /etc/X11/xorg.conf.orig | sed 's/#\(Modes "800x600"\)/\1/' \
                > /etc/X11/xorg.conf
        else
            cat /etc/X11/xorg.conf.orig | sed 's/#\(Modes "640x480"\)/\1/' \
                > /etc/X11/xorg.conf
        fi # if [ $(/bin/grep -c "1024x768" /proc/cmdline) -gt 0 ]
    fi # if [ $(/bin/egrep -c "rez|res|resolution|X|x" /proc/cmdline)

    # start X as the lack user
    /bin/su -s /bin/sh -c "$STARTX" lack
else
    # nope, don't run x; just sleep for a day, as /sbin/init will keep
    # restarting this script if it exits
    sleep 86400
fi

exit 0
