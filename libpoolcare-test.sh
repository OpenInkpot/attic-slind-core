#!/bin/sh -x
test_PKGDIR="/tmp/pkg"
test_REPODIR="/tmp/repo"
test_POOLDIR="/tmp/pool"
REPODIR=${test_REPODIR}
DEVSUITE=unstable
ARCHES="i386 ppc arm"
. libpoolcare.sh

test_database() {
	test_sanity
	mkoverrides
	if [ $? -ne 0 ]; then
	    echo "test_database: FAIL(1)"
	    return
	else
	    $SQLCMD "INSERT INTO overrides (pkgname, version, suite, arch, component)
		 VALUES('a','1.0slind0','stable','i386','data')"
	    $SQLCMD "INSERT INTO overrides (pkgname, version, suite, arch, component)
		 VALUES('a','1.0slind0','stable','','data-new')"
	    $SQLCMD "INSERT INTO overrides (pkgname, version, suite, arch, component)
		 VALUES('a','1.0slind0','testing','','data')"
	    $SQLCMD "INSERT INTO overrides (pkgname, version, suite, arch, component)
		 VALUES('a','1.0slind0','testing','ppc','data')"
	    $SQLCMD "INSERT INTO overrides (pkgname, version, suite, arch, component)
		 VALUES('a','1.0slind0','stable','arm','data')"
	    $SQLCMD "INSERT INTO overrides (pkgname, version, suite, arch, component)
		 VALUES('a','1.0slind2','stable','ppc','data')"
	    $SQLCMD "INSERT INTO overrides (pkgname, version, suite, arch, component)
		 VALUES('b','1.0slind2','stable','ppc','data')"
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
test_database
test_pkg
test_deb
test_dsc
# test_override
