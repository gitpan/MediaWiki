#! /usr/bin/perl -X

use strict;
use Test;
BEGIN { plan tests => 3 }
use MediaWiki;

my $c = MediaWiki->new();
$c->setup("t/bot.ini");
$c->{summary} = "Test of [[m:MediaWiki (perl)|MediaWiki]] perl module (8)";

my $pg =
	# $c->random();
	$c->get("Test page to be deleted");
my $title = $pg->title();
my $text = $pg->content();

if(!$pg->delete())
{
	skip(1);
	skip(1);
	skip(1);
	exit;
}
$pg = $c->get($title);
ok(!$pg->exists);
$pg->restore();

$pg = $c->get($title);
ok($pg->exists);
ok($pg->content eq $text);
