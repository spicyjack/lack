#!/bin/bash

# make_initramfs.sh
# Copyright (c)2006, 2009-2013 Brian Manning <brian at xaoc dot org>
# License: GPL v2 (see licence blurb at the bottom of the file)

# script to generate initramfs images based on lists of files you pass to it;
# the script compiles many small lists into one large list, and then feeds
# that to 'gen_init_cpio', which creates the initramfs file

# Get support and more info about this script at:
# https://github.com/spicyjack/lack
# https://github.com/spicyjack/lack/issues
# https://groups.google.com/group/linuxack | linuxack@googlegroups.com

# DO NOT CONTACT THE AUTHOR DIRECTLY; use the mailing list please

# TODO

# minimum config version required to work with this script
INITRAMFS_CFG_REQUIRED_VERSION=2
# the name of this script
SCRIPTNAME=$(basename $0)
# some defaults
QUIET=1 # 0 = no output, 1 = some output, 2 = noisy
# 0 = don't hardlink, 1 hardlink
LACK_HARDLINK_INITRD=0 # don't hardlink the initramfs to the initrd file
# this is the top level directory; all of the paths created below start from
# this directory and then work down the directory tree; this variable can be
# overridden with the --lackdir switch
LACK_BASE="/home/lack/src/lack/lack.git"
# the list of files output and fed to gen_init_cpio
FILELIST="initramfs-filelist.txt"
PROJECT_LIST="project-filelist.txt"
# default working directory
LACK_WORK_DIR="/dev/shm"

# external programs used
CAT=$(which cat)
DATE=$(which date)
RFC_2822_DATE=$(${DATE} --rfc-2822)
DIRNAME=$(which dirname)
GETOPT=$(which getopt)
GZIP=$(which gzip)
MKTEMP=$(which mktemp)
MV=$(which mv)
RM=$(which rm)
SED=$(which sed)
TRUE=$(which true)
TOUCH=$(which touch)

# helper functions

# set the script parameters from initramfs.cfg or a user-specified file
function set_vars {
    local PROJECT_DIR=$1
    # $1 is the name of the build to set up for
    # verify the initramfs.cfg file exists
    if [ ! -e $PROJECT_DIR/initramfs.cfg ]; then
        echo "ERROR: initramfs.cfg file not found;"
        echo "Checked ${PROJECT_DIR}"
        exit 1
    fi

    # verify a project name was used; we need one to know which initramfs
    # package file to go get
    if [ $VARSFILE ]; then
        if [ -e $VARSFILE ]; then
            # source in the environment variables; this could be a potential
            # hazard if the sourced file contains malicious scripting
            source $VARSFILE
        else
            echo "ERROR: --varsfile $VARSFILE does not exist in $PWD"
            exit 1
        fi # if [ -e $VARSFILE ];
    else
        source $PROJECT_DIR/initramfs.cfg
    fi # if [ $VARSFILE ];
    if [ "x$INITRAMFS_CFG_VERSION" != "x" ]; then
        if [ $INITRAMFS_CFG_VERSION -lt $INITRAMFS_CFG_REQUIRED_VERSION ];
        then
            echo "ERROR: initramfs.cfg file is out of date"
            echo -n "ERROR: Required initramfs.cfg version: "
            echo $INITRAMFS_CFG_REQUIRED_VERSION
            echo -n "ERROR: Project initramfs.cfg version: "
            echo $INITRAMFS_CFG_VERSION
            echo "ERROR: Project directory: $PROJECT_DIR"
            exit 1
        fi
    else
        echo "ERROR: INITRAMFS_CFG_VERSION not set in initramfs.cfg"
        echo "ERROR: Project directory: $PROJECT_DIR"
        exit 1
    fi
}

## FUNC: check_exit_status
## ARG:  Returned exit status code of that function
## ARG:  Name of the function/command we're checking the return status of
## DESC: Verifies the function exited with an exit status code (0), and
## DESC: exits the script if any other status code is found.
function check_exit_status {
    local EXIT_STATUS=$1
    local STATUS_MSG=$2

    if [ $EXIT_STATUS -gt 0 ]; then
        if [ "x${STATUS_MSG}" = "x" ]; then
            STATUS_MSG="unknown command"
        fi
        echo "ERROR: '${STATUS_MSG}' returned an exit code of ${EXIT_STATUS}"
        exit 1
    fi # if [ $STATUS_CODE -gt 0 ]
}

# cat the source file, filter it with sed, then append it to the destination
function sedify ()
{
    local SOURCE_FILE=$1
    local DEST_FILE=$2

    $CAT $SOURCE_FILE | $SED \
        "{
        s!:LACK_PROJECT_NAME:!${LACK_PROJECT_NAME}!g;
        s!:PROJECT_DIR:!${PROJECT_DIR}!g;
        s!:LACK_BASE:!${LACK_BASE}!g;
        s!:VERSION:!${KERNEL_VER}!g;
        s!:TEMP_DIR:!${TEMP_DIR}!g;
        s!:LACK_WORK_DIR:!${LACK_WORK_DIR}!g;
        }" >> $DEST_FILE
}

function show_vars()
{
    echo "variables:"
    echo "LACK_BASE=${LACK_BASE}"
    echo "KERNEL_VER=${KERNEL_VER}"
    echo "LACK_PROJECT_NAME=${LACK_PROJECT_NAME}"
    echo "PROJECT_DIR=${PROJECT_DIR}"
    echo "RECPIES_DIR='${RECPIES_DIR}'"
    echo "OUTPUT_FILE=${OUTPUT_FILE}"
}

function show_help () {
cat <<-EOF

  $SCRIPTNAME [options] --lackdir --project

  -or-

  $SCRIPTNAME [options] --recipes --project

  HELP OPTIONS
  -h|--help         Displays script options
  -e|--examples     Displays examples of script usage
  -H|--longhelp     Displays script options, environment vars and examples
  -n|--dry-run      Builds filelists but does not run 'gen_init_cpio'

  SCRIPT REQUIRED ARGUMENTS
  -r|--recipes      Directory holding recipes used to for initramfs filelist
  -p|--project      Directory with project 'initramfs.cfg' and local recipes

  SCRIPT OPTIONAL ARGUMENTS
  -l|--lack-base    Base directory to 'lack.git' repo on the local host
  -f|--varsfile     File to read in to set script environment variables
  -s|--showvars     List variables set in the --project stanza
  -o|--output       Filename to write the initramfs image to
  -q|--quiet        No script output (unless an error occurs)
  --hardlink     Create hardlink from 'initrd' to initramfs file
  -k|--keep         Don't delete the created initramfs filelist/init.sh script
  -w|--work         Directory to use for working files (default: /dev/shm)

  Use '--longhelp' to see more help options, including environment variables.
  Use '--examples' to see examples of script execution.

EOF
}

function show_longhelp () {
cat <<-EOF

    The '--varsfile' option should specify a shell script with specific
    environment variables set; since it's a shell script that's sourced by
    this script, it could be a *POTENTIAL* *SECURITY* *HAZARD*.

    The script needs the following environment variables defined (either
    inside the script itself, or in an external file that gets sourced with
    --varsfile) in order to function correctly:

    LACK_BASE
        The path containing the LACK tools scripts, config files, and
        'initramfs' startup scripts; defaults to
        '/home/lack/src/lack/lack.git'
    RECIPES_DIR
        The path containing the project files and recipe files; set globally
        above, but can be overridden on a per-project basis
    PROJECT_DIR: directory to look in for initramfs filelist, project
        configuration file, local recipes, and support scripts
    KERNEL_VER:
        the kernel version number, used in specifying the kernel module
        directory to add kernel modules from, as well as being part of the
        name of the output initramfs file (initramfs-KERNEL_VER.cpio.gz)
    RECPIES:
        a quoted, whitespace-separated list of packages to include in the
        final initramfs image; each package's recipe is used when building the
        initramfs image.  The list can span multiple lines without using a
        backslash '\\' character, as long as the entire list is enclosed in
        quotes.  The packages should be listed in order that you want them to
        appear in the ramdisk image.
    OUTPUT_FILE:
        file to write the initramfs image to
EOF
}

function show_examples () {
cat <<-EOF

    Normal usage:

    bash ${SCRIPTNAME} --recipes /path/to/recipes \\
        --project /path/to/project

    # Output all of the important environment variables for a profile; you
    # can edit these and then use them in place of a built-in profile;

    bash ${SCRIPTNAME} --project /path/to/project --showvars \\
        > projectvars.txt

    # Now use edit this environment variables file, and then use it to
    # generate an initramfs image:
    bash ${SCRIPTNAME} --varsfile projectvars.txt \\
        --nohardlink --keepfiles

    Use '--longhelp' to see all help options, including environment variables
EOF
}

### BEGIN SCRIPT ###
# run getopt
TEMP=$(${GETOPT} -o hHenp:d:f:sb:o:qlkw: \
--long help,longhelp,examples,dry-run,lack-base:,project:,projectdir:,dir: \
--long varsfile:,showvars,recipes:,recipes-dir:,output:,quiet,hardlink \
--long keeplist,keepfiles,keep,workdir:,work: \
-n "${SCRIPTNAME}" -- "$@")
check_exit_status $? $GETOPT

# Note the quotes around `$TEMP': they are essential!
# read in the $TEMP variable
eval set -- "$TEMP"

# read in command line options and set appropriate environment variables
# if you change the below switches to something else, make sure you change the
# getopts call(s) above
while $TRUE; do
    case "$1" in
        # show the script options
        -h|--help)
            # show short help
            show_help
            exit 0;;
        # show *ALL* script options
        -H|--longhelp)
            show_help # short options
            show_longhelp # environment variables
            show_examples # examples of script usage
            exit 0;;
        # show examples
        -e|--examples)
            show_examples
            exit 0;;
        # don't create the initramfs image, just generate filelists
        -n|--dry-run)
            DRY_RUN=1
            shift
            ;;
        # read in environment variables from this file
        -f|--varsfile)
            VARSFILE=$2
            shift 2
            ;;
        # list variables after reading them in
        -s|--showvars)
            SHOWVARS=1
            shift
            ;;
        # LACK_BASE, path to lack.git directory
        -l|--lack-base)
            LACK_BASE=$2
            shift 2
            ;;
        # path to recipes.git
        -r|--recipes|--recipes-dir)
            RECIPES_DIR=$2
            shift 2
            ;;
        # project directory, with initramfs.cfg and local recipes
        -p|--project|--projectdir)
            PROJECT_DIR=$2
            shift 2
            ;;
        # filename to write the initramfs file to; defaults to
        # /boot/initramfs-$KERNEL_VER.cpio.gz if not specified
        -o|--output)
            OUTPUT_FILE=$2
            export OUTPUT_FILE
            shift 2
            ;;
        # don't output anything (unless there's an error)
        -q|--quiet)
            QUIET=0
            shift
            ;;
        # hardlink the new initramfs file to initrd for the
        # update-grub script to work properly
        --hardlink)
            LACK_HARDLINK_INITRD=1
            shift
            ;;
        # keep the initramfs file list
        -k|--keepfiles|--keeplist|--keep)
            KEEP_TEMP_DIR=1
            shift
            ;;
        # working directory; defaults to /tmp
        -w|--workdir|--work)
            LACK_WORK_DIR=$2
            export LACK_WORK_DIR
            shift 2
            ;;
        --) shift
            break
            ;;
        *) # we shouldn't get here; die gracefully
            echo "ERROR: unknown option '$1'" >&2
            echo "ERROR: use --help to see all script options" >&2
            exit 1
            ;;
    esac
done

# see if we just list variables and then exit
if [ $SHOWVARS ]; then
    show_vars
    exit 0
fi

# try and figure out where this script is located
if [ "x$LACK_BASE" = "x" ]; then
    LACK_DIR=$(${DIRNAME} $0)
fi

# make sure we can reach the LACK_BASE directory, it's substituted in recipies
echo -n "- Checking for LACK base directory; "
if [ ! -d ${LACK_BASE}/initscripts ]; then
    echo "missing!"
    echo "ERROR: can't determine \$LACK_BASE directory"
    exit 1
else
    #LACK_BASE="${SCRIPT_DIR}/.."
    echo "found! (LACK_BASE=${LACK_BASE})"
fi

# see if the project directory exists
echo -n "- Checking for project directory; "
if [ "x$PROJECT_DIR" = "x" ]; then
    echo "--project switch not used/empty"
    echo "ERROR: --project not specified"
    exit 1
fi
if [ ! -d $PROJECT_DIR ]; then
    echo "directory is missing!"
    echo "ERROR: --project specified, but directory does not exist"
    echo "ERROR: checked directory: ${PROJECT_DIR}"
    exit 1
fi
echo "found directory!"
# remove trailing slash, if any
TEMP_PROJECT_DIR=$(echo ${PROJECT_DIR} | sed 's!/$!!')
PROJECT_DIR=${TEMP_PROJECT_DIR}
echo "  -> Project directory: ${PROJECT_DIR}"

# see if the recipe directory exists
echo -n "- Checking for recipes directory; "
if [ "x$RECIPES_DIR" = "x" ]; then
    echo "--recipes switch not used/empty"
    echo "ERROR: --project not specified"
    exit 1
fi
if [ ! -d $RECIPES_DIR ]; then
    echo "directory is missing!"
    echo "ERROR: --recipes specified, but directory does not exist"
    echo "ERROR: checked directory: ${RECIPES_DIR}"
    exit 1
fi
echo "found directory!"
echo "  -> Recipes directory: ${RECIPES_DIR}"

# no sense in running if gen_init_cpio doesn't exist
if [ ! $DRY_RUN ]; then
    echo -n "- Checking for gen_init_cpio file; "
    # set up an error flag
    GENINITCPIO_ERROR=0
    if [ ! -e "/usr/src/linux/usr/gen_init_cpio" ]; then
        echo
        echo "Huh. gen_init_cpio doesn't exist"
        GENINITCPIO_ERROR=1
    elif [ ! -x "/usr/src/linux/usr/gen_init_cpio" ]; then
        echo
        echo "Huh. gen_init_cpio is not executable (mode 755)"
        GENINITCPIO_ERROR=1
    fi

    if [ $GENINITCPIO_ERROR -eq 1 ]; then
        echo
        echo "  (Please check gen_init_cpio file in /usr/src/linux/usr)" >&2
        echo "Can't build initramfs image... Exiting." >&2
        exit 1
    fi
    echo "found!"
fi

# create a temp directory
TEMP_DIR=$(${MKTEMP} -d ${LACK_WORK_DIR}/lack_initramfs.XXXXX)
echo "- Created temporary directory '${TEMP_DIR}'"

### EXPORTS
# export things that were set up either in getopts or hardcoded into this
# script
export LACK_BASE PROJECT_DIR TEMP_DIR FILELIST PROJECT_LIST LACK_WORK_DIR

# build the header for the filelist
echo "# Begin $FILELIST;" >> $TEMP_DIR/$FILELIST
echo "# Filelist generated on $RFC_2822_DATE" >> $TEMP_DIR/$FILELIST
echo "# This file can be changed by editing the '*.txt' file for a package," \
    >> $TEMP_DIR/$FILELIST
echo "# or editing the script function in common_init_scripts.sh" \
    >> $TEMP_DIR/$FILELIST
echo "# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=" \
    >> $TEMP_DIR/$FILELIST

# SOURCE! call set_vars to source the project's initramfs.cfg file
# this generates things like the busybox file entry, hostname file, /init
# script entries in the output filelist file
set_vars $PROJECT_DIR

# verify the output initramfs file can be written to
# $OUTPUT_FILE was either set in a profile or using --output
if [ "x$OUTPUT_FILE" != "x" ]; then
    $TOUCH $OUTPUT_FILE
    check_exit_status $? $TOUCH
else
    echo "=-=-=-=-=-=-=-=-=-=-=-=-=-="
    echo "ERROR: output file not set"
    echo "=-=-=-=-=-=-=-=-=-=-=-=-=-="
    echo
    show_vars
    exit 1
fi

# check that RECIPES is not zero length
if [ -z "${RECIPES}" ]; then
    echo "ERROR: no recpies defined in RECIPES variable!"
    exit 1
fi

# copy all the desired recipie files first
for RECIPE in $(echo ${RECIPES});
do
    # verify the recipe file exists
    # check in $PROJECT_DIR first; note this works even if
    # $PROJECT_DIR is not defined; if it's not defined, it will fail, and
    # the check in $LACK_BASE will then be done
    if [ -r $PROJECT_DIR/recipes/$RECIPE.txt ]; then
        # project-specific recpie exists
        FOUND_RECIPE_DIR="$PROJECT_DIR/recipes"
    else
        if [ -r ${RECIPES_DIR}/$RECIPE.txt ]; then
            # recipe exists in LACK recipes directory
            FOUND_RECIPE_DIR="${RECIPES_DIR}"
        else
            # nope; delete the output file and exit
            echo "ERROR: ${RECIPE}.txt file does not exist in"
            echo "${RECIPES_DIR} (common) directory or"
            echo "${PROJECT_DIR}/recipes (project-specific) directory"
            cd $RECIPES_DIR
            RECIPES_GIT_BRANCH=$(git branch)
            cd $OLDPWD
            echo "Maybe you have the wrong recipes git branch checked out?"
            echo "Common recipes current git branch: $RECIPES_GIT_BRANCH"
            echo "- Deleting output file ${OUTPUT_FILE}"
            rm $OUTPUT_FILE
            if [ -z $KEEP_TEMP_DIR ]; then
                echo "- Deleting temporary directory ${TEMP_DIR}"
                rm -rf $TEMP_DIR
            fi # if [ -z $KEEP_TEMP_DIR ]
            exit 1
        fi
    fi
    # then do some searching and replacing; write the output file to
    # FILELIST
    sedify $FOUND_RECIPE_DIR/$RECIPE.txt $TEMP_DIR/$FILELIST
done

# verify the initramfs recipe file exists
echo -n "- Checking for $PROJECT_LIST file in $TEMP_DIR; "
if [ ! -r $TEMP_DIR/$PROJECT_LIST ];
then
    # nope; delete the output file and exit
    echo
    echo "ERROR: ${PROJECT_LIST} file does not exist in ${TEMP_DIR}"
    #rm -rf $TEMP_DIR
    exit 1
fi
echo "found!"
echo "  -> ${TEMP_DIR}/${PROJECT_LIST}"

# then grab the project specific file, which should have the kernel modules
# and do some searching and replacing
sedify $TEMP_DIR/$PROJECT_LIST $TEMP_DIR/$FILELIST

# include the list of files that we just generated as part of the initramfs
# image for future reference and debugging/troubleshooting
echo -n "file /boot/${FILELIST}.gz " >> $TEMP_DIR/$FILELIST
echo "${TEMP_DIR}/${FILELIST}.gz 0644 0 0" >> $TEMP_DIR/$FILELIST

# compress the file list
$GZIP -c -9 $TEMP_DIR/$FILELIST > ${TEMP_DIR}/${FILELIST}.gz

# generate the initramfs image
if [ $QUIET -gt 0 ]; then
    EXTRA_CMDS="time "
fi

if [ $DRY_RUN ]; then
    # remove the empty initramfs file that was created earlier with 'touch'
    # leave both filelists (compressed and uncompressed)
    echo "- Deleting $OUTPUT_FILE,"
    echo "  as --dry-run should not create this file"
    rm $OUTPUT_FILE
    # FIXME what is this perl script for?
    PERL_SCRIPT=$(cat <<'EOPS'
        my $counter = 0;
        while ( <> ) {
            $counter++;
            # skip comment lines
            next if ( $_ =~ /^#/ );
            next if ( $_ =~ /^$/ );
            chomp($_);
            # split the line up into fields
            @line = split(q( ), $_);
            if ( $line[0] eq q(dir) ) {
                # $line[1] should be the name of the directory
                print qq(WARN: missing directory : ) . $line[1]
                    . qq(, line $counter\n)
                    unless ( -d $line[1] );
            } elsif ( $line[0] eq q(file) ) {
                print qq(WARN: missing file: ) . $line[2]
                    . qq(, line $counter\n)
                    unless ( -e $line[2] );
            } elsif ( $line[0] eq q(slink) ) {
                print qq(WARN: missing symlink source: )
                    . $line[2] . qq(, line $counter\n)
                    unless ( -e $line[2] );
            } else {
                print qq(WARN: unknown filetype: ) . $line[0]
                    . qq(, line: $counter\n);
            }
        }
EOPS)
    echo "Running perl script on $TEMP_DIR/$FILELIST"
    cat $TEMP_DIR/$FILELIST | perl -e "$PERL_SCRIPT"

    # barks if the file is missing
    echo "- initramfs output directory is: ${TEMP_DIR}"
    echo "  Please delete it manually"
else
    # run the gen_init_cpio command, output to $OUTPUT_FILE
    eval $EXTRA_CMDS /usr/src/linux/usr/gen_init_cpio $TEMP_DIR/$FILELIST \
        | $GZIP -c -9 > $OUTPUT_FILE
    if [ -z $KEEP_TEMP_DIR ]; then
        rm -rf $TEMP_DIR
    else
        echo "initramfs temporary directory is: ${TEMP_DIR}"
        echo "Please delete it manually"
    fi
    if [ $LACK_HARDLINK_INITRD -gt 0 ]; then
        echo "Hardlinking $OUTPUT_FILE to initrd file"
        if [ -r /boot/initrd-$KERNEL_VER.gz ]; then
            rm /boot/initrd-$KERNEL_VER.gz
        fi
        ln $OUTPUT_FILE /boot/initrd-$KERNEL_VER.gz
    fi
fi

# if we got here, everything worked
exit 0

# *begin licence blurb*
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, version 2 of the License.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place, Suite 330, Boston, MA  02111-1307 USA

# vi: set sw=4 ts=4:
# end of line
