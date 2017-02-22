#!/bin/sh

# Trigger for listener script ('listener.pl') prsent
# in this directory. Invokes the unit tests in this repository.

/usr/bin/perl Makefile.PL && /usr/bin/make test

