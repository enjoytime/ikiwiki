#!/usr/bin/perl
use warnings;
use strict;

BEGIN {
	eval q{use XML::Feed; use HTML::Parser; use HTML::LinkExtor};
	if ($@) {
		eval q{use Test::More skip_all =>
			"XML::Feed and/or HTML::Parser not available"};
	}
	else {
		eval q{use Test::More tests => 78};
	}
}

use Cwd;

my $tmp = 't/tmp';
my $statedir = 't/tinypodcast/.ikiwiki';

sub simple_podcast {
	my $baseurl = 'http://example.com';
	my @command = (qw(./ikiwiki.out -plugin inline -rss -atom));
	push @command, qw(-underlaydir=underlays/basewiki);
	push @command, qw(-set underlaydirbase=underlays -templatedir=templates);
	push @command, "-url=$baseurl", qw(t/tinypodcast), "$tmp/out";

	ok(! system("mkdir $tmp"), q{setup});
	ok(! system(@command), q{build});

	my %media_types = (
		'simplepost'	=> undef,
		'piano.mp3'	=> 'audio/mpeg',
		'scroll.3gp'	=> 'video/3gpp',
		'walter.ogg'	=> 'video/x-theora+ogg',
	);

	for my $format (qw(atom rss)) {
		my $feed = XML::Feed->parse("$tmp/out/simple/index.$format");

		is($feed->title, 'simple',
			qq{$format feed title});
		is($feed->link, "$baseurl/simple/",
			qq{$format feed link});
		is($feed->description, 'wiki',
			qq{$format feed description});
		if ('atom' eq $format) {
			is($feed->author, $feed->description,
				qq{$format feed author});
			is($feed->id, $feed->link,
				qq{$format feed id});
			is($feed->generator, "ikiwiki",
				qq{$format feed generator});
		}

		for my $entry ($feed->entries) {
			my $title = $entry->title;
			my $url = $entry->id;
			my $body = $entry->content->body;
			my $enclosure = $entry->enclosure;

			is($entry->link, $url, qq{$format $title link});
			isnt($entry->issued, undef,
				qq{$format $title issued date});
			isnt($entry->modified, undef,
				qq{$format $title modified date});

			if (defined $media_types{$title}) {
				is($url, "$baseurl/$title",
					qq{$format $title id});
				is($body, undef,
					qq{$format $title no body text});
				is($enclosure->url, $url,
					qq{$format $title enclosure url});
				is($enclosure->type, $media_types{$title},
					qq{$format $title enclosure type});
				cmp_ok($enclosure->length, '>', 0,
					qq{$format $title enclosure length});
			}
			else {
				is($url, "$baseurl/$title/",
					qq{$format $title id});
				isnt($body, undef,
					qq{$format $title body text});
				is($enclosure, undef,
					qq{$format $title no enclosure});
			}
		}
	}

	ok(! system("rm -rf $tmp $statedir"), q{teardown});
}

sub single_page_html {
	my @command = (qw(./ikiwiki.out));
	push @command, qw(-underlaydir=underlays/basewiki);
	push @command, qw(-set underlaydirbase=underlays -templatedir=templates);
	push @command, qw(t/tinypodcast), "$tmp/out";

	ok(! system("mkdir $tmp"), q{setup});
	ok(! system(@command), q{build});

	my $html = "$tmp/out/pianopost/index.html";

	my $body = _extract_html_content($html, 'content');
	like($body, qr/article has content and/m, q{html body text});

	my $enclosure = _extract_html_content($html, 'enclosure');
	like($enclosure, qr/Download this episode/m, q{html enclosure});

	my ($href) = _extract_html_links($html, 'piano');
	ok(-f $href, q{html enclosure exists});

	# XXX die if more than one enclosure is specified

	ok(! system("rm -rf $tmp $statedir"), q{teardown});
}

sub _extract_html_content {
	my ($file, $desired_id, $desired_tag) = @_;
	$desired_tag = 'div' unless defined $desired_tag;

	my $p = HTML::Parser->new(api_version => 3);
	my $content = '';

	$p->handler(start => sub {
		my ($tag, $self, $attr) = @_;
		return if $tag ne $desired_tag;
		return unless exists $attr->{id} && $attr->{id} eq $desired_id;

		$self->handler(text => sub {
			my ($dtext) = @_;
			$content .= $dtext;
		}, "dtext");

		$self->handler(end  => sub {
			my ($tag, $self) = @_;
			$self->eof if $tag eq $desired_tag;
		}, "tagname,self");
	}, "tagname,self,attr");

	$p->parse_file($file) || die $!;

	return $content;
}

sub _extract_html_links {
	my ($file, $desired_value) = @_;

	my @hrefs = ();

	my $p = HTML::LinkExtor->new(sub {
		my ($tag, %attr) = @_;
		return if $tag ne 'a';
		return unless $attr{href} =~ qr/$desired_value/;
		push(@hrefs, values %attr);
	}, getcwd() . '/' . $file);

	$p->parse_file($file);

	return @hrefs;
}

simple_podcast();
single_page_html();
