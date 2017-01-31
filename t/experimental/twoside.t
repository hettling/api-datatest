#!/usr/bin/perl
use strict;
use warnings;
use Test::More 'no_plan';

use LWP::Simple;
use JSON;
use JSON::Path;
use Data::Dumper;

# build query
my $unitid = "RMNH.PISC.S.1";
my $query = "http://api.biodiversitydata.nl/v0/specimen/search/?unitID=" . $unitid;

# make API request
my $json = get( $query );

# decode json
##my $decoded_json = decode_json( $json );

# make JSON paths for all indexed fields
my @indexed_fields = qw(unitID sourceSystem.name typeStatus phaseOrStage sex collectorsFieldNumber collectionType gatheringEvent.localityText gatheringEvent.gatheringAgents.fullName gatheringEvent.gatheringAgents.organization gatheringEvent.dateTimeBegin _geoshape);

# for querying unit IDs (registration numbers), we must only have one result, so take the first one
my @jpaths = map { JSON::Path->new("\$.searchResults[0].result." . $_) } @indexed_fields;

my %result;
@result{@indexed_fields} = map { $_->value($json) } @jpaths;

for my $k( keys(%result) ) {
	if ( my $v = $result{$k} ) {
		print "Making query for $k=$v\n";		
		my $r_query = "http://api.biodiversitydata.nl/v0/specimen/search/?" . $k . "=" . $v . "&_maxResults=100";
		print $r_query . "\n";
		my $json = get( $r_query );
		
##		print "JSON : $json \n";
	}

}
