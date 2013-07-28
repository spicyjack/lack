#!/usr/bin/env perl

# $Id: index.pl,v 1.10 2009-01-06 18:19:27 brian Exp $
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
     
# Config objects to keep track of:
# - root device for use with losetup command
# - disk encryption key
# - maximum upload size for disk keys; the disk key itself is about 4k, and
# each user's public key is about 400 bytes, so if we say 4000 + ( # users *
# 400 ), we should be good as far as how many bytes we want to limit uploads to

########
# main #
########
use strict;
use warnings;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
#use utf8;

# set up some bounds in CGI.pm
my $max_user_keys = 40;
# maximum number of keys expected in a disk key
#$CGI::POST_MAX = 4000 + ($max_user_keys * 400);
$CGI::POST_MAX = 60000;
$CGI::DISABLE_UPLOADS = 0; # explicitly turn uploads on

# variables used by ConfigIni
my $DEBUG = undef; # are we debugging? turns off signals/etc. (default: undef)
#my $DEBUG = 1; # are we debugging? turns off signals/etc. (default: undef)
my $listkeys; # allow users to list keys (default: false)
my $tmpkeydir = q(/tmp);
my $hostname = qx(cat /etc/hostname | tr -d '\n');
my $flashkeydir = qq(/mnt/flash/keyhosts/$hostname);


### start page
my $q = new CGI;

#print $q->header(-charset => q(UTF-8)),
print $q->header(),

$q->start_html(-title => qq('$hostname' Bootstrap Page),
    -lang => q(en_US), -encoding => q(UTF-8),
    -declare_xml => q(UTF-8) ),

$q->start_multipart_form(
        -method => q(POST), 
        -action => qq(https://) . $ENV{HTTP_HOST} . q(:24443),
        ),

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

# if the thumbdrive is inserted and it contains a 'keys' directory, or
# the user passes the string 'key_id' as a GET parameter
if ( -d $flashkeydir || $q->param(q(key_id)) ) {
    print $q->Tr(
        $q->td({-align => q(right)}, q(Key ID:)),  qq(\n),
        $q->td({-align => q(left)}, $q->textfield(
            -nosticky => 1,
            -name => q(key_id),
            -size => 40,
            -maxlength => 60),
            q( (example: '1234ABCD') ),
        ), qq(\n),
    );
} else {
    # no thumbdrive; upload keys instead
    print $q->Tr(
        $q->td({-align => q(right)}, q(GPG Private Key:)),  qq(\n),
        $q->td({-align => q(left)}, $q->filefield(
                -name => q(gpg_privkeyfile),
                -size => 50,
                -maxlength => 80),
        ), qq(\n),
    ), # $q->Tr
    $q->Tr(
        $q->td({-align => q(right)}, q(GPG Public Key:)),  qq(\n),
        $q->td({-align => q(left)}, $q->filefield(
                -name => q(gpg_pubkeyfile),
                -size => 50,
                -maxlength => 80),
        ), qq(\n),
    ), # $q->Tr
    $q->Tr( 
        $q->td({-align => q(right)}, q(Disk Key:)),  qq(\n),
        $q->td({-align => q(left)}, $q->filefield(
            -name => q(disk_keyfile),
            -size => 50,
            -maxlength => 80),
        ), qq(\n), # $q->td
    ), qq(\n); # $q->Tr
} # if ( -d $flashkeydir || $q->param(q(key_id)) )

print $q->end_table(), qq(\n), 
    $q->p(
        $q->submit(-label => q(Unlock Disk)), 
        $q->reset(-label => q(Reset Form)) 
    ),
$q->end_form(), qq(\n);

my @paramnames = $q->param;
print $q->p(qq(Query parameters were: ) . join(q(:), @paramnames)), qq(\n)
    if ( defined $DEBUG );

# FIXME make this check for multiple fields filled in instead of this one;
# supress warnings if none of the fields actually had data in them
if ( $q->param(q(passphrase)) ) {
    # the user passed in a passphrase, we must have to do something here
    my $gpg_priv_fh = $q->upload(q(gpg_privkeyfile));
    my $gpg_pub_fh = $q->upload(q(gpg_pubkeyfile));
    my $disk_fh = $q->upload(q(disk_keyfile));
    my $passphrase = $q->param(q(passphrase));
    my $root_dev = &GetRootDev;

    if ( defined $DEBUG ) {
        print $q->hr(), qq(\n), $q->p(qq(Passphrase was : $passphrase)), qq(\n);
    } 
    my $try_verify;
    if ( defined $gpg_priv_fh && defined $gpg_pub_fh && defined $disk_fh ) {
        print $q->p(qq(uploading files to $tmpkeydir)) if ( defined $DEBUG );
        # try for unlocking the disk key with the user's gpg key/passphrase
        my ($gpg_privkeyfile, $gpg_pubkeyfile, $disk_keyfile);
        while (<$gpg_priv_fh>) { $gpg_privkeyfile .= $_; }
        while (<$gpg_pub_fh>) { $gpg_pubkeyfile .= $_; }
        while (<$disk_fh>) { $disk_keyfile .= $_; }
        $try_verify = 1;
        if ( ! -r qq($tmpkeydir/secring.gpg) ) {
            open(FH_GPG_PRIVKEY, qq(> $tmpkeydir/secring.gpg));
            print FH_GPG_PRIVKEY $gpg_privkeyfile;
            close(FH_GPG_PRIVKEY);
            chmod 0600, qq($tmpkeydir/secring.gpg);
        } else {
            print $q->p($q->strong(q(WARNING:)), 
                qq($tmpkeydir/secring.gpg exists, not overwriting)), qq(\n);
        } # if ( ! -r qq($tmpkeydir/secring.gpg) )
        if ( ! -r qq($tmpkeydir/pubring.gpg) ) {
            open(FH_GPG_PUBKEY, qq(> $tmpkeydir/pubring.gpg));
            print FH_GPG_PUBKEY $gpg_pubkeyfile;
            close(FH_GPG_PUBKEY);
            chmod 0600, qq($tmpkeydir/pubring.gpg);
        } else {
            print $q->p($q->strong(q(WARNING:)), 
                qq($tmpkeydir/secring.gpg exists, not overwriting)), qq(\n);
        } # if ( ! -r qq($tmpkeydir/secring.gpg) )
        if ( ! -r qq($tmpkeydir/user_disk_key.gpg) ) {
            open(FH_DISK_KEY, qq(> $tmpkeydir/user_disk_key.gpg));
            print FH_DISK_KEY $disk_keyfile;
            close(FH_DISK_KEY);
            chmod 0600, qq($tmpkeydir/user_disk_key.gpg);
        } else {
            print $q->p($q->strong(q(WARNING:)), 
                qq($tmpkeydir/user_disk_key.gpg exists, not overwriting)), 
                qq(\n);
        } # if ( ! -r qq($tmpkeydir/secring.gpg) )
        if ( defined $DEBUG ) {
            print $q->p(qq(contents of folder $tmpkeydir are:));
            print qq(<pre>\n);
            system(qq(/bin/ls -l $tmpkeydir));
            print qq(</pre>\n);
        } # if ( defined $DEBUG )
    } elsif ( $q->param(q(key_id)) ) {
        my $key_id = $q->param(q(key_id));
        # let's untaint the key parameter first
        if ($key_id =~ /^([\w.]+)$/) {
            $key_id = $1;             # $data now untainted
        } else {
            print $q->p(qq(Could not untaint '$key_id')), qq(\n);
            $try_verify = undef;
        } # if ($key_id =~ /^([\w.]+)$/)
        # try for reading the disk key and gpg keys from a thumbdrive
        # we need both the private and public keyrings and the disk key
        my $got_keys;
        if ( -r $flashkeydir . q(/) . $key_id . q(.sec) ) {
            print $q->p(q(Copying ) . $key_id 
                . qq(.sec to $tmpkeydir/secring.gpg\n)) if ( defined $DEBUG );
            system(qq(/bin/cp $flashkeydir/) . $key_id 
                . qq(.sec $tmpkeydir/secring.gpg));
            $got_keys++;
        } else {
            print $q->p(q(Could not find ') . $key_id 
                . qq(.sec' on the thumbdrive <$flashkeydir>));
            $got_keys--;
        } # if ( -r $key_id . q(.sec) )
        if ( -r $flashkeydir . q(/) . $key_id . q(.pub) ) {
            print $q->p(q(Copying ) . $key_id 
                . qq(.pub to $tmpkeydir/pubring.gpg\n)) if ( defined $DEBUG );
            system(qq(/bin/cp $flashkeydir/) . $key_id 
                    . qq(.pub $tmpkeydir/pubring.gpg));
            $got_keys++;
        } else {
            print $q->p(q(Could not find ') . $key_id 
                . qq(.pub' on the thumbdrive <$flashkeydir>));
            $got_keys--;
        } # if ( -r $key_id . q(.pub) )
        if ( -r $flashkeydir . q(/user_disk_key.gpg) ) {
            print $q->p(qq(Copying user_disk_key.gpg to $tmpkeydir\n)) 
                if ( defined $DEBUG );
            system(qq(/bin/cp $flashkeydir/user_disk_key.gpg $tmpkeydir));
            $got_keys++; 
        } else {
            print $q->p(q(Could not find 'user_disk_key.gpg' ) 
                . qq(on the thumbdrive <$flashkeydir>));
            $got_keys--; 
        } # if ( -r $tmpkeydir . q(/) . $key_id . q(.sec) )
        # ternary test; see 'Conditional Operator' in 'perlop' for more info
        $try_verify = ( $got_keys >= 3 ) ? 1 : undef;
    } # if ( defined $gpg_upload )
    # catches both 'undef' and '0' values...
    if ( defined $try_verify && $try_verify ) {
        # losetup switches;
        # -G gpghome, -K gpgkey, -p passphrase file descriptor, -e AES128
        my $losetup_command = qq(/sbin/losetup -G $tmpkeydir );
        $losetup_command .= qq(-K $tmpkeydir/user_disk_key.gpg );
        $losetup_command .= qq(-p 0 -e AES128 /dev/loop0 $root_dev);
        #my $gpg_command = qq(gpg --batch --homedir $tmpkeydir --always-trust );
        #$gpg_command .= qq(--lock-never --passphrase-fd 0 --decrypt );
        #$gpg_command .= qq($tmpkeydir/user_disk_key.gpg 2>/dev/null);
        #my $gpg_returnval = qx(echo $passphrase | $gpg_command);
#my $losetup_rv 
#            = system( qq(echo $passphrase | $losetup_command 2>/dev/null ));
        open(LOSETUP, qq(| $losetup_command 2>>/var/log/boot.log));
        print LOSETUP qq($passphrase\n);                     
        close LOSETUP;
#|| print $q->p( $q->strong(q(Whoops; something )
#            . qq(happened closing LOSETUP:\n$! $?)) );
#print $q->p(q(losetup run with command: )), qq(\n), 
#$q->pre($losetup_command), qq(\n), 
        # FIXME check the output of losetup here
        print $q->p(q(encrypted partition mounted, booting system...)), qq(\n);
#$q->p(qq(Exit code of losetup command was: '$losetup_rv': $!)), 
#            qq(\n) if ( defined $DEBUG );
        # now kill the prompt 
        # FIXME need a way to detect succes/failure of the LOSETUP command above
        #if ( $losetup_rv == 0 ) {
        open(PID, "< /var/run/keyprompt.pid");
        my @prompt_pid = <PID>;
        close(PID);
        system(q(kill -TERM ) . $prompt_pid[0]);
        #} # if ( $losetup_rv == 0 )
    } else {
        print $q->p(q(ERROR: could not unlock disk with parameters given));
    } # if ( defined $try_verify )
} else {
    print $q->p(q(parameter passphrase not found...)), qq(\n);
} # if ( $q->param(q(passphrase) )        

print $q->end_html();

exit 0;

### SUBROUTINES

sub GetRootDev {
    if ( -e q(/proc/cmdline) ) {
        my $cmdline = qx#cat /proc/cmdline | tr -d '\n'#;
        my @cmdargs = split(/\s+/, $cmdline);
        foreach my $currarg ( @cmdargs ) {
            my ($key, $value) = split(/=/, $currarg);
            #print qq(key: '$key'; value: '$value'\n);
            if ( $key eq q(rootdev) ) { 
                return $value;
            } # if ( $key == q(rootdev) )
        } # foreach my $currarg ( @cmdargs )
    } else {
        die q(ERROR: file /proc/cmdline does not exist);
    } # if ( -e q(/proc/cmdline) )
} # sub GetRootDev

=pod

=head2 sub GetRootDev

Parses the C</proc/cmdline> file in Linux in order to determine what the root
device is to use with loopback mounts.

=head1 VERSION

The CVS version of this file is $Revision: 1.10 $. See the top of this file for
the author's version number.

=head1 AUTHOR

Brian Manning E<lt>elspicyjack at gmail dot comE<gt>

=cut

# vi: set ft=perl sw=4 ts=4 cin:
# eol
