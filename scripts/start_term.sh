#!/bin/sh

# script to start a terminal window

    # write our PID out to a file
    echo $$ > /tmp/start_term.pid

    # launch mrxvt if it's available
    # XXX if you want to disable mrxvt, don't include it's package
    if [ -x /usr/bin/mrxvt ]; then
        TERM="/usr/bin/mrxvt"
    else
        TERM="/usr/bin/xterm"
    fi
    # launch the terminal process
    $TERM +sb -geometry +0-0 &
    # grab the PID of the program that was just launched
    TERM_PID=$!
    # write it to a file
    echo $TERM_PID > /tmp/terminal.pid

    # loop waiting for the terminal to exit
    while /bin/true;
    do
        sleep 1
        # the whole TERM_PID directory goes away when the process exits
        if [ ! -e /proc/$TERM_PID/cmdline ]; then
            break
        fi
    done

    # remove the terminal PID file
    rm /tmp/terminal.pid
    # remove our PID file
    rm /tmp/start_term.pid
    exit 0
