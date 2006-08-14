#! /usr/bin/perl -X

use strict;
use Test;
BEGIN { plan tests => 1 }
use MediaWiki;

my $c = MediaWiki->new();
$c->setup("t/bot.ini");

if(!$c->_cfg("bot", "user"))
{
	skip(1);
	exit;
}

my $image;
open F, "t/blank.gif";
read F, $image, -s F;
close F;

$c->upload("blank.gif", $image, "Test of [[m:MediaWiki (perl)|MediaWiki]] perl module (6)", 1);
my $code = $c->download("blank.gif");
ok($code, $image);
