#!/usr/bin/perl
use strict;
use warnings;
use Test::More 'no_plan';

use LWP::Simple;
use JSON;
use JSON::Path;
use Data::Dumper;

# Get Spreadsheet data
my $sheet_url = "https://docs.google.com/spreadsheets/d/1Fb2tvVBU8-YTNAgklAPNV9iiiy2ZQSqQfZkhrJ0A1sQ";
$sheet_url .= "/pub?output=tsv";
my @arr = `curl $sheet_url`;
my @arr_spl = map { [split("\t", $_)] } @arr;

my @transposed;
foreach my $j (0..$#{$arr_spl[0]}) {
	push(@transposed, [map $_->[$j], @arr_spl]);
}

my %table;
foreach my $i ( 0..$#transposed ) {
	my @curr = @{$transposed[$i]};
	# remove trailing whitespaces
	@curr = map { $_ =~ s/\s+$//g; $_ } @curr;
	my $colname = shift @curr;;
	$table{$colname} = \@curr;
} 

my @collections = @{%table->{'collection'}};

	for my $c ( @collections ) {
		ok ( $c, "Collection is $c" );
		
		# The collection data to download as archives
		my $url = "http://api.biodiversitydata.nl/v0/specimen/search/dwca/?collection=$c";
		# my $url = "http://145.136.242.170:8080/v2/specimen/dwca/query/?collection=$c"; # v2 test
		# http://145.136.242.166/ # v2 test dashboard
		# http://145.136.242.164/ # v2 dev
		
		# Validate using Darwin Core Archive validator
		my $req_url = "http://tools.gbif.org/dwca-validator/validatews.do?archiveUrl=$url";
		my $ua = LWP::UserAgent->new;
		my $response = $ua->get( $req_url );
		ok( $response->is_success, "GBif server responding to request" );

		# Check validation result. 
		# XX Unfortunately, if the file was not found or similar, the response is still a success
		#  but not valid json, so the following will crap out...
		my $jp = JSON::Path->new("\$.valid");
		my $val = $jp->value( $response->decoded_content );
		ok ( $val==1, "Response is a valid Darwin Core Archive" );

				
		# make API request to donwload zip content
#		my $can_accept = HTTP::Message::decodable;
#		my $response = LWP::UserAgent->new->get( $url, 'Accept-Encoding' => $can_accept );

		# check status
#		ok ( $response->is_success, "Checking HTTP status" );

		# write zip response to file
#		my $filename = 'test.zip';
#		open my $fh, '>', $filename, or die $!;
#		print $fh $response->decoded_content;
#		close $fh;
#		ok ( -s $filename, "File $filename not empty" ); 

		# unzip file

		# validate XML with schema
}

