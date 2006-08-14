#! /usr/bin/perl -X

use strict;
use Test;
BEGIN { plan tests => 2 }
use MediaWiki;

my $PAGE = "Участник:Edward Chernenko/MediaWiki module switch test";

my $c = MediaWiki->new();
$c->setup("t/bot.ini");

$c->{summary} = "Test of [[m:MediaWiki (perl)|MediaWiki]] perl module (7)";
$c->text($PAGE, "test!!!");
$c->switch({ 'host' => "ru.wikipedia.org", 'path' => "w"});
$c->text($PAGE, "testix");
$c->switch({ 'host' => "test.wikipedia.org", 'path' => "w"});
ok($c->text($PAGE), "test!!!");
$c->switch({ 'host' => "ru.wikipedia.org", 'path' => "w"});
ok($c->text($PAGE), "testix");

#
# cleanup
#
$c->text($PAGE, "");
$c->switch({ 'host' => "test.wikipedia.org", 'path' => "w"});
$c->text($PAGE, "");
