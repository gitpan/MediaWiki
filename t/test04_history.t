#! /usr/bin/perl -X

use strict;
use Test;
BEGIN { plan tests => 2 }
use MediaWiki;

my $c = MediaWiki->new();
$c->setup("t/bot.ini");

my $user = $c->user();
ok($user);

my $i = 0;
TRY_FIND_TEST_PAGE:
	while($i < 10)
	{
		my $pg = $c->random();
		my $e = $pg->last_edit;
		if($e->{user} ne $user)
		{
			$pg->{content} = "Hello, World! (Bot test; do not consider as vandalism - should be reverted)";
			$pg->{summary} = "Test of [[m:MediaWiki (perl)|MediaWiki]] perl module (4)";
			$pg->save();
			$e = $pg->last_edit;
			ok($e->{user}, $user);
			$pg->revert();

			last TRY_FIND_TEST_PAGE;
		}
		$i ++;
	}
if($i == 10)
{
	skip(1);
}
