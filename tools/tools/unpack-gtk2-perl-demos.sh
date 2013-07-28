#!/bin/bash

# script to unpack all of the Gtk2-Perl demos into $TEMP_DIR

TEMP_DIR="/tmp"
if [ -z $TEMP_DIR ]; then
    echo "ERROR: unpack-gtk2-perl-demos.sh called, but TEMP_DIR unset"
    exit 1
fi

GTK2_PERL_DOCS="/usr/share/doc/libgtk2-perl-doc"

if [ ! -d $GTK2_PERL_DOCS ]; then
    echo "${GTK2_PERL_DOCS} directory doesn't exist"
    exit 1
fi

/bin/mkdir $TEMP_DIR/gtk2-perl-examples
/bin/cp -av $GTK2_PERL_DOCS/examples/* $TEMP_DIR/gtk2-perl-examples
/usr/bin/find $TEMP_DIR/gtk2-perl-examples -name "*.gz" -exec gunzip '{}' \;
