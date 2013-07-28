#!/usr/bin/env perl

# $Id: perl_cmdline_parse.pl,v 1.1 2009-01-06 06:54:36 brian Exp $
# Copyright (c)2001 by Brian Manning
#
# perl script that parses /proc/cmdline on Linux, formats and displays the
# contents

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

SomeScript

=head1 DESCRIPTION

B<SomeScript> does I<Something>

=cut

package main;
$main::VERSION = (q$Revision: 1.1 $ =~ /(\d+)/g)[0];
use strict;
use warnings;

if ( -e q(/proc/cmdline) ) {
    my $cmdline = qx#cat /proc/cmdline | tr -d '\n'#;
    my @cmdargs = split(/\s+/, $cmdline);
    foreach my $currarg ( @cmdargs ) {
        my ($key, $value) = split(/=/, $currarg);
        print qq(key: '$key'; value: '$value'\n);
    } # foreach my $currarg ( @cmdargs )
} else {
    die q(ERROR: file /proc/cmdline does not exist);
} # if ( -e q(/proc/cmdline) )

################
# SomeFunction #
################
sub SomeFunction {
} # sub SomeFunction
				
=pod

=head1 CONTROLS

=over 5

=item B<Description of Controls>

=over 5

=item B<A Control Here>

This is a description about A Control.

=item B<Another Control>

This is a description of Another Control

=back 

=back

=head1 FUNCTIONS 

=head2 SomeFunction()

SomeFunction() is a function that does something.  

=head1 VERSION

The CVS version of this file is $Revision: 1.1 $. See the top of this file for the
author's version number.

=head1 AUTHOR

Brian Manning E<lt>elspicyjack at gmail dot comE<gt>

=cut

# vi: set ft=perl sw=4 ts=4 cin:
# end of line
1;

