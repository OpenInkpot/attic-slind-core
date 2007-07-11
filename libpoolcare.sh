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
# $2 -- package suite name
# $3 -- arch name (optional)
override_get_pkg_version() {
	local _source="$1"
	local _suite="$2"
	local _arch="$3"

	local _version=`$SQLCMD "SELECT version || ' ' || arch FROM overrides
			WHERE pkgname='$_source'
			AND suite='$_suite'
			AND (arch='$_arch' OR arch='')" | \
	gawk	-v pkgname="$_source"		\
		-v suite="$_suite"		\
	'function ERROR(arch){
		printf("ERROR: More than one arch=%s record found for package \"%s\" in suite \"%s\"\n",
			arch, pkgname, suite) >"/dev/stderr";
		fatal_error=1;
	}
	(NF == 2){
		arch=$2;
		arch_records++;
		arch_version=$1
	}
	(NF == 1){
		all_records++;
		all_version=$1;
	}
	END{
		if (all_records > 1) ERROR("all");
		if (arch_records > 1) ERROR(arch);
		if (fatal_error) exit(1);
		if (arch_records > 0) print arch_version;
		else if (all_records > 0) print all_version;
	}'`
	if [ -z "$_version" ]; then
		yell "Can't find $_source version in overrides.db"
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
	gawk	-v pkgname="$_source"		\
		-v req_version="$_version"	\
		-v suite="$_suite"		\
		-v all_arches_list="$ARCHES"	\
	'BEGIN{
		cnt = split(all_arches_list, tmp);
		for(i = 1; i <= cnt; i++) all_arches[tmp[i]] = "0";
	}
	function ERROR(arch){
		printf("ERROR: More than one arch=%s record found for package \"%s\" in suite \"%s\"\n",
			arch, pkgname, suite) >"/dev/stderr";
		fatal_error=1;
	}
	($1 == req_version){
		if (NF == 2){
			all_arches[$2]++;
			and_arches[$2] = "yes";
		}else{
			all_records++;
			for(arch in all_arches) and_arches[arch] = "yes";
		}
	}
	($1 != req_version){
		if (NF == 2){
			all_arches[$2]++;
			not_arches[$2] = "yes";
		}else all_records++;
	}
	END{
		if (all_records > 1) ERROR("all");
		for(arch in all_arches)
		    if (all_arches[arch] > 1) ERROR(arch);
		if (fatal_error) exit(1);
		for(arch in and_arches)
			if (!(arch in not_arches)) print(arch);
	}'
}

#get a list of components for .deb package from overrides.db
# $1 -- source package name of .deb file
# $2 -- package version
# $3 -- package suite name
# $4 -- arch name (optional)
override_get_pkg_components_list() {
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
	gawk	-v pkgname="$_source"		\
		-v req_version="$_version"	\
		-v suite="$_suite"		\
		-v req_arch="$_arch"		\
		-v all_arches_list="$ARCHES"	\
	'BEGIN{
		cnt = split(all_arches_list, tmp);
		for(i = 1; i <= cnt; i++) all_arches[tmp[i]] = "0";
	}
	function ERROR(arch){
		printf("ERROR: More than one arch=%s record found for package \"%s\" in suite \"%s\"\n",
			arch, pkgname, suite) >"/dev/stderr";
		fatal_error=1;
	}
	($1 == req_version){
		if (NF == 3){
			all_arches[$3]++;
			and_arches[$3] = "yes";
			component[$3] = $2;
		}else{
			all_records++;
			for(arch in all_arches){
				and_arches[arch] = "yes";
				component[arch] = $2;
			}
		}
	}
	($1 != req_version){
		if (NF == 3){
			all_arches[$3]++;
			not_arches[$3] = "yes";
		}else all_records++;
	}
	END{
		if (all_records > 1) ERROR("all");
		for(arch in all_arches)
		    if (all_arches[arch] > 1) ERROR(arch);
		if (fatal_error) exit(1);
		for(arch in and_arches){
			if (arch in not_arches) continue;
			if ((req_arch == "all") || (req_arch == arch))
				result[component[arch]] = "";
		}
		for(comp in result) print(comp);
	}'
}

override_insert_deb_info() {
	local _deb="$1"
	local _suite="$2"
	local _arch="$3"
	local _source=`get_deb_header $_deb Source`
	local _version=`get_deb_header $_deb Version`
	local _debname=`get_deb_header $_deb Package`
	local _debsize=`du -sb $_deb | cut -f1`
	local _md5sum=`md5sum $_deb | cut -d' ' -f1`
	local _debcontrol=`ar p $_deb control.tar.gz | tar zxO ./control | egrep -v '^Source:|^Version:|^Package:|^Section:|^Architecture:'`
	if [ -z "$_source" ]; then
		_source=$_debname
	fi
	local _ov_section=`override_get_pkg_components_list $_source $_version $_suite $_debarch`
	if [ -z "$_ov_section" ]; then
		yell "ERROR: Stale binary .deb $_deb, no source for $_source $_version $_suite $_debarch"
		return
	fi
	local _debarch=`get_deb_header $_deb Architecture`
	local _section=`get_deb_header $_deb Section`
	if [ -z "$_section" ]; then
	    _section=$_ov_section
	fi
	local archlist
	if [ -z "$_arch" ]; then
		archlist=`$SQLCMD "SELECT arch from overrides WHERE pkgname='$_source',
								  version='$_version',
								  suite='$_suite'"`
	else
		archlist="$_arch"
	fi
	if [ -z "$archlist" ]; then
		yell "ERROR: No source package $_source $_version $_suite"
		return
	fi

	local arch
	for arch in $archlist; do
		$SQLCMD "INSERT INTO binary_cache(pkgname, version, suite,
					  arch, deb_name, deb_arch,
					  deb_size, deb_md5sum,
					  deb_control, deb_section)
					  VALUES('$_source','$_version',
					         '$_suite','$arch','$_debname','$_debarch',
						 '$_debsize','$_md5sum', '$_debcontrol', '$_section')"
	done
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

# replace suite for package in overrides db
# $1 -- source package name of .deb file
# $2 -- package version
# $3 -- package suite name
# $4 -- new package suite name
override_replace_suite(){
	local _source="$1"
	local _version="$2"
	local _suite="$3"
	local _new_suite="$4"

	yell "# change suite for $_source=$_version from suite='$_suite' to suite=$_new_suite in overrides"
	$SQLCMD "UPDATE overrides SET suite='$_new_suite'
			WHERE pkgname='$_source'
			AND version='$_version'
			AND suite='$_suite';
		 UPDATE binary_cache SET suite='$_new_suite'
			WHERE pkgname='$_source'
			AND version='$_version'
			AND suite='$_suite'"
}

# try to add package to overrides db
# $1 -- source package name of .deb file
# $2 -- package version
# $3 -- package suite name
# $4 -- source package's 'Section:' field
# returns FAIL on failure and OK on success
override_try_add_package(){
	local _source="$1"
	local _version="$2"
	local _suite="$3"
	local _component="$4"
	local _version_count=0
	local _count=0
	local _found=0
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
			# check the list for existance of required package version
			for((_i=0;_i<_count;_i++)); do
				if [ "$_version" = "${_ver[$_i]}" ]; then
					# the package is the same, just set a _found flag
					_found=1
				fi
			done

			if [ "$_found" -eq 0 ]; then
				# too many record for package, resolve this situation manually
				yell "WARNING: too many suitable records, can't update overrides for source package $_source=$_version"
				echo "FAIL"
			else
				echo "OK"
			fi
		elif [ "$_version_count" -eq 1 ]; then
			dpkg --compare-versions "$_version" gt "${_ver[0]}"
			if [ "$?" = "0" ]; then
				# the package is newer than current, add it to required 
				# suite and move older one to "attic"
				override_replace_suite $_source ${_ver[0]} $_suite "attic"
				for((_i=0;_i<_count;_i++)); do
					override_insert_new_record $_source $_version $_suite "${_arch[$_i]}" $_component
				done
			elif [ "$_version" = "${_ver[0]}" ]; then
				# the package is the same, do nothing
				true
			else
				# the package is older than current, add it to "attic"
				for((_i=0;_i<_count;_i++)); do
					override_insert_new_record $_source $_version "attic" "${_arch[$_i]}" $_component
				done
			fi
			echo "OK"
		else
			# the package is new, add it to required suite for all arches.
			override_insert_new_record $_source $_version $_suite '' $_component
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

	[ -d "$_sourcespath" ] || mkdir -p "$_sourcespath"
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

	ar p $_debfile control.tar.gz | tar zxO ./control | \
		grep "^${_hdr}: " | cut -d' ' -f2
}

# get a placement of given deb in pool or related Package index
# $1 -- request: "index" or "pool"
# $2 -- path to .deb file
# $3 -- suite
get_deb_pathlist() {
	local _request="$1"
	local _debfile="$2"
	local _suite="$3"
	local _comp

	local _version="`get_deb_header $_debfile Version`"
	local _arch="`get_deb_header $_debfile Architecture`"
	local _deb_comp="`get_deb_header $_debfile Section`"
	local _source="`get_deb_header $_debfile Source`"
	if [ -z "$_source" ]; then
		_source="`get_deb_header $_debfile Package`"
	fi

	local _comp_list=`override_get_pkg_components_list $_source $_version $_suite $_arch`
	if [ -z "$_comp_list" ]; then
		yell "WARNING: package $_debfile does not match override.db"
		return
	fi

	# if Section field is pesent, use it as a component name  
	if [ -n "$_deb_comp" ]; then
		_comp_list="$_deb_comp"
	fi

	case "$_request" in
		pool)
			local _pkgprefix=`expr "$_source" : "\(lib.\|.\)"`
			for _comp in $_comp_list; do
				echo "pool/$_comp/$_pkgprefix/$_source/$_suite"
			done
			;;
		index)
			local _arches_list="$_arch"
			if [ "$_arches_list" = "all" ]; then
				_arches_list=`override_get_pkg_arches_list $_source $_version $_suite`
			fi
			for _comp in $_comp_list; do
				for _arch in $_arches_list; do
					echo "$_suite/$_comp/binary-$_arch"
				done
			done
			;;
		*)
			yell "ERROR: unknown request to get_deb_pathlist()."
			;;
	esac
}

# output package's information (control) for Packages file
# $1 -- name to source
# $2 -- version
# $3 -- arch for source
# $4 -- suite

get_Packages_by_source() {
	local _pkgname="$1"
	local _version="$2"
	local _arch="$3"
	local _suite="$4"
	local _SQL="SELECT 'Package: ' || deb_name || '<BR>'
			||'Source: ' || pkgname || '<BR>'
	                ||'Version: ' || version || '<BR>'
			||'Architecture: ' || deb_arch || '<BR>'
			||'Size: ' || deb_size || '<BR>'
			||'MD5sum: ' || deb_md5sum || '<BR>'
			||'Section: ' || deb_section || '<BR>'
			|| deb_control || '<BR>'
	            FROM binary_cache WHERE pkgname='$_pkgname'
				      AND version='$_version'
				      AND arch='$_arch'
				      AND suite='$_suite'"

	$SQLCMD "$_SQL" | sed -e 's/<BR>/\n/g'
}

# output package's information (control) for Packages file
# $1 -- architecture for suite
# $2 -- suite

get_Packages_by_suite() {
	local _arch="$1"
	local _suite="$2"
	local _SQL="SELECT 'Package: ' || deb_name || '<BR>'
			||'Source: ' || pkgname || '<BR>'
	                ||'Version: ' || version || '<BR>'
			||'Architecture: ' || deb_arch || '<BR>'
			||'Size: ' || deb_size || '<BR>'
			||'MD5sum: ' || deb_md5sum || '<BR>'
			||'Section: ' || deb_section || '<BR>'
			|| deb_control || '<BR>'
	            FROM binary_cache WHERE suite='$_suite' AND arch='$_arch'"
	$SQLCMD "$_SQL" | sed -e 's/<BR>/\n/g'
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
