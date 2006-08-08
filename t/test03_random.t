#! /usr/bin/perl -X

use strict;
use Test;
BEGIN { plan tests => 2 }
use MediaWiki;

my $STR = "MediaWiki perl module test";
my $PAGE = "Sandbox/MediaWiki_perl_module";

my $c = MediaWiki->new();
$c->setup("t/bot.ini");

my $pg = $c->random();
ok($pg->title() ne 'Special:Random');
ok($pg->exists());
