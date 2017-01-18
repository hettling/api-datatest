#!/usr/bin/perl
use strict;
use warnings;
use Test::More 'no_plan';

use LWP::Simple;
use JSON;
use Data::Dumper;

# build query
my $query = "http://api.biodiversitydata.nl/v0/specimen/search/?typeStatus=holotype";

# make API request
my $json = get( $query );

# decode json
my $decoded_json = decode_json( $json );

my $num_results = $decoded_json->{'totalSize'};

my $expected = 26294;
ok( $num_results == $expected )

