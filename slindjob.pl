#!/usr/bin/perl

use Config::IniFiles;
use DBD::SQLite;
use DBI;
use Data::Dumper;

# open user's slind-config.ini
our $scfg = new Config::IniFiles
	-file => '/etc/slind/slind-config.ini',
	-allowcontinue => 1;

our $LOGTIME = timestamp();
our $LOGFILE = "/tmp/slindjob-$LOGTIME";
our $REPORTFILE = "/tmp/slindjob_maillog";
our $pkglistdir = $scfg->val('slindjob', 'chr_pkglist_dir');
our $gitrepos = $scfg->val('maintainer-common', 'chr_gitrepos_dir');
our $repodir = $scfg->val('maintainer-common', 'chr_repodir');
our $archlist = $scfg->val('target', 'target_arch');
our $suite = $scfg->val('common', 'slind_suite');
our $sudo = $scfg->val('common', 'root_cmd');
our @toolchain = qw/binutils gcc.* glibc uclibc linux-kernel-headers gdb pkg-config/;
our $since = '2005/01/01';
our $pretty = 'short';
our $maxth = '5'; # XXX: this should be defined in slind-config.ini as well
our @pkglist_all, @pkglist_build, @pkglist_host, $rebuild_toolchains = 0;

# path to overrides.db
our $ovpath = $repodir. "/indices/overrides.db";
unless (-f $ovpath) {
	print "No overrides db found.\n";
	exit 1;
}

# db handle
our $ovh = DBI->connect("dbi:SQLite:dbname=$ovpath", "", "");
unless (-f $ovpath) {
	print "Can't open overrides db\n";
	exit 1;
}

# set proxies, if we have to
$ENV{http_proxy} = $scfg->val('common', 'http_proxy_url')
	if $scfg->val('common', 'http_proxy_url');
$ENV{ftp_proxy} = $scfg->val('common', 'ftp_proxy_url')
	if $scfg->val('common', 'ftp_proxy_url');

our $rootcmd = "sudo env http_proxy=". $ENV{http_proxy} . " ftp_proxy=" . $ENV{ftp_proxy} . " ";

our $comp = 'core debug security gui';
our %rootfs = (
#	'base'   => '',
	'normal' => 'tcpdump nvi',
#	'bloat'  => 'nvi strace tcpdump joe',
);

# read in the time and date of last build run
if (-e "$repodir/scripts/timestamp") {
	open F, "$repodir/scripts/timestamp";
	{ local $/; $since = <F> }
	close F;
}

# write out current time and date for future build runs
open F, ">$repodir/scripts/timestamp";
print F timespec();
close F;

chomp $since;
logmsg("Building \"$suite\" ($LOGTIME).\nLast build date: $since.\n");

update_all();

logmsg("Host-packages to be rebuilt during this run: ".
	join(', ', @pkglist_host). "\n");
logmsg("Packages to be rebuilt during this run: ".
	join(', ', @pkglist_build). "\n");
logmsg("Architectures: $archlist\n");
logmsg("For datailed per-package per-architecture build logs, see ".
	"http://ftp.slind.org/pub/SLIND/logs/$LOGTIME/\n");

# write a list of packages to be rebuilt
open F, ">$repodir/indices/cheburashka.list";
print F join("\n", @pkglist_build);
close F;

# do rebuild
rebuildall();

logmsg("Build finished at ". timespec(). "\n");

exit 0;

logmsg("Building rootfs images\n");
for $rn (keys %rootfs) {
	mkrootfs('i386', $rn, $rootfs{$rn});
	for $a (split / /, $archlist) {
		mkrootfs($a, $rn, $rootfs{$rn});
	}
}

exit 0;

sub logmsg
{
	my $msg = shift;

	open RF, ">>$REPORTFILE" || die "Can't open $REPORTFILE";
	print RF "$msg";
	close RF;
	print "$msg";
}

# execute a command and report if it succeeded or failed
sub spawn
{
	my ($cmd, $msg) = @_;

	$msg = "executing $cmd" unless $msg;
	logmsg("$msg... ");

	my $ret = system("$cmd >> $LOGFILE 2>&1");
	logmsg($ret ? "FAILED\n" : "OK\n");

	return $ret;
}

# call git-log to see if there are any new changes
# $_[0] -- package name
sub gitlog
{
	my $pkgname = shift;
	my $log;

	$ENV{GIT_DIR} = "$gitrepos/$pkgname/.git";
	#print "git log --since='$since' --pretty=$pretty\n";
	open P, "git log --since='$since' --pretty=$pretty |";
	{ local $/; $log = <P> }
	close P;
	delete $ENV{GIT_DIR};

	return 0 unless length $log;

	$log = `echo "$log" | git-shortlog`;
	open Q, ">>/tmp/slindjob_mailstat";
	print Q "$pkgname:\n$log\n";
	close Q;
	print $pkgname, "\n";
	return 1;
}

# update all known git repos and see which ones have changes
# since the time we last updated
sub update_all
{
	# obtain all package names known to overrides.db
	my $sth = $ovh->prepare(
		"SELECT DISTINCT(pkgname), 'host-tools' FROM overrides
		  WHERE component='host-tools' UNION
		 SELECT DISTINCT(pkgname), 'other' FROM overrides
		  WHERE component != 'host-tools' ORDER BY pkgname");
	$sth->execute();

	my $row;
	while (defined ($row = $sth->fetchrow_arrayref())) {
		my $pkg = $row->[0];
		push(@pkglist_all, $pkg) if $row->[1] ne 'host-tools';

		spawn("grasp update $pkg", "Updating $pkg package");
		spawn("grasp build $pkg", "Building $pkg source package");
		my $changed = gitlog($pkg);
		if ($row->[1] eq 'host-tools') {
			foreach $regex (@toolchain) {
				if ($pkg =~ /$regex/) {
					$rebuild_toolchains += $changed;
					goto END_TOOLS;
				}
			}
			push @pkglist_host, $pkg;
			END_TOOLS:
		} else {
			push @pkglist_build, $pkg if $changed;
		}
	}

	spawn("slindak -r $repodir -F");
	spawn($rootcmd . "apt-get update");
}

sub restoretoolchain
{
	my $hostarch = `dpkg-architecture -qDEB_BUILD_ARCH 2>/dev/null`;
	chomp $hostarch;

	my $deps;
	open P, "apt-cache show $hostarch-toolchain |";
	while (<P>) {
		if (m/Depends: (.*)/) {
			$deps = $1;
		}
	}
	close P;
	if ($? == 0 && $deps ne "") {
		die ("Can't parse depends: $deps") unless ($deps =~ /.*g\+\+-([^-,]*)-([^ ,]*)[ ,].*/);
		spawn("sudo apt-get --purge remove --yes --force-yes cpp-$1-$2 binutils-$2 pkg-config-$2 libc6-$hostarch-cross",
				"Removing current toolchain");
		spawn($rootcmd . "apt-get install " .
				"--yes --force-yes g++", "Installing host toolchain");
	}
}

# rebuild anything that must be rebuilt
sub rebuildall
{
	my ($pid, $arch);
	my $th = 0;
	my %pidhash;
	my $pkg;

	restoretoolchain();

	system("rm -rf /tmp/build");
	mkdir("/tmp/build");
	foreach $pkg (@pkglist_host) {
		spawn("cd /tmp/build && fakeroot apt-get --compile source $pkg",
					"Rebuilding host package $pkg");
	}

	my @hostpkgs;
	opendir TD, "/tmp/build";
	while ($pkg = readdir(TD)) {
		next unless $pkg =~ m/([^_]*).*\.deb$/;
		# toolchain package neeeds some additional care
		push(@hostpkgs, $1) unless ($1 eq "toolchain-package");
		system("slindak -r $repodir -i /tmp/build/$pkg -s $suite");
	}
	closedir TD;

	# update repository indices
	spawn("slindak -r $repodir -F");
	spawn($rootcmd . "apt-get update");
	spawn($rootcmd . "apt-get install " .
				"--yes --force-yes " .
				join(' ', @hostpkgs));


	if ($rebuild_toolchains) {
		# This could fail in maintainer-like mode
		spawn($rootcmd . "apt-get install " .
				"--yes --force-yes toolchain-package");
		for $arch (split / /, $archlist) {
			$ENV{SETNJOBS} = $maxth;
			$ENV{USENJOBS} = $maxth;

			# build toolchain for $arch
			spawn("env SETNJOBS=$maxth USENJOBS=$maxth mktpkg --force $arch $suite");

			# deliver built packages to $repodir
			my $pkg;
			opendir TD, "/tmp/tpkg";
			while ($pkg = readdir(TD)) {
				next unless $pkg =~ m/\.deb$/;
				system("slindak -r $repodir -i /tmp/tpkg/$pkg ".
					"-s $suite");
			}
			closedir TD;

			# We may have replaced the toolchain. Restore it.
			restoretoolchain();
		}

		# update repository indices
		system("slindak -r $repodir -F");
	}

	my $hostarch = `dpkg-architecture -qDEB_BUILD_ARCH 2>/dev/null`;
	chomp $hostarch;

	# install binary toolchains
	spawn($rootcmd . "apt-get update");
	spawn($rootcmd . "apt-get install --yes --force-yes ".
		join(' ', map {
			"$_-cross-toolchain"
		} split / /, $archlist));
	if ($archlist =~ /$hostarch/) {
		spawn($rootcmd . "apt-get install --yes --force-yes $hostarch-toolchain");
	}

	for $arch (split / /, $archlist) {
retry:
		if ($th < $maxth) {
			# start a child process to build the world for us
			$pid = fork();
			unless ($pid) {
				print "--- running northern-cross for $arch ---\n";
				spawn("northern-cross world --arch $arch --path $repodir --suite $suite --rrevdep --logdir $repodir/logs/$LOGTIME/nc_$arch");
				exit 0;
			} else {
				$pidhash{$pid} = $arch;
				$th++;
			}
		} else {
			# wait for the first child to return
			$pid = waitpid -1, 0;
			print "# reaping $pidhash{$pid} ($pid, $th)\n";
			delete $pidhash{$pid};
			$th-- if $th;
			goto retry;
		}
	}

	# wait until the last child has returned
	while ($th) {
		$pid = waitpid -1, 0;
		print "# reaping $pidhash{$pid} ($pid, $th)\n";
		delete $pidhash{$pid};
		$th-- if $th;
	}

	# make sure the indices are consistent
	system("slindak -r $repodir -C");
	system("slindak -r $repodir -F");
}

sub mkrootfs
{
	my ($arch, $name, $pkglist) = @_;
	my $buildcpuarch = `dpkg-architecture -qDEB_BUILD_GNU_CPU 2>/dev/null`;
	my $hostcpuarch = `dpkg-architecture -f -a$arch -qDEB_HOST_GNU_CPU 2>/dev/null`;
	my $deboscript = "/usr/lib/slind-core/debootstrap/$suite";

	chomp $buildcpuarch;
	chomp $hostcpuarch;
	#print "## $buildcpuarch vs $hostcpuarch\n";
	print '='x79, "\nBuilding $arch rootfs [$name]\n", '='x79, "\n";

	open SL, ">/tmp/s.l";
	print SL "deb file:///repo $suite $comp\n";
	close SL;

	if ($buildcpuarch eq $hostcpuarch) {
		spawn("$sudo rm -rf /rootfs-$arch");
		return
			if spawn("$sudo debootstrap --components=core $suite ".
			"/rootfs-$arch file://$repodir $deboscript");

		spawn("$sudo mkdir -p /rootfs-$arch/repo");
		spawn("$sudo mount --bind $repodir /rootfs-$arch/repo");
		spawn("$sudo mv /tmp/s.l /rootfs-$arch/etc/apt/sources.list");

		if ($pkglist) {
			spawn("$sudo chroot /rootfs-$arch apt-get update");
			spawn("$sudo chroot /rootfs-$arch apt-get install ".
				"--yes --force-yes $pkglist");
		}
		spawn("$sudo chroot /rootfs-$arch apt-get clean");
		spawn("$sudo umount /rootfs-$arch/repo");
		spawn("$sudo tar cf /build/rootfs-$arch.tar /rootfs-$arch");
		spawn("$sudo chown build /build/rootfs-$arch.tar");
		spawn("$sudo chmod u+s /rootfs-$arch/sbin/ldconfig");
	} else {
		spawn("rm -rf /rootfs-$arch/*");
		spawn("$sudo mkdir -p /rootfs-$arch");
		spawn("$sudo chown -R build /rootfs-$arch");
		return if spawn("cross-shell bs $arch");
		spawn("rm -rf /rootfs-$arch/repo");
		spawn("ln -sf $repodir /rootfs-$arch/repo");
		spawn("mv -f /tmp/s.l /rootfs-$arch/etc/apt/sources.list");
		spawn("cross-shell apt $arch $pkglist") if $pkglist;
		spawn("cross-shell pack $arch");
	}

	rename "/build/rootfs-$arch.tar", "/build/rootfs-$arch-$name.tar";
}

# return current date and time in a manner suitable for
# filename suffix
sub timestamp
{
	my @lt = localtime(time);
	return sprintf("%04d%02d%02d_%02d%02d",
		($lt[5] + 1900), ($lt[4] + 1), $lt[3], $lt[2], $lt[1]);
}

# return current date and time in a human readable form
# (or, acceptable by --since of git-log)
sub timespec
{
	my @lt = localtime(time);
	return sprintf("%04d/%02d/%02d %02d:%02d",
		$lt[5] + 1900, $lt[4] + 1, $lt[3], $lt[2], $lt[1]);
}

