--
-- SELECT
--
--Testcase 1:
CREATE EXTENSION :DB_EXTENSIONNAME;
--Testcase 2:
CREATE SERVER :DB_SERVERNAME FOREIGN DATA WRAPPER :DB_EXTENSIONNAME
  OPTIONS (odbc_DRIVER :DB_DRIVERNAME, odbc_SERVER :DB_SERVER, odbc_port :DB_PORT, odbc_DATABASE :DB_DATABASE);
--Testcase 3:
CREATE USER MAPPING FOR public SERVER :DB_SERVERNAME OPTIONS (odbc_UID :DB_USER, odbc_PWD :DB_PASS);  

--Testcase 4:
CREATE FOREIGN TABLE onek (
  unique1   int4,
  unique2   int4,
  two       int4,
  four      int4,
  ten       int4,
  twenty    int4,
  hundred   int4,
  thousand  int4,
  twothousand int4,
  fivethous int4,
  tenthous  int4,
  odd       int4,
  even      int4,
  stringu1  name,
  stringu2  name,
  string4   name) SERVER :DB_SERVERNAME OPTIONS (schema :DB_SCHEMA, table 'onek');

--Testcase 5:
CREATE FOREIGN TABLE onek2 (
  unique1   int4,
  unique2   int4,
  two       int4,
  four      int4,
  ten       int4,
  twenty    int4,
  hundred   int4,
  thousand  int4,
  twothousand int4,
  fivethous int4,
  tenthous  int4,
  odd       int4,
  even      int4,
  stringu1  name,
  stringu2  name,
  string4   name) SERVER :DB_SERVERNAME OPTIONS (schema :DB_SCHEMA, table 'onek');  

--Testcase 6:
CREATE FOREIGN TABLE int8_tbl (q1 int8, q2 int8) SERVER :DB_SERVERNAME OPTIONS (schema :DB_SCHEMA, table 'int8_tbl');

-- btree index
-- awk '{if($1<10){print;}else{next;}}' onek.data | sort +0n -1
--
--Testcase 7:
EXPLAIN VERBOSE
SELECT * FROM onek
   WHERE onek.unique1 < 10
   ORDER BY onek.unique1;
--Testcase 8:
SELECT * FROM onek
   WHERE onek.unique1 < 10
   ORDER BY onek.unique1;
--
-- awk '{if($1<20){print $1,$14;}else{next;}}' onek.data | sort +0nr -1
--
--Testcase 9:
EXPLAIN VERBOSE
SELECT onek.unique1, onek.stringu1 FROM onek
   WHERE onek.unique1 < 20
   ORDER BY unique1 using >;
--Testcase 10:
SELECT onek.unique1, onek.stringu1 FROM onek
   WHERE onek.unique1 < 20
   ORDER BY unique1 using >;
--
-- awk '{if($1>980){print $1,$14;}else{next;}}' onek.data | sort +1d -2
--
--Testcase 11:
EXPLAIN VERBOSE
SELECT onek.unique1, onek.stringu1 FROM onek
   WHERE onek.unique1 > 980
   ORDER BY stringu1 using <;

SELECT onek.unique1, onek.stringu1 FROM onek
   WHERE onek.unique1 > 980
   ORDER BY stringu1 using <;

--
-- awk '{if($1>980){print $1,$16;}else{next;}}' onek.data |
-- sort +1d -2 +0nr -1
--
--Testcase 12:
EXPLAIN VERBOSE
SELECT onek.unique1, onek.string4 FROM onek
   WHERE onek.unique1 > 980
   ORDER BY string4 using <, unique1 using >;
--Testcase 13:
SELECT onek.unique1, onek.string4 FROM onek
   WHERE onek.unique1 > 980
   ORDER BY string4 using <, unique1 using >;
--
-- awk '{if($1>980){print $1,$16;}else{next;}}' onek.data |
-- sort +1dr -2 +0n -1
--
--Testcase 14:
EXPLAIN VERBOSE
SELECT onek.unique1, onek.string4 FROM onek
   WHERE onek.unique1 > 980
   ORDER BY string4 using >, unique1 using <;
--Testcase 15:
SELECT onek.unique1, onek.string4 FROM onek
   WHERE onek.unique1 > 980
   ORDER BY string4 using >, unique1 using <;
--
-- awk '{if($1<20){print $1,$16;}else{next;}}' onek.data |
-- sort +0nr -1 +1d -2
--
--Testcase 16:
EXPLAIN VERBOSE
SELECT onek.unique1, onek.string4 FROM onek
   WHERE onek.unique1 < 20
   ORDER BY unique1 using >, string4 using <;
--Testcase 17:
SELECT onek.unique1, onek.string4 FROM onek
   WHERE onek.unique1 < 20
   ORDER BY unique1 using >, string4 using <;
--
-- awk '{if($1<20){print $1,$16;}else{next;}}' onek.data |
-- sort +0n -1 +1dr -2
--
--Testcase 18:
EXPLAIN VERBOSE
SELECT onek.unique1, onek.string4 FROM onek
   WHERE onek.unique1 < 20
   ORDER BY unique1 using <, string4 using >;
--Testcase 19:
SELECT onek.unique1, onek.string4 FROM onek
   WHERE onek.unique1 < 20
   ORDER BY unique1 using <, string4 using >;
--
-- test partial btree indexes
--
-- As of 7.2, planner probably won't pick an indexscan without stats,
-- so ANALYZE first.  Also, we want to prevent it from picking a bitmapscan
-- followed by sort, because that could hide index ordering problems.
--
-- ANALYZE onek2;

--Testcase 20:
SET enable_seqscan TO off;
--Testcase 21:
SET enable_bitmapscan TO off;
--Testcase 22:
SET enable_sort TO off;

--
-- awk '{if($1<10){print $0;}else{next;}}' onek.data | sort +0n -1
--
--Testcase 23:
EXPLAIN VERBOSE
SELECT onek2.* FROM onek2 WHERE onek2.unique1 < 10 ORDER BY onek2.unique1; -- add ORDER BY to stablize test result
--Testcase 24:
SELECT onek2.* FROM onek2 WHERE onek2.unique1 < 10 ORDER BY onek2.unique1; -- add ORDER BY to stablize test result
--
-- awk '{if($1<20){print $1,$14;}else{next;}}' onek.data | sort +0nr -1
--
--Testcase 25:
EXPLAIN VERBOSE
SELECT onek2.unique1, onek2.stringu1 FROM onek2
    WHERE onek2.unique1 < 20
    ORDER BY unique1 using >;
--Testcase 26:
SELECT onek2.unique1, onek2.stringu1 FROM onek2
    WHERE onek2.unique1 < 20
    ORDER BY unique1 using >;
--
-- awk '{if($1>980){print $1,$14;}else{next;}}' onek.data | sort +1d -2
--
--Testcase 27:
EXPLAIN VERBOSE
SELECT onek2.unique1, onek2.stringu1 FROM onek2
   WHERE onek2.unique1 > 980 ORDER BY onek2.unique1;
--Testcase 28:
SELECT onek2.unique1, onek2.stringu1 FROM onek2
   WHERE onek2.unique1 > 980 ORDER BY onek2.unique1;
--Testcase 29:
RESET enable_seqscan;
--Testcase 30:
RESET enable_bitmapscan;
--Testcase 31:
RESET enable_sort;
--
-- Test VALUES lists
--
--Testcase 32:
EXPLAIN VERBOSE
select * from onek, (values(147, 'RFAAAA'), (931, 'VJAAAA')) as v (i, j)
    WHERE onek.unique1 = v.i and onek.stringu1 = v.j;
--Testcase 33:
select * from onek, (values(147, 'RFAAAA'), (931, 'VJAAAA')) as v (i, j)
    WHERE onek.unique1 = v.i and onek.stringu1 = v.j;
-- a more complex case
-- looks like we're coding lisp :-)
--Testcase 34:
EXPLAIN VERBOSE
select * from onek,
  (values ((select i from
    (values(10000), (2), (389), (1000), (2000), ((select 10029))) as foo(i)
    order by i asc limit 1))) bar (i)
  where onek.unique1 = bar.i;
--Testcase 35:
select * from onek,
  (values ((select i from
    (values(10000), (2), (389), (1000), (2000), ((select 10029))) as foo(i)
    order by i asc limit 1))) bar (i)
  where onek.unique1 = bar.i;
-- try VALUES in a subquery
--Testcase 36:
EXPLAIN VERBOSE
select * from onek
    where (unique1,ten) in (values (1,1), (20,0), (99,9), (17,99))
    order by unique1;
--Testcase 37:
select * from onek
    where (unique1,ten) in (values (1,1), (20,0), (99,9), (17,99))
    order by unique1;
-- VALUES is also legal as a standalone query or a set-operation member
--Testcase 38:
EXPLAIN VERBOSE
VALUES (1,2), (3,4+4), (7,77.7)
UNION ALL
SELECT 2+2, 57
UNION ALL
SELECT q1, q2 FROM int8_tbl;
--Testcase 39:
VALUES (1,2), (3,4+4), (7,77.7)
UNION ALL
SELECT 2+2, 57
UNION ALL
SELECT q1, q2 FROM int8_tbl;

-- corner case: VALUES with no columns
-- PostgreSQL support create table with no column while MYSQL does not, therefore, result for MYSQL for table with no column will be error.
--Testcase 40:
CREATE FOREIGN TABLE nocols() SERVER :DB_SERVERNAME OPTIONS (schema :DB_SCHEMA, table 'nocols');
--Testcase 41:
INSERT INTO nocols DEFAULT VALUES;
--Testcase 42:
SELECT * FROM nocols n, LATERAL (VALUES(n.*)) v;

--
-- Test ORDER BY options
--

--Testcase 43:
CREATE FOREIGN TABLE foo (id int, f1 int) SERVER :DB_SERVERNAME OPTIONS (schema :DB_SCHEMA, table 'foo');
--Testcase 44:
EXPLAIN VERBOSE
SELECT * FROM foo ORDER BY f1;
--Testcase 45:
SELECT * FROM foo ORDER BY f1;
--Testcase 46:
EXPLAIN VERBOSE
SELECT * FROM foo ORDER BY f1 ASC;	-- same thing
--Testcase 47:
SELECT * FROM foo ORDER BY f1 ASC;
--Testcase 48:
EXPLAIN VERBOSE
SELECT * FROM foo ORDER BY f1 NULLS FIRST;
--Testcase 49:
SELECT * FROM foo ORDER BY f1 NULLS FIRST;
--Testcase 50:
EXPLAIN VERBOSE
SELECT * FROM foo ORDER BY f1 DESC;
--Testcase 51:
SELECT * FROM foo ORDER BY f1 DESC;
--Testcase 52:
EXPLAIN VERBOSE
SELECT * FROM foo ORDER BY f1 DESC NULLS LAST;
--Testcase 53:
SELECT * FROM foo ORDER BY f1 DESC NULLS LAST;
--
-- Test planning of some cases with partial indexes
--

-- partial index is usable
--Testcase 54:
explain (costs off)
select * from onek2 where unique2 = 11 and stringu1 = 'ATAAAA';
--Testcase 55:
select * from onek2 where unique2 = 11 and stringu1 = 'ATAAAA';
-- actually run the query with an analyze to use the partial index
--Testcase 56:
explain (costs off, analyze on, timing off, summary off)
select * from onek2 where unique2 = 11 and stringu1 = 'ATAAAA';
--Testcase 57:
explain (costs off)
select unique2 from onek2 where unique2 = 11 and stringu1 = 'ATAAAA';
--Testcase 58:
select unique2 from onek2 where unique2 = 11 and stringu1 = 'ATAAAA';
-- partial index predicate implies clause, so no need for retest
--Testcase 59:
explain (costs off)
select * from onek2 where unique2 = 11 and stringu1 < 'B';
--Testcase 60:
select * from onek2 where unique2 = 11 and stringu1 < 'B';
--Testcase 61:
explain (costs off)
select unique2 from onek2 where unique2 = 11 and stringu1 < 'B';
--Testcase 62:
select unique2 from onek2 where unique2 = 11 and stringu1 < 'B';
-- but if it's an update target, must retest anyway
--Testcase 63:
explain (costs off)
select unique2 from onek2 where unique2 = 11 and stringu1 < 'B' for update;
--Testcase 64:
select unique2 from onek2 where unique2 = 11 and stringu1 < 'B' for update;
-- partial index is not applicable
--Testcase 65:
explain (costs off)
select unique2 from onek2 where unique2 = 11 and stringu1 < 'C';
--Testcase 66:
select unique2 from onek2 where unique2 = 11 and stringu1 < 'C';
-- partial index implies clause, but bitmap scan must recheck predicate anyway
--Testcase 67:
SET enable_indexscan TO off;
--Testcase 68:
explain (costs off)
select unique2 from onek2 where unique2 = 11 and stringu1 < 'B';
--Testcase 69:
select unique2 from onek2 where unique2 = 11 and stringu1 < 'B';
--Testcase 70:
RESET enable_indexscan;
-- check multi-index cases too
--Testcase 71:
explain (costs off)
select unique1, unique2 from onek2
  where (unique2 = 11 or unique1 = 0) and stringu1 < 'B';
--Testcase 72:
select unique1, unique2 from onek2
  where (unique2 = 11 or unique1 = 0) and stringu1 < 'B';
--Testcase 73:
explain (costs off)
select unique1, unique2 from onek2
  where (unique2 = 11 and stringu1 < 'B') or unique1 = 0;
--Testcase 74:
select unique1, unique2 from onek2
  where (unique2 = 11 and stringu1 < 'B') or unique1 = 0;

--Testcase 75:
DROP SERVER :DB_SERVERNAME CASCADE;
--Testcase 76:
DROP EXTENSION :DB_EXTENSIONNAME CASCADE;
