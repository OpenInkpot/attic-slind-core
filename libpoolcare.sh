# Common functions for those who want to operate with slind
# pools, packages, indices, overrides and whatnot.

# Before sourcing this file, make sure you have set:
# * REPODIR  -- root of your package repository
# * DEVSUITE -- name of 'CURRENT' suite, e.g. 'clydesdale'
# * ARCHES   -- list of supported architectures

DISTSDIR="$REPODIR/dists"
POOLDIR="$REPODIR/pool"
IDXDIR="$REPODIR/indices"
OVERRIDES_DB="$IDXDIR/overrides.db"
SQLCMD="sqlite3 $OVERRIDES_DB"

# initialize overrides database
mkoverrides() {
	mkdir -p $IDXDIR
	$SQLCMD "create table overrides (
		pkgname varchar NOT NULL,
		version varchar NOT NULL,
		suite char(24) NOT NULL,
		arch char(32) NOT NULL,
		component varchar NOT NULL, UNIQUE (pkgname, version, suite, arch));
		
		create table binary_cache (
		pkgname varchar NOT NULL,
		version varchar NOT NULL,
		suite char(24) NOT NULL,
		arch char(32) NOT NULL,
		deb_name varchar NOT NULL,
		deb_arch varchar NOT NULL,
		deb_size int NOT NULL,
		deb_md5sum char(32) NOT NULL,
		deb_control text NOT NULL,
		deb_section varchar NOT NULL,
		UNIQUE (pkgname, version, suite, arch, deb_name, deb_arch));
		"
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

#get a list of available arches for packages
# $1 -- source package name of .deb file
# $2 -- package version
# $3 -- package suite name
override_get_pkg_arches_list() {
	local _source="$1"
	local _version="$2"
	local _suite="$3"

	$SQLCMD "SELECT DISTINCT version || ' ' || arch FROM overrides
			WHERE pkgname='$_source'
			AND suite='$_suite'
			ORDER BY version" | \
	gawk	-v pkgname=$_source		\
		-v req_version=$_version	\
		-v all_arches_list="$ARCHES"	\
	'BEGIN{
		cnt = split(all_arches_list, tmp);
		for(i = 1; i <= cnt; i++) all_arches[tmp[i]] = "";
	}
	($1 == req_version){
		if (NF == 2) and_arches[$2] = "yes";
		else for(arch in all_arches) and_arches[arch] = "yes";
	}
	(($1 != req_version) && (NF == 2)){
		not_arches[$2] = "yes";
	}
	END{
		for(arch in and_arches)
			if (!(arch in not_arches)) print(arch);
	}'
}

#get a list of components for .deb package from overrides.db
# $1 -- source package name of .deb file
# $2 -- package version
# $3 -- package suite name
# $4 -- arch name (optional)
override_get_pkg_componets_list() {
	local _source="$1"
	local _version="$2"
	local _suite="$3"
	local _arch="$4"

	if [ "$_arch" = "" ]; then
		_arch="all"
	fi

	$SQLCMD "SELECT DISTINCT version || ' ' || component || ' ' || arch FROM overrides
			WHERE pkgname='$_source'
			AND suite='$_suite'
			ORDER BY version" | \
	gawk	-v pkgname=$_source		\
		-v req_version=$_version	\
		-v req_arch=$_arch		\
		-v all_arches_list="$ARCHES"	\
	'BEGIN{
		cnt = split(all_arches_list, tmp);
		for(i = 1; i <= cnt; i++) all_arches[tmp[i]] = "";
	}
	($1 == req_version){
		if (NF == 3){
			and_arches[$3] = "yes";
			component[$3] = $2;
		}else for(arch in all_arches){
			and_arches[arch] = "yes";
			component[arch] = $2;
		}
	}
	(($1 != req_version) && (NF == 3)){
		not_arches[$3] = "yes";
	}
	END{
		for(arch in and_arches){
			if (arch in not_arches) continue;
			if ((req_arch == "all") || (req_arch == arch))
				result[component[arch]] = "";
		}
		for(comp in result) print(comp);
	}'
}

# match source package against overrides db
# $1 -- source package name of
# $2 -- package version
# returns a list of 'suite/component' path component
override_get_src_poolpath_list() {
	local _source="$1"
	local _version="$2"

	$SQLCMD "SELECT DISTINCT suite || '/' || component FROM overrides
			WHERE pkgname='$_source'
			AND version='$_version'"
}

# add new record to overrides db
# $1 -- source package name of .deb file
# $2 -- package version
# $3 -- package suite name
# $4 -- arch (optional)
# $5 -- component (optional)
override_insert_new_record(){
	local _source="$1"
	local _version="$2"
	local _suite="$3"
	local _arch="$4"
	local _component="$5"

	if [ "$_arch" = "all" ]; then
		_arch=""
	fi

	if [ -z "$_component" ]; then
		_component="host-tools"
	fi

	yell "# adding $_source=$_version to suite='$_suite', component='$_component', arch='$_arch' in overrides"
	$SQLCMD "INSERT INTO overrides (pkgname, version, suite, arch, component) VALUES('$_source', '$_version', '$_suite', '$_arch', '$_component')"
}

# update package version in overrides db
# $1 -- source package name of .deb file
# $2 -- old package version
# $3 -- package suite name
# $4 -- new package version
override_update_package_version(){
	local _source="$1"
	local _version="$2"
	local _suite="$3"
	local _new_version="$4"

	yell "# update $_source=$_version from suite='$_suite' to version=$_new_version in overrides"
	$SQLCMD "UPDATE overrides SET version='$_new_version'
			WHERE pkgname='$_source'
			AND version='$_version'
			AND suite='$_suite'"
}

# try to add package to overrides db
# $1 -- source package name of .deb file
# $2 -- package version
# $3 -- package suite name
# returns FAIL on failure and OK on success
override_try_add_package(){
	local _source="$1"
	local _version="$2"
	local _suite="$3"
	local _version_count=0
	local _count=0
	local _ver
	local _arch
	local _comp
	local _i
	

	# Get (version, arch, component) for required (source, suite) and store
	# them to separate arrays.
	$SQLCMD "SELECT version || ' ' || component || ' ' || arch FROM overrides 
			WHERE pkgname='$_source'
			AND suite='$_suite'" \
	| (
		while read _ver[$_count] _comp[$_count] _arch[$_count]; do
			_count=$((_count+1))
		done


		# get a number of different versions of package
		for((_i=0;_i<_count;_i++)); do
			_version_count=1
			if [ "${_ver[0]}" != "${_ver[$_i]}" ]; then
				_version_count=2
				break
			fi
		done

		if [ "$_version_count" -gt 1 ]; then
			# too many record for package, resolve this situation manually
			yell "WARNING: too many suitable records, can't update overrides for source package $_source=$_version"
			echo "FAIL"
		elif [ "$_version_count" -eq 1 ]; then
			dpkg --compare-versions "$_version" gt "${_ver[0]}"
			if [ "$?" = "0" ]; then
				# the package is newer than current, add it to requited 
				# suite and move older one to "attic"
				override_update_package_version $_source ${_ver[0]} $_suite $_version
				for((_i=0;_i<_count;_i++)); do
					override_insert_new_record $_source ${_ver[$_i]} "attic" "${_arch[$_i]}" "${_comp[$_i]}"
				done
			elif [ "$_version" = "${_ver[0]}" ]; then
				# the package is the same, do nothing
				true
			else
				# the package is older than current, add it to "attic"
				for((_i=0;_i<_count;_i++)); do
					override_insert_new_record $_source $_version "attic" "${_arch[$_i]}" "${_comp[$_i]}"
				done
			fi
			echo "OK"
		else
			# the package is new, add it to required suite for all arches.
			override_insert_new_record $_source $_version $_suite
			echo "OK"
		fi
	)
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
# $2 -- suite
get_deb_distpath() {
	local _debfile="$1"
	local _suite="$2"
	local _arches_list
	local _a
	local _comp

	local _version="`get_deb_header $_debfile Version`"
	local _arch="`get_deb_header $_debfile Architecture`"
	local _source="`get_deb_header $_debfile Source`"
	if [ -z "$_source" ]; then
		_source="`get_deb_header $_debfile Package`"
	fi

	local _comp_list=`override_get_pkg_componets_list $_source $_version $_suite $_arch`
	if [ -z "$_comp_list" ]; then
		yell "WARNING: package $_debfile does not match override.db"
		return
	fi

	for _comp in $_comp_list; do
		if [ "$_arch" = "all" ]; then
			_arches_list=`override_get_pkg_arches_list $_source $_version $_suite`
			for _a in $_arches_list; do
				echo "$_path/binary-$_a"
			done
		else
			echo "$_suite/$_comp/binary-$_arch"
		fi
	done
}

# determine where a given package belongs in a pool
# $1 -- path to .deb file
# $2 -- suite
get_deb_poolpath() {
	local _debfile="$1"
	local _suite="$2"
	local _comp

	local _version="`get_deb_header $_debfile Version`"
	local _arch="`get_deb_header $_debfile Architecture`"
	local _deb_comp="`get_deb_header $_debfile Section`"
	local _source="`get_deb_header $_debfile Source`"
	if [ -z "$_source" ]; then
		_source="`get_deb_header $_debfile Package`"
	fi
	
	# check the package presence and get a list of component names
	local _comp_list=`override_get_pkg_componets_list $_source $_version $_suite $_arch`
	if [ -z "$_comp_list" ]; then
		yell "WARNING: package $_debfile does not match override.db"
		return
	fi

	# if Section field is pesent, use it as a component name  
	if [ -n "$_deb_comp" ]; then
		_comp_list="$_deb_comp"
	fi

	local _pkgprefix=`expr "$_source" : "\(lib.\|.\)"`
	for _comp in $_comp_list; do
		echo "pool/$_comp/$_pkgprefix/$_source/$_suite"
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

test_sanity() {
	if [ -z "${REPODIR}" ];then
		yell "REPODIR is not set"
		exit 1
	fi
	[ -d "${REPODIR}" ] || yell "WARNING: IDXDIR=${REPODIR} does not exist"
	if [ -z "${IDXDIR}" ];then
		yell "IDXDIR is not set"
		exit 1
	fi
	[ -d "${IDXDIR}" ] || yell "WARNING: IDXDIR=${IDXDIR} does not exist"
	if [ -z "${OVERRIDES_DB}" ];then
		yell "OVERRIDES_DB is not set"
		exit 1
	fi
	[ -r "${OVERRIDES_DB}" ] || yell "WARNING: overrides database does not exist"
	if [ -z "${DEVSUITE}" ];then
		yell "DEVSUITE is not set"
		exit 1
	fi
	if [ -z "${ARCHES}" ];then
		yell "ARCHES is not set"
		exit 1
	fi
}
