#!/usr/bin/perl
use strict;
use warnings;
# use lib 'lib';
use ExtUtils::MakeMaker;


WriteMakefile(
	'PREREQ_PM' => {
		'JSON'        => 0,
		'JSON::Path'  => 0,
		'LWP::Simple' => 0,
	}
);
