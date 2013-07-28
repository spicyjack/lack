#!/usr/bin/env perl

# $Id: forkssldemo.pl,v 1.8 2009-03-20 09:10:37 brian Exp $
# Copyright (c)2006 by Brian Manning <elspicyjack at gmail dot com>
#
# perl script to start an HTTPD server
# based on the example given for HTTP::Daemon module

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

B<farkhttpd.pl> starts a forking HTTP/HTTPS daemon.

=cut

########
# main #
########
use strict;
use warnings;
use Socket;
use POSIX q(:sys_wait_h);
use IO::Socket::INET;
use IO::Socket::SSL;
use HTTP::Daemon::SSL;
use HTTP::Status;

my $waitpid = 0;

sub REAPER {
    while ( ( $waitpid= waitpid(-1, WNOHANG) ) > 0 ) {
        warn qq(reaped PID $waitpid) . ($? ? qq( with error $?) : q());
    }
    $SIG{CHLD} = \&REAPER; 
    # SysV requires that the handler for CHLD be reset every time it's used
}

$SIG{CHLD} = \&REAPER;
$SIG{INT} = \&killserver;

# define common variables so that a %SIG handler can access the close method of
# any open $clients
my ($daemon, $client, $request);
my $port = 9000;

# create an HTTP::Daemon object to listen for requests
# HTTP::Daemon is a subclass of IO::Socket::INET among other things; more docs
# can be found by referring to that POD page as well

=pod

$daemon = HTTP::Daemon->new( 
        LocalPort => $port,
        Proto => q(tcp),
    ) || die qq(Failed to start HTTP::Daemon on port $port : '$!');

=cut

$daemon = HTTP::Daemon::SSL->new( 
        LocalPort => $port,
        Proto => q(tcp),
        SSL_verify_mode => 0x00,
        SSL_key_file => q(ff.antlinux-key.pem),
        SSL_passwd_cb => sub { return q(raftbreadshinycratequirtfist) },
        SSL_cert_file => q(ff.antlinux-cert.pem),
    ) || die qq(Failed to start HTTP::Daemon on port $port : '$!');

print qq(Please contact me at: <URL:) . $daemon->url() . qq(>\n);
# Got a connection, process it
# props to SOAP::Transport::HTTP::Daemon::ForkOnAccept for the below
while (1) {
# FIXME log requests to a file?
CLIENT: {
    while ($client = $daemon->accept() ) {
        my $pid = fork();
    
        # The fork failed ($pid is undefined)
        die qq(Fork failed $!) unless (defined $pid);

        # the parent closes the new connection 
        if ( $pid != 0 ) {
            # parent process, don't need the client connection, close it and
            # wait for the next connection
            $client->close;
            next CLIENT;
        } # if ( $pid != 0 )

        # child process, $pid == 0
        # the child closes the listening socket, as it's the parent's job to
        # monitor it
        $daemon->close();    

        # translate raw bytes of the peer address into something human readable;
        # inet_ntoa() is provided by Socket
        print qq(Recevied HTTP request from ') 
            . inet_ntoa($client->peeraddr()) . qq('\n);

        print qq(client is now ) . ref($client) . qq(\n);
        # keep reading data from the socket as long as it's open
        while ($request = $client->get_request) {
            if ($request->method eq 'GET' and $request->url->path eq "/xyzzy") {
                # remember, this is *not* recommended practice :-)
                $client->send_file_response("/etc/motd");
            } else {
                # RC_FORBIDDEN is provided by HTTP::Status
                $client->send_error(RC_FORBIDDEN, $daemon->url 
                    . q(: You are not authorized to use this service));
            } # if ($request->method eq 'GET' and url->path eq "/xyzzy") 
        } # while ($request = $client->get_request)
        print qq(Closing socket connection with ') 
            . inet_ntoa($client->peeraddr()) . qq('\n);
        $client->close;
        undef($client);
    } # while (my $client = $daemon->accept)
} # CLIENT
} # while (1)

sub killserver {
    warn(qq(Huh, received a Ctrl-C, exiting...\n));
    # $client is not in scope here
    #$client->close();
    exit 1;
}


=pod

=head1 VERSION

The CVS version of this file is $Revision: 1.8 $. See the top of this file for
the author's version number.

=head1 AUTHOR

Brian Manning E<lt>elspicyjack at gmail dot comE<gt>

=cut

# vi: set ft=perl sw=4 ts=4:
# end of line

