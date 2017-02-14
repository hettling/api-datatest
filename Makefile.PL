#!/usr/bin/perl
use strict;
use warnings;
use lib 'lib';
use ExtUtils::MakeMaker;


WriteMakefile(
	'PREREQ_PM' => {
		'JSON'         => 0,
		'JSON::Path'   => 0,
		'LWP::Simple'  => 0,
		'Term::Prompt' => 0,
		'Storable'     => 0,
		'File::Compare' => 0,
		'Net::Google::DataAPI::Auth::OAuth2' => 0,
		'Net::Google::Spreadsheets' => 0,
		'Net::Google::Spreadsheets::Worksheet' => 0,
	}
);
