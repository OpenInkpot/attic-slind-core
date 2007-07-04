#!/bin/sh -x
test_PKGDIR="/tmp/pkg"
test_REPODIR="/tmp/repo"
test_POOLDIR="/tmp/pool"
REPODIR=${test_REPODIR}
DEVSUITE=unstable
ARCHES="i386 ppc arm sh4 mips"
. libpoolcare.sh

test_database() {
	test_sanity
	mkoverrides
	if [ $? -ne 0 ]; then
	    echo "test_database: FAIL(1)"
	    return
	else
	    override_insert_new_record 'a' '1.0slind0' 'stable'  'i386' 'data'
	    override_insert_new_record 'a' '1.0slind0' 'stable'  ''     'data-new'
	    override_insert_new_record 'a' '1.0slind0' 'testing' ''     'data'
	    override_insert_new_record 'a' '1.0slind0' 'testing' 'ppc'  'data'
	    override_insert_new_record 'a' '1.0slind0' 'stable'  'arm'  'data'
	    override_insert_new_record 'a' '1.0slind2' 'stable'  'ppc'  'data'
	    override_insert_new_record 'a' '1.0slind2' 'stable'  'mips' 'data'
	    override_insert_new_record 'b' '1.0slind2' 'stable'  'ppc'  'data'

	    override_insert_new_record 'c' '1.0slind0' 'stable'  ''     'data-all'
	    override_insert_new_record 'c' '1.0slind1' 'stable'  'i386' 'data-i386'
	    override_insert_new_record 'c' '1.0slind1' 'stable'  'ppc'  'data-ppc'
	    override_insert_new_record 'c' '1.0slind1' 'stable'  'arm'  'data-arm'
	    override_insert_new_record 'c' '1.0slind1' 'stable'  'sh4'  'data-sh4'
	    override_insert_new_record 'c' '1.0slind1' 'stable'  'mips' 'data-mips'

	    override_insert_new_record 'd' '1.0slind0' 'stable'  ''     'data-all'
	    override_insert_new_record 'd' '1.0slind1' 'stable'  ''     'data-all'

	    echo "test_database: OK"
	fi
}
test_pkg() {
	echo "Creating 2 empty packages in ${test_PKGDIR}"
	rm -Rf "${test_PKGDIR}"
	mkdir -p "${test_PKGDIR}/a/debian/a" "${test_PKGDIR}/b/debian/b"
	cat >${test_PKGDIR}/a/debian/control <<EOF
Source: a
Section: core
Priority: optional
Maintainer: Nobody <nobody@localhost>

Package: a
Architecture: any
Description: test package
  test package
EOF
	cat >${test_PKGDIR}/a/debian/changelog <<EOF
a (1.0slind3) unstable; urgency=low

  * test

 -- Nobody <nobody@localhost>  Wed, 23 May 2007 14:28:33 +0400
EOF
	cat >${test_PKGDIR}/b/debian/control <<EOF
Source: b
Section: core
Priority: optional
Maintainer: Nobody <nobody@localhost>

Package: b
Architecture: any
Description: test package
  test package
EOF
	cat >${test_PKGDIR}/b/debian/changelog <<EOF
b (1.0slind3) unstable; urgency=low

  * test

 -- Nobody <nobody@localhost>  Wed, 23 May 2007 14:28:33 +0400
EOF
	echo -e "#!/bin/sh\ndh_gencontrol\ndh_builddeb" | tee ${test_PKGDIR}/b/debian/rules > ${test_PKGDIR}/a/debian/rules
	echo "Hello, World!" | tee ${test_PKGDIR}/b/debian/b/README > ${test_PKGDIR}/a/debian/a/README
	echo 4 | tee ${test_PKGDIR}/{a,b}/debian/compat >/dev/null
	chmod +x ${test_PKGDIR}/*/debian/rules
	(cd ${test_PKGDIR}/a && dpkg-buildpackage -rfakeroot)
	(cd ${test_PKGDIR}/b && dpkg-buildpackage -rfakeroot)
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
	deb_to_Packages $f $test_PKGDIR
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
test_override() {
  echo $ARCHES
  overrides_get_indep_deb_arches "a" "1.0slind0" "stable"
  get_deb_distpath 
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

	_arches=`override_get_pkg_arches_list 'd' '1.0slind0' 'stable'`
	if [ -n "$_arches" ]; then
		echo "test_override_get_pkg_arches_list: FAIL(6)"
		return
	fi

	echo "test_override_get_pkg_arches_list: OK"
}

test_override_get_pkg_components_list() {
	local _components

	_components=`override_get_pkg_components_list 'a' '1.0slind0' 'unknown'`
	if [ -n "$_components" ]; then
		echo "test_override_get_pkg_components_list: FAIL(1)"
		return
	fi

	_components=`override_get_pkg_components_list 'a' '1.0slind0' 'stable' | sort | xargs`
	if [ "$_components" != "data data-new" ]; then
		echo "test_override_get_pkg_components_list: FAIL(2)"
		return
	fi

	_components=`override_get_pkg_components_list 'a' '1.0slind0' 'unknown' 'ppc'`
	if [ -n "$_components" ]; then
		echo "test_override_get_pkg_components_list: FAIL(3)"
		return
	fi

	_components=`override_get_pkg_components_list 'a' '1.0slind0' 'stable' 'arm' | sort | xargs`
	if [ "$_components" != "data" ]; then
		echo "test_override_get_pkg_components_list: FAIL(4)"
		return
	fi

	_components=`override_get_pkg_components_list 'a' '1.0slind0' 'stable' 'sh4' | sort | xargs`
	if [ "$_components" != "data-new" ]; then
		echo "test_override_get_pkg_components_list: FAIL(5)"
		return
	fi

	_components=`override_get_pkg_components_list 'a' '1.0slind2' 'stable' 'ppc' | sort | xargs`
	if [ "$_components" != "data" ]; then
		echo "test_override_get_pkg_components_list: FAIL(6)"
		return
	fi

	_components=`override_get_pkg_components_list 'a' '1.0slind2' 'stable' 'arm'`
	if [ -n "$_components" ]; then
		echo "test_override_get_pkg_components_list: FAIL(7)"
		return
	fi

	_components=`override_get_pkg_components_list 'c' '1.0slind0' 'stable'`
	if [ -n "$_components" ]; then
		echo "test_override_get_pkg_components_list: FAIL(8)"
		return
	fi

	_components=`override_get_pkg_components_list 'c' '1.0slind1' 'stable' | sort | xargs`
	if [ "$_components" != "data-arm data-i386 data-mips data-ppc data-sh4" ]; then
		echo "test_override_get_pkg_components_list: FAIL(9)"
		return
	fi

	_components=`override_get_pkg_components_list 'c' '1.0slind1' 'stable' 'ppc' | sort | xargs`
	if [ "$_components" != "data-ppc" ]; then
		echo "test_override_get_pkg_components_list: FAIL(10)"
		return
	fi

	_components=`override_get_pkg_components_list 'd' '1.0slind0' 'stable'`
	if [ -n "$_components" ]; then
		echo "test_override_get_pkg_components_list: FAIL(11)"
		return
	fi
	
	echo "test_override_get_pkg_components_list: OK"
}

test_override_try_add_package() {
	local _result
	local _components

	_result=`override_try_add_package 'gcc' '4.1.2-1' 'clydesdale' 'broken'`
	if [ "$_result" != OK ]; then
		echo "test_override_try_add_package: FAIL(1)"
		return
	fi
	_components=`override_get_pkg_components_list 'gcc' '4.1.2-1' 'clydesdale'`
	if [ "$_components" != "broken" ]; then
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
	_components=`override_get_pkg_components_list 'gcc' '4.1.2-2' 'clydesdale'`
	if [ "$_components" != "broken1" ]; then
		echo "test_override_try_add_package: FAIL(3a)"
		return
	fi
	_components=`override_get_pkg_components_list 'gcc' '4.1.2-1' 'attic'`
	if [ "$_components" != "broken" ]; then
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

test_database
test_override_get_pkg_arches_list
test_override_get_pkg_components_list
test_override_try_add_package
test_pkg
test_deb
test_dsc
override_insert_new_record 'b' '1.0slind3' 'stable' 'i386' 'data'
for f in $test_PKGDIR/*.deb;do
    override_insert_deb_info $f "stable" "i386"
done

