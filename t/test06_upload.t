#! /usr/bin/perl -X

use strict;
use Test;
BEGIN { plan tests => 1 }
use MediaWiki;

my $PAGE = "MediaWiki_perl_module_test_blank.gif";

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

$c->upload($PAGE, $image, "Test of [[m:MediaWiki (perl)|MediaWiki]] perl module (6)", 1);
my $code = $c->download($PAGE);
ok($code, $image);
