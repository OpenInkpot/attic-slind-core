#!/bin/sh
test_PKGDIR="/tmp/pkg"
test_REPODIR="/tmp/repo"
test_POOLDIR="/tmp/pool"
REPODIR=${test_REPODIR}
DEVSUITE=unstable
ARCHES="i386 ppc arm sh4 mips"
COMPONENTS="data data-all"
. libpoolcare.sh

create_deb_package() {
	local _name="$1"
	local _version="$2"
	local _arch="$3"
	local _section="$4"

	if [ -z "$_arch" ]; then
		_arch="all"
	fi

	if [ -z "$_section" ]; then
		_section="core"
	fi

	rm -Rf "${test_PKGDIR}/$_name-$_version" 2>/dev/null
	mkdir -p "${test_PKGDIR}/$_name-$_version/debian/$_name"
	cat >"${test_PKGDIR}/$_name-$_version/debian/control" <<EOF
Source: $_name
Section: $_section
Priority: optional
Maintainer: Nobody <nobody@localhost>

Package: $_name
Architecture: $_arch
Description: test package
  test package
EOF
	cat >"${test_PKGDIR}/$_name-$_version/debian/changelog" <<EOF
$_name ($_version) unstable; urgency=low

  * test

 -- Nobody <nobody@localhost>  Wed, 23 May 2007 14:28:33 +0400
EOF
	echo -e "#!/bin/sh\ndh_gencontrol\ndh_builddeb" > "${test_PKGDIR}/$_name-$_version/debian/rules"
	echo "Hello, World!" > "${test_PKGDIR}/$_name-$_version/debian/$_name/README"
	echo 4 > "${test_PKGDIR}/$_name-$_version/debian/compat"
	chmod +x "${test_PKGDIR}/$_name-$_version/debian/rules"
	(cd "${test_PKGDIR}/$_name-$_version" && dpkg-buildpackage -rfakeroot) >/dev/null
}


test_database() {
	test_sanity
	mkoverrides
	if [ $? -ne 0 ]; then
		echo "test_database: FAIL(1)"
		return
	else
		override_insert_new_record 'a' '1.0slind0' 'stable'  ''     'data'
		override_insert_new_record 'a' '1.0slind0' 'testing' ''     'data'
		override_insert_new_record 'a' '1.0slind0' 'testing' 'ppc'  'data'
		override_insert_new_record 'a' '1.0slind2' 'stable'  'ppc'  'data'
		override_insert_new_record 'a' '1.0slind2' 'stable'  'mips' 'data'

		override_insert_new_record 'b' '1.0slind2' 'stable'  'ppc'  'data'

		override_insert_new_record 'c' '1.0slind0' 'stable'  ''     'data'
		override_insert_new_record 'c' '1.0slind1' 'stable'  'i386' 'data'
		override_insert_new_record 'c' '1.0slind1' 'stable'  'ppc'  'data'
		override_insert_new_record 'c' '1.0slind1' 'stable'  'arm'  'data'
		override_insert_new_record 'c' '1.0slind1' 'stable'  'sh4'  'data'
		override_insert_new_record 'c' '1.0slind1' 'stable'  'mips' 'data'

		override_insert_new_record 'd' '1.0slind0' 'stable'  ''     'data-all'
		override_insert_new_record 'd' '1.0slind1' 'stable'  ''     'data-all'
		override_insert_new_record 'd' '1.0slind0' 'stable'  'arm'  'data-all'
		override_insert_new_record 'd' '1.0slind1' 'stable'  'arm'  'data-all'
		override_insert_new_record 'e' '1:2.3.slind12' 'stable'  'arm'  'data-all'

		echo "test_database: OK"
	fi
}

test_pkg() {
	create_deb_package a 1.0slind0
	create_deb_package a 1.0slind2
	create_deb_package a 1.0slind3
	create_deb_package b 1.0slind3
	create_deb_package c 1.0slind0
	create_deb_package e '1:2.3.slind12'
}

test_deb() {
    for f in ${test_PKGDIR}/*.deb; do
	if [ -n "`get_deb_header $f Nonexisting`" ]; then
	    echo "test_deb: FAIL(1)"
	    return
	fi
	if [ -z "`get_deb_header $f Package`" ]; then
	    echo "test_deb: FAIL(2)"
	    return
	fi
    done
    for f in ${test_PKGDIR}/*.deb; do
	deb_cache $f 'stable'
    done
    if [ ! -r $test_PKGDIR/Packages ]; then
	echo "test_deb: FAIL(3)"
	return
    fi
    if [ ! -r $test_PKGDIR/Packages.gz ]; then
	echo "test_deb: FAIL(4)"
	return
    fi
    for f in ^Package: ^Version: ^Section:;do
	grep $f $test_PKGDIR/Packages >/dev/null;
	if [ $? -ne 0 ]; then
	   echo "test_deb: FAIL(5)"
	   return
	fi
    done
    echo "test_deb: OK"
}
test_dsc() {
    for f in $test_PKGDIR/*.dsc; do
	dsc_to_Sources $f $test_PKGDIR
    done
    if [ ! -r $test_PKGDIR/Sources ]; then
	echo "test_dsc: FAIL(1)"
	return
    fi
    if [ ! -r $test_PKGDIR/Sources.gz ]; then
	echo "test_dsc: FAIL(2)"
	return
    fi
    for f in ^Package: ^Version: ^Maintainer: ^Files:;do
	grep $f $test_PKGDIR/Sources >/dev/null;
	if [ $? -ne 0 ]; then
	   echo "test_dsc: FAIL(3)"
	   return
	fi
    done
    echo "test_dsc: OK"
}

test_override_get_pkg_version() {
	local _version

	_version=`override_get_pkg_version 'a' 'unknown'`;
	if [ -n "$_version" ]; then
		echo "test_override_get_pkg_version: FAIL(1)"
		return
	fi

	_version=`override_get_pkg_version 'a' 'stable'`;
	if [ "$_version" != "1.0slind0" ]; then
		echo "test_override_get_pkg_version: FAIL(2)"
		return
	fi

	_version=`override_get_pkg_version 'a' 'stable' 'i386'`;
	if [ "$_version" != "1.0slind0" ]; then
		echo "test_override_get_pkg_version: FAIL(3)"
		return
	fi

	_version=`override_get_pkg_version 'a' 'stable' 'ppc'`;
	if [ "$_version" != "1.0slind2" ]; then
		echo "test_override_get_pkg_version: FAIL(4)"
		return
	fi

	_version=`override_get_pkg_version 'b' 'stable'`;
	if [ -n "$_version" ]; then
		echo "test_override_get_pkg_version: FAIL(5)"
		return
	fi

	_version=`override_get_pkg_version 'b' 'stable' 'arm'`;
	if [ -n "$_version" ]; then
		echo "test_override_get_pkg_version: FAIL(6)"
		return
	fi

	_version=`override_get_pkg_version 'b' 'stable' 'ppc'`;
	if [ "$_version" != "1.0slind2" ]; then
		echo "test_override_get_pkg_version: FAIL(7)"
		return
	fi

	echo "test_override_get_pkg_version: OK"
}

test_override_get_pkg_arches_list() {
	local _arches

	_arches=`override_get_pkg_arches_list 'a' '1.0slind0' 'unknown'`
	if [ -n "$_arches" ]; then
		echo "test_override_get_pkg_arches_list: FAIL(1)"
		return
	fi

	_arches=`override_get_pkg_arches_list 'a' '1.0slind0' 'stable' | sort | xargs`
	if [ "$_arches" != "arm i386 sh4" ]; then
		echo "test_override_get_pkg_arches_list: FAIL(2)"
		return
	fi

	_arches=`override_get_pkg_arches_list 'a' '1.0slind2' 'stable' | sort | xargs`
	if [ "$_arches" != "mips ppc" ]; then
		echo "test_override_get_pkg_arches_list: FAIL(3)"
		return
	fi

	_arches=`override_get_pkg_arches_list 'c' '1.0slind0' 'stable'`
	if [ -n "$_arches" ]; then
		echo "test_override_get_pkg_arches_list: FAIL(4)"
		return
	fi

	_arches=`override_get_pkg_arches_list 'c' '1.0slind1' 'stable' | sort | xargs`
	if [ "$_arches" != "arm i386 mips ppc sh4" ]; then
		echo "test_override_get_pkg_arches_list: FAIL(5)"
		return
	fi

	_arches=`override_get_pkg_arches_list 'e' '1:2.3.slind12' 'stable' | sort | xargs`
	if [ "$_arches" != "arm" ]; then
		echo "test_override_get_pkg_arches_list: FAIL(6)"
		return
	fi

	echo "test_override_get_pkg_arches_list: OK"
}

test_override_get_pkg_component() {
	local _component

	_component=`override_get_pkg_component 'a' 'unknown'`
	if [ -n "$_component" ]; then
		echo "test_override_get_pkg_component: FAIL(1)"
		return
	fi

	_component=`override_get_pkg_component 'a' 'stable'`
	if [ "$_component" != "data" ]; then
		echo "test_override_get_pkg_component: FAIL(2)"
		return
	fi

	_component=`override_get_pkg_component 'c' 'stable'`
	if [ "$_component" != "data" ]; then
		echo "test_override_get_pkg_component: FAIL(3)"
		return
	fi

	echo "test_override_get_pkg_component: OK"
}

test_override_try_add_package() {
	local _result
	local _component

	_result=`override_try_add_package 'gcc' '4.1.2-1' 'clydesdale' 'broken'`
	if [ "$_result" != OK ]; then
		echo "test_override_try_add_package: FAIL(1)"
		return
	fi
	_component=`override_get_pkg_component 'gcc' 'clydesdale'`
	if [ "$_component" != "broken" ]; then
		echo "test_override_try_add_package: FAIL(1a)"
		return
	fi

	_result=`override_try_add_package 'gcc' '4.1.2-1' 'clydesdale' 'broken'`
	if [ "$_result" != OK ]; then
		echo "test_override_try_add_package: FAIL(2)"
		return
	fi

	_result=`override_try_add_package 'gcc' '4.1.2-2' 'clydesdale' 'broken1'`
	if [ "$_result" != OK ]; then
		echo "test_override_try_add_package: FAIL(3)"
		return
	fi
	_component=`override_get_pkg_component 'gcc' 'clydesdale'`
	if [ "$_component" != "broken1" ]; then
		echo "test_override_try_add_package: FAIL(3a)"
		return
	fi
	_component=`override_get_pkg_component 'gcc' 'attic'`
	if [ "$_component" != "broken" ]; then
		echo "test_override_try_add_package: FAIL(3b)"
		return
	fi

	_result=`override_try_add_package 'c' '1.0slind1' 'stable'`
	if [ "$_result" != OK ]; then
		echo "test_override_try_add_package: FAIL(4)"
		return
	fi

	_result=`override_try_add_package 'c' '1.0slind2' 'stable'`
	if [ "$_result" != FAIL ]; then
		echo "test_override_try_add_package: FAIL(5)"
		return
	fi

	echo "test_override_try_add_package: OK"
}

test_deb_cache() {
	local _result

	_result=`deb_cache "${test_PKGDIR}/a_1.0slind3_all.deb" "stable"`
	if [ -n "$_result" ]; then
		echo "test_deb_cache: FAIL(1)"
		return
	fi

	_result=`deb_cache "${test_PKGDIR}/c_1.0slind0_all.deb" "stable"`
	if [ -n "$_result" ]; then
		echo "test_deb_cache: FAIL(2)"
		return
	fi

	_result=`deb_cache "${test_PKGDIR}/a_1.0slind0_all.deb" "stable"`
	if [ "$_result" != "$POOLDIR/core/a/a/stable" ]; then
		echo "test_deb_cache: FAIL(3)"
		return
	fi

	_result=`deb_cache "${test_PKGDIR}/a_1.0slind2_all.deb" "stable"`
	if [ "$_result" != "$POOLDIR/core/a/a/stable" ]; then
		echo "test_deb_cache: FAIL(4)"
		return
	fi

	echo "test_deb_cache: OK"
}

rm -rf $test_PKGDIR $test_REPODIR $test_POOLDIR
test_database
override_check_suite stable
test_pkg
#test_deb
test_dsc
test_override_get_pkg_version
test_override_get_pkg_arches_list
test_override_get_pkg_component
test_override_try_add_package
test_deb_cache
override_insert_new_record 'b' '1.0slind3' 'stable' 'i386' 'data'
for f in $test_PKGDIR/*.deb; do
       deb_cache $f "stable"
done
make_Packages 'stable' 'i386'
