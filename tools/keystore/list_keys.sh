#!/bin/sh

# script to list all of the keys in the secret keyring

$(which gpg) --no-default-keyring \
    --secret-keyring ./keystore.sec \
    --keyring ./keystore.pub --list-secret-keys

