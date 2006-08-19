#! /usr/bin/perl -X

use strict;
use Test;
BEGIN { plan tests => 2 }
use MediaWiki;

my $PAGE = "Участник:Edward Chernenko/MediaWiki module switch test";

my $c = MediaWiki->new();
$c->setup("t/bot.ini");
my $start_wiki = $c->_cfg("wiki", "host");

$c->{summary} = "Test of [[m:MediaWiki (perl)|MediaWiki]] perl module (7)";
!$c->text($PAGE, "test!!!");
$c->switch({ 'host' => "ru.wikipedia.org", 'path' => "w" });
if(!$c->text($PAGE, "testix"))
{
	skip(1);
	skip(1);
	exit(0);
}
$c->switch({ 'host' => $start_wiki, 'path' => "w" });
ok($c->text($PAGE), "test!!!");
$c->switch({ 'host' => "ru.wikipedia.org", 'path' => "w" });
ok($c->text($PAGE), "testix");

#
# cleanup
#
$c->{summary} = "Test of [[m:MediaWiki (perl)|MediaWiki]] perl module (7) rev";
$c->text($PAGE, "");
$c->switch({ 'host' => $start_wiki, 'path' => "w" });
$c->text($PAGE, "");
