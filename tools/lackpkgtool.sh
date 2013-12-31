#!/bin/sh

# lackpkgtool.sh
# Copyright (c)2010 by Brian Manning <brian at portaboom dot com>
# License: GPL v2 (see licence blurb at the bottom of the file)
# Get support and more info about this script at:
# http://code.google.com/p/lack/
# http://groups.google.com/group/linuxack|linuxack@googlegroups.com

# DO NOT CONTACT THE AUTHOR DIRECTLY; use the mailing list please

# script that generates either lists of files, or squashfs packages, based on
# input from the system's packaging tools or a list of files

# SCRIPT DESIGN
# Inputs:
# - one or more debian packages or gen_init_cpio filelists; multiple
#   packages or filelists need to be passed in after double-dashes '--';
#   use $* to pick them up
#   - multiple packages can be written to individual files or a single file,
#   select via command line switch (--output/--multiple?)
#   - http://www.shelldorado.com/goodcoding/cmdargs.html
# - one or more filelists for converting into squashfs and/or cpio files
#
# Outputs:
# - one or more filelists
# - one or more squashfs packages
#
# Script arguments:
# - WORKDIR - working directory
#
# Actions:
# - Write a manifest file of some kind
#   - package version
#   - package date
#   - packaged by
#   - checksums?

# external programs used
CAT=$(which cat)
CP=$(which cp)
DPKG=$(which dpkg)
DPKG_QUERY=$(which dpkg-query)
DATE=$(which date)
FIND=$(which find)
GETOPT=$(which getopt)
GZIP=$(which gzip)
MKTEMP=$(which mktemp)
MKDIR=$(which mkdir)
MV=$(which mv)
READLINK=$(which readlink)
RM=$(which rm)
SED=$(which sed)
SCRIPTNAME=$(basename $0)
STAT=$(which stat)
TOUCH=$(which touch)
TR=$(which tr)
TRUE=$(which true)
UNAME=$(which uname)

# handy shortcuts using the above commands
EPOCH_DATE_CMD="${DATE} +%s.%N"
SCRIPT_START=$(${EPOCH_DATE_CMD})


### LOCAL VARIABLES ###
# don't be verbose by default
VERBOSE=0
# pattern of strings to exclude
EXCLUDES="share/doc|/man|/info|bug"
EXCLUDES="${EXCLUDES}|^/\.$|^/boot$|^/lib/modules$|\.pod$|\.h$"
# we need all the extra directories now when making squashfs packages
#EXCLUDES="${EXCLUDES}|^/\.$|^/boot$|^/usr$|^/usr/share$|^/lib$|^/lib/modules$"
# make all files owned by root by default
ALL_ROOT=1
# set the user id based on what's in the environment
FUID=$EUID
# 100 is 'users'
FGID=100
# don't append by default
APPEND=0
# don't overwrite by default
OVERWRITE=0
# don't sort output filelists by default
SORT_FILELIST=0
# don't sort the list of packages provided as input
SORT_INPUT=0
# filelist header has already been output?
FILELIST_HEADER_FLAG=0

### FUNCTIONS ###

## FUNC: say
## ARG: the message to be written on STDOUT or to $LOGFILE
## ENV: VERBOSE, the verbosity level of the script
## ENV: LOGFILE; if set, writes to that logfile
## DESC: Check if $VERBOSE is set, and if so, output the message passed in
function say {
    local MESSAGE=$1
    if [ $VERBOSE -gt 0 ]; then
        if [ "x${LOGFILE}" != "x" ]; then
            echo $MESSAGE >> $LOGFILE
        else
            echo $MESSAGE
        fi # if [ "x${LOGFILE}" != "x" ]
    fi
} # function say

## FUNC: warn
## ARG: the message to be written to STDERR
## DESC: Write a message to STDERR
function warn {
    local MESSAGE=$1
    echo $MESSAGE >&2
} # function warn

## FUNC: check_squashfile_exists
## ARG:  SQUASH_ARG, the squashfs file to check for
## DESC: Check to see if a squashfile exists; handle an existing squashfile
## DESC: depending on whether '--append' or '--overwrite' was set
function check_squashfile_exists {
    local SQUASH_ARG=$1
    warn "- Checking for existing squashfs file: ${SQUASH_ARG}.sfs"
    if [ -e "${SQUASH_ARG}.sfs" ]; then
        if [ $OVERWRITE -eq 1 ]; then
            warn "- Deleting existing squashfs file: ${SQUASH_ARG}.sfs"
            rm $SQUASH_ARG.sfs
            return 0
        elif [ $APPEND -eq 1 ]; then
            warn "- Appending to existing squashfs file: ${SQUASH_ARG}.sfs"
            return 0
        fi
        echo "ERROR: existing squashfs file found, and --append/--overwrite"
        echo "ERROR: options not specified"
        echo "ERROR: squashfs file: ${SQUASH_ARG}.sfs"
        exit 1
    fi # if [ "x${LOGFILE}" != "x" ]
} # run_mksquashfs

## FUNC: run_mksquashfs
## ARG:  SQUASH_ARG, the directory to compress
## ENV:  FUID - user ID for files/directories in the output squashfs file
## ENV:  GUID - group ID for files/directories in the output squashfs file
## ENV:  ALL_ROOT - all files/directories owned by root in output squashfs file
## DESC: Runs the 'mksquashfs' command to build a squashfs package
function run_mksquashfs {
    local SQUASH_ARG=$1
    warn "- Creating squashfs file: ${SQUASH_ARG}.sfs"
    MKSQUASHFS_CMD="mksquashfs ${SQUASH_ARG}"
    MKSQUASHFS_CMD="${MKSQUASHFS_CMD} ${SQUASH_ARG}.sfs"
    if [ $ALL_ROOT -eq 0 ]; then
        MKSQUASHFS_CMD="${MKSQUASHFS_CMD} -force-uid $FUID -force-gid $FGID"
    else
        MKSQUASHFS_CMD="${MKSQUASHFS_CMD} -all-root"
    fi # if [ $ALL_ROOT -eq 0 ];
    say "- Running mksquashfs command:"
    say "- ${MKSQUASHFS_CMD}"
    if [ "x${LOGFILE}" != "x" ]; then
        eval ${MKSQUASHFS_CMD} >> $LOGFILE
    else
        eval ${MKSQUASHFS_CMD}
    fi # if [ "x${LOGFILE}" != "x" ]
} # run_mksquashfs

## FUNC: check_exit_status
## ARG: the command that was run, quoted if it contains spaces
## ARG: the exit status from the command
## DESC: check the status of the last run command; exit if the exit status
## DESC: is anything but 0
function check_exit_status {
    local STATUS=$1
    local COMMAND=$2

    if [ $STATUS -gt 0 ]; then
        warn "Command '${COMMAND}' failed with status code: ${STATUS}"
        exit 1
    fi
} # check_exit_status

## FUNC: show_excludes
## DESC: Show the contents of the EXCLUDES environment variable (set above)
## DESC: Don't use 'say', we always want to print this
function show_excludes {
    echo "EXCLUDES is currently set to:"
    echo "-> '${EXCLUDES}'"
} # check_exit_status

## FUNC: check_excludes
## ARG: LINE, the current line from the filelist or package list
## ENV: SKIP_EXCLUDES - if this is set, don't use the contents of $EXCLUDES
## ENV: EXCLUDES - a regular expression that's fed to the 'grep' command
## ERR: 0 - the file is to be *INCLUDED* in the output filelist/package
## ERR: 1 - the file is to be *EXCLUDED* in the output filelist/package
function check_excludes {
    local LINE=$1
    # check to see if we are skipping excludes
    if [ "x${SKIP_EXCLUDES}" == x ]; then
        # run through the exclusions list
        #say "- Checking excludes: ${LINE}"
        if [ $(echo $LINE | grep -cE "${EXCLUDES}") -gt 0 ]; then
            return 1
        fi
    fi # if [ "x${SKIP_EXCLUDES}" = x ]
    # skip missing files and/or directories
    if [ ! -e $LINE ]; then
        return 1
    fi
    return 0
} # function check_excludes

## FUNC: dump_filelist_header
## ARG: none yet, but add one for the name of the package :(
## DESC: output the header of a filelist
function dump_filelist_header {
    local PKG_NAME=$1
    local PKG_VERSION=$2
# we know the name of the package.... generate a nicer header that includes
# the current date and package name
cat <<EOHD
# package name/version: ${PKG_NAME} / ${PKG_VERSION}
# description: example package with comments
# depends: _base otherpackage1 otherpackage2
# helpcommand: /usr/bin/somebin --help
# versioncommand: /usr/bin/somebin --version
# examplecommand: /usr/bin/somebin -x -y -z 10
#
# dir <name> <mode> <uid> <gid>
# file <name> <source> <mode> <uid> <gid>
# slink <new name> <original file> <mode> <uid> <gid>
#
EOHD
} # dump_filelist_header

## FUNC: show_examples
## DESC: Show some usage examples
function show_examples {
# note some of the lines below have extra whitespace at the end, this is to
# make the lines format correctly when output to a terminal
cat <<EOU
    EXAMPLES OF SCRIPT USAGE:

    ### CREATING FILELISTS
    # create a filelist of the Debian package 'perl'
    ${SCRIPTNAME} --package --listout -- linux-image > linux-image.txt

    # append to an existing package (no gen_init_cpio file header)
    ${SCRIPTNAME} --append --package --listout \\
        -- loop-aes-modules ndiswrapper-modules >> linux-image.txt

    # create a filelist from a directory of files
    ${SCRIPTNAME} --directory --listout /tmp/somedirectory > somepackage.txt

    # create a filelist, and mangle some of the filenames in the filelist
    ${SCRIPTNAME} --directory --listout --regex 's!/some/path!/other/path!g' \\
        -- /tmp/somedirectory > somepackage.txt


    ### CREATING SQUASHFS ARCHIVES
    # create individual output squashfs files from installed Debian packages
    ${SCRIPTNAME} --package --squashfs --workdir /dev/shm -- perl perl-base

    # create a single output squashfs file from an installed Debian package,
    # output to --workdir
    ${SCRIPTNAME} --package --squashfs --workdir /dev/shm \\
        --output perl-combined.sfs -- perl perl-base

    # create a single output squashfs file from one or more filellists
    ${SCRIPTNAME} --filelist --squashfs --workdir /dev/shm \\
        --basepath /path/to/recipesdir --output debug-tools.2010.362.1 \\
        -- debug-tools lspci.lenny

    ### MISC EXAMPLES
    # use a different EXCLUDES regex, display it on STDOUT, then exit
    ${SCRIPTNAME} --excludes "this|that|somethingelse" --show-excludes

EOU
} # function show_examples

# verify we're not running under dash
if [ -z $BASH_VERSION ]; then
#if [ $(readlink /bin/sh | grep -c dash) -gt 0 ]; then
    # execute this script under bash instead
    warn "WARNING: this script doesn't run under dash..."
    warn "WARNING: execute this script with /bin/bash"
    exit 1
fi # if [ $(readlink /bin/sh | grep -c dash) -gt 0 ]

### SCRIPT SETUP ###
# and this is the GNU part
TEMP=$(/usr/bin/getopt -o hvepdfb:sqtco:w:xal:u:g:r: \
    --long help,verbose,examples,\
    --long package,directory,filelist,basepath: \
    --long sort-output,sort-input,squashfs,listout,cpio,output:,workdir: \
    --long overwrite,append,show-excludes,excludes:,skip-excludes \
    --long log:,logfile:,uid:,gid:,regex: \
    -n "${SCRIPTNAME}" -- "$@")

# if getopts exited with an error code, then exit the script
#if [ $? -ne 0 -o $# -eq 0 ] ; then
if [ $? != 0 ] ; then
    warn "Run '${SCRIPTNAME} --help' to see script options" >&2
    exit 1
fi

# Note the quotes around `$TEMP': they are essential!
# read in the $TEMP variable
eval set -- "$TEMP"

# read in command line options and set appropriate environment variables
# if you change the below switches to something else, make sure you change the
# getopts call(s) above
while true ; do
    case "$1" in
        -h|--help) # show the script options
        cat <<-EOF

    ${SCRIPTNAME} [options]

    HELP OPTIONS
    -h|--help           Displays this help message
    -v|--verbose        Nice pretty output messages
    -e|--examples       Show examples of script usage and exit

    INPUT OPTIONS
    -p|--package        Package names to query for a list of files
    -d|--directory      Directories containing files to package
    -f|--filelist       Filelists used with 'gen_init_cpio' program
    -b|--basepath       Base path(s) to search for filelist files
                        Multiple directories are separated with a colon ':'

    OUTPUT OPTIONS
    -s|--sort-output    Sort the output of filelists
    --sort-input        Sort the input package list
    -q|--squashfs       Output squashfs package(s)
    -t|--listout        Output filelist(s) suitable for gen_init_cpio
    -c|--cpio           Create a CPIO file (via gen_init_cpio)
    -o|--output         Output only a single file with this name + .sfs
    -w|--workdir        Working directory to use for copying/storing files
    -x|--overwrite      Overwrite any existing output files
    -a|--append         Append to an existing file, don't create a new file

    EXCLUDING FILE OPTIONS
    --show-excludeѕ     Show exclude argument to 'grep' and exit
    --excludes          Use this exclude expression instead of the builtin
    --skip-excludes     Don't use the excludes list when creating
                        filelists/squashfs packages

    MISC. OPTIONS
    -l|--logfile        Output logs to this file instead of STDOUT
    -u|--uid            Use this UID for all files output
    -g|--gid            Use this GID for all files output
    -r|--regex          Apply the regular expression to destination file

    Use --examples to see examples of script usage.

    All files are owned by 'root.root' unless --uid/--gid are used.
EOF
        exit 0;;
        -v|--verbose) # output pretty messages
            VERBOSE=1
            shift
            ;;
        -e|--examples) # show usage examples
            show_examples
            exit 0
            ;;
        --show-excludes) # show the excludes used with grep 
            show_excludes
            exit 0
            ;;

        ### Input options ###
        -d|--directory) # use directories of files as input
            INPUT_OPT="directory"
            shift 1
            ;;
        -p|--package) # use package names for input
            INPUT_OPT="package"
            shift 1
            ;;
        -f|--filelist) # use lists of packages for input
            INPUT_OPT="filelist"
            shift 1
            ;;
        -b|--base|--basepath|--basepaths)
            # base directory to look for filelists (recipes)
            BASE_PATHS=$(echo ${2} | tr ':' ' ')
            shift 2
            ;;

        ### OUTPUT OPTIONS ###
        -s|--sort|--sort-output) # sort output filelists
            SORT_FILELIST=1
            shift 1
            ;;
        --sort-input) # sort output filelists
            SORT_INPUT=1
            shift 1
            ;;
        -q|--squashfs) # make squashfs file(s)
            OUTPUT_OPT="squashfs"
            shift 1
            ;;
        -t|--listout) # make filelist(s)
            OUTPUT_OPT="filelist"
            shift 1
            ;;
        -c|--cpio) # make cpio file(s)
            OUTPUT_OPT="cpio"
            shift 1
            ;;
        -o|--output)
            # make one large file instead of multiple files for each
            # filelist/directory/package
            SINGLE_OUTFILE=$2
            shift 2
            if [ $(echo ${SINGLE_OUTFILE} | grep -c "^/") -gt 0 ]; then
                warn "WARN: --output argument starts with a slash '/'"
                warn "WARN: this is probably not what you want, as this path"
                warn "WARN: will be created under WORKDIR -> ${WORKDIR}"
            fi
            ;;
        -w|--workdir) # working directory
            WORKDIR=$2
            shift 2
            ;;
        -x|--overwrite) # overwrite any existing files
            OVERWRITE=1
            shift
            ;;
        -a|--append) # append to existing files
            APPEND=1
            shift
            ;;

        ### MISC OPTIONS ###
        -l|--log|--logfile) # logfile for things that could generate errors
            LOGFILE=$2
            # initialize
            : > $LOGFILE
            shift 2
            ;;
        -u|--uid) # user ID to use when creating squashfs files/filelists
            FUID=$2
            ALL_ROOT=0
            shift 2
            ;;
        -g|--gid) # group ID to use when creating squashfs files/filelists
            FGID=$2
            ALL_ROOT=0
            shift 2
            ;;
        -s|--skip|--skip-excludes) # skip excluding of files using grep
            SKIP_EXCLUDES=1
            shift
            ;;
        --excludes) # use this exclude expression instead of the default
            EXCLUDES=$2
            shift 2
            ;;
        -r|--regex) # use a regex to substitute strings in filelists
            REGEX=$2
            shift 2
            ;;
        --) shift
            # everything after here should be a filelist file,
            # directory names or package names
            break
            ;;
        *) # something we didn't expect; warn the user
            warn "ERROR: unknown option '$1'"
            warn "ERROR: use --help to see all script options"
            exit 1
    esac
done

if [ $(echo $@ | wc -w ) -eq 0 ]; then
    warn "ERROR: no packages/directories/filelists to process"
    warn "ERROR: use the --help switch to see all script options"
    exit 1
fi # if [ -z $@ ]; then

if [ $OVERWRITE -eq 1 ] && [ $APPEND -eq 1 ]; then
    warn "ERROR: --append and --overwrite are mutually exclusive options!"
    warn "ERROR: use the --help switch to see all script options"
    exit 1
fi # if [ -z $@ ]; then

### SCRIPT MAIN LOOP ###
# reset FUID/FGID if ALL_ROOT is set (default = set)
if [ $ALL_ROOT -eq 1 ]; then
    FUID=0
    FGID=0
fi # if [ $ALL_ROOT -eq 1 ]

# loop across the arguments listed after the double-dashes '--'
if [ $SORT_INPUT -eq 1 ]; then
    PACKAGE_LIST=$(echo $@ | sort)
else
    PACKAGE_LIST=$(echo $@)
fi

for CURR_PKG in $(echo ${PACKAGE_LIST});
do
    # depending on what the input type will be is what actions we will take
    case "$INPUT_OPT" in
        package)
            say "=== Processing package '${CURR_PKG}' ==="
            warn "- Querying package system for package '${CURR_PKG}'"
            TEMP_PKGLIST=$(mktemp --tmpdir ${WORKDIR} filelist.XXXXX)
            if [ "x${LOGFILE}" != "x" ]; then
                ${DPKG} -L ${CURR_PKG} > ${TEMP_PKGLIST} 2>>$LOGFILE
                check_exit_status $? "dpkg -L ${CURR_PKG}"
            else
                ${DPKG} -L ${CURR_PKG} > ${TEMP_PKGLIST}
                check_exit_status $? "dpkg -L ${CURR_PKG}"
            fi
            if [ $SORT_FILELIST -gt 0 ]; then
                PKG_CONTENTS=$(cat ${TEMP_PKGLIST} | sort | sed 's/ /\\ /g')
            else
                PKG_CONTENTS=$(cat ${TEMP_PKGLIST} | sed 's/ /\\ /g')
            fi
            # remove the package list tempfile if we're done with it
            rm $TEMP_PKGLIST
            TEMP_PKGMETA=$(mktemp --tmpdir ${WORKDIR} filelist.XXXXX)
            ${DPKG_QUERY} -s ${CURR_PKG} > ${TEMP_PKGMETA}
            check_exit_status $? "dpkg-query -s ${CURR_PKG}"
            PKG_VERSION=$(cat ${TEMP_PKGMETA} \
                | grep '^Version:' | awk '{print $2}')
            rm $TEMP_PKGMETA
            ;;
        directory)
            PKG_CONTENTS=$(${FIND} ${CURR_PKG} -type f)
            check_exit_status $? "find ${CURR_PKG} -type f"
            ;;
        filelist)
            # unset FILELIST_FILE; if the filelist is missing, we want to be
            # notified about it, and having the FILELIST_FILE variable set
            # due to a previous loop will bypass checks for it being empty
            unset FILELIST_FILE
            # go through all of the permutations of paths/filenames
            if [ "x${BASE_PATHS}" != "x" ]; then
                for CHECK_PATH in $(echo ${BASE_PATHS});
                do
                    # we need to eval here so the tilde '~' is expanded if
                    # used
                    # check for 'package_name.txt' first
                    eval CHECK_FILE="${CHECK_PATH}/${CURR_PKG}.txt"
                    say "- Checking for filelist ${CHECK_FILE}"
                    if [ -s $CHECK_FILE ]; then
                        FILELIST_FILE=$CHECK_FILE
                        say "- Found: ${CHECK_FILE}"
                        # first file found winѕ, break out of this loop
                        break
                    fi # if [ -e ${CHECK_PATH}/${CURR_PKG}.txt ]
                    # we need to eval here so the tilde '~' is expanded if
                    # used
                    # then check for just 'package_name'
                    eval CHECK_FILE="${CHECK_PATH}/${CURR_PKG}"
                    say "- Checking for filelist ${CHECK_FILE}"
                    if [ -s $CHECK_FILE ]; then
                        FILELIST_FILE=$CHECK_FILE
                        say "- Found: ${CHECK_FILE}"
                        # first file found winѕ, break out of this loop
                        break
                    fi # if [ -e ${CHECK_PATH}/${CURR_PKG} ]
                done
            fi # if [ "x${BASE_PATHS}" != "x" ]

            # if the above didn't come up with the full path to a filelist
            # file, assume the filelist we're looking for is in $PWD
            if [ "x${FILELIST_FILE}" = "x" ]; then
                say "- Using filelist file ${PWD}/${CURR_PKG}"
                FILELIST_FILE=${CURR_PKG}
            fi # if [ "x${FILELIST_FILE}" = "x" ]

            # process the filelist file that was found
            say "- Processing filelist file: ${FILELIST_FILE}"
            if [ -s $FILELIST_FILE ]; then
                warn "- Parsing: ${FILELIST_FILE}"
                # FIXME
                # - this doesn't catch symlinks in filelist files
                # - this also breaks if the source and destination files are
                # different
                #PKG_CONTENTS=$(cat ${FILELIST_FILE})
                PKG_CONTENTS=$(cat ${FILELIST_FILE} | grep -v "^#" \
                    | awk '{print $2}')
                #check_exit_status $? "find ${FILELIST_FILE} -type f"
            else
                warn "ERROR: filelist ${FILELIST_FILE} not found!"
                warn "(Maybe use --basepath option?)"
                exit 1
            fi # if [ -e ${CURR_PKG} ]
            ;;
        *) # unknown argument
            warn "ERROR: must use --list|--directory|--package arguments"
            warn "ERROR: to specify what the input to this script is"
            exit 1
            ;;
    esac # case "$INPUT_OPT"
    LINE_COUNT=$(echo $PKG_CONTENTS | wc -w)
    say "- ${CURR_PKG} has ${LINE_COUNT} files"

    if [ "x$PKG_CONTENTS" == "x" ]; then
        warn "ERROR: PKG_CONTENTS variable empty;"
        warn "ERROR: Perhaps you didn't specify an input type???"
        warn "ERROR: Run script with --help to see script options"
        warn "ERROR: Run script with --usage to see script usage examples"
        exit 1
    fi # if [ -z $OUTPUT ]; then

    ### NO OUTPUT TYPE SPECIFIED ###
    if [ "x${OUTPUT_OPT}" == "x" ]; then
        warn "ERROR: must use one of: --squashfs|--filelist|--cpio"
        warn "ERROR: to specify what the output of this script will be"
        exit 1

    ### FILELIST OUTPUT ###
    elif [ $OUTPUT_OPT == "filelist" ]; then
        say "== PACKAGE CONTENTS =="
        say "$PKG_CONTENTS"
        # print the recipe header
        if [ $APPEND -eq 0 ]; then
            if [ $FILELIST_HEADER_FLAG -eq 0 ]; then
                dump_filelist_header $CURR_PKG $PKG_VERSION
                FILELIST_HEADER_FLAG=1
            else
                echo "# package name/version: ${CURR_PKG} / ${PKG_VERSION}"
            fi
        fi

        # PKG_CONTENTS should be a list of files, directories and/or symlinks
        for LINE in $(echo $PKG_CONTENTS);
        do
            if [ ! -e $LINE ]; then
                warn "WARN: File ${LINE} does not exist on the filesystem"
                continue
            fi # if [ ! -e $LINE ]; then
            # check to see if we need to exclude this file
            # this also skip missing files and/or directories
            check_excludes $LINE
            if [ $? -gt 0 ]; then
                continue
            fi
            # this makes it easy to use case to decide what to write to the
            # output file
            FILE_TYPE=$($STAT --printf "%F" $LINE)
            # AUG == access rights in octal, FUID, FGID
            STAT_AUG=$($STAT --printf "%a %u %g" $LINE)
            PERMS=$(echo $STAT_AUG | awk '{print $1}')
            # munge the userid/groupid bits
            if [ -z $FUID ]; then
                FUID=$(echo $STAT_AUG | awk '{print $2}')
            fi

            if [ -z $FGID ]; then
                FGID=$(echo $STAT_AUG | awk '{print $3}')
            fi

            # check if this is the kernel; we don't need to package it up in
            # the initramfs file
            if [ $(echo $LINE | grep -c "vmlinuz") -gt 0 ]; then
                echo "#file $LINE $LINE $STAT_AUG"
                continue
            fi

            # munge the target filename if required
            SOURCE=$LINE
            if [ "x$REGEX" != "x" ]; then
                TARGET=$(echo $LINE | $SED $REGEX)
            else
                TARGET=$LINE
            fi # if [ -n $REGEX ]

            case "$FILE_TYPE" in
                "regular file")
                    echo "file $TARGET $SOURCE $PERMS $FUID $FGID"
                    ;;
                "directory")
                    echo "dir $SOURCE $PERMS $FUID $FGID"
                    ;;
                "symbolic link")
                    TARGET=$($READLINK -f $SOURCE | $TR -d '\n')
                    echo "slink $SOURCE $TARGET $PERMS $FUID $FGID"
                    ;;
            esac
        done # for LINE in $(echo $PKG_CONTENTS);

    ### SQUASHFS OUTPUT ###
    elif [ $OUTPUT_OPT == "squashfs" ]; then
        if [ "x$WORKDIR" == "x" ]; then
            warn "ERROR: --workdir argument needs to be used with --squashfs"
            exit 1
        fi # if [ "x$WORKDIR" == "x" ]

        # create a directory for the squashfs source in $WORKDIR
        # FIXME this only works for Debian packages;
        SQUASH_SRC="${WORKDIR}/${CURR_PKG}-${PKG_VERSION}"
        # if $SINGLE_OUTFILE is set, use a single directory for all files
        if [ "x$SINGLE_OUTFILE" != "x" ]; then
            SQUASH_SRC="${WORKDIR}/${SINGLE_OUTFILE}"
        fi # if [ "x$SINGLE_OUTFILE" != "x" ]
        #if [ $(echo ${SQUASH_SRC} | grep -c "/$") -eq 0 ]; then
        #    SQUASH_SRC="${SQUASH_SRC}/"
        #fi
        if [ ! -d $SQUASH_SRC ]; then
            say "- Creating working directory: ${SQUASH_SRC}"
            $MKDIR -p $SQUASH_SRC
            if [ $? -gt 0 ]; then
                warn "ERROR: can't create work directory $SQUASH_SRC"
                exit 1
            fi # if [ $? -gt 0 ]
        fi # if [ ! -d $WORKDIR ]

        warn "- Copying: '${CURR_PKG}' to ${SQUASH_SRC}"

        LINE_NUM=1
        for LINE in $(echo $PKG_CONTENTS);
        do
            if [ ! -e $LINE ]; then
                warn "WARN: File ${LINE} does not exist on the filesystem"
                continue
            fi # if [ ! -e $LINE ]; then
            # check to see if we need to exclude this file
            # this also skip missing files and/or directories
            check_excludes $LINE
            if [ $? -gt 0 ]; then
                continue
            fi
            # this makes it easy to use case to decide what to write to the
            # output file
            FILE_TYPE=$($STAT --printf "%F" $LINE)
            # AUG == access rights in octal, FUID, FGID
            STAT_AUG=$($STAT --printf "%a %u %g" $LINE)
            PERMS=$(echo $STAT_AUG | awk '{print $1}')
            #say "- line: ${LINE} ${PERMS} ${FUID} ${FGID}"

            # munge the target filename if required
            SOURCE=$LINE
            if [ "x$REGEX" != "x" ]; then
                SOURCE=$(echo $LINE | $SED $REGEX)
            else
                SOURCE=$LINE
            fi # if [ -n $REGEX ]

            case "$FILE_TYPE" in
                "regular file")
                    TARGET=$(echo ${SOURCE} | sed 's!^/!!')
                    PRE=$(printf '% 5s cp:' ${LINE_NUM})
                    say "- ${PRE} ${SOURCE} to ${SQUASH_SRC}/${TARGET}"
                    if [ "x${LOGFILE}" != "x" ]; then
                        # --preserve=all
                        $CP --preserve=all $SOURCE "${SQUASH_SRC}/${TARGET}" \
                            >> $LOGFILE 2>&1
                        check_exit_status $? \
                            "${CP} ${SOURCE} ${SQUASH_SRC}/${TARGET}"
                    else
                        $CP --preserve=all $SOURCE "${SQUASH_SRC}/${TARGET}"
                        check_exit_status $? \
                            "${CP} ${SOURCE} ${SQUASH_SRC}/${TARGET}"
                    fi # if [ "x${LOGFILE}" != "x" ]
                    ;;
                "directory")
                    # skip packaging the toplevel directory
                    if [ $SOURCE != "./" ]; then
                        SOURCE=$(echo ${SOURCE} | sed 's!^/!!')
                        PRE=$(printf '% 5s mkdir:' ${LINE_NUM})
                        say "- ${PRE} ${SQUASH_SRC}/${SOURCE}"
                        if [ "x${LOGFILE}" != "x" ]; then
                            $MKDIR -p "${SQUASH_SRC}/${SOURCE}" \
                                >> $LOGFILE 2>&1
                        else
                            $MKDIR -p "${SQUASH_SRC}/${SOURCE}"
                        fi

                    fi # if [ $TARGET != "./" ]
                    ;;
                "symbolic link")
                    #TARGET=$($READLINK -f $SOURCE | $TR -d '\n')
                    #TARGET=$($READLINK -f $SOURCE | sed 's!^/!!')
                    TARGET=$($READLINK -f $SOURCE)
                    SOURCE=$(echo ${SOURCE} | sed 's!^/!!')
                    PRE=$(printf '% 5s ln:' ${LINE_NUM})
                    say "- ${PRE} ${TARGET} ${SQUASH_SRC}/${SOURCE}"
                    if [ "x${LOGFILE}" != "x" ]; then
                        ln -s $TARGET ${SQUASH_SRC}/${SOURCE} >> $LOGFILE 2>&1
                    else
                        ln -s $TARGET ${SQUASH_SRC}/${SOURCE}
                    fi
                    ;;
            esac # case "$FILE_TYPE" in
            LINE_NUM=$(( ${LINE_NUM} + 1 ))
        done # for LINE in $(echo $PKG_CONTENTS);

        # call mksquashfs if we're packaging individual packages,
        # i.e. $SINGLE_OUTFILE is not set
        if [ "x$SINGLE_OUTFILE" = "x" ]; then
            check_squashfile_exists $SQUASH_SRC
            run_mksquashfs "${SQUASH_SRC}"
        fi # if [ "x$SINGLE_OUTFILE" == "x" ]
    ### CPIO OUTPUT ###
    elif [ "x$OUTPUT_OPT" = "xcpio" ]; then
        :
    else
        warn "ERROR: unknown output type; OUTPUT_OPT is '${OUTPUT_OPT}'"
        exit 1
    fi # if [ $OUTPUT_OPT == "filelist" ]; then
done # for $CURR_PKG in $@;

# call mksquashfs if we're packaging a single package
if [ "x$SINGLE_OUTFILE" != "x" ]; then
    check_squashfile_exists $SQUASH_SRC
    run_mksquashfs "${SQUASH_SRC}"
    #check_squashfile_exists $SINGLE_OUTFILE
    #run_mksquashfs $SINGLE_OUTFILE
fi # if [ "x$SINGLE_OUTFILE" == "x" ]

if [ "x$OUTPUT_OPT" = "xfilelist" ]; then
    # print the vim tag at the bottom so the recipes are formatted nicely
    # when you edit them
    echo "# vim: set filetype=config shiftwidth=2 tabstop=2 paste:"
fi

# calculate script execution time, and output pretty statistics
SCRIPT_END=$(${EPOCH_DATE_CMD})
warn "- Finished querying package system"
EXECUTION_TIME=$( echo "${SCRIPT_END} - ${SCRIPT_START}" | bc )
#warn "script start time: $SCRIPT_START"
#warn "script end time: $SCRIPT_END"
#warn "script execution time in seconds: $EXECUTION_TIME"
EXECUTION_MINS=$( echo "scale=0; $EXECUTION_TIME/60" | bc)
#warn "script execution time in minutes: $EXECUTION_MINS"
if [ $EXECUTION_MINS -gt 60 ]; then
    EXECUTION_MOD=$( echo "$EXECUTION_MINS * 60" | bc )
    EXECUTION_SECS=$( echo "$EXECUTION_TIME - $EXECUTION_MOD" | bc )
    TOTAL_TIME="- Total script execution time: "
    TOTAL_TIME="${TOTAL_TIME} ${EXECUTION_MINS} minutes, "
    TOTAL_TIME="${TOTAL_TIME} ${EXECUTION_SECS} seconds"
    warn $TOTAL_TIME
else
    warn "- Total script execution time: 0${EXECUTION_TIME} seconds"
fi

# exit with the happy
exit 0

# *begin license blurb*
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

# vi: set filetype=sh shiftwidth=4 tabstop=4:
# eof
