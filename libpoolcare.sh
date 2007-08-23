# Common functions for those who want to operate with slind
# pools, packages, indices, overrides and whatnot.

# Before sourcing this file, make sure you have set:
# * CHR_REPODIR -- root of your package repository
# * DEVSUITE    -- name of 'CURRENT' suite, e.g. 'clydesdale'
# * ARCHES      -- list of supported architectures
# * COMPONENTS  -- list of available components

DISTSDIR="$CHR_REPODIR/dists"
POOLDIR="$CHR_REPODIR/pool"
IDXDIR="$CHR_REPODIR/indices"
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
		component varchar NOT NULL, UNIQUE (pkgname, version, suite, arch, component));
		
		create table binary_cache (
		pkgname varchar NOT NULL,
		version varchar NOT NULL,
		suite char(24) NOT NULL,
		index_arch char(32) NOT NULL,
		pool_file varchar NOT NULL,
		deb_name varchar NOT NULL,
		deb_arch varchar NOT NULL,
		deb_size int NOT NULL,
		deb_md5sum char(32) NOT NULL,
		deb_control text NOT NULL,
		deb_section varchar NOT NULL,
		UNIQUE (pkgname, suite, index_arch, component, deb_name, deb_section));
		"
}

# throw a message to stderr
# $1 -- the message
# $2 -- optional echo flags (-n, -e, whatever)
yell() {
	echo $2 "$1" >&2
}

# check the suite for errors
# $1 -- suite name
override_check_suite() {
	local _suite="$1"

	$SQLCMD "SELECT pkgname || ' ' || version || ' ' || component || ' ' || arch FROM overrides
			WHERE suite='$_suite'" | \
	gawk	-v suite="$_suite"		 \
		-v all_comps_list="$COMPONENTS"	 \
		-v all_arches_list="$ARCHES"	 \
	'BEGIN{
		tmp_count = split(all_arches_list, tmp);
		for(i = 1; i <= tmp_count; i++) all_arch[tmp[i]] = ""; 
		tmp_count = split(all_comps_list, tmp);
		for(i = 1; i <= tmp_count; i++) all_comp[tmp[i]] = ""; 
	}
	function ERROR(msg){
		printf("ERROR: %s\n", msg) >"/dev/stderr";
		error = 1;
	}
	function WARNING(msg){
		printf("WARNING: %s\n", msg) >"/dev/stderr";
	}
	{
		pkgname = $1;
		version = $2;
		component = $3;
		arch = (NF == 4) ? $4 : "all";
		mask = (NF == 4) ?  2 :   1;

		if (!(component in all_comp))
			WARNING("Unknown component in record (" pkgname ", " version ", " arch ", " component ") for suite " suite);
		if (!((arch == "all") || (arch in all_arch)))
			WARNING("Unknown arch in record (" pkgname ", " version ", " arch ", " component ") for suite " suite);

		arch_count["pkgname:" pkgname ", arch:" arch ", component:" component]++;
		version_count["pkgname:" pkgname ", version:" version] = \
			or(version_count["pkgname:" pkgname ", version:" version], mask);
		if (component != comp[pkgname]){
			comp[pkgname] = component; 
			comp_count[pkgname]++;
		}
	}
	END{
		for(idx in arch_count) if (arch_count[idx] > 1)
			ERROR("More than one (" idx ") records found in suite " suite);
		for(idx in version_count) if (version_count[idx] == 3)
			WARNING("Some arch records override ALL record for (" idx ") in suite " suite);
		print error ? "FAIL" : "OK";
		exit(error);
	}'
}

# get most recent package version from overrides.db
# $1 -- source package name
# $2 -- package suite name
# $3 -- arch name (optional)
override_get_pkg_version() {
	local _source="$1"
	local _suite="$2"
	local _arch="$3"

	$SQLCMD "SELECT version FROM overrides
			WHERE pkgname='$_source'
			AND suite='$_suite'
			AND (arch='$_arch' OR arch='')
			ORDER BY arch DESC LIMIT 1"
}

#get a package component from overrides.db
# $1 -- source package name of .deb file
# $2 -- package suite name
override_get_pkg_component() {
	local _source="$1"
	local _suite="$2"

	$SQLCMD "SELECT component FROM overrides
			WHERE pkgname='$_source'
			AND suite='$_suite'
			LIMIT 1"
}

# match source package against overrides db
# $1 -- source package name
# $2 -- package version
# returns a list of 'suite/component' path component
override_get_src_poolpath_list() {
	local _source="$1"
	local _version="$2"

	$SQLCMD "SELECT DISTINCT '$DISTSDIR/' || suite || '/' || component || '/source' FROM overrides
			WHERE pkgname='$_source'
			AND version='$_version'"
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
		all_arch_cnt = split(all_arches_list, all_arch);
	}
	{
		if ($1 == req_version){
			if (NF == 2) and_arches[$2] = "yes";
			else for(i = 1; i <= all_arch_cnt; i++) and_arches[all_arch[i]] = "yes";
		}else{
			if (NF == 2) not_arches[$2] = "yes";
		}
	}
	END{
		for(arch in and_arches)
			if (!(arch in not_arches)) print(arch);
	}'
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
	$SQLCMD "UPDATE OR REPLACE overrides SET suite='$_new_suite'
			WHERE pkgname='$_source'
			AND version='$_version'
			AND suite='$_suite';
		 DELETE FROM overrides
			WHERE pkgname='$_source'
			AND version='$_version'
			AND suite='$_suite';
		 DELETE FROM binary_cache
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
	local _tmp_version
	local _version_count=0
	local _count=0
	local _ver
	local _arch
	local _comp
	local _i
	local _tmpfile1=`mktemp`
	

	# Get (version, arch, component) for required (source, suite) and store
	# them to separate arrays.
	$SQLCMD "SELECT version || ' ' || component || ' ' || arch FROM overrides 
			WHERE pkgname='$_source'
			AND suite='$_suite'" > $_tmpfile

	cat $_tmpfile | (
		while read _ver _comp _arch; do
			# exit, if required version already exist
			if [ "$_version" = "$_ver" ]; then
				echo "OK"
				exit
			fi

			# collect a number of different versions of package
			if [ "$_tmp_version" != "$_ver" ]; then
				_tmp_version="$_ver"
				_version_count=$((_version_count+1))
			fi

			_count=$((_count+1))
		done
	)

	case "$_version_count" in
		0)	# the package is new, add it to required suite for all arches.
			override_insert_new_record $_source $_version $_suite '' $_component
			echo "OK"
			;;
		1)	# only one version of package exist
			dpkg --compare-versions "$_version" gt "$_ver"
			if [ "$?" = "0" ]; then
				# the package is newer than current, move older one to "attic"
				override_replace_suite $_source $_ver $_suite "attic"
			else
				# the package is older than current, add it to "attic"
				_suite="attic"
			fi
			cat $_tmpfile | (
				while read _ver _comp _arch; do
					override_insert_new_record $_source $_version $_suite "$_arch" $_component
				done )
			echo "OK"
			;;
		*)	# too many versions of package exist, resolve this situation manually
			yell "WARNING: too many suitable records, can't update overrides for source package $_source=$_version"
			echo "FAIL"
			;;
	esac

	rm $_tmpfile
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

# cache .deb file information and return path to place deb to the pool
# $1 -- path to .deb file
# $2 -- suite
deb_cache() {
	local _debfile="$1"
	local _suite="$2"
	local _index_arch

	local _size=`du -sb $_debfile | cut -f1`
	local _md5sum=`md5sum $_debfile | cut -d' ' -f1`
	local _control=`ar p $_debfile control.tar.gz | tar zxO ./control | egrep -v '^Package:|^Version:|^Section:|^Architecture:|^Source:' | sed "s/'/''/g"`
	local _name=`get_deb_header $_debfile Package`
	local _version=`get_deb_header $_debfile Version`
	local _section=`get_deb_header $_debfile Section`
	local _arch=`get_deb_header $_debfile Architecture`
	local _source=`get_deb_header $_debfile Source`
	if [ -z "$_source" ]; then
		_source="$_name"
	fi

	local _index_arch_list=`override_get_pkg_arches_list $_source $_version $_suite`
	if [ -z "$_index_arch_list" ]; then
		yell "WARNING: package $_debfile does not match override.db"
		return
	fi
	if [ "$_arch" != "all" ]; then
		_index_arch_list="$_arch"
	fi

	if [ -z "$_section" ]; then
		_section=`override_get_pkg_component $_source $_suite`
	fi
	if [ "$_arch" = "all" -a "$_section" = "host-tools" ]; then
		_index_arch_list="$ARCHES"
	fi

	local _pkgprefix=`expr "$_source" : "\(lib.\|.\)"`
	local _pool_path="pool/$_section/$_pkgprefix/$_source/$_suite"
	local _pool_file="$_pool_path/`basename $_debfile`"

	for _index_arch in $_index_arch_list; do
		$SQLCMD "REPLACE INTO binary_cache (
				pkgname, version, suite, index_arch,
				pool_file, deb_name, deb_arch, deb_section, 
				deb_size, deb_md5sum, deb_control)
			VALUES('$_source', '$_version', '$_suite', '$_index_arch',
				'$_pool_file', '$_name', '$_arch', '$_section',
				'$_size', '$_md5sum', '$_control')"
	done

	# return destination path 
	echo "$CHR_REPODIR/$_pool_path"
}

# output package's information (control) for Packages file
# $1 -- suite
# $2 -- index_arch
make_Packages() {
	local _suite="$1"
	local _index_arch="$2"
	local _section
	local _path
	local _SQL

	# create predefined binary indexes
	for _section in $COMPONENTS; do
		_path="$DISTSDIR/$_suite/$_section/binary-$_index_arch"
		mkdir -p "$_path"
		: > "$_path/Packages"
		gzip -c9 < "$_path/Packages" > "$_path/Packages.gz"
	done
	
	local _section_list=`$SQLCMD "SELECT DISTINCT deb_section FROM binary_cache
		WHERE suite='$_suite' AND index_arch='$_index_arch'"`
	if [ -z "$_section_list" ]; then
		return
	fi

	for _section in $_section_list; do
		_path="$DISTSDIR/$_suite/$_section/binary-$_index_arch"
		_SQL="SELECT 'Package: ' || deb_name || '<BR>'
			||'Source: ' || pkgname || '<BR>'
	                ||'Version: ' || version || '<BR>'
			||'Architecture: ' || deb_arch || '<BR>'
			||'Filename: ' || pool_file || '<BR>'
			||'Size: ' || deb_size || '<BR>'
			||'MD5sum: ' || deb_md5sum || '<BR>'
			||'Section: ' || deb_section || '<BR>'
			|| deb_control || '<BR>'
	            FROM binary_cache
			WHERE suite='$_suite'
			AND deb_section='$_section'
			AND index_arch='$_index_arch'"

		mkdir -p "$_path"
		$SQLCMD "$_SQL" | sed -e 's/<BR>/\n/g' >"$_path/Packages"
		gzip -c9 < "$_path/Packages" > "$_path/Packages.gz"
	done
}

test_sanity() {
	if [ -z "${CHR_REPODIR}" ];then
		yell "CHR_REPODIR is not set"
		exit 1
	fi
	[ -d "${CHR_REPODIR}" ] || yell "WARNING: IDXDIR=${CHR_REPODIR} does not exist"
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
	if [ -z "${COMPONENTS}" ];then
		yell "COMPONENTS is not set"
		exit 1
	fi
}

# Process a .dsc file.
# $1 -- path to .dsc file
# This is a do-it-all function for one source package.
scan_just_one_dsc() {
	local _dscfile="$1"
	local _path_list
	local _path
	local _result

	local _pkgname="`grep '^Source: ' $_dscfile | cut -d' ' -f2`"
	local _pkgver="`grep '^Version: ' $_dscfile | cut -d' ' -f2`"
	local _pkgcomp="`grep '^Section: ' $_dscfile | cut -d' ' -f2`"

	[ -n "$_pkgcomp" ] || _pkgcomp='broken'
	echo $COMPONENTS | egrep "\<$_pkgcomp\>" >/dev/null || _pkgcomp='broken'

	# check with overrides db
	_path_list=`override_get_src_poolpath_list $_pkgname $_pkgver`
	if [ -z "$_path_list" ]; then
		_result=`override_try_add_package $_pkgname $_pkgver $DEVSUITE $_pkgcomp`
		if [ "$_result" != "OK" ]; then
			yell "WARNING: cannot add source package $_pkgname=$_pkgver in" -n
			yell "overrides table, ignore this package for now"
			return
		fi
		_path_list=`override_get_src_poolpath_list $_pkgname $_pkgver`
		if [ -z "$_path_list" ]; then
			yell "WARNING: can't index source package $_pkgname=$_pkgver"
			return
		fi
	fi

	for _path in $_path_list; do
		# write a source entry to Sources file
		dsc_to_Sources "$_dscfile" "$_path"
	done
}

scan_all_dsc() {
	local _suite
	local _component
	local _dscfile
	local _suite_comp

	echo "=========================="
	echo "# Creating .dsc indexes"
	echo "=========================="

	# create predefined src indexes
	for _suite in $SUITES; do
		# Do we have components overrided for this suite?
		load_suites_config $_suite

		for _component in $COMPONENTS; do
			if [ ! -d "$DISTSDIR/$_suite/$_component/source" ]; then
				mkdir -p "$DISTSDIR/$_suite/$_component/source"
			fi
			: > "$DISTSDIR/$_suite/$_component/source/Sources"
			gzip -c9 \
				< "$DISTSDIR/$_suite/$_component/source/Sources" \
				> "$DISTSDIR/$_suite/$_component/source/Sources.gz"
		done
	done

	find "$POOLDIR" -type f -name '*.dsc' | while read _dscfile; do
		scan_just_one_dsc "$_dscfile"
	done
}

