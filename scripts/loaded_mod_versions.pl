#!/usr/bin/perl

# script to output the versions of Perl modules

{
    no strict 'refs';
    foreach (sort keys %INC) {
         next unless m{^(.*)\.pm$};
          (my $mod = $1) =~ s{[\\/]+}{::}g;
           print "$mod : ${$mod . '::VERSION'}\n"
    }
}
