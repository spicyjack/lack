#!/usr/bin/env perl

# $Id: index.cgi,v 1.9 2009-03-20 09:10:37 brian Exp $
# Copyright (c)2006 by Brian Manning <elspicyjack at gmail dot com>
#
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

=pod

=head1 NAME

index.cgi

=head1 DESCRIPTION

B<index.cgi>, a script for bootstrapping a Project Naranja system.

=cut

# TODO
# - add a http://someserver:someport/listkeys option that can be turned on/off;
# when a client calls 'listkeys', all of the keys in the $keyfile_path below
# are listed in HTML and that HTML is passed back to the client
# - decide how the script will react to different URI calls 
# ( i.e. create/refine USE CASES for the below )
#   - Key ID in URI and USB thumbdrive inserted: read the key off of the
#   thumbdrive, verify the Key ID via the 'gpg' command, if that key exists in
#   the return an HTML form with the password and key upload box
#   - URI is '/upload': present the user with an HTML form containing 3 boxes;
#   disk key, GPG key and password field; the user uploads the two keys, and
#   types the password in the box to unlock the disk
     
# Config File Modules:
# - Config::Auto - parses many different types of config files, uses other
# modules as available)
# - Config::Grammar - use keys to build a multilevel config file
# - YAML - YAML is a generic data serialization language that is optimized for
# human readability.
# - Config::Simple - Config::Simple is a class representing configuration file
# object. It supports several configuration file syntax and tries to identify
# the file syntax automatically.
# - Config::IniFiles - Used by Config::Auto for parsing Windows-style .ini
# files

# Config objects to keep track of:
# - root device for use with losetup command
# - disk encryption key
# - maximum upload size for disk keys; the disk key itself is about 4k, and
# each user's public key is about 400 bytes, so if we say 4000 + ( # users *
# 400 ), we should be good as far as how many bytes we want to limit uploads to

# Object Design Notes
# -------------------
# HTML Object:
# - parse URI/uploaded file
# - write the beginning of the form/webpage (HTTP header, HTML body, form tags)
# - write password box
# - write key ID box
# - write disk key upload box
# - write GPG key upload box
# - write the rest of the form (</form>)
# Key Object:
# - verifies GPG key can unlock disk key
# - attempts to set up loopback mount using disk key, GPG key and passphrase
# Listener Object:
# - opens sockets for listening
# - handles incoming requests
# - creates HTML objects as needed

########
# main #
########
use strict;
use warnings;
use CGI;
use utf8;

# set up some bounds in CGI.pm
my $max_user_keys = 40
# maximum number of keys expected in a disk key
$CGI::POST_MAX = 4000 + ($max_user_keys * 400);
$CGI::DISABLE_UPLOADS = 0; # explicitly turn uploads on

# variables used by getopts
my $DEBUG = 1; # are we debugging? turns off signals/etc. (default: false)
my $listkeys; # allow users to list keys (default: false)
my $keydir = q(/dev/shm);
### start page
my $q = new CGI;

#print $q->header(-charset => q(UTF-8)),
print $q->header(),

$q->start_html(-title => q(Naranja Bootstrap Page),
    -lang => q(en_US), -encoding => q(UTF-8),
    -declare_xml => q(UTF-8) ),

$q->start_multipart_form(-method => q(POST)),

$q->start_table();

print $q->Tr(  
    $q->td({-align => q(right)}, q(Passphrase:)),  qq(\n),
    $q->td({-align => q(left)}, $q->password_field(
        -nosticky => 1,
        -name => q(passphrase),
        -size => 40,
        -maxlength => 60),
    ), qq(\n),
), qq(\n); # $q->Tr

if ( -d q(/mnt/flash/keys) || $q->param(q(key)) ) {
    # the USB thumbdrive is inserted; use that
    print $q->Tr(
        $q->td({-align => q(right)}, q(Keyfile:)),  qq(\n),
        $q->td({-align => q(left)}, $q->textfield(
            -nosticky => 1,
            -name => q(key),
            -size => 40,
            -maxlength => 60),
            q( (example: '1234ABCD') ),
        ), qq(\n),
    );
} else {
    # no thumbdrive; upload keys instead
    print $q->Tr(
        $q->td({-align => q(right)}, q(GPG Key:)),  qq(\n),
        $q->td({-align => q(left)}, $q->filefield(
                -name => q(gpg_key),
                -size => 50,
                -maxlength => 80),
        ), qq(\n),
    ), # $q->Tr
    $q->Tr( 
        $q->td({-align => q(right)}, q(Disk Key:)),  qq(\n),
        $q->td({-align => q(left)}, $q->filefield(
            -name => q(disk_key),
            -size => 50,
            -maxlength => 80),
        ), qq(\n), # $q->td
    ), qq(\n); # $q->Tr
} # if ( -d q(/mnt/flash/keys) )                

print $q->end_table(), qq(\n), 
    $q->p(
        $q->submit(-label => q(Unlock Disk)), 
        $q->reset(-label => q(Reset Form)) 
    ),
$q->end_form(),
qq(\n);

if ( $q->param(q(passphrase)) ) {
    # the user passed in a passphrase, we must have to do something here
    my $gpg_fh = $q->upload(q(gpg_key));
    my $disk_fh = $q->upload(q(disk_key));
    my $passphrase = $q->param(q(passphrase));
    print $q->hr(), qq(\n), $q->p(qq(Passphrase was : $passphrase)), qq(\n)
        if ( defined $DEBUG );
    my $try_verify;
    if ( defined $gpg_fh && defined $disk_fh ) {
        # try for unlocking the disk key with the user's gpg key/passphrase
        my ($gpg_key_file, $disk_key_file);
        while (<$gpg_fh>) { $gpg_key_file .= $_; }
        while (<$disk_fh>) { $disk_key_file .= $_; }
        $try_verify = 1;
        if ( ! -r qq($keydir/secring.gpg) ) {
            open(FH_GPG_KEY, qq(> $keydir/secring.gpg));
            print FH_GPG_KEY $gpg_key_file;
            close(FH_GPG_KEY);
        } else {
            print $q->p($q->strong(q(WARNING:)), 
                qq($keydir/secring.gpg exists, not overwriting)), qq(\n);
            $try_verify = undef;
        } # if ( ! -r qq($keydir/secring.gpg) )
        if ( ! -r qq($keydir/user_disk_key.gpg) ) {
            open(FH_DISK_KEY, qq(> $keydir/user_disk_key.gpg));
            print FH_DISK_KEY $disk_key_file;
            close(FH_DISK_KEY);
        } else {
            print $q->p($q->strong(q(WARNING:)), 
                qq($keydir/user_disk_key.gpg exists, not overwriting)), qq(\n);
            $try_verify = undef;
        } # if ( ! -r qq($keydir/secring.gpg) )
    } elsif ( $q->param(q(key)) ) {
        my $key_id = $q->param(q(key));
        # let's untaint the key parameter first
        if ($key_id =~ /^([\w.]+)$/) {
            $key_id = $1;             # $data now untainted
        } else {
            print $q->p(qq(Could not untaint '$key_id')), qq(\n);
            $try_verify = undef;
        } # if ($key_id =~ /^([\w.]+)$/)
        # try for reading the disk key and gpg key from a thumbdrive
        if ( -r $keydir . q(/) . $key_id . q(.sec) ) { $try_verify = 1; }  
    } # if ( defined $gpg_upload )
    if ( defined $try_verify ) {
        # losetup switches;
        # -G gpghome, -K gpgkey, -p passphrase file descriptor, -e AES128
        my $losetup_command = q(/sbin/losetup -G /mnt/flash/keys );
        $losetup_command .= q(-K /mnt/flash/keys/user_disk_key.gpg );
        $losetup_command .= q(-p 0 -e AES128 /dev/loop0 /dev/sda2);
        #my $gpg_command = qq(gpg --batch --homedir $keydir --always-trust );
        #$gpg_command .= qq(--lock-never --passphrase-fd 0 --decrypt );
        #$gpg_command .= qq($keydir/user_disk_key.gpg 2>/dev/null);
        #my $gpg_returnval = qx(echo $passphrase | $gpg_command);
        my $losetup_rv = qx(echo $passphrase | $losetup_command);
        print $q->p(q(losetup run with command: )), qq(\n), 
            $q->pre($losetup_command), qq(\n), 
            $q->p(qq(Output of losetup command was: '$losetup_rv')), qq(\n) 
            if ( defined $DEBUG );
    } # if ( defined $try_verify )
} # if ( $q->param(q(passphrase) )        

print $q->end_html();

=pod

=head1 VERSION

The CVS version of this file is $Revision: 1.9 $. See the top of this file for
the author's version number.

=head1 AUTHOR

Brian Manning E<lt>elspicyjack at gmail dot comE<gt>

=cut

# vi: set ft=perl sw=4 ts=4:
# eol
