#! /usr/bin/perl -X

use strict;
use Test;
BEGIN { plan tests => 2 }
use MediaWiki;

my $STR = "MediaWiki perl module test";
my $PAGE = "Sandbox/MediaWiki_perl_module";

my $c = MediaWiki->new();
$c->setup("t/bot.ini");

$c->{summary} = "Test of [[m:MediaWiki (perl)|MediaWiki]] perl module (2)";
$c->text($PAGE, $c->text($PAGE) . "----\n$STR");
my $text = $c->text($PAGE);
ok($text =~ s/$STR$//g);
$c->{summary} = "Test of [[m:MediaWiki (perl)|MediaWiki]] perl module (2) rev";
$c->text($PAGE, $text);
ok($c->text($PAGE) !~ /$STR$/);
