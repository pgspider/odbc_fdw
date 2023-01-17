# Changelog

## 0.5.2.3-3
Released 2023-01-13

Changes:
- Support PosgreSQL 15
- Fix bind null for junk column

## 0.5.2.3-2
Released 2022-06-21

Changes:
- WHERE clause push-down
- Column push-down
- Pushdown function in WHERE clause
- Pushdown aggregate function on SELECT clause (target list)

## 0.5.2.3-1
Released 2021-12-23

Changes:
- Support PosgreSQL 14
- Support DML query
- Add enhance test

## 0.5.2.3
Released 2020-11-09

Changes:
- Fix bug with data over 8192 bytes with some drivers (https://github.com/CartoDB/odbc_fdw/pull/138).

## 0.5.2.2
Released 2020-11-02

Changes:
- Fix bug with short binary data (https://github.com/CartoDB/odbc_fdw/pull/137).

## 0.5.2.1
Released 2020-10-30

Changes:
- Fix potential privacy problem (https://github.com/CartoDB/odbc_fdw/pull/128).
- Fix bug with ignored first column (https://github.com/CartoDB/odbc_fdw/pull/129).
- Fix IMPORT SCHEMA not retrieving all tables (https://github.com/CartoDB/odbc_fdw/pull/129).
- Check for errors while reading data (https://github.com/CartoDB/odbc_fdw/pull/130).
- Support for VARBINAR (https://github.com/CartoDB/odbc_fdw/pull/131).

## 0.5.2
Released 2020-10-14

Changes:
- Improve error messages (https://github.com/CartoDB/odbc_fdw/pull/126).
- Add support for VARCHAR(0) (https://github.com/CartoDB/odbc_fdw/pull/125).
- Fix missing columns problem (https://github.com/CartoDB/odbc_fdw/pull/123).

## 0.5.1
Released 2020-02-17

Changes:
- Fixes #96 by closing connections (https://github.com/CartoDB/odbc_fdw/pull/116).

## 0.5.0
Released 2020-01-16

Changes:
- Update CI dependencies (https://github.com/CartoDB/odbc_fdw/pull/102).
- PG 12 compatibility (https://github.com/CartoDB/odbc_fdw/pull/104).
- Added support for MS Windows builds & CI (https://github.com/CartoDB/odbc_fdw/pull/101)

## 0.4.0
Released 2019-01-29

Changes:
- Changes in the testing infraestructure (https://github.com/CartoDB/odbc_fdw/pull/80, https://github.com/CartoDB/odbc_fdw/pull/81, https://github.com/CartoDB/odbc_fdw/pull/84, https://github.com/CartoDB/odbc_fdw/pull/87, https://github.com/CartoDB/odbc_fdw/pull/93).
- Fixes to support the final release of PostgreSQL 11 (https://github.com/CartoDB/odbc_fdw/pull/82).
- Use TupleDescAttr instead of its internal representation (https://github.com/CartoDB/odbc_fdw/pull/89).

## 0.3.0
Released 2018-02-20

Bug fixes:
- Fixed issues with travis builds
- elog_debug: Avoid warnings when disabled 0a8b95a
- Avoid unsigned/signed comparison warnings 763d70e

Announcements:
- Added support for PostgreSQL versions 9.6 and 10, and future v11.
- Changed to apache hive 2.2.1 in travis builds
- Updated README.md with supported driver versions 4ede641
- Added CONTRIBUTING.md document
- Added an `.editorconfig` file to help enforce formatting of c/h/sql/yml files 222b39a
- Applied bulk formatting pass to get everything lined up d53480e
- Added this NEWS.md file
- Added a release procedure in HOWTO_RELEASE.md file


## 0.2.0
Released 2016-09-30

Bug fixes:
- Fixed missing schema option `OPTION` a3b43b0

Announcements:
- Added test capabilities for all connectors
- Added support for schema-less ODBC data sources (e.g. Hive) 109557a
- Updated `freetds` package version to `1.00.14cdb7`
- Added ODBCTablesList function to query for the list of tables the user has access to in the server
- Added ODBCTableSize function to get the size, in rows, of the foreign table
- Added ODBCQuerySize function to get the size, in rows, of the provided query


## 0.1.0-rc1
Released 2016-08-03

Bug fixes:
- Quote connection attributes #15
- Handle single quotes when quoting options #19
- Prevent memory leak and race conditions d52fd60
- Handle partial SQLGetData results 3db51c0
- Use adequate minimum buffer size for numeric data to avoid precission loss df59364
- Fix various binary column problems 4caff4f

Announcements:
- Allows definition of arbitrary ODBC attributes with `odbc_` options 778ae02
- Limits size of varying columns and buffers 8149e32


## 0.0.1
Released 2016-07-15

First version based off https://github.com/bluthg/odbc_fdw at 0d44e9d. Additionally, it provides the following:

Bug fixes:
- Fixed compilation issues and API mismatches
- Fixed bug causing segfaults with query columns not present in foreign table
- Many other fixes for typos, NULL values, pointers, lenght of params, etc.

Announcements:
- Minimum PostgreSQL supported version updated to 9.5 and removed support for older versions
- Updated build instructions
- Added license file
- Updated README file
- Added driver, host and port parameters
- Added tests for the build `PGUSER=postgres make installcheck`
- Added support for `IMPORT FOREIGN SCHEMA`
- Added support for Add for no `sql_query` and no `sql_count` in options cases
- Added `encoding` option
- Allows username and password in server definition
- Added support for `GUID` columns
