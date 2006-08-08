package MediaWiki::page;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(new);

use strict;
use vars qw(
	$edittime_regex
	$watchthis_regex
	$minoredit_regex
	$edittoken_regex
	$edittoken_rev_regex
	$autosumm_regex
	$edittoken_delete_regex
	$pagehistory_delete_regex
	$timestamp_regex
	$historyuser_regex1
	$historyuser_regex2
	$anon_regex
	$minor_regex
	$date_regex
	$autocomment_regex
	$autocomment_delete_regex
	$autocomment_clear_regex
	$unhex_regex
	$comment_regex
	$li_regex
);
our @protection = ("", "autoconfirmed", "sysop");

BEGIN
{
	use HTTP::Request::Common;

	#
	# We should compile all regular expressions first
	#
	$edittime_regex = qr/(?<=value=")[0-9]+(?=" name="wpEdittime")/;
	$watchthis_regex = qr/name='wpWatchthis' checked/;
	$minoredit_regex = qr/(?<=value=')1(?=' name='wpMinoredit')/;
	$edittoken_regex = qr/(?<=value=")[0-9a-f]+(?=" name="wpEditToken")/;
	$edittoken_rev_regex = qr/(?<=name=['"]wpEditToken['"] value=")[0-9a-f]+(?=")/;
	$autosumm_regex = qr/(?<=name="wpAutoSummary" value=")[0-9a-f]+(?=")/;
	$edittoken_delete_regex = qr/.*wpEditToken["'] value="(.*?)".*/;
	$pagehistory_delete_regex = qr/.*<ul id\="pagehistory">(.*?)<\/ul>.*/;
	$timestamp_regex = qr/(?=>).*?(?=<\/a> <span class='history_user'>)/;
	$historyuser_regex1 = qr/(?<=<span class='history_user'>).*?(?=<\/span>)/;
	$historyuser_regex2 = qr/(?<=\:)(.*?)">\1(?=<\/a>)/;
	$anon_regex = qr/(?<=Contributions">).*?(?=<\/a>)/;
	$minor_regex = qr/span class='minor'/;
	$date_regex = qr/(.*?)<.*/;
	$autocomment_regex = qr/(?<=<span class="autocomment">).*?(?=<\/span>)/;
	$autocomment_delete_regex = qr/<span class="autocomment">.*?<\/span>\s*/;
	$autocomment_clear_regex = qr/(?<=#).*?(?=")/;
	$unhex_regex = qr/\.([0-9a-fA-F][0-9a-fA-F])/;
	$comment_regex = qr/(?<=<span class='comment'>\().*?(?=\)<\/span>)/;
	$li_regex = qr/(?<=<li>).*?(?=<\/li>)/;
}

sub new
{
	my($class, %params) = @_;
	my $ref = {};

	$ref->{client} = $params{-client} || MediaWiki->new();
	$ref->{title} = $params{-page} || "Special:Random";
	$ref->{prepared} = ($params{-mode} && $params{-mode} =~ /w/) ? 1 : 0;
	$ref->{loaded} = 0;
	$ref->{ua} = $ref->{client}->{ua};

	bless $ref, $class;
	$ref->load()
		if(!defined $params{-mode} || $params{-mode} =~ /r/ || $ref->{prepared});
	return $ref;
}

sub oldid
{
	my($obj, $oldid) = @_;
	my $t = $obj->{ua}->get($obj->_wiki_url . "&action=raw&oldid=$oldid");
	return $t->is_success ? $t->content : undef;
}
sub load
{
	my $obj = shift;
	$obj->{loaded} = 0;

	if($obj->{prepared})
	{
		$obj->prepare();
	}
	else
	{
		my $t = $obj->{ua}->get($obj->_wiki_url . "&action=raw");
		if(!$t->is_success())
		{
			if($t->code == 404 || $t->code =~ /^3/)
			{
				$obj->{exists} = $t->code == 404 ? 0 : 1;
				$obj->{loaded} = 1;
			}
			return if($t->code !~ /^3/);
		}

		$obj->{content} = $t->content;
		if($obj->{title} eq 'Special:Random')
		{
			my $proj = $obj->{project};
			($obj->{title}) = split(/ (—|-) $proj/, $t->header("Title"));
			$obj->load();
		}

		$obj->{exists} = $t->code == 404 ? 0 : 1;
	}
	$obj->{title} =~ tr/_/ /;
	$obj->{loaded} = 1;
}
sub save
{
	my $obj = shift;

	$obj->prepare()
		if(!$obj->{prepared});
	$obj->{prepared} = 0;

	my $ret = $obj->{client}->{ua}->request(
		POST $obj->_wiki_url . "&action=edit",
		Content_Type  => 'application/x-www-form-urlencoded',
		Content       => [ (
			'wpTextbox1' => $obj->{content},
			'wpEdittime' => $obj->{edittime},
			'wpSave' => 'Save page',
			'wpSection' => '',
			'wpSummary' => $obj->_summary(),
			'wpEditToken' => $obj->{edittoken},
			'title' => $obj->{title},
			'action' => 'submit',
			'wpMinoredit' => $obj->{minor},
			'wpAutoSummary' => $obj->{autosumm}
		)]
	)->code;
	if($ret == 302)
	{
		$obj->history_clear();
		return 1;
	}
	return 0;
}
sub prepare
{
	my $obj = shift;

	my $t = $obj->{ua}->get($obj->_wiki_url . "&action=edit");
	return unless $t->is_success;
	$t = $t->content();

	if($obj->{prepared}) # Must fill 'content' field
	{
		my($a) = split /<\/textarea>/, $t;
		$a =~ s/.*<textarea.*?>//sg;

		$obj->{content} = $a;
		$obj->{exists} = 1;
	}

	if($t =~ /$edittime_regex/)
	{
		$obj->{edittime} = $&;
	}
	if($obj->{client}->{watch} || $t =~ /$watchthis_regex/)
	{
		$obj->{watch} = 1;
	}
	if($obj->{client}->{minor} || $t =~ /$minoredit_regex/)
	{
		$obj->{minor} = 1;
	}
	if($t =~ /$edittoken_regex/)
	{
		$obj->{edittoken} = $&;
	}
	if($t =~ /$autosumm_regex/)
	{
		$obj->{autosumm} = $&;
	}
}
sub exists
{
	my $obj = shift;
	$obj->load()
		unless($obj->{loaded});
	return $obj->{exists};
}
sub title
{
	my $obj = shift;
	return $obj->{title}
		if($obj->{loaded} || ($obj->{title} && $obj->{title} ne "Special:Random"));

	$obj->load();
	return $obj->{title};
}
sub content
{
	my $obj = shift;
	$obj->load()
		unless $obj->{loaded};
	return $obj->{content};
}

sub _wiki_url
{
	my($obj, $title) = @_;
	return $obj->{client}->{index} . "?title=" . ($title || $obj->{title});
}
sub _summary
{
	my $obj = shift;
	return $obj->{summary} || $obj->{client}->{summary} || "Bot (Edward's framework)";
}

sub delete
{
	my $obj = shift;

	if(!$obj->{prepared})
	{
		my $res = $obj->{ua}->get($obj->_wiki_url . "&action=delete");
		return unless($res->is_success);
		$res = $res->content;
		$res =~ s/$edittoken_delete_regex/$1/s;
		$obj->{edittoken} = $res;
	}
	$obj->{prepared} = 0;

	return $obj->{ua}->request(
		POST $obj->_wiki_url . "&action=delete",
		Content_Type  => 'application/x-www-form-urlencoded',
		Content       => [(
			'wpReason' => $obj->_summary(),
			'wpEditToken' => $obj->{edittoken},
			'wpConfirmB' => 'confirm'
		)]
	)->is_success();
}
sub restore
{
	my $obj = shift;

	if(!$obj->{prepared})
	{
		my $res = $obj->{ua}->get($obj->_wiki_url . "&action=restore");
		return unless($res->is_success);
		$res = $res->content;
		$res =~ s/$edittoken_delete_regex/$1/s;
		$obj->{edittoken} = $res;
	}
	$obj->{prepared} = 0;

	return $obj->{ua}->request(
		POST $obj->_wiki_url("Special:Undelete") . "&action=submit",
		Content_Type  => 'application/x-www-form-urlencoded',
		Content       => [(
			'target' => $obj->{title},
			'wpEditToken' => $obj->{edittoken},
			'restore' => 'confirm'
		)]
	)->is_success();
}
sub protect
{
	my($obj, $edit, $move) = @_;
	$edit = 1 unless(defined $edit);

	if(!$obj->{prepared})
	{
		my $res = $obj->{ua}->get($obj->_wiki_url . "&action=protect");
		return unless($res->is_success);
		$res = $res->content;
		$res =~ /$edittoken_rev_regex/;
		$obj->{edittoken} = $&;
	}
	$obj->{prepared} = 0;

	return
		$obj->{ua}->request(
		POST $obj->_wiki_url . "&action=protect",
		Content_Type  => 'application/x-www-form-urlencoded',
		Content       => [(
			'mwProtect-level-edit' => $protection[$edit],
			'mwProtect-level-move' => $protection[defined $move ? $move : $edit],
			'mwProtect-reason' => $obj->_summary(),
			'wpEditToken' => $obj->{edittoken}
		)]
	)->is_success();
}
sub move
{
	my($obj, $title) = @_;

	if(!$obj->{prepared})
	{
		my $res = $obj->{ua}->get($obj->_wiki_url("Special:Movepage/" . $obj->{title}));
		return unless($res->is_success);
		$res = $res->content;
		$res =~ s/$edittoken_delete_regex/$1/s;
		$obj->{edittoken} = $res;
	}
	$obj->{prepared} = 0;

	my $res = $obj->{ua}->request(
		POST $obj->_wiki_url("Special:Movepage") . "&action=submit",
		Content_Type  => 'application/x-www-form-urlencoded',
		Content       => [(
			'wpNewTitle' => $title,
			'wpOldTitle' => $obj->{title},
			'wpReason' => $obj->_summary(),
			'wpEditToken' => $obj->{edittoken}
		)]
	);
	return unless($res->code == 302);

	$obj->{title} = $title;
	return 1;
}
sub watch
{
	my($obj, $unwatch) = @_;
	return $obj->{ua}->get($obj->_wiki_url . "action=" . ($unwatch ? "un" : "") . "watch")->is_success;
}
sub unwatch
{
	my $obj = shift;
	$obj->watch(1);
}

sub _pagename
{
	my $obj = shift;
	my @a = split /:/, $obj->title();
	shift @a;
	return join(":", @a);
}
sub upload
{
	my($obj, $content, $note, $force) = @_;
	my $title = $obj->_pagename();
	my $ns_special = $obj->{client}->_cfg("wiki", "special") || "Special";

	my $tmp = `mktemp`;
	chomp $tmp;

	open F, ">$tmp";
	print F $content;
	close F;

	my $res = $obj->{ua}->request(
		# FIXME: may not work for some MediaWiki installations
		POST "http://$main::wiki_host/$main::wiki_path/index.php/$ns_special:Upload",
		Content_Type  => 'multipart/form-data',
		Content       => [(
			'wpUploadFile' => [ $tmp ],
			'wpDestFile' => $title,
			'wpUploadDescription' => $note ? $note : "",
			'wpUpload' => 'upload',
			'wpIgnoreWarning' => $force ? 'true' : 0
		)]
	);

	#
	# TODO: check for all known warnings; return error info
	#
	return 1;
}

sub block
{
	my($obj, $time) = @_;
	my $user = $obj->_pagename();

	if(!$obj->{prepared})
	{
		my $res = $obj->{ua}->get($obj->_wiki_url("Special:Blockip/" . $obj->{title}));
		return unless($res->is_success);
		$res = $res->content;
		$res =~ /$edittoken_rev_regex/;
		$obj->{edittoken} = $&;
	}
	$obj->{prepared} = 0;

	return $obj->{ua}->request(
		POST $obj->_wiki_url("Special:Blockip") . "&action=submit",
		Content_Type  => 'application/x-www-form-urlencoded',
		Content       => [(
			'wpBlockAddress' => $obj->_pagename(),
			'wpBlockExpiry' => 'other',
			'wpBlockOther' => $time,
			'wpBlockReason' => $obj->_summary(),
			'wpEditToken' => $obj->{edittoken},
			'wpBlock' => 'Block'
		)]
	)->code == 302;
}
sub unblock
{
	my $obj = shift;
	my $user = $obj->_pagename();

	if(!$obj->{prepared})
	{
		my $res = $obj->{ua}->get($obj->_wiki_url("Special:Ipblocklist"). "&action=unblock&ip=$user");
		return unless($res->is_success);
		$res = $res->content;
		$res =~ /$edittoken_rev_regex/;
		$obj->{edittoken} = $&;
	}
	$obj->{prepared} = 0;

	my $res = $obj->{ua}->request(
		POST $obj->_wiki_url("Special:Ipblocklist") . "&action=submit",
		Content_Type  => 'application/x-www-form-urlencoded',
		Content       => [(
			'wpUnblockAddress' => $obj->_pagename(),
			'wpUnblockReason' => $obj->_summary(),
			'wpEditToken' => $obj->{edittoken},
			'wpBlock' => 'Unblock'
		)]
	);

	print STDERR $res->request->as_string, "\n\n", $res->as_string;
}

sub _history_init
{
	my($obj, $force) = @_;
	if(!$obj->{history} || $force)
	{
		$obj->{history} = [];
		$obj->{history_offset} = undef;
	}
}
sub _history_preload
{
	my($obj, $offset) = @_;
	my $page = $obj->{title};
	my $limit = $obj->{client}->{history_step} || 50;

	my $wiki_path = $obj->{client}->_cfg("wiki", "path");
	my $link_regex = qr/<a href="\/$wiki_path\/index\.php\/(.*?)" title="(.*?)">:?(.*?)<\/a>/;
	my $offset_regex = qr/(?<=offset=)[0-9]+[^"]*" title="$page">next $limit<\/a>/;

	my $res = $obj->{ua}->get($obj->_wiki_url . "&action=history&limit=$limit" . ($offset ? "&offset=$offset" : "") . "&uselang=en");
	return unless($res->is_success);
	$res = $res->content();

	if($res =~ /$offset_regex/)
	{
		my @a = split /\&/, $&;
		$offset = shift @a;
	}
	else
	{
		$offset = undef;
	}
	$res =~ s/$pagehistory_delete_regex/$1/g;

	$res =~ /$li_regex/g if($obj->{history_offset});
	while($res =~ /$li_regex/g)
	{
		my $item = $&;
		my $oldid;

		while($item =~ /(?<=&amp;oldid=)[0-9]+(?=" title="$page")/g)
		{
			$oldid = $&;
		}

		$item =~ /$timestamp_regex/;
		my($time, $date) = split /, /, $&;
		my @a = split />/, $time;
		$time = pop @a;
		$date =~ s/$date_regex/$1/g;

		$item =~ /$historyuser_regex1/;
		my $user = $&; my $anon;
		if($user =~ /$historyuser_regex2/)
		{
			$user = (split /"/, $&)[0];
			$anon = 0;
		}
		else
		{
			$user =~ /$anon_regex/;
			$user = $&;
			$anon = 1;
		}

		my $minor = 0;
		$minor = 1
			if($item =~ /$minor_regex/);

		my $section = "";
		if($item =~ /$autocomment_regex/)
		{
			my $autocomment = $&;
			$item =~ s/$autocomment_delete_regex//g;

			$autocomment =~ /$autocomment_clear_regex/;
			$section = $&;
			$section =~ s/$unhex_regex/pack("C", hex($1))/eg;
		}

		my $comment = "";
		if($item =~ /$comment_regex/)
		{
			$comment = $&;
			$comment =~ s/$link_regex/[[$1|$3]]/g;
		}

		my $edit = {
			'page' => $obj,
			'oldid' => $oldid,
			'user' => $user,
			'anon' => $anon,
			'minor' => $minor,
			'comment' => $comment,
			'section' => $section,
			'time' => $time,
			'date' => $date,
			'datetime' => "$time, $date"
		};
		push @{$obj->{history}}, $edit;
	}
	$obj->{history_offset} = $offset;
	return $offset;
}

sub history
{
	my($obj, $cb) =  @_;
	my $limit = $obj->{client}->{history_step} || 50;
	my $offset; my $j = 0;

	$obj->_history_init();
	while(1)
	{
		$offset = $obj->_history_preload($offset);

		for(my $k = $j; $k < @{$obj->{history}}; $k ++, $j ++)
		{
			my $ret = &$cb($obj->{history}->[$k]);
			return $ret if($ret);
		}
		last unless $offset;
	}
}
sub history_clear
{
	my $obj = shift;
	delete $obj->{history};
}
sub last_edit
{
	my $obj = shift;
	my $hp = $obj->{history};
	if(!$hp || !@$hp)
	{
		$obj->_history_init();
		$obj->_history_preload();
		$hp = $obj->{history};
	}
	return $hp->[0];
}
sub markpatrolled
{
	my $obj = shift;
	my $hp = $obj->{history};
	if(!$hp || !@$hp)
	{
		$obj->_history_init();
		$obj->_history_preload();
		$hp = $obj->{history};
	}
	my $oldid = $hp->[0]->{oldid};
	return $obj->{ua}->get($obj->_wiki_url . "&action=markpatrolled&rcid=$oldid")->is_success;
}
sub revert
{
	my $obj = shift;
	my $msg = $obj->{client}->message("Revertpage") || "rv";
	$obj->_history_init();

	my $j = 0; my $offset = $obj->{history_offset}; my $last_user;
	while(1)
	{
		if(!$obj->{history}->[$j])
		{
			last if($j && !$offset);
			$offset = $obj->_history_preload($offset);
		}

		my $edit = $obj->{history}->[$j];
		my $user = $edit->{user};
		if($last_user && $last_user ne $user)
		{
			$msg =~ s/\$2/$last_user/g;
			$msg =~ s/\$1/$user/g;

			$obj->{content} = $obj->oldid($edit->{oldid});

			my $save_summ = $obj->{summary};
			$obj->{summary} = $msg;
			my $ret = $obj->save();
			$obj->{summary} = $save_summ;
			return $ret;
		}

		$last_user = $edit->{user}
			unless $last_user;

		$j ++;
	}
	return;
}

sub replace
{
	my($obj, $cb) = @_;
	my $text = $obj->content();
	return if($text =~ /\{\{NO_BOT_TEXT_PROCESSING}}/);

	my @parts = ();
	my $last_end = 0;
	while($text =~ /<(nowiki|math|pre)>.*?<\/\1>/sg)
	{
		my $skipped = $&;
		my $len = length $&;
		my $end = pos($text);
		my $start = $end - $len;

		my $used = substr $text, $last_end, $start - $last_end;
		$last_end = $end;

		push @parts, [$used, 1]
			if(length($used) > 0);
		push @parts, [$skipped, 0];
	}
	if($last_end <= length($text) - 1)
	{
		push @parts,
			[substr($text, $last_end, length($text) - $last_end), 1];
	}

	foreach my $part(@parts)
	{
		&$cb(\$part->[0])
			if($part->[1] == 1);
	}

	my $new_text = "";
	foreach my $part(@parts)
	{
		$new_text .= $part->[0];
	}
	return 1 if($new_text eq $text);
	$obj->{content} = $new_text;
	return $obj->save();
}
sub remove
{
	my($obj, $regex) = @_;
	my $text = $obj->content();

	my @parts = ();
	my $last_end = 0;
	while($text =~ /<(nowiki|math|pre)>.*?<\/\1>/sg)
	{
		my $skipped = $&;
		my $len = length $&;
		my $end = pos($text);
		my $start = $end - $len;

		my $used = substr $text, $last_end, $start - $last_end;
		$last_end = $end;

		push @parts, [$used, 1]
			if(length($used) > 0);
		push @parts, [$skipped, 0];
	}
	if($last_end <= length($text) - 1)
	{
		push @parts,
			[substr($text, $last_end, length($text) - $last_end), 1];
	}

	foreach my $part(@parts)
	{
		$part->[0] =~ s/$regex//g
			if($part->[1] == 1);
	}

	my $new_text = "";
	foreach my $part(@parts)
	{
		$new_text .= $part->[0];
	}
	return 1 if($new_text eq $text);
	$obj->{content} = $new_text;
	return $obj->save();
}
sub remove_template
{
	my($obj, $tmpl) = @_;
	return $obj->remove('\{\{' . quotemeta($tmpl) . '\|[.\n]*?\}\}');
}
