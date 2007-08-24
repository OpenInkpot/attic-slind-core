-- DON'T MODIFY THIS FILE BY MINDLESS DUMP! YOU WILL LOSE COMMENTS!
-- TO MODIFY FROM DUMP, COPY-OUT ACTUAL INSERTIONS!

-- overrides.db is a database which purpose is to have fine-grained control over packages.

-- Table overrides controls source packages. Only packages matching
-- this table records could be included in indexes and thus be
-- installed from repository
BEGIN TRANSACTION;
CREATE TABLE overrides (
--	Name of source
		pkgname varchar NOT NULL,
--	Version of source
		version varchar NOT NULL,
--	Suite (distro version nickname)
		suite char(24) NOT NULL,
--	Architecture (arch name or empty for package to belong
--	to all architectures. We need 2 or more table records for 2 or
--	more architectures.
		arch char(32) NOT NULL,
--	Distribution component (and source section)
		component varchar NOT NULL,
		UNIQUE (pkgname, version, suite, arch, component)
);
INSERT INTO "overrides" VALUES('freetype','2.2.1-4.slind0','clydesdale','','gui');
INSERT INTO "overrides" VALUES('base-passwd','3.5.10.slind3','attic','','base');
INSERT INTO "overrides" VALUES('base-files','3.1.6.slind3','attic','','base');
INSERT INTO "overrides" VALUES('busybox','1:1.01-3','clydesdale','','core');
INSERT INTO "overrides" VALUES('ifupdown','0.6.7.slind1','attic','','broken');
INSERT INTO "overrides" VALUES('ifupdown','0.6.7.slind2','attic','','base');
INSERT INTO "overrides" VALUES('ncurses','5.4-4.slind2','attic','','broken');
INSERT INTO "overrides" VALUES('ncurses','5.4-4.slind3','clydesdale','','core');
INSERT INTO "overrides" VALUES('netbase','4.21.slind1','attic','','broken');
INSERT INTO "overrides" VALUES('netbase','4.21.slind2','attic','','base');
INSERT INTO "overrides" VALUES('net-tools','1.60-15.slind1','clydesdale','','broken');
INSERT INTO "overrides" VALUES('sysklogd','1.4.1-17.slind1','attic','','base');
INSERT INTO "overrides" VALUES('sysvinit','2.86.ds1-slind0','attic','','broken');
INSERT INTO "overrides" VALUES('sysvinit','2.86.ds1-slind1','clydesdale','','core');
INSERT INTO "overrides" VALUES('udhcp','0.9.8cvs20050303-2.slind1','attic','','net');
INSERT INTO "overrides" VALUES('zlib','1:1.2.3-4.slind3','clydesdale','','core');
INSERT INTO "overrides" VALUES('binutils','2.17-2.slind0','clydesdale','','host-tools');
INSERT INTO "overrides" VALUES('cross-shell','0.2','clydesdale','','host-tools');
INSERT INTO "overrides" VALUES('dpkg','1:1.13.25.slind1','clydesdale','','host-tools');
INSERT INTO "overrides" VALUES('dpkg','1:1.13.25.slind1','clydesdale','','core');
INSERT INTO "overrides" VALUES('dpkg-cross','2:1.34','clydesdale','','host-tools');
INSERT INTO "overrides" VALUES('dpkg-pool','0.2','attic','','broken');
INSERT INTO "overrides" VALUES('dpkg-pool','0.3','clydesdale','','host-tools');
INSERT INTO "overrides" VALUES('fakechroot','2.5-1.slind2','clydesdale','','broken');
INSERT INTO "overrides" VALUES('fakechroot-cross','2.5-2','clydesdale','','host-tools');
INSERT INTO "overrides" VALUES('gdb','6.6-1','clydesdale','','host-tools');
INSERT INTO "overrides" VALUES('glibc','2.4-1','clydesdale','','host-tools');
INSERT INTO "overrides" VALUES('glibc','2.3.6-1','clydesdale','arm','host-tools');
INSERT INTO "overrides" VALUES('grasp','0.1','clydesdale','','host-tools');
INSERT INTO "overrides" VALUES('gcc-4.1','4.1.0-slind0','attic','','host-tools');
INSERT INTO "overrides" VALUES('gcc-4.1','4.1.2-1','clydesdale','','host-tools');
INSERT INTO "overrides" VALUES('linux-kernel-headers','2.6.12.0-1.slind1','clydesdale','','host-tools');
INSERT INTO "overrides" VALUES('northern-cross','0.1.3','clydesdale','','host-tools');
INSERT INTO "overrides" VALUES('slind-utils','0.1','clydesdale','','host-tools');
INSERT INTO "overrides" VALUES('slind-core','0.1','attic','','broken');
INSERT INTO "overrides" VALUES('slind-core','0.2','attic','','broken');
INSERT INTO "overrides" VALUES('slind-core','0.3','clydesdale','','host-tools');
INSERT INTO "overrides" VALUES('toolchain-package','0.1','clydesdale','','host-tools');
INSERT INTO "overrides" VALUES('uclibc','0.9.28.3-1','clydesdale','','host-tools');
INSERT INTO "overrides" VALUES('uclibc','0.9.28svn20060414-1slind0','attic','','libs');
INSERT INTO "overrides" VALUES('udhcp','0.9.8cvs20050303-2.slind2','clydesdale','','core');
INSERT INTO "overrides" VALUES('base-files','3.1.6.slind4','clydesdale','','core');
INSERT INTO "overrides" VALUES('base-passwd','3.5.10.slind4','clydesdale','','core');
INSERT INTO "overrides" VALUES('ifupdown','0.6.7.slind3','clydesdale','','core');
INSERT INTO "overrides" VALUES('sysklogd','1.4.1-17.slind2','clydesdale','','core');
INSERT INTO "overrides" VALUES('netbase','4.21.slind3','clydesdale','','core');
INSERT INTO "overrides" VALUES('joe','3.1-0.2','attic','','editors');
INSERT INTO "overrides" VALUES('glib2.0','2.10.3-4.slind0','clydesdale','','core');
INSERT INTO "overrides" VALUES('gettext','0.14.5-2slind4','attic','','devel');
INSERT INTO "overrides" VALUES('dropbear','0.47-1.slind1','attic','','net');
INSERT INTO "overrides" VALUES('openssl','0.9.8a-7.slind1','attic','','utils');
INSERT INTO "overrides" VALUES('openssh','1:4.2p1-5.slind1','attic','','net');
INSERT INTO "overrides" VALUES('cron','3.0pl1-94.slind2','attic','','admin');
INSERT INTO "overrides" VALUES('logrotate','3.7.1-3.slind2','clydesdale','','core');
INSERT INTO "overrides" VALUES('joe','3.1-0.3','clydesdale','','core');
INSERT INTO "overrides" VALUES('cron','3.0pl1-94.slind3','clydesdale','','core');
INSERT INTO "overrides" VALUES('openssl','0.9.8a-7.slind2','clydesdale','','security');
INSERT INTO "overrides" VALUES('openssh','1:4.2p1-5.slind2','clydesdale','','security');
INSERT INTO "overrides" VALUES('dropbear','0.47-1.slind2','clydesdale','','security');
INSERT INTO "overrides" VALUES('gettext','0.14.5-2slind5','clydesdale','','core');
INSERT INTO "overrides" VALUES('apt','0.6.42.1.slind2','clydesdale','','core');
CREATE TABLE binary_cache (
--	Name of source
		pkgname varchar NOT NULL,
--	Version of source
		version varchar NOT NULL,
--	Suite (distro version nickname)
		suite char(24) NOT NULL,
--	Architecture to be included in index, can't be 'all' or empty.
		index_arch char(32) NOT NULL,
--	Distribution component (and source section) for source.
		component varchar NOT NULL,
--	File name in pool, relative to pool's root.
		pool_file varchar NOT NULL,
--	Name for binary package as in control file.
		deb_name varchar NOT NULL,
--	Architecture for binary package (.deb), can't be empty, and can be 'all'.
		deb_arch varchar NOT NULL,
--	Size of binary package in bytes.
		deb_size int NOT NULL,
--	MD5 hash sum of binary package.
		deb_md5sum char(32) NOT NULL,
--	Various other fields of control file which are not so interesting
--	for purpose of database, for index generation
		deb_control text NOT NULL,
--	Distribution component (and package section) for .deb.
		deb_section varchar NOT NULL,
		UNIQUE (pkgname, suite, index_arch, component, deb_name, deb_section)
);
CREATE VIEW bin_packages AS SELECT 'Package: ' || deb_name || X'0A'
			||'Source: ' || pkgname || X'0A'
	                ||'Version: ' || version || X'0A'
			||'Architecture: ' || deb_arch || X'0A'
			||'Filename: ' || pool_file || X'0A'
			||'Size: ' || deb_size || X'0A'
			||'MD5sum: ' || deb_md5sum || X'0A'
			||'Section: ' || deb_section || X'0A'
			|| deb_control || X'0A' AS entry, suite, deb_section, index_arch
	            FROM binary_cache;

-- binary_cache checking triggers for INSERT and UPDATE event.
-- Try to keep them identical.
CREATE TRIGGER check_binary_cache_insert BEFORE INSERT ON binary_cache
FOR EACH ROW
BEGIN
	SELECT RAISE(ROLLBACK, 'insert ton table binary_cache violates non-emptiness policy for fields')
	WHERE NEW.index_arch IS NULL OR trim(NEW.index_arch) = '' OR
	      NEW.pkgname IS NULL OR trim(NEW.pkgname) = '' OR
	      NEW.version IS NULL OR trim(NEW.version) = '' OR
	      NEW.suite IS NULL OR trim(NEW.suite) = '' OR
	      NEW.component IS NULL OR trim(NEW.component) = '' OR
	      NEW.pool_file IS NULL OR trim(NEW.pool_file) = '' OR
	      NEW.deb_name IS NULL OR trim(NEW.pkgname) = '' OR
	      NEW.deb_md5sum IS NULL OR trim(NEW.pkgname) = '' OR
	      NEW.deb_size IS NULL OR NEW.deb_size <= 0 OR
	      NEW.deb_control IS NULL;
	SELECT RAISE(ROLLBACK, 'primary key violation on table binary_cache')
	WHERE (SELECT pkgname
		      FROM overrides
		      WHERE pkgname=NEW.pkgname AND
			    version=NEW.version AND suite=NEW.suite)
	      IS NULL;
END;

CREATE TRIGGER check_binary_cache_delete BEFORE UPDATE ON binary_cache
FOR EACH ROW
BEGIN
	SELECT RAISE(ROLLBACK, 'insert on table binary_cache violates non-emptiness policy for fields')
	WHERE NEW.index_arch IS NULL OR trim(NEW.index_arch) = '' OR
	      NEW.pkgname IS NULL OR trim(NEW.pkgname) = '' OR
	      NEW.version IS NULL OR trim(NEW.version) = '' OR
	      NEW.suite IS NULL OR trim(NEW.suite) = '' OR
	      NEW.component IS NULL OR trim(NEW.component) = '' OR
	      NEW.pool_file IS NULL OR trim(NEW.pool_file) = '' OR
	      NEW.deb_name IS NULL OR trim(NEW.pkgname) = '' OR
	      NEW.deb_md5sum IS NULL OR trim(NEW.pkgname) = '' OR
	      NEW.deb_size IS NULL OR NEW.deb_size <= 0 OR
	      NEW.deb_control IS NULL;
	SELECT RAISE(ROLLBACK, 'primary key violation on table binary_cache')
	WHERE (SELECT pkgname
		      FROM overrides
		      WHERE pkgname=NEW.pkgname AND
			    version=NEW.version AND suite=NEW.suite)
	      IS NULL;
END;

CREATE TRIGGER check_overrides BEFORE INSERT ON overrides
FOR EACH ROW
BEGIN
	SELECT RAISE(ROLLBACK, 'insert on table overrides violates non-emptiness policy for fields')
	WHERE NEW.pkgname IS NULL OR trim(NEW.pkgname) = '' OR
	      NEW.version IS NULL OR trim(NEW.version) = '' OR
	      NEW.suite IS NULL OR trim(NEW.suite) = '' OR
	      NEW.component IS NULL OR trim(NEW.component) = '' OR
	      NEW.arch IS NULL OR trim(NEW.arch) = '';
END;

-- This trigger cleans-up binary_cache table after deletions from overrides.
CREATE TRIGGER check_overrides_del AFTER DELETE ON overrides
FOR EACH ROW
BEGIN
	DELETE FROM binary_cache
	WHERE (SELECT pkgname FROM overrides WHERE pkgname=OLD.pkgname
			      AND version=OLD.version AND suite=OLD.suite) IS NULL
	AND suite = OLD.suite;
END;

-- We will use this view for triggers for special operations
CREATE VIEW src_packages AS SELECT * FROM overrides;

-- On insertion to this view we move old records to attic before.
CREATE TRIGGER src_upgrade INSTEAD OF INSERT ON src_packages
FOR EACH ROW
BEGIN
		-- Moving old records to attic if only 1 record exists for this suite.
		-- Assumes we are doing upgrade, not downgrade.
		-- It is unable to check debian versions.
		UPDATE overrides SET suite='attic'
		WHERE (SELECT count(pkgname) FROM overrides WHERE pkgname=NEW.pkgname
								  AND version=NEW.version
								  AND suite=NEW.suite) = 1
		      AND pkgname=NEW.pkgname AND suite=NEW.suite;
		INSERT INTO overrides(pkgname, version, suite, arch, component)
		VALUES(NEW.pkgname, NEW.version, NEW.suite, NEW.arch, NEW.component);
END;

COMMIT;

