#! /usr/bin/perl -X

use strict;
use Test;
BEGIN { plan tests => 4 }
use MediaWiki;

my $STR = "MediaWiki perl module test";
my $PAGE = "Sandbox/MediaWiki_perl_module";

my $c = MediaWiki->new();
$c->setup("t/bot.ini");

my $pg = $c->get($PAGE, "rw");
ok($pg->{prepared} && $pg->content);

$pg->{content} .= "---\n $STR";
$pg->{summary} = "Test of [[m:MediaWiki (perl)|MediaWiki]] perl module (1)";
$pg->save();
ok(!$pg->{prepared});
$pg->{content} = "";
$pg->load();

ok($pg->{content} =~ s/$STR$//g);
$pg->{summary} = "Test of [[m:MediaWiki (perl)|MediaWiki]] perl module (1) rev";
$pg->save();
$pg->load();
ok($pg->content !~ /$STR$/);
