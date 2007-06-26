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
		suite char(24) NOT NULL,
		arch char(32) NOT NULL,
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
	local _source="$2"
	case "$_comp" in
		devel|libdevel)
			echo "host-tools"
			yell "WARNING: section $_comp in package $_source"
			;;
		libs)
			echo "core"
			yell "WARNING: section $_comp in package $_source"
			;;
		*)
			echo "$_comp"
			;;
	esac
}

# get most recent package version from overrides.db
# $1 -- source package name
# $2 -- package suite name (optional)
# $3 -- arch name (optional)
override_get_pkg_version() {
	local _source="$1"
	local _suite="$2"
	local _arch="$3"

	local _condition="pkgname='$_source' and (arch='$_arch' or arch='')"
	if [ -n "$_suite" ]; then
		_condition="$_condition and suite='$_suite'"
	fi

	local _version=`$SQLCMD "SELECT version FROM overrides
		WHERE $_condition ORDER BY arch DESC LIMIT 1"`
	if [ -z "$_version" ]; then
		echo "Can't find $_pkgname version in overrides.db" >&2
		exit 1
	fi

	echo "$_version"
}

# get a list of suites for .deb package from overrides.db
# $1 -- source package name of .deb file
# $2 -- package version
# $3 -- arch name (optional)
# returns a list of suites
override_get_pkg_suites_list() {
	local _source="$1"
	local _version="$2"
	local _arch="$3"

	$SQLCMD "SELECT DISTINCT suite FROM overrides
			WHERE pkgname='$_source'
			AND version='$_version'
			AND (arch='$_arch' OR arch='')
			ORDER BY suite DESC"
}

#get a list of components for .deb package from overrides.db
# $1 -- source package name of .deb file
# $2 -- package version
# $3 -- arch name (optional)
override_get_pkg_componets_list() {
	local _source="$1"
	local _version="$2"
	local _arch="$3"

	$SQLCMD "SELECT DISTINCT component FROM overrides
			WHERE pkgname='$_source'
			AND version='$_version'
			AND (arch='$_arch' OR arch='')
			ORDER BY component DESC"
}

# match source package against overrides db
# $1 -- source package name of
# $2 -- package version
# returns a list of 'suite/component' path component
override_get_src_poolpath_list() {
	local _source="$1"
	local _pkgver="$2"

	$SQLCMD "SELECT DISTINCT suite || '/' || component FROM overrides
			WHERE pkgname='$_source'
			AND version='$_pkgver'"
}

# Produce a 'Sources' entry from .dsc.
# $1 -- path to .dsc file
# $2 -- path to Sources file
dsc_to_Sources() {
	local _dscfile="$1"
	local _sourcespath="$2"
	local _dscfilename="`echo -n $_dscfile | sed -e 's,^.*/,,'`"
	local _dscmd5="`md5sum $_dscfile | cut -d' ' -f1`"
	local _dscsz="`stat -c %s $_dscfile`"
	local _dscdir="`echo -n $_dscfile | sed -e 's,/[^/]*$,,' -e 's,^.*pool/,pool/,'`"

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

	local _value=`ar p $_debfile control.tar.gz | tar zxO ./control | \
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
	local _comp
	local _path

	local _version="`get_deb_header $_debfile Version`"
	local _arch="`get_deb_header $_debfile Architecture`"
	local _source="`get_deb_header $_debfile Source`"
	if [ -z "$_source" ]; then
		_source="`get_deb_header $_debfile Package`"
	fi

	local _path_list=`override_get_src_poolpath_list $_source $_version`
	if [ -z "$_path_list" ]; then
		yell "WARNING: cannot find $_source=$_version in" -n
		yell "overrides table, assuming suite=$DEVSUITE"

		local _comp="`get_deb_header $_debfile Section`"
		if [ -z "$_comp" ]; then
			yell "WARNING: package $_debfile lacks a " -n
			yell "'Section:' header, assuming 'core'"
			_comp=core
		else
			_comp="`translate_section $_comp $_source`"
		fi
		_path_list="$DEVSUITE/$_comp"
	fi

	for _path in $_path_list; do
		if [ "$_arch" = "all" ]; then
			for _a in $ARCHES; do
				echo "$_path/binary-$_a"
			done
		else
			echo "$_path/binary-$_arch"
		fi
	done
}

# determine where a given package belongs in a pool
# $1 -- path to .deb file
get_deb_poolpath() {
	local _debfile="$1"
	local _comp

	local _version="`get_deb_header $_debfile Version`"
	local _arch="`get_deb_header $_debfile Architecture`"
	local _source="`get_deb_header $_debfile Source`"
	if [ -z "$_source" ]; then
		_source="`get_deb_header $_debfile Package`"
	fi

	local _comp_list=`override_get_pkg_componets_list $_source $_version $_arch`
	if [ -z "$_comp_list" ]; then
		_comp_list="`get_deb_header $_debfile Section`"
		if [ -z "$_comp_list" ]; then
			yell "WARNING: package $_debfile lacks a " -n
			yell "'Section:' header, assuming 'core'"
			_comp_list=core
		fi
	fi

	_pkgprefix=`expr "$_source" : "\(lib.\|.\)"`
	for _comp in $_comp_list; do
		echo "pool/$_comp/$_pkgprefix/$_source"
	done
}

# output package's information (control) to a Packages file
# $1 -- path to .deb file
# $2 -- path to Packages
deb_to_Packages() {
	local _debfile="$1"
	local _packagespath="$2"
	local _debfilename="`echo -n $_debfile | sed -e 's,^.*/,,'`"
	local _debmd5="`md5sum $_debfile | cut -d' ' -f1`"
	local _debsz="`stat -c %s $_debfile`"
	local _debdir="`echo -n $_debfile | sed -e 's,/[^/]*$,,' -e 's,^.*pool/,pool/,'`"

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

