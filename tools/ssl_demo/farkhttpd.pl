#!/usr/bin/env perl

# $Id: farkhttpd.pl,v 1.18 2009-03-20 09:10:37 brian Exp $
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

farkhttpd.pl

=head1 DESCRIPTION

B<farkhttpd.pl> a forking HTTP daemon used to bootstrap a Project Naranja
system.

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
     
# Object Design Notes
# -------------------
# Init Object:
# - runs getopts
# - sets signals
# - starts parent
# Parent Object:
# - forks children
# - logs to STDOUT/STDERR/logfile
# Child Object:
# - logs to logfile
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
# - verifies the number of children already forked; returns a HTTP status code
# if there are too many children forked already
# - verifies requested ports are not already being listened to, and not in
# /etc/services (commonly used ports)

########
# main #
########
use strict;
use warnings;
use Socket;
use Getopt::Long;
use POSIX q(:sys_wait_h);
use HTTP::Daemon;
use HTTP::Status;
# TODO wrap the above in a BEGIN{} block to catch missing modules and present a
# nice error message to the user

# variables used by getopts
my $DEBUG; # are we debugging? turns off signals/etc. (default: false)
my $listkeys; # allow users to list keys (default: false)
my @portlist; # list of ports to choose from when starting a server
my $piddir = q(/var/run/farkhttpd); # where to write pid/log files
my $maxchildren = 10; # maximum number of processes to fork; 0 == unlimited
my $currentchildren = 0; # current number of forked processes

# parse command line options
my $parser = new Getopt::Long::Parser;
$parser->configure();
$parser->getoptions(
	q(h|help|longhelp) => \&ShowHelp, 
	q(d|debug|DEBUG) => \$DEBUG,
	q(p|pl|portlist=i) => \@portlist,
	q(pd|piddir=s) => \$piddir,
	q(mc|maxchild|maxchildren:i) => \$maxchildren,
   	q(listkeys|lk) => \$listkeys,
    # --keyfile_path - 
    # --dry_run - do everything up to forking a server
); # $parser->getoptions

my $waitpid = 0;

sub REAPER {
    while ( ( $waitpid= waitpid(-1, WNOHANG) ) > 0 ) {
        warn qq(reaped PID $waitpid) . ($? ? qq( with error $?) : q());
    }
    $SIG{CHLD} = \&REAPER; 
    # SysV requires that the handler for CHLD be reset every time it's used
}

# signals
# define SIGCHILD
$SIG{CHLD} = \&REAPER;

# only turn on \&killserver if $DEBUG is enabled; in a production system,
# we don't want to allow the system to continue to start up if the console
# operator accidentally hit Ctrl-C
if ( defined $DEBUG ) {
	$SIG{INT} = \&killserver;
} # if ( defined $DEBUG )

# define common variables so that a %SIG handler can access the close method of
# any open $clients
my ($daemon, $client, $request);

my $keyfile_path = $ENV{PWD}; # ha!

# create an HTTP::Daemon object to listen for requests
# HTTP::Daemon is a subclass of IO::Socket::INET among other things; more docs
# about object attributes that can be set when the object is created
# can be found by referring to that POD page as well
$daemon = HTTP::Daemon->new( 
        #LocalAddr => q(172.27.1.93),
        #LocalAddr => q(black.pq.antlinux.com),
        LocalAddr => q(localhost), # set to localhost when using stunnel
        LocalPort => 24824,
        Proto => q(tcp),
        ) || die qq(Failed to start HTTP::Daemon: '$!');

print qq(Please contact me at: <URL:) . $daemon->url . qq(>\n);
# Got a connection, process it
# props to SOAP::Transport::HTTP::Daemon::ForkOnAccept for the below
while (1) {

CLIENT: {
    while ($client = $daemon->accept) {
    # $client isa(HTTP::Daemon::ClientConn)

# FIXME count how many children processes; after X number of children, refuse
# to fork any more to prevent DoS attacks; this may not work anyways, the
# children are not going away after a socket is closed (or the socket is never
# closing properly :/ )

# children are not going away like they should
		if ( $currentchildren == $maxchildren ) { # FIXME is this right?
			# automagically close this connection and exit this while loop
            $client->close;
            next CLIENT;
		} # if ( $currentchildren == $maxchildren )	

		# create the child process
        my $pid = fork();
    
        # We are going to close the new connection on one of two conditions
        #  1. The fork failed ($pid is undefined)
        #  2. We are the parent ($pid != 0)
        unless ( defined $pid && $pid == 0 ) {
            # parent process, don't need the client connection, close it and
            # wait for the next connection
            $client->close;
            next CLIENT;
        } # unless ( defined $pid && $pid == 0 ) 
    
        # child process, $pid == 0
        # the child closes the listening socket, as it's the parent's job to
        # monitor it
# FIXME write a file for each child; name the file after the PID of the child
# process, and use it as a logfile of activity
        $daemon->close();

		# bump up the child process count
		$currentchildren++; # FIXME is this right?

        # open filehandles to be able to print
        #open(STDIN,  "<&STDIN")   || die "can't dup client to stdin";
        #open(STDOUT, ">&STDOUT")   || die "can't dup client to stdout";
		# FIXME log requests to a file using the PID of the child process as
		# the filename
        print qq(Child process, pid is $pid or $$\n);
        # translate raw bytes of the peer address into something human readable;
        # inet_ntoa() is provided by Socket
        print qq(Recevied HTTP request from ') 
            . inet_ntoa($client->peeraddr()) . qq('\n);
        # keep reading data from the socket as long as it's open
        while ($request = $client->get_request) {
            # $request is a HTTP::Request 
            # $request->url has been deprecated; use $request->uri instead
            if ($request->method eq 'GET') {
                my $request_uri = $request->uri->path;
                # do some massaging of the URI
                $request_uri =~ s!^/!!;
                if ( length($request_uri) > 0 ) {
                    if ( -r $keyfile_path . q(/) . $request_uri . q(.sec) ) {
                        # remember, this is *not* recommended practice :-)
                        # $keymgr->send_auth_form
                        $client->send_file_response("/etc/motd");
                    } else {
                        print qq(Client requested URI of '$request_uri'\n);
                        $client->send_error(RC_NOT_FOUND);
                    } # іf ( -r qq($keyfile_path/$request_uri) )
                } else {
                    $client->send_error(RC_NOT_FOUND);
                } # if ( length($request_uri) > 0 )
            } else {
                # return a 404 for HEADs and POSTs (for now) 
                # RC_NOT_FOUND is provided by HTTP::Status
                $client->send_error(RC_NOT_FOUND);
            } # if ($request->method eq 'GET' and url->path eq "/xyzzy") 
        } # while ($request = $client->get_request)
        print qq(Closing socket connection with ') . $client->peeraddr() 
            . qq('\n);
        $client->close;
        undef($client);
    } # while (my $client = $daemon->accept)
} # CLIENT
} # while (1)

sub killserver {
    warn(qq(Huh, received a Ctrl-C, exiting...\n));
    if ( defined $client ) {
        $client->close();
    } # if ( defined $client )
    exit 1;
}

=pod

=head1 VERSION

The CVS version of this file is $Revision: 1.18 $. See the top of this file for
the author's version number.

=head1 AUTHOR

Brian Manning E<lt>elspicyjack at gmail dot comE<gt>

=cut

# vi: set ft=perl sw=4 ts=4:
# end of line

