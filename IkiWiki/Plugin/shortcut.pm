#!/usr/bin/perl
package IkiWiki::Plugin::shortcut;

use warnings;
use strict;
use IkiWiki;

sub import { #{{{
	hook(type => "checkconfig", id => "shortcut", call => \&checkconfig);
	hook(type => "preprocess", id => "shortcut", call => \&preprocess_shortcut);
} #}}}

sub checkconfig () { #{{{
	# Preprocess the shortcuts page to get all the available shortcuts
	# defined before other pages are rendered.
	IkiWiki::preprocess("shortcuts", "shortcuts",
		readfile(srcfile("shortcuts.mdwn")));
} # }}}

sub preprocess_shortcut (@) { #{{{
	my %params=@_;

	if (! defined $params{name} || ! defined $params{url}) {
		return "[[shortcut missing name or url parameter]]";
	}

	hook(type => "preprocess", no_override => 1, id => $params{name},
		call => sub { shortcut_expand($params{url}, $params{desc}, @_) });

	return "shortcut $params{name} points to $params{url}";
} # }}}

sub shortcut_expand ($$@) { #{{{
	my $url=shift;
	my $desc=shift;
	my %params=@_;

	# Get params in original order.
	my @params;
	while (@_) {
		my $key=shift;
		my $value=shift;
		push @params, $key if ! length $value;
	}

	# If the shortcuts page changes, all pages that use shortcuts will
	# need to be updated.
	add_depends($params{destpage}, "shortcuts");

	my $text=join(" ", @params);
	my $encoded_text=$text;
	$encoded_text=~s/([^A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg;
	
	if (defined $desc) {
		$desc=~s/\%s/$text/g;
	}
	else {
		$desc=$text;
	}

	$url=~s/\%s/$encoded_text/g;
	return "<a href=\"$url\">$desc</a>";
} #}}}

1
