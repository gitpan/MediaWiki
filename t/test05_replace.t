#! /usr/bin/perl -X

use strict;
use Test;
BEGIN { plan tests => 1 }
use MediaWiki;

my $PAGE = "Sandbox/MediaWiki_perl_module";

my $c = MediaWiki->new();
$c->setup("t/bot.ini");

my $pg = $c->get($PAGE, "w");
$pg->{content} = "Test of replacements bot! {{bot uploaded article}} <nowiki>{{bot uploaded article}}</nowiki> TESTIX Unix <math>Unix</math>";
$pg->{summary} = "Test of [[m:MediaWiki (perl)|MediaWiki]] perl module (5) prep";
$pg->save();
$pg->{summary} = "Test of [[m:MediaWiki (perl)|MediaWiki]] perl module (5)";
$pg->replace(sub {
	my $textp = shift;

	$$textp =~ s'{{bot uploaded article}}'{{botup}}'g;
	$$textp =~ s'TESTIX'Testix'g;
	$$textp =~ s'Unix'UNIX'g;
});
$pg->load();
ok($pg->content(), "Test of replacements bot! {{botup}} <nowiki>{{bot uploaded article}}</nowiki> Testix UNIX <math>Unix</math>");
$pg->revert();
