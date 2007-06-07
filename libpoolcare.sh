# Common functions for those who want to operate with slind
# pools, packages, indices, overrides and whatnot.

# Before sourcing this file, make sure you have set:
# * REPODIR -- root of your package repository
# * DEVSUITE -- name of 'CURRENT' suite, e.g. 'clydesdale'

DISTSDIR="$REPODIR/dists"
POOLDIR="$REPODIR/pool"
IDXDIR="$REPODIR/indices"
OVERRIDES_DB="$IDXDIR/overrides.db"
SQLCMD="sqlite3 $OVERRIDES_DB"

# initialize overrides database
mkoverrides() {
	$SQLCMD "create table overrides (
		pkgname varchar NOT NULL,
		version varchar NOT NULL,
		suite char(24),
		component varchar NOT NULL);"
	$SQLCMD "create table arch_overrides (
		pkgname varchar NOT NULL,
		version varchar NOT NULL,
		arch NOT NULL,
		suite char(24),
		component varchar NOT NULL);"
}

# throw a message to stderr
# $1 -- the message
# $2 -- optional echo flags (-n, -e, whatever)
yell() {
	echo $2 "$1" >&2
}

translate_section() {
	local _comp="$1"
	local _pkgname="$2"
	case "$_comp" in
		devel|libdevel)
			echo "host-tools"
			yell "WARNING: section $_comp in package $_pkgname"
			;;
		libs)
			echo "core"
			yell "WARNING: section $_comp in package $_pkgname"
			;;
		*)
			echo "$_comp"
			;;
	esac
}

# match source package against overrides db
# $1 -- source package name
# $2 -- source package version
# returns 'suite/component' path component
override_poolpath() {
	local _pkgname="$1"
	local _pkgver="$2"

	# 1. Check if this package/version record exists in db
	_overrid=`$SQLCMD "select suite from overrides
			    where pkgname='$_pkgname'
			      and version='$_pkgver'"`

	if [ -z "$_overrid" ]; then
		# -- it doesn't
		# 2.A. Check if some other version of the package is in
		# the current $DEVSUITE in db.
		_overrid=`$SQLCMD "select version from overrides
				    where pkgname='$_pkgname'
				      and suite='$DEVSUITE'"`
		if [ -n "$_overrid" ]; then
			# -- it is
			# 3.A.A. Compare our version with the one in the db
			yell "Warning: there is another version of " -n
			yell "$_pkgname ($_overrid) in $DEVSUITE."

			dpkg --compare-versions "$_pkgver" lt "$_overrid"
			if [ "$?" != "0" ]; then
				# -- our version is newer
				# 4.A.A.A. Put our version to $DEVSUITE and
				# move the older one to attic.
				yell "...but $_pkgver is newer, so moving " -n
				yell "$_overrid to attic"

				_comp=`$SQLCMD "select component from overrides
						 where pkgname='$_pkgname'"`
				$SQLCMD "update overrides
					    set version='$_pkgver'
					  where pkgname='$_pkgname'
					    and suite='$DEVSUITE';
					 insert into overrides
					 values ('$_pkgname', '$_overrid',
						 'attic', '$_comp')"
				# That is to say, our package/version is in
				# $DEVSUITE.
				_suite="$DEVSUITE"
			else 
				# -- our version is older than the one in db
				# 4.A.A.B. Put ourselves to 'attic' right away.
				_suite="attic"
			fi
		else
			# -- it is not: the package is new
			# 3.A.B. Add package/version to $DEVSUITE.
			yell "# adding $_pkgname=$_pkgver to overrides"
			$SQLCMD "insert into overrides values('$_pkgname', '$_pkgver', '$DEVSUITE', 'host-tools')"
			_suite="$DEVSUITE"
		fi
	else
		# -- it is
		# 2.B. Do nothing.
		yell "# $_pkgname=$_pkgver already in overrides"
		_suite="$_overrid"
	fi

	# Find the component
	_comp=`$SQLCMD "select component from overrides
			 where suite='$_suite'
			   and pkgname='$_pkgname'"`
	if [ -z "$_comp" ]; then
		_comp="host-tools"
	fi

	echo "$_suite/$_comp"
}

# Produce a 'Sources' entry from .dsc.
# $1 -- path to .dsc file
# $2 -- path to Sources file
dsc_to_Sources() {
	local _dscfile="$1"
	local _sourcespath="$2"
	_dscfilename="`echo -n $_dscfile | sed -e 's,^.*/,,'`"
	_dscmd5="`md5sum $_dscfile | cut -d' ' -f1`"
	_dscsz="`stat -c %s $_dscfile`"
	_dscdir="`echo -n $_dscfile | sed -e 's,/[^/]*$,,' -e 's,^.*pool/,pool/,'`"

	gawk                               \
		-v dscmd5="$_dscmd5"       \
		-v dscsz="$_dscsz"         \
		-v dscfile="$_dscfilename" \
		-v dscdir="$_dscdir"       \
	'END { printf "\n"; }
	/^Files: / {
		printf "Directory: %s\n", dscdir;
		printf "Files:\n %s %s %s\n", dscmd5, dscsz, dscfile;
		next;
	}
	// {
		if ($1 == "Source:")
			printf "Package: %s\n", $2;
		else
			print $0;
	}'     \
		< "$_dscfile" \
		>> "$_sourcespath/Sources"

	gzip -c9                                              \
		< "$_sourcespath/Sources"   \
		> "$_sourcespath/Sources.gz"
}

# get a header from .deb package's control file
# $1 -- path to .deb file
# $2 -- header name
get_deb_header() {
	local _debfile="$1"
	local _hdr="$2"

	_value=`ar p $_debfile control.tar.gz | tar zxO ./control | \
		grep "^${_hdr}: " | cut -d' ' -f2`
	if [ "$_hdr" = "Version" ]; then
		_value=`echo $_value | sed -e 's,^[^:]*:,,'`
	fi

	echo "$_value"
}

# guess a dist/ path to Package file where information about
# the given package should be written
# $1 -- path to .deb file
get_deb_distpath() {
	local _debfile="$1"

	_source="`get_deb_header $_debfile Source`"
	if [ -z "$_source" ]; then
		_tmp="`dirname $_debfile`"
		_source="`get_deb_header $_debfile Package`"
	fi

	_comp="`get_deb_header $_debfile Section`"
	if [ -z "$_comp" ]; then
		yell "WARNING: package $_debfile lacks a " -n
		yell "'Section:' header, assuming 'core'"
		_comp=core
	fi

	_version="`get_deb_header $_debfile Version`"
	_arch="`get_deb_header $_debfile Architecture`"
	_suite=`$SQLCMD "select suite from overrides
			  where pkgname='$_source'
			    and version='$_version'"`
	if [ -z "$_suite" ]; then
		yell "WARNING: cannot find $_source=$_version in" -n
		yell "overrides table, assuming $DEVSUITE"
		_suite="$DEVSUITE"
	fi
	#yell "#### $_debfile: [$_comp] [$_suite] [$_source] [$_version]"

	_comp="`translate_section $_comp $_source`"
	if [ "$_arch" = "all" ]; then
		for _arch in $ARCHES; do
			echo "$_suite/$_comp/binary-$_arch"
		done
	else
		echo "$_suite/$_comp/binary-$_arch"
	fi
}

# determine where a given package belongs in a pool
# $1 -- path to .deb file
get_deb_poolpath() {
	local _debfile="$1"

	_comp="`get_deb_header $_debfile Section`"
	if [ -z "$_comp" ]; then
		yell "WARNING: package $_debfile lacks a " -n
		yell "'Section:' header, assuming 'core'"
		_comp=core
	fi

	_source="`get_deb_header $_debfile Source`"
	if [ -z "$_source" ]; then
		_tmp="`dirname $_debfile`"
		_source="`basename $_tmp`"
		yell "WARNING: package $_debfile lacks a " -n
		yell "'Source:' header, assuming '$_source'"
	fi

	_comp_overrid=`$SQLCMD "select component from overrides
				 where pkgname='$_source'
				   and version='$_version'"`
	if [ -n "$_comp_overrid" ]; then
		_comp="$_comp_overrid"
	fi

	_pkgprefix=`expr "$_source" : "\(lib.\|.\)"`
	echo "pool/$_comp/$_pkgprefix/$_source"
}

# output package's information (control) to a Packages file
# $1 -- path to .deb file
# $2 -- path to Packages
deb_to_Packages() {
	local _debfile="$1"
	local _packagespath="$2"
	_debfilename="`echo -n $_debfile | sed -e 's,^.*/,,'`"
	_debmd5="`md5sum $_debfile | cut -d' ' -f1`"
	_debsz="`stat -c %s $_debfile`"
	_debdir="`echo -n $_debfile | sed -e 's,/[^/]*$,,' -e 's,^.*pool/,pool/,'`"

	ar p $_debfile control.tar.gz | tar zxO ./control | \
	gawk                               \
		-v debmd5="$_debmd5"       \
		-v debsz="$_debsz"         \
		-v debfile="$_debfilename" \
		-v debdir="$_debdir"       \
	'END { printf "\n"; }
	/^Description: / {
		printf "Filename: %s/%s\n", debdir, debfile;
		printf "Size: %s\n", debsz;
		printf "MD5sum: %s\n", debmd5;
		printf "%s\n", $0;
		next;
	}
	// {
		print $0;
	}'     \
		>> "$_packagespath/Packages"

	gzip -c9                              \
		< "$_packagespath/Packages"   \
		> "$_packagespath/Packages.gz"
}

