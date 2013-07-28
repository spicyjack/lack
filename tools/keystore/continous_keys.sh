#!/bin/sh

# FIXME 
# - grab stats from each gnupg key creation, so that you can come up with
# performance metrics

while /bin/true; 
do 
    OUTDATE=$(date +%d%b%Y)
    echo "Creating new GPG key folder in /dev/shm/${OUTDATE}"; 
    time sh ~/src/lack.hg/scripts/keystore/gnupg-batch.sh
        --output /dev/shm/${OUTDATE} \
        --count 500 \
        --dicepath ~/src/perl.hg/diceware \
        --list ~/src/perl.hg/diceware/diceware.wordlist.asc
done
