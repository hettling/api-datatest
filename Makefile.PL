#!/usr/bin/perl
use strict;
use warnings;
# use lib 'lib';
use ExtUtils::MakeMaker;


WriteMakefile(
	'PREREQ_PM' => {
		'JSON'       => 0,
		'LWD_SIMPLE' => 0,
	}
);
