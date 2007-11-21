#!/usr/bin/perl

use Config::IniFiles;
use Data::Dumper;

# open user's slind-config.ini
our $scfg = new Config::IniFiles
	-file => $ENV{HOME}. '/.slind/slind-config.ini',
	-allowcontinue => 1;

our $LOGFILE = "/tmp/slindjob-" . timestamp();
our $REPORTFILE = "/tmp/slindjob_maillog";
our $pkglistdir = $scfg->val('slindjob', 'chr_pkglist_dir');
our $gitrepos = $scfg->val('maintainer-common', 'chr_gitrepos_dir');
our $repodir = $scfg->val('maintainer-common', 'chr_repodir');
our $archlist = $scfg->val('target', 'target_arch');
our $suite = $scfg->val('common', 'slind_suite');
our $sudo = $scfg->val('common', 'root_cmd');
our $since = '2005/01/01';
our $pretty = 'short';
our $maxth = '5'; # XXX: this should be defined in slind-config.ini as well
our @pkglist_all, @pkglist_build, $rebuild_toolchains = 0;

# set proxies, if we have to
$ENV{http_proxy} = $scfg->val('common', 'http_proxy_url')
	if $scfg->val('common', 'http_proxy_url');
$ENV{ftp_proxy} = $scfg->val('common', 'ftp_proxy_url')
	if $scfg->val('common', 'ftp_proxy_url');

our $comp = 'core debug security gui';
our %rootfs = (
	'base'   => '',
	'normal' => 'tcpdump nvi',
	'bloat'  => 'nvi strace tcpdump joe',
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

print "since: $since\n";

update_all();

# write a list of packages to be rebuilt
open F, ">$repodir/indices/cheburashka.list";
print F join("\n", @pkglist_build);
close F;

# do rebuild
rebuildall();

for $rn (keys %rootfs) {
	mkrootfs('i386', $rn, $rootfs{$rn});
	for $a (split / /, $archlist) {
		mkrootfs($a, $rn, $rootfs{$rn});
	}
}

exit 0;

# execute a command and report if it succeeded or failed
sub spawn
{
	my ($cmd, $msg) = @_;

	$msg = "executing $cmd" unless $msg;

	print "$msg... ";
	my $ret = system("$cmd >> $LOGFILE 2>&1");
	print ($ret ? "FAILED\n" : "OK\n");

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
	opendir LD, $pkglistdir;

	my $file;
	while ($file = readdir(LD)) {
		next unless $file =~ m/\.pkglist$/;
		open F, "$pkglistdir/$file";

		my $pkg;
		while ($pkg = <F>) {
			chomp $pkg;
			print ">>>>> $pkg <<<<<\n";
			push(@pkglist_all, $pkg) if $file ne 'host-tools.pkglist';

			spawn("grasp update $pkg", "Updating $pkg package");
			spawn("grasp build $pkg", "Building $pkg source package");
			my $changed = gitlog($pkg);
			if ($file eq 'host-tools.pkglist') {
				$rebuild_toolchains += $changed;
			} else {
				push @pkglist_build, $pkg if $changed;
			}
		}

		close F;
	}

	closedir LD;
	system("slindak -r $repodir -F");
	system("sudo env http_proxy=". $ENV{http_proxy}. " apt-get update");
}

# rebuild anything that must be rebuilt
sub rebuildall
{
	my ($pid, $arch);
	my $th = 0;
	my %pidhash;

	if ($rebuild_toolchains) {
		for $arch (split / /, $archlist) {
			$ENV{SETNJOBS} = $maxth;
			$ENV{USENJOBS} = $maxth;

			# build toolchain for $arch
			spawn("env SETNJOBS=$maxth USENJOBS=$maxth mktpkg --force $arch clydesdale");

			# deliver built packages to $repodir
			my $pkg;
			opendir TD, "/tmp/tpkg";
			while ($pkg = readdir(TD)) {
				next unless $pkg =~ m/\.deb$/;
				system("slindak -r $repodir -i /tmp/tpkg/$pkg ".
					"-s $suite");
			}
			closedir TD;
		}

		# update repository indices
		system("slindak -r $repodir -F");
	}

	for $arch (split / /, $archlist) {
retry:
		if ($th < $maxth) {
			# start a child process to build the world for us
			$pid = fork();
			unless ($pid) {
				print "--- running northern-cross for $arch ---\n";
				system("northern-cross world --arch $arch --path $repodir --rrevdep --logdir $repodir/logs/nc_$arch");
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
	return ($lt[5] + 1900). ($lt[4] + 1).$lt[3]. '_'. $lt[2].$lt[1];
}

# return current date and time in a human readable form
# (or, acceptable by --since of git-log)
sub timespec
{
	my @lt = localtime(time);
	return ($lt[5] + 1900). '/'. ($lt[4] + 1). '/' .$lt[3]. 
		' '. $lt[2]. ':'. $lt[1];
}

