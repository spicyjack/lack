#!/usr/bin/perl

# script to check the contents of an initramfs filelist
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
        print qq(WARN: directory doesn't exist: ) . $line[1] 
            . qq(, line $counter\n)
            unless ( -d $line[1] );
    } elsif ( $line[0] eq q(file) ) {
        print qq(WARN: file doesn't exist: ) . $line[2] 
            . qq(, line $counter\n)
            unless ( -e $line[2] );
    } elsif ( $line[0] eq q(slink) ) {
        print qq(WARN: symlink source doesn't exist: ) . $line[2] 
            . qq(, line $counter\n)
            unless ( -e $line[2] );
    } else {
        print qq(WARN: unknown filetype: ) . $line[0] . qq(, line: $counter\n);
    } # if ( $line[0] eq q(dir) )

} # while ( <> )

