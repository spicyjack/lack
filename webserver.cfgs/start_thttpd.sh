#!/bin/sh
echo "The next PASSWORD prompt will be your SUDO password:"
/usr/bin/sudo /usr/local/sbin/thttpd -C
/usr2/bmanning/cvs/antlinux/builds/naranja/webserver/thttpd.conf -nos
