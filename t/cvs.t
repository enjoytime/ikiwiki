#!/usr/bin/perl
use warnings;
use strict;
use Test::More; my $total_tests = 10;
use IkiWiki;

my $dir = "/tmp/ikiwiki-test-cvs.$$";

sub _plan {
	my $can_plan = shift;

	my $cvs = `which cvs`; chomp $cvs;
	my $cvsps = `which cvsps`; chomp $cvsps;
	return plan(skip_all => 'cvs or cvsps not available')
		unless -x $cvs && -x $cvsps;

	foreach my $module (qw(File::ReadBackwards File::MimeInfo)) {
		eval qq{use $module};
		if ($@) {
			return plan(skip_all => "$module not available");
		}
	}

	return plan(skip_all => "can't create $dir: $!")
		unless mkdir($dir);

	return unless $can_plan;

	return plan(tests => $total_tests);
}

sub _startup {
	my $can_plan = shift;

	_plan($can_plan);
	_generate_minimal_config();
	_create_test_repo();
}

sub _shutdown {
	my $had_plan = shift;

	system "rm -rf $dir";
	done_testing() unless $had_plan;
}

sub _generate_minimal_config {
	%config = IkiWiki::defaultconfig();
	$config{rcs} = "cvs";
	$config{srcdir} = "$dir/src";
	$config{cvsrepo} = "$dir/repo";
	$config{cvspath} = "ikiwiki";
	IkiWiki::loadplugins();
	IkiWiki::checkconfig();
}

sub _create_test_repo {
	my $cvs = "cvs -d $config{cvsrepo}";
	my $dn = ">/dev/null";
	system "$cvs init $dn";
	system "mkdir $dir/$config{cvspath} $dn";
	system "cd $dir/$config{cvspath} && "
		. "$cvs import -m import $config{cvspath} VENDOR RELEASE $dn";
	system "rm -rf $dir/$config{cvspath} $dn";
	system "$cvs co -d $config{srcdir} $config{cvspath} $dn";
}

sub test_web_add_and_commit {
	my $message = "Added the first page";
	writefile('test1.mdwn', $config{srcdir}, readfile("t/test1.mdwn"));
	IkiWiki::rcs_add("test1.mdwn");
	IkiWiki::rcs_commit(
		file => "test1.mdwn",
		message => $message,
		token => "moo",
	);

	my @changes = IkiWiki::rcs_recentchanges(3);
	is(
		$#changes,
		0,
		q{1 total commit},
	);
	is(
		$changes[0]{message}[0]{"line"},
		$message,
		q{first line of most recent commit message matches},
	);
	is(
		$changes[0]{pages}[0]{"page"},
		"test1",
		q{first pagename from most recent commit matches},
	);

	# prevent web edits from attempting to create .../CVS/foo.mdwn
	# on case-insensitive filesystems, also prevent .../cvs/foo.mdwn
	# unless your "CVS" is something else and we've made it configurable
	# how much of the web-edit workflow are we actually testing?
	# because we want to test comments:
	# - when the first comment for page.mdwn is added, and page/ is
	#   created to hold the comment, page/ isn't added to CVS control,
	#   so the comment isn't either
	# - side effect for moderated comments: after approval they
	#   show up normally AND are still pending, too
	# - comments.pm treats rcs_commit_staged() as returning conflicts?
}

sub test_manual_add_and_commit {
	my $message = "Added the second page";
	writefile('test2.mdwn', $config{srcdir}, readfile("t/test2.mdwn"));
	system "cd $config{srcdir}"
		. " && cvs add test2.mdwn >/dev/null 2>&1";
	system "cd $config{srcdir}"
		. " && cvs commit -m \"$message\" test2.mdwn >/dev/null";

	my @changes = IkiWiki::rcs_recentchanges(3);
	is(
		$#changes,
		1,
		q{2 total commits},
	);
	is(
		$changes[0]{message}[0]{"line"},
		$message,
		q{first line of most recent commit message matches},
	);
	is(
		$changes[0]{pages}[0]{"page"},
		"test2",
		q{first pagename from most recent commit matches},
	);
	is(
		$changes[1]{pages}[0]{"page"},
		"test1",
		q{first pagename from second-most-recent commit matches},
	);

	# CVS commits run ikiwiki once for every committed file (!)
	# - commit_prep alone should fix this
	# CVS multi-dir commits show only the first dir in recentchanges
	# - commit_prep might also fix this?
	# CVS post-commit hook is amped off to avoid locking against itself
	# - commit_prep probably doesn't fix this... but maybe?
}

sub test_chdir_magic {
	# cvs.pm operations are always occurring inside $config{srcdir}
	# other ikiwiki operations are occurring wherever, and are unaffected
	# when are we bothering with "local $CWD" and when aren't we?
}

sub test_genwrapper {
	# testable directly? affects rcs_add, but are we exercising this?
}

sub test_checkconfig {
	# undef cvspath, expect "ikiwiki"
	# define cvspath normally, get it back
	# define cvspath in a subdir, get it back?
	# define cvspath with extra slashes, get sanitized version back
	# - yoink test_extra_path_slashes
	# undef cvs_wrapper, expect $config{wrappers} same size as before

	my $initial_cvspath = $config{cvspath};
	$config{cvspath} = "/ikiwiki//";
	IkiWiki::checkconfig();
	is(
		$config{cvspath},
		$initial_cvspath,
		q{rcs_recentchanges assumes checkconfig has sanitized cvspath},
	);
}

sub test_getsetup {
	# anything worth testing?
}

sub test_cvs_info {
	# inspect "Repository revision" (used in code)
	# inspect "Sticky Options" (used in tests to verify existence of "-kb")
}

sub test_cvs_run_cvs {
	# extract the stdout-redirect thing
	# - prove that it silences stdout
	# - prove that stderr comes through just fine
	# prove that when cvs exits nonzero (fail), function exits false
	# prove that when cvs exits zero (success), function exits true
	# always pass -f, just in case
	# steal from git.pm: safe_git(), run_or_{die,cry,non}
	# - open() instead of system()
	# always call cvs_run_cvs(), don't ever run 'cvs' directly
}

sub test_cvs_run_cvsps {
	# parameterize command like run_cvs()
	# expose config vars for e.g. "--cvs-direct -z 30"
	# always pass -x (unless proven otherwise)
	# always pass -b HEAD (configurable like gitmaster_branch?)
}

sub test_cvs_parse_cvsps {
	# extract method from rcs_recentchanges
	# document expected changeset format
	# document expected changeset delimiter
	# try: cvsps -q -x -p && ls | sort -rn | head -100
	# - benchmark against current impl (that uses File::ReadBackwards)
}

sub test_cvs_parse_log_accum {
	# add new, preferred method for rcs_recentchanges to use
	# teach log_accum to record commits (into transient?)
	# script cvsps to bootstrap (or replace?) commit history
	# teach ikiwiki-makerepo to set up log_accum and commit_prep
	# why are NetBSD commit mails unreliable?
	# - is it working for CVS commits and failing for web commits?
}

sub test_cvs_is_controlling {
	# with no args:
	# - if srcdir is in CVS, return true
	# - else, return false
	# with a dir arg:
	# - if dir is in CVS, return true
	# - else, return false
	# with a file arg:
	# - is there anything that wants the answer? if so, answer
	# - else, die
}

sub test_rcs_update {
	# can it assume we're under CVS control? or must it check?
	# anything else worth testing?
}

sub test_rcs_prepedit {
	# can it assume we're under CVS control? or must it check?
	# for existing file, returns latest revision in repo
	# - what's this used for? should it return latest revision in checkout?
	# for new file, returns empty string
}

sub test_rcs_commit {
	# can it assume we're under CVS control? or must it check?
	# if someone else changed the page since rcs_prepedit was called:
	# - try to merge into our working copy
	# - if merge succeeds, proceed to commit
	# - else, return page content with the conflict markers in it
	# commit:
	# - if success, return undef
	# - else, revert + return content with the conflict markers in it
	# git.pm receives "session" param -- useful here?
	# web commits start with "web commit {by,from} "
	# seeing File::chdir errors on commit?
}

sub test_rcs_commit_staged {
	# if commit succeeds, return undef
	# else, warn and return error message (really? or just non-undef?)
}

sub test_rcs_add {
	my $dir1 = "test3";
	my $dir2 = "test4/test5";
	ok(
		mkdir($config{srcdir} . "/$dir1"),
		qq{can make $dir1},
	);
	IkiWiki::rcs_add($dir1);
	IkiWiki::rcs_commit(
		file => $dir1,
		message => "shouldn't happen",
		token => "oom",
	);

	# can it assume we're under CVS control? or must it check?
	# add a top-level text file
	# - rcs_commit it
	# - inspect recentchanges: new change, no -kb
	# add a top-level dir
	# - test mustn't hang (does it hang if we comment out genwrapper?)
	# - inspect recentchanges: no new change
	# - rcs_commit it
	# - reinspect recentchanges: still no new change
	# add a text file in that dir
	# - rcs_commit_staged
	# - inspect recentchanges: new change, no -kb
	# add a top-level dir + add a binary file in it
	# - rcs_commit_staged
	# - inspect recentchanges: new change, yes -kb
	# add a top-level dir + subdir + add one text and one binary file in it
	# - rcs_commit_staged
	# - inspect recentchanges: one new change, two files, one -kb, one not

	# extract method: filetype-guessing
	# add a binary file, remove it, add a text file by same name, no -kb?
	# add a text file, remove it, add a binary file by same name, -kb?
}

sub test_rcs_remove {
	# can it assume we're under CVS control? or must it check?
	# remove a top-level file
	# - rcs_commit
	# - inspect recentchanges: one new change, file removed
	# remove two files (in different dirs)
	# - rcs_commit_staged
	# - inspect recentchanges: one new change, both files removed
}

sub test_rcs_rename {
	# can it assume we're under CVS control? or must it check?
	# rename a file in the same dir
	# - rcs_commit_staged
	# - inspect recentchanges: one new change, one file removed, one added
	# rename a file into a different dir
	# - rcs_commit_staged
	# - inspect recentchanges: one new change, one file removed, one added
	# rename a file into a not-yet-existing dir
	# - rcs_commit_staged
	# - inspect recentchanges: one new change, one file removed, one added
	# is it safe to use "mv"? what if $dest is somehow outside the wiki?
}

sub test_rcs_recentchanges {
	# can it assume we're under CVS control? or must it check?
	# don't worry whether we're called with a number (we always are)
	# other rcs tests already inspect much of the returned structure
	# CVS commits say "cvs" and get the right committer
	# web commits say "web" and get the right committer
	# - and don't start with "web commit {by,from} "
	# "nickname" -- can we ever meaningfully set this?

	# prefer log_accum, then cvsps, else die
	# run the high-level recentchanges tests 2x (once for each method)
	# - including in other test subs that check recentchanges?
}

sub test_rcs_diff {
	# can it assume we're under CVS control? or must it check?
	# in list context, return all lines (with \n), up to $maxlines if set
	# in scalar context, return the whole diff, up to $maxlines if set
}

sub test_rcs_getctime {
	# can it assume we're under CVS control? or must it check?
	# given a file, find its creation time, else return 0
	# first implement in the obvious way
	# then cache
}

sub test_rcs_getmtime {
	# can it assume we're under CVS control? or must it check?
	# given a file, find its modification time, else return 0
	# first implement in the obvious way
	# then cache
}

sub test_rcs_receive {
	pass(q{rcs_receive doesn't make sense for CVS});
}

sub test_rcs_preprevert {
	# can it assume we're under CVS control? or must it check?
	# given a patchset number, return structure describing what'd happen:
	# - see doc/plugins/write.mdwn:rcs_receive()
	# don't forget about attachments
}

sub test_rcs_revert {
	# can it assume we're under CVS control? or must it check?
	# given a patchset number, stage the revert for rcs_commit_staged()
	# if commit succeeds, return undef
	# else, warn and return error message (really? or just non-undef?)
}

sub main {
	my $default_test_methods = '^test_*';
	my $test_methods = defined $ENV{TEST_METHOD} 
			 ? $ENV{TEST_METHOD}
			 : $default_test_methods;

	_startup($test_methods eq $default_test_methods);
	$_->() foreach get_test_subs($test_methods);
	_shutdown($test_methods eq $default_test_methods);
}

main();

################################################################################
# don't want a dependency on Test::Class; do want a couple of its features

sub get_test_subs {
	my $re = shift;
	no strict 'refs';
	return map { \&{*$_} } grep { /$re/ } list_module('main');
}

# http://stackoverflow.com/questions/607282/whats-the-best-way-to-discover-all-subroutines-a-perl-module-has

use B qw/svref_2object/;

sub in_package {
	my ($coderef, $package) = @_;
	my $cv = svref_2object($coderef);
	return if not $cv->isa('B::CV') or $cv->GV->isa('B::SPECIAL');
	return $cv->GV->STASH->NAME eq $package;
}

sub list_module {
	my $module = shift;
	no strict 'refs';
	return grep {
		defined &{"$module\::$_"} and in_package(\&{*$_}, $module)
	} keys %{"$module\::"};
}
