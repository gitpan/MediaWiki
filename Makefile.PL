#! /usr/bin/perl
use ExtUtils::MakeMaker;
WriteMakefile(
	NAME => 'MediaWiki',
        VERSION_FROM => 'lib/MediaWiki.pm',
	PREREQ_PM => {
		'Config::IniHash' => '0',
		'LWP' => '0',
		'HTTP::Request::Common' => '0',
		'Data::Dumper' => '0'
	}
);
