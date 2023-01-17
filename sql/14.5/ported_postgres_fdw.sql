-- SET consistant time zones;
--Testcase 1:
SET timezone = 'PST8PDT';
-- ===================================================================
-- create FDW objects
-- ===================================================================

--Testcase 2:
CREATE EXTENSION :DB_EXTENSIONNAME;

--Testcase 3:
CREATE SERVER :DB_SERVERNAME FOREIGN DATA WRAPPER :DB_EXTENSIONNAME
            OPTIONS (odbc_DRIVER :DB_DRIVERNAME,
                    odbc_SERVER :DB_SERVER,
					odbc_PORT :DB_PORT,
					odbc_DATABASE :DB_DATABASE_PORT_TEST
			);
--Testcase 4:
CREATE SERVER :DB_SERVERNAME2 FOREIGN DATA WRAPPER :DB_EXTENSIONNAME
            OPTIONS (odbc_DRIVER :DB_DRIVERNAME,
                    odbc_SERVER :DB_SERVER,
					odbc_PORT :DB_PORT,
					odbc_DATABASE :DB_DATABASE_PORT_TEST
			);

--Testcase 5:
CREATE USER MAPPING FOR public SERVER :DB_SERVERNAME OPTIONS(odbc_UID :DB_USER, odbc_PWD :DB_PASS);
--Testcase 6:
CREATE USER MAPPING FOR public SERVER :DB_SERVERNAME2 OPTIONS(odbc_UID :DB_USER, odbc_PWD :DB_PASS);

-- ===================================================================
-- create objects used through FDW postgres_svr server
-- ===================================================================
--Testcase 7:
CREATE TYPE user_enum AS ENUM ('foo', 'bar', 'buz');
--Testcase 8:
CREATE SCHEMA "S 1";
IMPORT FOREIGN SCHEMA :DB_SCHEMA_PORT_TEST2 FROM SERVER :DB_SERVERNAME INTO "S 1";

--Testcase 9:
INSERT INTO "S 1"."T1"
	SELECT id,
	       id % 10,
	       to_char(id, 'FM00000'),
	       '1970-01-01'::timestamptz + ((id % 100) || ' days')::interval,
	       '1970-01-01'::timestamp + ((id % 100) || ' days')::interval,
	       id % 10,
	       id % 10,
	       'foo'
	FROM generate_series(1, 1000) id;

--Testcase 10:
INSERT INTO "S 1"."T2"
	SELECT id,
	       'AAA' || to_char(id, 'FM000')
	FROM generate_series(1, 100) id;
--Testcase 11:
INSERT INTO "S 1"."T3"
	SELECT id,
	       id + 1,
	       'AAA' || to_char(id, 'FM000')
	FROM generate_series(1, 100) id;
--Testcase 12:
DELETE FROM "S 1"."T3" WHERE c1 % 2 != 0;	-- delete for outer join tests
--Testcase 13:
INSERT INTO "S 1"."T4"
	SELECT id,
	       id + 1,
	       'AAA' || to_char(id, 'FM000')
	FROM generate_series(1, 100) id;
--Testcase 14:
DELETE FROM "S 1"."T4" WHERE c1 % 3 != 0;	-- delete for outer join tests

-- ===================================================================
-- create foreign tables
-- ===================================================================
--Testcase 15:
CREATE FOREIGN TABLE ft1 (
	-- c0 int,
	c1 int OPTIONS (key 'true'),
	c2 int NOT NULL,
	c3 text,
	c4 timestamp,
	c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft1',
	c8 text
) SERVER :DB_SERVERNAME;
-- ALTER FOREIGN TABLE ft1 DROP COLUMN c0;  --ODBC can not work with it
-- BUG

--Testcase 16:
CREATE FOREIGN TABLE ft2 (
	c1 int OPTIONS (key 'true'),
	c2 int NOT NULL,
	-- cx int,
	c3 text,
	c4 timestamp,
	c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft2',
	c8 text
) SERVER :DB_SERVERNAME;
-- ALTER FOREIGN TABLE ft2 DROP COLUMN cx; --ODBC can not work with it

--Testcase 17:
CREATE FOREIGN TABLE ft4 (
	c1 int OPTIONS (key 'true'),
	c2 int NOT NULL,
	c3 text
) SERVER :DB_SERVERNAME OPTIONS (schema :DB_SCHEMA_PORT_TEST, table 'T3');

--Testcase 18:
CREATE FOREIGN TABLE ft5 (
	c1 int OPTIONS (key 'true'),
	c2 int NOT NULL,
	c3 text
) SERVER :DB_SERVERNAME OPTIONS (schema :DB_SCHEMA_PORT_TEST, table 'T4');

--Testcase 19:
CREATE FOREIGN TABLE ft6 (
	c1 int OPTIONS (key 'true'),
	c2 int NOT NULL,
	c3 text
) SERVER :DB_SERVERNAME2 OPTIONS (schema :DB_SCHEMA_PORT_TEST, table 'T4');

-- ===================================================================
-- tests for validator
-- ===================================================================
-- requiressl and some other parameters are omitted because
-- valid values for them depend on configure options
-- ALTER SERVER :DB_SERVERNAME OPTIONS (
-- 	use_remote_estimate 'false',
-- 	updatable 'true',
-- 	fdw_startup_cost '123.456',
-- 	fdw_tuple_cost '0.123',
-- 	service 'value',
-- 	connect_timeout 'value',
-- 	dbname 'value',
-- 	host 'value',
-- 	hostaddr 'value',
-- 	port 'value',
-- 	--client_encoding 'value',
-- 	application_name 'value',
-- 	--fallback_application_name 'value',
-- 	keepalives 'value',
-- 	keepalives_idle 'value',
-- 	keepalives_interval 'value',
-- 	tcp_user_timeout 'value',
-- 	-- requiressl 'value',
-- 	sslcompression 'value',
-- 	sslmode 'value',
-- 	sslcert 'value',
-- 	sslkey 'value',
-- 	sslrootcert 'value',
-- 	sslcrl 'value',
-- 	--requirepeer 'value',
-- 	krbsrvname 'value',
-- 	gsslib 'value'
-- 	--replication 'value'
-- );

-- Error, invalid list syntax
--Testcase 20:
ALTER SERVER :DB_SERVERNAME OPTIONS (ADD extensions 'foo; bar');

-- OK but gets a warning
--Testcase 21:
ALTER SERVER :DB_SERVERNAME OPTIONS (ADD extensions 'foo, bar');
-- ALTER SERVER :DB_SERVERNAME OPTIONS (DROP extensions);

-- Option user, password is not supported
-- ALTER USER MAPPING FOR public SERVER :DB_SERVERNAME
-- 	OPTIONS (DROP user, DROP password);

-- Attempt to add a valid option that's not allowed in a user mapping
-- Option sslmode is not supported
-- ALTER USER MAPPING FOR public SERVER :DB_SERVERNAME
-- 	OPTIONS (ADD sslmode 'require');

-- But we can add valid ones fine
-- Option sslpassword is not supported
-- ALTER USER MAPPING FOR public SERVER :DB_SERVERNAME
-- 	OPTIONS (ADD sslpassword 'dummy');

-- Ensure valid options we haven't used in a user mapping yet are
-- permitted to check validation.
-- Option sslkey, sslcert are not supported
-- ALTER USER MAPPING FOR public SERVER :DB_SERVERNAME
-- 	OPTIONS (ADD sslkey 'value', ADD sslcert 'value');

--Testcase 22:
ALTER FOREIGN TABLE ft1 OPTIONS (schema :DB_SCHEMA_PORT_TEST, table 'T1');
--Testcase 23:
ALTER FOREIGN TABLE ft2 OPTIONS (schema :DB_SCHEMA_PORT_TEST, table 'T1');
--Testcase 24:
ALTER FOREIGN TABLE ft1 ALTER COLUMN c1 OPTIONS (column 'C_1');
--Testcase 25:
ALTER FOREIGN TABLE ft2 ALTER COLUMN c1 OPTIONS (column 'C_1');
--Testcase 26:
\det+

-- Test that alteration of server options causes reconnection
-- Remote's errors might be non-English, so hide them to ensure stable results
\set VERBOSITY terse
--Testcase 27:
SELECT c3, c4 FROM ft1 ORDER BY c3, c1 LIMIT 1;  -- should work
--Testcase 28:
ALTER SERVER :DB_SERVERNAME OPTIONS (SET odbc_DATABASE 'no such database');
--Testcase 29:
SELECT c3, c4 FROM ft1 ORDER BY c3, c1 LIMIT 1;  -- should fail
--Testcase 30:
ALTER SERVER :DB_SERVERNAME OPTIONS (SET odbc_DATABASE :DB_DATABASE_PORT_TEST);
--Testcase 31:
SELECT c3, c4 FROM ft1 ORDER BY c3, c1 LIMIT 1;  -- should work again

-- Test that alteration of user mapping options causes reconnection
-- Option 'user' is not supported
-- ALTER USER MAPPING FOR CURRENT_USER SERVER :DB_SERVERNAME
--    OPTIONS (ADD user 'no such user');
-- SELECT c3, c4 FROM ft1 ORDER BY c3, c1 LIMIT 1;  -- should fail
-- ALTER USER MAPPING FOR CURRENT_USER SERVER :DB_SERVERNAME
--    OPTIONS (DROP user);
-- SELECT c3, c4 FROM ft1 ORDER BY c3, c1 LIMIT 1;  -- should work again
\set VERBOSITY default

-- Now we should be able to run ANALYZE.
-- To exercise multiple code paths, we use local stats on ft1
-- and remote-estimate mode on ft2.
--Testcase 32:
ALTER FOREIGN TABLE ft2 OPTIONS (use_remote_estimate 'true');

-- ===================================================================
-- simple queries
-- ===================================================================
-- single table without alias
--Testcase 33:
EXPLAIN (COSTS OFF) SELECT * FROM ft1 ORDER BY c3, c1 OFFSET 100 LIMIT 10;
--Testcase 34:
SELECT * FROM ft1 ORDER BY c3, c1 OFFSET 100 LIMIT 10;
-- single table with alias - also test that tableoid sort is not pushed to remote side
--Testcase 35:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 ORDER BY t1.c3, t1.c1, t1.tableoid OFFSET 100 LIMIT 10;
--Testcase 36:
SELECT * FROM ft1 t1 ORDER BY t1.c3, t1.c1, t1.tableoid OFFSET 100 LIMIT 10;
-- whole-row reference
--Testcase 37:
EXPLAIN (VERBOSE, COSTS OFF) SELECT t1 FROM ft1 t1 ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
--Testcase 38:
SELECT t1 FROM ft1 t1 ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
-- empty result
--Testcase 39:
SELECT * FROM ft1 WHERE false;
-- with WHERE clause
--Testcase 40:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE t1.c1 = 101 AND t1.c6 = '1' AND t1.c7 >= '1';
--Testcase 41:
SELECT * FROM ft1 t1 WHERE t1.c1 = 101 AND t1.c6 = '1' AND t1.c7 >= '1';
-- with FOR UPDATE/SHARE
--Testcase 42:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c1 = 101 FOR UPDATE;
--Testcase 43:
SELECT * FROM ft1 t1 WHERE c1 = 101 FOR UPDATE;
--Testcase 44:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c1 = 102 FOR SHARE;
--Testcase 45:
SELECT * FROM ft1 t1 WHERE c1 = 102 FOR SHARE;
-- aggregate
--Testcase 46:
SELECT COUNT(*) FROM ft1 t1;
-- subquery
--Testcase 47:
SELECT * FROM ft1 t1 WHERE t1.c3 IN (SELECT c3 FROM ft2 t2 WHERE c1 <= 10) ORDER BY c1;
-- subquery+MAX
--Testcase 48:
SELECT * FROM ft1 t1 WHERE t1.c3 = (SELECT MAX(c3) FROM ft2 t2) ORDER BY c1;
-- used in CTE
--Testcase 49:
WITH t1 AS (SELECT * FROM ft1 WHERE c1 <= 10) SELECT t2.c1, t2.c2, t2.c3, t2.c4 FROM t1, ft2 t2 WHERE t1.c1 = t2.c1 ORDER BY t1.c1;
-- fixed values
--Testcase 50:
SELECT 'fixed', NULL FROM ft1 t1 WHERE c1 = 1;
-- Test forcing the remote server to produce sorted data for a merge join.
--Testcase 51:
SET enable_hashjoin TO false;
--Testcase 52:
SET enable_nestloop TO false;
-- inner join; expressions in the clauses appear in the equivalence class list
--Testcase 53:
EXPLAIN (VERBOSE, COSTS OFF)
	SELECT t1.c1, t2."C_1" FROM ft2 t1 JOIN "S 1"."T1" t2 ON (t1.c1 = t2."C_1") OFFSET 100 LIMIT 10;
--Testcase 54:
SELECT t1.c1, t2."C_1" FROM ft2 t1 JOIN "S 1"."T1" t2 ON (t1.c1 = t2."C_1") OFFSET 100 LIMIT 10;
-- outer join; expressions in the clauses do not appear in equivalence class
-- list but no output change as compared to the previous query
--Testcase 55:
EXPLAIN (VERBOSE, COSTS OFF)
	SELECT t1.c1, t2."C_1" FROM ft2 t1 LEFT JOIN "S 1"."T1" t2 ON (t1.c1 = t2."C_1") OFFSET 100 LIMIT 10;
--Testcase 56:
SELECT t1.c1, t2."C_1" FROM ft2 t1 LEFT JOIN "S 1"."T1" t2 ON (t1.c1 = t2."C_1") OFFSET 100 LIMIT 10;
-- A join between local table and foreign join. ORDER BY clause is added to the
-- foreign join so that the local table can be joined using merge join strategy.
--Testcase 57:
EXPLAIN (VERBOSE, COSTS OFF)
	SELECT t1."C_1" FROM "S 1"."T1" t1 left join ft1 t2 join ft2 t3 on (t2.c1 = t3.c1) on (t3.c1 = t1."C_1") OFFSET 100 LIMIT 10;
--Testcase 58:
SELECT t1."C_1" FROM "S 1"."T1" t1 left join ft1 t2 join ft2 t3 on (t2.c1 = t3.c1) on (t3.c1 = t1."C_1") OFFSET 100 LIMIT 10;
-- Test similar to above, except that the full join prevents any equivalence
-- classes from being merged. This produces single relation equivalence classes
-- included in join restrictions.
--Testcase 59:
EXPLAIN (VERBOSE, COSTS OFF)
	SELECT t1."C_1", t2.c1, t3.c1 FROM "S 1"."T1" t1 left join ft1 t2 full join ft2 t3 on (t2.c1 = t3.c1) on (t3.c1 = t1."C_1") OFFSET 100 LIMIT 10;
--Testcase 60:
SELECT t1."C_1", t2.c1, t3.c1 FROM "S 1"."T1" t1 left join ft1 t2 full join ft2 t3 on (t2.c1 = t3.c1) on (t3.c1 = t1."C_1") OFFSET 100 LIMIT 10;
-- Test similar to above with all full outer joins
--Testcase 61:
EXPLAIN (VERBOSE, COSTS OFF)
	SELECT t1."C_1", t2.c1, t3.c1 FROM "S 1"."T1" t1 full join ft1 t2 full join ft2 t3 on (t2.c1 = t3.c1) on (t3.c1 = t1."C_1") OFFSET 100 LIMIT 10;
--Testcase 62:
SELECT t1."C_1", t2.c1, t3.c1 FROM "S 1"."T1" t1 full join ft1 t2 full join ft2 t3 on (t2.c1 = t3.c1) on (t3.c1 = t1."C_1") OFFSET 100 LIMIT 10;
--Testcase 63:
RESET enable_hashjoin;
--Testcase 64:
RESET enable_nestloop;

-- Test executing assertion in estimate_path_cost_size() that makes sure that
-- retrieved_rows for foreign rel re-used to cost pre-sorted foreign paths is
-- a sensible value even when the rel has tuples=0
--Testcase 65:
CREATE FOREIGN TABLE ft_empty (c1 int OPTIONS (key 'true'), c2 text)
  SERVER :DB_SERVERNAME OPTIONS (schema :DB_SCHEMA_PORT_TEST, table 'loct_empty');
--Testcase 66:
INSERT INTO ft_empty
  SELECT id, 'AAA' || to_char(id, 'FM000') FROM generate_series(1, 100) id;
--Testcase 67:
DELETE FROM ft_empty;
-- ANALYZE ft_empty;
--Testcase 68:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft_empty ORDER BY c1;

-- ===================================================================
-- WHERE with remotely-executable conditions
-- ===================================================================
--Testcase 69:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE t1.c1 = 1;         -- Var, OpExpr(b), Const
--Testcase 70:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE t1.c1 = 100 AND t1.c2 = 0; -- BoolExpr
--Testcase 71:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c1 IS NULL;        -- NullTest
--Testcase 72:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c1 IS NOT NULL;    -- NullTest
--Testcase 73:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE round(abs(c1), 0) = 1; -- FuncExpr
--Testcase 74:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c1 = -c1;          -- OpExpr(l)
--Testcase 75:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE (c1 IS NOT NULL) IS DISTINCT FROM (c1 IS NOT NULL); -- DistinctExpr
--Testcase 76:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c1 = ANY(ARRAY[c2, 1, c1 + 0]); -- ScalarArrayOpExpr
--Testcase 77:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c1 = (ARRAY[c1,c2,3])[1]; -- SubscriptingRef
--Testcase 78:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c6 = E'foo''s\\bar';  -- check special chars
--Testcase 79:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c8 = 'foo';  -- can't be sent to remote
-- parameterized remote path for foreign table
--Testcase 80:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM "S 1"."T1" a, ft2 b WHERE a."C_1" = 47 AND b.c1 = a.c2;
--Testcase 81:
SELECT * FROM ft2 a, ft2 b WHERE a.c1 = 47 AND b.c1 = a.c2;

-- check both safe and unsafe join conditions
--Testcase 82:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft2 a, ft2 b
  WHERE a.c2 = 6 AND b.c1 = a.c1 AND a.c8 = 'foo' AND b.c7 = upper(a.c7);
--Testcase 83:
SELECT * FROM ft2 a, ft2 b
WHERE a.c2 = 6 AND b.c1 = a.c1 AND a.c8 = 'foo' AND b.c7 = upper(a.c7);
-- bug before 9.3.5 due to sloppy handling of remote-estimate parameters
--Testcase 84:
SELECT * FROM ft1 WHERE c1 = ANY (ARRAY(SELECT c1 FROM ft2 WHERE c1 < 5));
--Testcase 85:
SELECT * FROM ft2 WHERE c1 = ANY (ARRAY(SELECT c1 FROM ft1 WHERE c1 < 5));
-- we should not push order by clause with volatile expressions or unsafe
-- collations
--Testcase 86:
EXPLAIN (VERBOSE, COSTS OFF)
	SELECT * FROM ft2 ORDER BY ft2.c1, random();
--Testcase 87:
EXPLAIN (VERBOSE, COSTS OFF)
	SELECT * FROM ft2 ORDER BY ft2.c1, ft2.c3 collate "C";

-- user-defined operator/function
--Testcase 88:
CREATE FUNCTION postgres_fdw_abs(int) RETURNS int AS $$
BEGIN
RETURN abs($1);
END
$$ LANGUAGE plpgsql IMMUTABLE;
--Testcase 89:
CREATE OPERATOR === (
    LEFTARG = int,
    RIGHTARG = int,
    PROCEDURE = int4eq,
    COMMUTATOR = ===
);

-- built-in operators and functions can be shipped for remote execution
--Testcase 90:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT count(c3) FROM ft1 t1 WHERE t1.c1 = abs(t1.c2);
--Testcase 91:
SELECT count(c3) FROM ft1 t1 WHERE t1.c1 = abs(t1.c2);
--Testcase 92:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT count(c3) FROM ft1 t1 WHERE t1.c1 = t1.c2;
--Testcase 93:
SELECT count(c3) FROM ft1 t1 WHERE t1.c1 = t1.c2;

-- by default, user-defined ones cannot
--Testcase 94:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT count(c3) FROM ft1 t1 WHERE t1.c1 = postgres_fdw_abs(t1.c2);
--Testcase 95:
SELECT count(c3) FROM ft1 t1 WHERE t1.c1 = postgres_fdw_abs(t1.c2);
--Testcase 96:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT count(c3) FROM ft1 t1 WHERE t1.c1 === t1.c2;
--Testcase 97:
SELECT count(c3) FROM ft1 t1 WHERE t1.c1 === t1.c2;

-- ORDER BY can be shipped, though
--Testcase 98:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE t1.c1 === t1.c2 order by t1.c2 limit 1;
--Testcase 99:
SELECT * FROM ft1 t1 WHERE t1.c1 === t1.c2 order by t1.c2 limit 1;

-- but let's put them in an extension ...
--Testcase 100:
ALTER EXTENSION :DB_EXTENSIONNAME ADD FUNCTION postgres_fdw_abs(int);
--Testcase 101:
ALTER EXTENSION :DB_EXTENSIONNAME ADD OPERATOR === (int, int);
-- Option 'extensions' is not supported
-- ALTER SERVER :DB_SERVERNAME OPTIONS (ADD extensions :DB_EXTENSIONNAME);

-- ... now they can be shipped
--Testcase 102:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT count(c3) FROM ft1 t1 WHERE t1.c1 = postgres_fdw_abs(t1.c2);
--Testcase 103:
SELECT count(c3) FROM ft1 t1 WHERE t1.c1 = postgres_fdw_abs(t1.c2);
--Testcase 104:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT count(c3) FROM ft1 t1 WHERE t1.c1 === t1.c2;
--Testcase 105:
SELECT count(c3) FROM ft1 t1 WHERE t1.c1 === t1.c2;

-- and both ORDER BY and LIMIT can be shipped
--Testcase 106:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE t1.c1 === t1.c2 order by t1.c2 limit 1;
--Testcase 107:
SELECT * FROM ft1 t1 WHERE t1.c1 === t1.c2 order by t1.c2 limit 1;

-- ===================================================================
-- JOIN queries
-- ===================================================================
-- Analyze ft4 and ft5 so that we have better statistics. These tables do not
-- have use_remote_estimate set.
-- ANALYZE ft4;
-- ANALYZE ft5;

-- join two tables
--Testcase 108:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
--Testcase 109:
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
-- join three tables
--Testcase 110:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) JOIN ft4 t3 ON (t3.c1 = t1.c1) ORDER BY t1.c3, t1.c1 OFFSET 10 LIMIT 10;
--Testcase 111:
SELECT t1.c1, t2.c2, t3.c3 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) JOIN ft4 t3 ON (t3.c1 = t1.c1) ORDER BY t1.c3, t1.c1 OFFSET 10 LIMIT 10;
-- left outer join
--Testcase 112:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft4 t1 LEFT JOIN ft5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;
--Testcase 113:
SELECT t1.c1, t2.c1 FROM ft4 t1 LEFT JOIN ft5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;
-- left outer join three tables
--Testcase 114:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 LEFT JOIN ft2 t2 ON (t1.c1 = t2.c1) LEFT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
--Testcase 115:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 LEFT JOIN ft2 t2 ON (t1.c1 = t2.c1) LEFT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
-- left outer join + placement of clauses.
-- clauses within the nullable side are not pulled up, but top level clause on
-- non-nullable side is pushed into non-nullable side
--Testcase 116:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t1.c2, t2.c1, t2.c2 FROM ft4 t1 LEFT JOIN (SELECT * FROM ft5 WHERE c1 < 10) t2 ON (t1.c1 = t2.c1) WHERE t1.c1 < 10;
--Testcase 117:
SELECT t1.c1, t1.c2, t2.c1, t2.c2 FROM ft4 t1 LEFT JOIN (SELECT * FROM ft5 WHERE c1 < 10) t2 ON (t1.c1 = t2.c1) WHERE t1.c1 < 10;
-- clauses within the nullable side are not pulled up, but the top level clause
-- on nullable side is not pushed down into nullable side
--Testcase 118:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t1.c2, t2.c1, t2.c2 FROM ft4 t1 LEFT JOIN (SELECT * FROM ft5 WHERE c1 < 10) t2 ON (t1.c1 = t2.c1)
			WHERE (t2.c1 < 10 OR t2.c1 IS NULL) AND t1.c1 < 10;
--Testcase 119:
SELECT t1.c1, t1.c2, t2.c1, t2.c2 FROM ft4 t1 LEFT JOIN (SELECT * FROM ft5 WHERE c1 < 10) t2 ON (t1.c1 = t2.c1)
			WHERE (t2.c1 < 10 OR t2.c1 IS NULL) AND t1.c1 < 10;
-- right outer join
--Testcase 120:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft5 t1 RIGHT JOIN ft4 t2 ON (t1.c1 = t2.c1) ORDER BY t2.c1, t1.c1 OFFSET 10 LIMIT 10;
--Testcase 121:
SELECT t1.c1, t2.c1 FROM ft5 t1 RIGHT JOIN ft4 t2 ON (t1.c1 = t2.c1) ORDER BY t2.c1, t1.c1 OFFSET 10 LIMIT 10;
-- right outer join three tables
--Testcase 122:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 RIGHT JOIN ft2 t2 ON (t1.c1 = t2.c1) RIGHT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
--Testcase 123:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 RIGHT JOIN ft2 t2 ON (t1.c1 = t2.c1) RIGHT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
-- full outer join
--Testcase 124:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft4 t1 FULL JOIN ft5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 45 LIMIT 10;
--Testcase 125:
SELECT t1.c1, t2.c1 FROM ft4 t1 FULL JOIN ft5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 45 LIMIT 10;
-- full outer join with restrictions on the joining relations
-- a. the joining relations are both base relations
--Testcase 126:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t1 FULL JOIN (SELECT c1 FROM ft5 WHERE c1 between 50 and 60) t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1;
--Testcase 127:
SELECT t1.c1, t2.c1 FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t1 FULL JOIN (SELECT c1 FROM ft5 WHERE c1 between 50 and 60) t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1;
--Testcase 128:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT 1 FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t1 FULL JOIN (SELECT c1 FROM ft5 WHERE c1 between 50 and 60) t2 ON (TRUE) OFFSET 10 LIMIT 10;
--Testcase 129:
SELECT 1 FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t1 FULL JOIN (SELECT c1 FROM ft5 WHERE c1 between 50 and 60) t2 ON (TRUE) OFFSET 10 LIMIT 10;
-- b. one of the joining relations is a base relation and the other is a join
-- relation
--Testcase 130:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, ss.a, ss.b FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t1 FULL JOIN (SELECT t2.c1, t3.c1 FROM ft4 t2 LEFT JOIN ft5 t3 ON (t2.c1 = t3.c1) WHERE (t2.c1 between 50 and 60)) ss(a, b) ON (t1.c1 = ss.a) ORDER BY t1.c1, ss.a, ss.b;
--Testcase 131:
SELECT t1.c1, ss.a, ss.b FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t1 FULL JOIN (SELECT t2.c1, t3.c1 FROM ft4 t2 LEFT JOIN ft5 t3 ON (t2.c1 = t3.c1) WHERE (t2.c1 between 50 and 60)) ss(a, b) ON (t1.c1 = ss.a) ORDER BY t1.c1, ss.a, ss.b;
-- c. test deparsing the remote query as nested subqueries
--Testcase 132:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, ss.a, ss.b FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t1 FULL JOIN (SELECT t2.c1, t3.c1 FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t2 FULL JOIN (SELECT c1 FROM ft5 WHERE c1 between 50 and 60) t3 ON (t2.c1 = t3.c1) WHERE t2.c1 IS NULL OR t2.c1 IS NOT NULL) ss(a, b) ON (t1.c1 = ss.a) ORDER BY t1.c1, ss.a, ss.b;
--Testcase 133:
SELECT t1.c1, ss.a, ss.b FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t1 FULL JOIN (SELECT t2.c1, t3.c1 FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t2 FULL JOIN (SELECT c1 FROM ft5 WHERE c1 between 50 and 60) t3 ON (t2.c1 = t3.c1) WHERE t2.c1 IS NULL OR t2.c1 IS NOT NULL) ss(a, b) ON (t1.c1 = ss.a) ORDER BY t1.c1, ss.a, ss.b;
-- d. test deparsing rowmarked relations as subqueries
--Testcase 134:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, ss.a, ss.b FROM (SELECT c1 FROM "S 1"."T3" WHERE c1 = 50) t1 INNER JOIN (SELECT t2.c1, t3.c1 FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t2 FULL JOIN (SELECT c1 FROM ft5 WHERE c1 between 50 and 60) t3 ON (t2.c1 = t3.c1) WHERE t2.c1 IS NULL OR t2.c1 IS NOT NULL) ss(a, b) ON (TRUE) ORDER BY t1.c1, ss.a, ss.b FOR UPDATE OF t1;
--Testcase 135:
SELECT t1.c1, ss.a, ss.b FROM (SELECT c1 FROM "S 1"."T3" WHERE c1 = 50) t1 INNER JOIN (SELECT t2.c1, t3.c1 FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t2 FULL JOIN (SELECT c1 FROM ft5 WHERE c1 between 50 and 60) t3 ON (t2.c1 = t3.c1) WHERE t2.c1 IS NULL OR t2.c1 IS NOT NULL) ss(a, b) ON (TRUE) ORDER BY t1.c1, ss.a, ss.b FOR UPDATE OF t1;
-- full outer join + inner join
--Testcase 136:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1, t3.c1 FROM ft4 t1 INNER JOIN ft5 t2 ON (t1.c1 = t2.c1 + 1 and t1.c1 between 50 and 60) FULL JOIN ft4 t3 ON (t2.c1 = t3.c1) ORDER BY t1.c1, t2.c1, t3.c1 LIMIT 10;
--Testcase 137:
SELECT t1.c1, t2.c1, t3.c1 FROM ft4 t1 INNER JOIN ft5 t2 ON (t1.c1 = t2.c1 + 1 and t1.c1 between 50 and 60) FULL JOIN ft4 t3 ON (t2.c1 = t3.c1) ORDER BY t1.c1, t2.c1, t3.c1 LIMIT 10;
-- full outer join three tables
--Testcase 138:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 FULL JOIN ft2 t2 ON (t1.c1 = t2.c1) FULL JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
--Testcase 139:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 FULL JOIN ft2 t2 ON (t1.c1 = t2.c1) FULL JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
-- full outer join + right outer join
--Testcase 140:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 FULL JOIN ft2 t2 ON (t1.c1 = t2.c1) RIGHT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
--Testcase 141:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 FULL JOIN ft2 t2 ON (t1.c1 = t2.c1) RIGHT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
-- right outer join + full outer join
--Testcase 142:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 RIGHT JOIN ft2 t2 ON (t1.c1 = t2.c1) FULL JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
--Testcase 143:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 RIGHT JOIN ft2 t2 ON (t1.c1 = t2.c1) FULL JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
-- full outer join + left outer join
--Testcase 144:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 FULL JOIN ft2 t2 ON (t1.c1 = t2.c1) LEFT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
--Testcase 145:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 FULL JOIN ft2 t2 ON (t1.c1 = t2.c1) LEFT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
-- left outer join + full outer join
--Testcase 146:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 LEFT JOIN ft2 t2 ON (t1.c1 = t2.c1) FULL JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
--Testcase 147:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 LEFT JOIN ft2 t2 ON (t1.c1 = t2.c1) FULL JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
-- right outer join + left outer join
--Testcase 148:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 RIGHT JOIN ft2 t2 ON (t1.c1 = t2.c1) LEFT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
--Testcase 149:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 RIGHT JOIN ft2 t2 ON (t1.c1 = t2.c1) LEFT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
-- left outer join + right outer join
--Testcase 150:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 LEFT JOIN ft2 t2 ON (t1.c1 = t2.c1) RIGHT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
--Testcase 151:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 LEFT JOIN ft2 t2 ON (t1.c1 = t2.c1) RIGHT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
-- full outer join + WHERE clause, only matched rows
--Testcase 152:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft4 t1 FULL JOIN ft5 t2 ON (t1.c1 = t2.c1) WHERE (t1.c1 = t2.c1 OR t1.c1 IS NULL) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;
--Testcase 153:
SELECT t1.c1, t2.c1 FROM ft4 t1 FULL JOIN ft5 t2 ON (t1.c1 = t2.c1) WHERE (t1.c1 = t2.c1 OR t1.c1 IS NULL) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;
-- full outer join + WHERE clause with shippable extensions set
--Testcase 154:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t1.c3 FROM ft1 t1 FULL JOIN ft2 t2 ON (t1.c1 = t2.c1) WHERE postgres_fdw_abs(t1.c1) > 0 OFFSET 10 LIMIT 10;
-- Option 'extensions' is not supported
-- ALTER SERVER :DB_SERVERNAME OPTIONS (DROP extensions);
-- full outer join + WHERE clause with shippable extensions not set
--Testcase 155:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t1.c3 FROM ft1 t1 FULL JOIN ft2 t2 ON (t1.c1 = t2.c1) WHERE postgres_fdw_abs(t1.c1) > 0 OFFSET 10 LIMIT 10;
-- ALTER SERVER :DB_SERVERNAME OPTIONS (ADD extensions :DB_EXTENSIONNAME);
-- join two tables with FOR UPDATE clause
-- tests whole-row reference for row marks
--Testcase 156:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10 FOR UPDATE OF t1;
--Testcase 157:
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10 FOR UPDATE OF t1;
--Testcase 158:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10 FOR UPDATE;
--Testcase 159:
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10 FOR UPDATE;
-- join two tables with FOR SHARE clause
--Testcase 160:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10 FOR SHARE OF t1;
--Testcase 161:
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10 FOR SHARE OF t1;
--Testcase 162:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10 FOR SHARE;
--Testcase 163:
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10 FOR SHARE;
-- join in CTE
--Testcase 164:
EXPLAIN (VERBOSE, COSTS OFF)
WITH t (c1_1, c1_3, c2_1) AS MATERIALIZED (SELECT t1.c1, t1.c3, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1)) SELECT c1_1, c2_1 FROM t ORDER BY c1_3, c1_1 OFFSET 100 LIMIT 10;
--Testcase 165:
WITH t (c1_1, c1_3, c2_1) AS MATERIALIZED (SELECT t1.c1, t1.c3, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1)) SELECT c1_1, c2_1 FROM t ORDER BY c1_3, c1_1 OFFSET 100 LIMIT 10;
-- ctid with whole-row reference
--Testcase 166:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.ctid, t1, t2, t1.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
-- SEMI JOIN, not pushed down
--Testcase 167:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1 FROM ft1 t1 WHERE EXISTS (SELECT 1 FROM ft2 t2 WHERE t1.c1 = t2.c1) ORDER BY t1.c1 OFFSET 100 LIMIT 10;
--Testcase 168:
SELECT t1.c1 FROM ft1 t1 WHERE EXISTS (SELECT 1 FROM ft2 t2 WHERE t1.c1 = t2.c1) ORDER BY t1.c1 OFFSET 100 LIMIT 10;
-- ANTI JOIN, not pushed down
--Testcase 169:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1 FROM ft1 t1 WHERE NOT EXISTS (SELECT 1 FROM ft2 t2 WHERE t1.c1 = t2.c2) ORDER BY t1.c1 OFFSET 100 LIMIT 10;
--Testcase 170:
SELECT t1.c1 FROM ft1 t1 WHERE NOT EXISTS (SELECT 1 FROM ft2 t2 WHERE t1.c1 = t2.c2) ORDER BY t1.c1 OFFSET 100 LIMIT 10;
-- CROSS JOIN can be pushed down
--Testcase 171:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 CROSS JOIN ft2 t2 ORDER BY t1.c1, t2.c1 OFFSET 100 LIMIT 10;
--Testcase 172:
SELECT t1.c1, t2.c1 FROM ft1 t1 CROSS JOIN ft2 t2 ORDER BY t1.c1, t2.c1 OFFSET 100 LIMIT 10;
-- different server, not pushed down. No result expected.
--Testcase 173:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft5 t1 JOIN ft6 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 100 LIMIT 10;
--Testcase 174:
SELECT t1.c1, t2.c1 FROM ft5 t1 JOIN ft6 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 100 LIMIT 10;
-- unsafe join conditions (c8 has a UDT), not pushed down. Practically a CROSS
-- JOIN since c8 in both tables has same value.
--Testcase 175:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 LEFT JOIN ft2 t2 ON (t1.c8 = t2.c8) ORDER BY t1.c1, t2.c1 OFFSET 100 LIMIT 10;
--Testcase 176:
SELECT t1.c1, t2.c1 FROM ft1 t1 LEFT JOIN ft2 t2 ON (t1.c8 = t2.c8) ORDER BY t1.c1, t2.c1 OFFSET 100 LIMIT 10;
-- unsafe conditions on one side (c8 has a UDT), not pushed down.
--Testcase 177:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 LEFT JOIN ft2 t2 ON (t1.c1 = t2.c1) WHERE t1.c8 = 'foo' ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
--Testcase 178:
SELECT t1.c1, t2.c1 FROM ft1 t1 LEFT JOIN ft2 t2 ON (t1.c1 = t2.c1) WHERE t1.c8 = 'foo' ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
-- join where unsafe to pushdown condition in WHERE clause has a column not
-- in the SELECT clause. In this test unsafe clause needs to have column
-- references from both joining sides so that the clause is not pushed down
-- into one of the joining sides.
--Testcase 179:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) WHERE t1.c8 = t2.c8 ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
--Testcase 180:
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) WHERE t1.c8 = t2.c8 ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
-- Aggregate after UNION, for testing setrefs
--Testcase 181:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1c1, avg(t1c1 + t2c1) FROM (SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) UNION SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1)) AS t (t1c1, t2c1) GROUP BY t1c1 ORDER BY t1c1 OFFSET 100 LIMIT 10;
--Testcase 182:
SELECT t1c1, avg(t1c1 + t2c1) FROM (SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) UNION SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1)) AS t (t1c1, t2c1) GROUP BY t1c1 ORDER BY t1c1 OFFSET 100 LIMIT 10;
-- join with lateral reference
--Testcase 183:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1."C_1" FROM "S 1"."T1" t1, LATERAL (SELECT DISTINCT t2.c1, t3.c1 FROM ft1 t2, ft2 t3 WHERE t2.c1 = t3.c1 AND t2.c2 = t1.c2) q ORDER BY t1."C_1" OFFSET 10 LIMIT 10;
--Testcase 184:
SELECT t1."C_1" FROM "S 1"."T1" t1, LATERAL (SELECT DISTINCT t2.c1, t3.c1 FROM ft1 t2, ft2 t3 WHERE t2.c1 = t3.c1 AND t2.c2 = t1.c2) q ORDER BY t1."C_1" OFFSET 10 LIMIT 10;

-- non-Var items in targetlist of the nullable rel of a join preventing
-- push-down in some cases
-- unable to push {ft1, ft2}
--Testcase 185:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT q.a, ft2.c1 FROM (SELECT 13 FROM ft1 WHERE c1 = 13) q(a) RIGHT JOIN ft2 ON (q.a = ft2.c1) WHERE ft2.c1 BETWEEN 10 AND 15;
--Testcase 186:
SELECT q.a, ft2.c1 FROM (SELECT 13 FROM ft1 WHERE c1 = 13) q(a) RIGHT JOIN ft2 ON (q.a = ft2.c1) WHERE ft2.c1 BETWEEN 10 AND 15;

-- ok to push {ft1, ft2} but not {ft1, ft2, ft4}
--Testcase 187:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT ft4.c1, q.* FROM ft4 LEFT JOIN (SELECT 13, ft1.c1, ft2.c1 FROM ft1 RIGHT JOIN ft2 ON (ft1.c1 = ft2.c1) WHERE ft1.c1 = 12) q(a, b, c) ON (ft4.c1 = q.b) WHERE ft4.c1 BETWEEN 10 AND 15;
--Testcase 188:
SELECT ft4.c1, q.* FROM ft4 LEFT JOIN (SELECT 13, ft1.c1, ft2.c1 FROM ft1 RIGHT JOIN ft2 ON (ft1.c1 = ft2.c1) WHERE ft1.c1 = 12) q(a, b, c) ON (ft4.c1 = q.b) WHERE ft4.c1 BETWEEN 10 AND 15 ORDER BY ft4.c1;

-- join with nullable side with some columns with null values
--Testcase 189:
UPDATE ft5 SET c3 = null where c1 % 9 = 0;
--Testcase 190:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT ft5, ft5.c1, ft5.c2, ft5.c3, ft4.c1, ft4.c2 FROM ft5 left join ft4 on ft5.c1 = ft4.c1 WHERE ft4.c1 BETWEEN 10 and 30 ORDER BY ft5.c1, ft4.c1;
--Testcase 191:
SELECT ft5, ft5.c1, ft5.c2, ft5.c3, ft4.c1, ft4.c2 FROM ft5 left join ft4 on ft5.c1 = ft4.c1 WHERE ft4.c1 BETWEEN 10 and 30 ORDER BY ft5.c1, ft4.c1;

-- multi-way join involving multiple merge joins
-- (this case used to have EPQ-related planning problems)
--Testcase 192:
CREATE TABLE local_tbl (c1 int NOT NULL, c2 int NOT NULL, c3 text, CONSTRAINT local_tbl_pkey PRIMARY KEY (c1));
--Testcase 193:
INSERT INTO local_tbl SELECT id, id % 10, to_char(id, 'FM0000') FROM generate_series(1, 1000) id;
ANALYZE local_tbl;
--Testcase 194:
SET enable_nestloop TO false;
--Testcase 195:
SET enable_hashjoin TO false;
--Testcase 196:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM ft1, ft2, ft4, ft5, local_tbl WHERE ft1.c1 = ft2.c1 AND ft1.c2 = ft4.c1
    AND ft1.c2 = ft5.c1 AND ft1.c2 = local_tbl.c1 AND ft1.c1 < 100 AND ft2.c1 < 100 FOR UPDATE;
--Testcase 197:
SELECT * FROM ft1, ft2, ft4, ft5, local_tbl WHERE ft1.c1 = ft2.c1 AND ft1.c2 = ft4.c1
    AND ft1.c2 = ft5.c1 AND ft1.c2 = local_tbl.c1 AND ft1.c1 < 100 AND ft2.c1 < 100 FOR UPDATE;
--Testcase 198:
RESET enable_nestloop;
--Testcase 199:
RESET enable_hashjoin;
--Testcase 200:
DROP TABLE local_tbl;

-- check join pushdown in situations where multiple userids are involved
--Testcase 201:
CREATE ROLE regress_view_owner SUPERUSER;
--Testcase 202:
CREATE USER MAPPING FOR regress_view_owner SERVER :DB_SERVERNAME;
GRANT SELECT ON ft4 TO regress_view_owner;
GRANT SELECT ON ft5 TO regress_view_owner;

--Testcase 203:
CREATE VIEW v4 AS SELECT * FROM ft4;
--Testcase 204:
CREATE VIEW v5 AS SELECT * FROM ft5;
--Testcase 205:
ALTER VIEW v5 OWNER TO regress_view_owner;
--Testcase 206:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2 FROM v4 t1 LEFT JOIN v5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;  -- can't be pushed down, different view owners
--Testcase 207:
SELECT t1.c1, t2.c2 FROM v4 t1 LEFT JOIN v5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;
--Testcase 208:
ALTER VIEW v4 OWNER TO regress_view_owner;
--Testcase 209:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2 FROM v4 t1 LEFT JOIN v5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;  -- can be pushed down
--Testcase 210:
SELECT t1.c1, t2.c2 FROM v4 t1 LEFT JOIN v5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;

--Testcase 211:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2 FROM v4 t1 LEFT JOIN ft5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;  -- can't be pushed down, view owner not current user
--Testcase 212:
SELECT t1.c1, t2.c2 FROM v4 t1 LEFT JOIN ft5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;
--Testcase 213:
ALTER VIEW v4 OWNER TO CURRENT_USER;
--Testcase 214:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2 FROM v4 t1 LEFT JOIN ft5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;  -- can be pushed down
--Testcase 215:
SELECT t1.c1, t2.c2 FROM v4 t1 LEFT JOIN ft5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;
--Testcase 216:
ALTER VIEW v4 OWNER TO regress_view_owner;

-- cleanup
--Testcase 217:
DROP OWNED BY regress_view_owner;
--Testcase 218:
DROP ROLE regress_view_owner;


-- ===================================================================
-- Aggregate and grouping queries
-- ===================================================================

-- Simple aggregates
--Testcase 219:
explain (verbose, costs off)
select count(c6), sum(c1), avg(c1), min(c2), max(c1), stddev(c2), sum(c1) * (random() <= 1)::int as sum2 from ft1 where c2 < 5 group by c2 order by 1, 2;
--Testcase 220:
select count(c6), sum(c1), avg(c1), min(c2), max(c1), stddev(c2), sum(c1) * (random() <= 1)::int as sum2 from ft1 where c2 < 5 group by c2 order by 1, 2;

--Testcase 221:
explain (verbose, costs off)
select count(c6), sum(c1), avg(c1), min(c2), max(c1), stddev(c2), sum(c1) * (random() <= 1)::int as sum2 from ft1 where c2 < 5 group by c2 order by 1, 2 limit 1;
--Testcase 222:
select count(c6), sum(c1), avg(c1), min(c2), max(c1), stddev(c2), sum(c1) * (random() <= 1)::int as sum2 from ft1 where c2 < 5 group by c2 order by 1, 2 limit 1;

-- Aggregate is not pushed down as aggregation contains random()
--Testcase 223:
explain (verbose, costs off)
select sum(c1 * (random() <= 1)::int) as sum, avg(c1) from ft1;

-- Aggregate over join query
--Testcase 224:
explain (verbose, costs off)
select count(*), sum(t1.c1), avg(t2.c1) from ft1 t1 inner join ft1 t2 on (t1.c2 = t2.c2) where t1.c2 = 6;
--Testcase 225:
select count(*), sum(t1.c1), avg(t2.c1) from ft1 t1 inner join ft1 t2 on (t1.c2 = t2.c2) where t1.c2 = 6;

-- Not pushed down due to local conditions present in underneath input rel
--Testcase 226:
explain (verbose, costs off)
select sum(t1.c1), count(t2.c1) from ft1 t1 inner join ft2 t2 on (t1.c1 = t2.c1) where ((t1.c1 * t2.c1)/(t1.c1 * t2.c1)) * random() <= 1;

-- GROUP BY clause having expressions
--Testcase 227:
explain (verbose, costs off)
select c2/2, sum(c2) * (c2/2) from ft1 group by c2/2 order by c2/2;
--Testcase 228:
select c2/2, sum(c2) * (c2/2) from ft1 group by c2/2 order by c2/2;

-- Aggregates in subquery are pushed down.
--Testcase 229:
explain (verbose, costs off)
select count(x.a), sum(x.a) from (select c2 a, sum(c1) b from ft1 group by c2, sqrt(c1) order by 1, 2) x;
--Testcase 230:
select count(x.a), sum(x.a) from (select c2 a, sum(c1) b from ft1 group by c2, sqrt(c1) order by 1, 2) x;

-- Aggregate is still pushed down by taking unshippable expression out
--Testcase 231:
explain (verbose, costs off)
select c2 * (random() <= 1)::int as sum1, sum(c1) * c2 as sum2 from ft1 group by c2 order by 1, 2;
--Testcase 232:
select c2 * (random() <= 1)::int as sum1, sum(c1) * c2 as sum2 from ft1 group by c2 order by 1, 2;

-- Aggregate with unshippable GROUP BY clause are not pushed
--Testcase 233:
explain (verbose, costs off)
select c2 * (random() <= 1)::int as c2 from ft2 group by c2 * (random() <= 1)::int order by 1;

-- GROUP BY clause in various forms, cardinal, alias and constant expression
--Testcase 234:
explain (verbose, costs off)
select count(c2) w, c2 x, 5 y, 7.0 z from ft1 group by 2, y, 9.0::int order by 2;
--Testcase 235:
select count(c2) w, c2 x, 5 y, 7.0 z from ft1 group by 2, y, 9.0::int order by 2;

-- GROUP BY clause referring to same column multiple times
-- Also, ORDER BY contains an aggregate function
--Testcase 236:
explain (verbose, costs off)
select c2, c2 from ft1 where c2 > 6 group by 1, 2 order by sum(c1);
--Testcase 237:
select c2, c2 from ft1 where c2 > 6 group by 1, 2 order by sum(c1);

-- Testing HAVING clause shippability
--Testcase 238:
explain (verbose, costs off)
select c2, sum(c1) from ft2 group by c2 having avg(c1) < 500 and sum(c1) < 49800 order by c2;
--Testcase 239:
select c2, sum(c1) from ft2 group by c2 having avg(c1) < 500 and sum(c1) < 49800 order by c2;

-- Unshippable HAVING clause will be evaluated locally, and other qual in HAVING clause is pushed down
--Testcase 240:
explain (verbose, costs off)
select count(*) from (select c5, count(c1) from ft1 group by c5, sqrt(c2) having (avg(c1) / avg(c1)) * random() <= 1 and avg(c1) < 500) x;
--Testcase 241:
select count(*) from (select c5, count(c1) from ft1 group by c5, sqrt(c2) having (avg(c1) / avg(c1)) * random() <= 1 and avg(c1) < 500) x;

-- Aggregate in HAVING clause is not pushable, and thus aggregation is not pushed down
--Testcase 242:
explain (verbose, costs off)
select sum(c1) from ft1 group by c2 having avg(c1 * (random() <= 1)::int) > 100 order by 1;

-- Remote aggregate in combination with a local Param (for the output
-- of an initplan) can be trouble, per bug #15781
--Testcase 243:
explain (verbose, costs off)
select exists(select 1 from pg_enum), sum(c1) from ft1;
--Testcase 244:
select exists(select 1 from pg_enum), sum(c1) from ft1;

--Testcase 245:
explain (verbose, costs off)
select exists(select 1 from pg_enum), sum(c1) from ft1 group by 1;
--Testcase 246:
select exists(select 1 from pg_enum), sum(c1) from ft1 group by 1;


-- Testing ORDER BY, DISTINCT, FILTER, Ordered-sets and VARIADIC within aggregates

-- ORDER BY within aggregate, same column used to order
--Testcase 247:
explain (verbose, costs off)
select array_agg(c1 order by c1) from ft1 where c1 < 100 group by c2 order by 1;
--Testcase 248:
select array_agg(c1 order by c1) from ft1 where c1 < 100 group by c2 order by 1;

-- ORDER BY within aggregate, different column used to order also using DESC
--Testcase 249:
explain (verbose, costs off)
select array_agg(c5 order by c1 desc) from ft2 where c2 = 6 and c1 < 50;
--Testcase 250:
select array_agg(c5 order by c1 desc) from ft2 where c2 = 6 and c1 < 50;

-- DISTINCT within aggregate
--Testcase 251:
explain (verbose, costs off)
select array_agg(distinct (t1.c1)%5) from ft4 t1 full join ft5 t2 on (t1.c1 = t2.c1) where t1.c1 < 20 or (t1.c1 is null and t2.c1 < 5) group by (t2.c1)%3 order by 1;
--Testcase 252:
select array_agg(distinct (t1.c1)%5) from ft4 t1 full join ft5 t2 on (t1.c1 = t2.c1) where t1.c1 < 20 or (t1.c1 is null and t2.c1 < 5) group by (t2.c1)%3 order by 1;

-- DISTINCT combined with ORDER BY within aggregate
--Testcase 253:
explain (verbose, costs off)
select array_agg(distinct (t1.c1)%5 order by (t1.c1)%5) from ft4 t1 full join ft5 t2 on (t1.c1 = t2.c1) where t1.c1 < 20 or (t1.c1 is null and t2.c1 < 5) group by (t2.c1)%3 order by 1;
--Testcase 254:
select array_agg(distinct (t1.c1)%5 order by (t1.c1)%5) from ft4 t1 full join ft5 t2 on (t1.c1 = t2.c1) where t1.c1 < 20 or (t1.c1 is null and t2.c1 < 5) group by (t2.c1)%3 order by 1;

--Testcase 255:
explain (verbose, costs off)
select array_agg(distinct (t1.c1)%5 order by (t1.c1)%5 desc nulls last) from ft4 t1 full join ft5 t2 on (t1.c1 = t2.c1) where t1.c1 < 20 or (t1.c1 is null and t2.c1 < 5) group by (t2.c1)%3 order by 1;
--Testcase 256:
select array_agg(distinct (t1.c1)%5 order by (t1.c1)%5 desc nulls last) from ft4 t1 full join ft5 t2 on (t1.c1 = t2.c1) where t1.c1 < 20 or (t1.c1 is null and t2.c1 < 5) group by (t2.c1)%3 order by 1;

-- FILTER within aggregate
--Testcase 257:
explain (verbose, costs off)
select sum(c1) filter (where c1 < 100 and c2 > 5) from ft1 group by c2 order by 1 nulls last;
--Testcase 258:
select sum(c1) filter (where c1 < 100 and c2 > 5) from ft1 group by c2 order by 1 nulls last;

-- DISTINCT, ORDER BY and FILTER within aggregate
--Testcase 259:
explain (verbose, costs off)
select sum(c1%3), sum(distinct c1%3 order by c1%3) filter (where c1%3 < 2), c2 from ft1 where c2 = 6 group by c2;
--Testcase 260:
select sum(c1%3), sum(distinct c1%3 order by c1%3) filter (where c1%3 < 2), c2 from ft1 where c2 = 6 group by c2;

-- Outer query is aggregation query
--Testcase 261:
explain (verbose, costs off)
select distinct (select count(*) filter (where t2.c2 = 6 and t2.c1 < 10) from ft1 t1 where t1.c1 = 6) from ft2 t2 where t2.c2 % 6 = 0 order by 1;
--Testcase 262:
select distinct (select count(*) filter (where t2.c2 = 6 and t2.c1 < 10) from ft1 t1 where t1.c1 = 6) from ft2 t2 where t2.c2 % 6 = 0 order by 1;
-- Inner query is aggregation query
--Testcase 263:
explain (verbose, costs off)
select distinct (select count(t1.c1) filter (where t2.c2 = 6 and t2.c1 < 10) from ft1 t1 where t1.c1 = 6) from ft2 t2 where t2.c2 % 6 = 0 order by 1;
--Testcase 264:
select distinct (select count(t1.c1) filter (where t2.c2 = 6 and t2.c1 < 10) from ft1 t1 where t1.c1 = 6) from ft2 t2 where t2.c2 % 6 = 0 order by 1;

-- Aggregate not pushed down as FILTER condition is not pushable
--Testcase 265:
explain (verbose, costs off)
select sum(c1) filter (where (c1 / c1) * random() <= 1) from ft1 group by c2 order by 1;
--Testcase 266:
explain (verbose, costs off)
select sum(c2) filter (where c2 in (select c2 from ft1 where c2 < 5)) from ft1;

-- Ordered-sets within aggregate
--Testcase 267:
explain (verbose, costs off)
select c2, rank('10'::varchar) within group (order by c6), percentile_cont(c2/10::numeric) within group (order by c1) from ft1 where c2 < 10 group by c2 having percentile_cont(c2/10::numeric) within group (order by c1) < 500 order by c2;
--Testcase 268:
select c2, rank('10'::varchar) within group (order by c6), percentile_cont(c2/10::numeric) within group (order by c1) from ft1 where c2 < 10 group by c2 having percentile_cont(c2/10::numeric) within group (order by c1) < 500 order by c2;

-- Using multiple arguments within aggregates
--Testcase 269:
explain (verbose, costs off)
select c1, rank(c1, c2) within group (order by c1, c2) from ft1 group by c1, c2 having c1 = 6 order by 1;
--Testcase 270:
select c1, rank(c1, c2) within group (order by c1, c2) from ft1 group by c1, c2 having c1 = 6 order by 1;

-- User defined function for user defined aggregate, VARIADIC
--Testcase 271:
create function least_accum(anyelement, variadic anyarray)
returns anyelement language sql as
  'select least($1, min($2[i])) from generate_subscripts($2,1) g(i)';
--Testcase 272:
create aggregate least_agg(variadic items anyarray) (
  stype = anyelement, sfunc = least_accum
);

-- Disable hash aggregation for plan stability.
--Testcase 273:
set enable_hashagg to false;

-- Not pushed down due to user defined aggregate
--Testcase 274:
explain (verbose, costs off)
select c2, least_agg(c1) from ft1 group by c2 order by c2;

-- Add function and aggregate into extension
--Testcase 275:
alter extension :DB_EXTENSIONNAME add function least_accum(anyelement, variadic anyarray);
--Testcase 276:
alter extension :DB_EXTENSIONNAME add aggregate least_agg(variadic items anyarray);
-- alter server :DB_SERVERNAME options (set extensions :DB_EXTENSIONNAME);

-- Now aggregate will be pushed.  Aggregate will display VARIADIC argument.
--Testcase 277:
explain (verbose, costs off)
select c2, least_agg(c1) from ft1 where c2 < 100 group by c2 order by c2;
--Testcase 278:
select c2, least_agg(c1) from ft1 where c2 < 100 group by c2 order by c2;

-- Remove function and aggregate from extension
--Testcase 279:
alter extension :DB_EXTENSIONNAME drop function least_accum(anyelement, variadic anyarray);
--Testcase 280:
alter extension :DB_EXTENSIONNAME drop aggregate least_agg(variadic items anyarray);
-- alter server :DB_SERVERNAME options (set extensions :DB_EXTENSIONNAME);

-- Not pushed down as we have dropped objects from extension.
--Testcase 281:
explain (verbose, costs off)
select c2, least_agg(c1) from ft1 group by c2 order by c2;

-- Cleanup
--Testcase 282:
reset enable_hashagg;
--Testcase 283:
drop aggregate least_agg(variadic items anyarray);
--Testcase 284:
drop function least_accum(anyelement, variadic anyarray);


-- Testing USING OPERATOR() in ORDER BY within aggregate.
-- For this, we need user defined operators along with operator family and
-- operator class.  Create those and then add them in extension.  Note that
-- user defined objects are considered unshippable unless they are part of
-- the extension.
--Testcase 285:
create operator public.<^ (
 leftarg = int4,
 rightarg = int4,
 procedure = int4eq
);

--Testcase 286:
create operator public.=^ (
 leftarg = int4,
 rightarg = int4,
 procedure = int4lt
);

--Testcase 287:
create operator public.>^ (
 leftarg = int4,
 rightarg = int4,
 procedure = int4gt
);

--Testcase 288:
create operator family my_op_family using btree;

--Testcase 289:
create function my_op_cmp(a int, b int) returns int as
  $$begin return btint4cmp(a, b); end $$ language plpgsql;

--Testcase 290:
create operator class my_op_class for type int using btree family my_op_family as
 operator 1 public.<^,
 operator 3 public.=^,
 operator 5 public.>^,
 function 1 my_op_cmp(int, int);

-- This will not be pushed as user defined sort operator is not part of the
-- extension yet.
--Testcase 291:
explain (verbose, costs off)
select array_agg(c1 order by c1 using operator(public.<^)) from ft2 where c2 = 6 and c1 < 100 group by c2;

-- Update local stats on ft2
ANALYZE ft2;

-- Add into extension
--Testcase 292:
alter extension :DB_EXTENSIONNAME add operator class my_op_class using btree;
--Testcase 293:
alter extension :DB_EXTENSIONNAME add function my_op_cmp(a int, b int);
--Testcase 294:
alter extension :DB_EXTENSIONNAME add operator family my_op_family using btree;
--Testcase 295:
alter extension :DB_EXTENSIONNAME add operator public.<^(int, int);
--Testcase 296:
alter extension :DB_EXTENSIONNAME add operator public.=^(int, int);
--Testcase 297:
alter extension :DB_EXTENSIONNAME add operator public.>^(int, int);
-- alter server :DB_SERVERNAME options (set extensions :DB_EXTENSIONNAME);

-- Now this will be pushed as sort operator is part of the extension.
--Testcase 298:
explain (verbose, costs off)
select array_agg(c1 order by c1 using operator(public.<^)) from ft2 where c2 = 6 and c1 < 100 group by c2;
--Testcase 299:
select array_agg(c1 order by c1 using operator(public.<^)) from ft2 where c2 = 6 and c1 < 100 group by c2;

-- Remove from extension
--Testcase 300:
alter extension :DB_EXTENSIONNAME drop operator class my_op_class using btree;
--Testcase 301:
alter extension :DB_EXTENSIONNAME drop function my_op_cmp(a int, b int);
--Testcase 302:
alter extension :DB_EXTENSIONNAME drop operator family my_op_family using btree;
--Testcase 303:
alter extension :DB_EXTENSIONNAME drop operator public.<^(int, int);
--Testcase 304:
alter extension :DB_EXTENSIONNAME drop operator public.=^(int, int);
--Testcase 305:
alter extension :DB_EXTENSIONNAME drop operator public.>^(int, int);
-- alter server :DB_SERVERNAME options (set extensions :DB_EXTENSIONNAME);

-- This will not be pushed as sort operator is now removed from the extension.
--Testcase 306:
explain (verbose, costs off)
select array_agg(c1 order by c1 using operator(public.<^)) from ft2 where c2 = 6 and c1 < 100 group by c2;

-- Cleanup
--Testcase 307:
drop operator class my_op_class using btree;
--Testcase 308:
drop function my_op_cmp(a int, b int);
--Testcase 309:
drop operator family my_op_family using btree;
--Testcase 310:
drop operator public.>^(int, int);
--Testcase 311:
drop operator public.=^(int, int);
--Testcase 312:
drop operator public.<^(int, int);

-- Input relation to aggregate push down hook is not safe to pushdown and thus
-- the aggregate cannot be pushed down to foreign server.
--Testcase 313:
explain (verbose, costs off)
select count(t1.c3) from ft2 t1 left join ft2 t2 on (t1.c1 = random() * t2.c2);

-- Subquery in FROM clause having aggregate
--Testcase 314:
explain (verbose, costs off)
select count(*), x.b from ft1, (select c2 a, sum(c1) b from ft1 group by c2) x where ft1.c2 = x.a group by x.b order by 1, 2;
--Testcase 315:
select count(*), x.b from ft1, (select c2 a, sum(c1) b from ft1 group by c2) x where ft1.c2 = x.a group by x.b order by 1, 2;

-- FULL join with IS NULL check in HAVING
--Testcase 316:
explain (verbose, costs off)
select avg(t1.c1), sum(t2.c1) from ft4 t1 full join ft5 t2 on (t1.c1 = t2.c1) group by t2.c1 having (avg(t1.c1) is null and sum(t2.c1) < 10) or sum(t2.c1) is null order by 1 nulls last, 2;
--Testcase 317:
select avg(t1.c1), sum(t2.c1) from ft4 t1 full join ft5 t2 on (t1.c1 = t2.c1) group by t2.c1 having (avg(t1.c1) is null and sum(t2.c1) < 10) or sum(t2.c1) is null order by 1 nulls last, 2;

-- Aggregate over FULL join needing to deparse the joining relations as
-- subqueries.
--Testcase 318:
explain (verbose, costs off)
select count(*), sum(t1.c1), avg(t2.c1) from (select c1 from ft4 where c1 between 50 and 60) t1 full join (select c1 from ft5 where c1 between 50 and 60) t2 on (t1.c1 = t2.c1);
--Testcase 319:
select count(*), sum(t1.c1), avg(t2.c1) from (select c1 from ft4 where c1 between 50 and 60) t1 full join (select c1 from ft5 where c1 between 50 and 60) t2 on (t1.c1 = t2.c1);

-- ORDER BY expression is part of the target list but not pushed down to
-- foreign server.
--Testcase 320:
explain (verbose, costs off)
select sum(c2) * (random() <= 1)::int as sum from ft1 order by 1;
--Testcase 321:
select sum(c2) * (random() <= 1)::int as sum from ft1 order by 1;

-- LATERAL join, with parameterization
--Testcase 322:
set enable_hashagg to false;
--Testcase 323:
explain (verbose, costs off)
select c2, sum from "S 1"."T1" t1, lateral (select sum(t2.c1 + t1."C_1") sum from ft2 t2 group by t2.c1) qry where t1.c2 * 2 = qry.sum and t1.c2 < 3 and t1."C_1" < 100 order by 1;
--Testcase 324:
select c2, sum from "S 1"."T1" t1, lateral (select sum(t2.c1 + t1."C_1") sum from ft2 t2 group by t2.c1) qry where t1.c2 * 2 = qry.sum and t1.c2 < 3 and t1."C_1" < 100 order by 1;
--Testcase 325:
reset enable_hashagg;

-- bug #15613: bad plan for foreign table scan with lateral reference
--Testcase 326:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT ref_0.c2, subq_1.*
FROM
    "S 1"."T1" AS ref_0,
    LATERAL (
        SELECT ref_0."C_1" c1, subq_0.*
        FROM (SELECT ref_0.c2, ref_1.c3
              FROM ft1 AS ref_1) AS subq_0
             RIGHT JOIN ft2 AS ref_3 ON (subq_0.c3 = ref_3.c3)
    ) AS subq_1
WHERE ref_0."C_1" < 10 AND subq_1.c3 = '00001'
ORDER BY ref_0."C_1";

--Testcase 327:
SELECT ref_0.c2, subq_1.*
FROM
    "S 1"."T1" AS ref_0,
    LATERAL (
        SELECT ref_0."C_1" c1, subq_0.*
        FROM (SELECT ref_0.c2, ref_1.c3
              FROM ft1 AS ref_1) AS subq_0
             RIGHT JOIN ft2 AS ref_3 ON (subq_0.c3 = ref_3.c3)
    ) AS subq_1
WHERE ref_0."C_1" < 10 AND subq_1.c3 = '00001'
ORDER BY ref_0."C_1";

-- Check with placeHolderVars
--Testcase 328:
explain (verbose, costs off)
select sum(q.a), count(q.b) from ft4 left join (select 13, avg(ft1.c1), sum(ft2.c1) from ft1 right join ft2 on (ft1.c1 = ft2.c1)) q(a, b, c) on (ft4.c1 <= q.b);
--Testcase 329:
select sum(q.a), count(q.b) from ft4 left join (select 13, avg(ft1.c1), sum(ft2.c1) from ft1 right join ft2 on (ft1.c1 = ft2.c1)) q(a, b, c) on (ft4.c1 <= q.b);


-- Not supported cases
-- Grouping sets
--Testcase 330:
explain (verbose, costs off)
select c2, sum(c1) from ft1 where c2 < 3 group by rollup(c2) order by 1 nulls last;
--Testcase 331:
select c2, sum(c1) from ft1 where c2 < 3 group by rollup(c2) order by 1 nulls last;
--Testcase 332:
explain (verbose, costs off)
select c2, sum(c1) from ft1 where c2 < 3 group by cube(c2) order by 1 nulls last;
--Testcase 333:
select c2, sum(c1) from ft1 where c2 < 3 group by cube(c2) order by 1 nulls last;
--Testcase 334:
explain (verbose, costs off)
select c2, c6, sum(c1) from ft1 where c2 < 3 group by grouping sets(c2, c6) order by 1 nulls last, 2 nulls last;
--Testcase 335:
select c2, c6, sum(c1) from ft1 where c2 < 3 group by grouping sets(c2, c6) order by 1 nulls last, 2 nulls last;
--Testcase 336:
explain (verbose, costs off)
select c2, sum(c1), grouping(c2) from ft1 where c2 < 3 group by c2 order by 1 nulls last;
--Testcase 337:
select c2, sum(c1), grouping(c2) from ft1 where c2 < 3 group by c2 order by 1 nulls last;

-- DISTINCT itself is not pushed down, whereas underneath aggregate is pushed
--Testcase 338:
explain (verbose, costs off)
select distinct sum(c1)/1000 s from ft2 where c2 < 6 group by c2 order by 1;
--Testcase 339:
select distinct sum(c1)/1000 s from ft2 where c2 < 6 group by c2 order by 1;

-- WindowAgg
--Testcase 340:
explain (verbose, costs off)
select c2, sum(c2), count(c2) over (partition by c2%2) from ft2 where c2 < 10 group by c2 order by 1;
--Testcase 341:
select c2, sum(c2), count(c2) over (partition by c2%2) from ft2 where c2 < 10 group by c2 order by 1;
--Testcase 342:
explain (verbose, costs off)
select c2, array_agg(c2) over (partition by c2%2 order by c2 desc) from ft1 where c2 < 10 group by c2 order by 1;
--Testcase 343:
select c2, array_agg(c2) over (partition by c2%2 order by c2 desc) from ft1 where c2 < 10 group by c2 order by 1;
--Testcase 344:
explain (verbose, costs off)
select c2, array_agg(c2) over (partition by c2%2 order by c2 range between current row and unbounded following) from ft1 where c2 < 10 group by c2 order by 1;
--Testcase 345:
select c2, array_agg(c2) over (partition by c2%2 order by c2 range between current row and unbounded following) from ft1 where c2 < 10 group by c2 order by 1;


-- ===================================================================
-- parameterized queries
-- ===================================================================
-- simple join
--Testcase 346:
PREPARE st1(int, int) AS SELECT t1.c3, t2.c3 FROM ft1 t1, ft2 t2 WHERE t1.c1 = $1 AND t2.c1 = $2;
--Testcase 347:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st1(1, 2);
--Testcase 348:
EXECUTE st1(1, 1);
--Testcase 349:
EXECUTE st1(101, 101);
-- subquery using stable function (can't be sent to remote)
--Testcase 350:
PREPARE st2(int) AS SELECT * FROM ft1 t1 WHERE t1.c1 < $2 AND t1.c3 IN (SELECT c3 FROM ft2 t2 WHERE c1 > $1 AND date(c4) = '1970-01-17'::date) ORDER BY c1;
--Testcase 351:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st2(10, 20);
--Testcase 352:
EXECUTE st2(10, 20);
--Testcase 353:
EXECUTE st2(101, 121);
-- subquery using immutable function (can be sent to remote)
--Testcase 354:
PREPARE st3(int) AS SELECT * FROM ft1 t1 WHERE t1.c1 < $2 AND t1.c3 IN (SELECT c3 FROM ft2 t2 WHERE c1 > $1 AND date(c5) = '1970-01-17'::date) ORDER BY c1;
--Testcase 355:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st3(10, 20);
--Testcase 356:
EXECUTE st3(10, 20);
--Testcase 357:
EXECUTE st3(20, 30);
-- custom plan should be chosen initially
--Testcase 358:
PREPARE st4(int) AS SELECT * FROM ft1 t1 WHERE t1.c1 = $1;
--Testcase 359:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st4(1);
--Testcase 360:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st4(1);
--Testcase 361:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st4(1);
--Testcase 362:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st4(1);
--Testcase 363:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st4(1);
-- once we try it enough times, should switch to generic plan
--Testcase 364:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st4(1);
-- value of $1 should not be sent to remote
--Testcase 365:
PREPARE st5(text,int) AS SELECT * FROM ft1 t1 WHERE c8 = $1 and c1 = $2;
--Testcase 366:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st5('foo', 1);
--Testcase 367:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st5('foo', 1);
--Testcase 368:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st5('foo', 1);
--Testcase 369:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st5('foo', 1);
--Testcase 370:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st5('foo', 1);
--Testcase 371:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st5('foo', 1);
--Testcase 372:
EXECUTE st5('foo', 1);

-- altering FDW options requires replanning
--Testcase 373:
PREPARE st6 AS SELECT * FROM ft1 t1 WHERE t1.c1 = t1.c2;
--Testcase 374:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st6;
--Testcase 375:
PREPARE st7 AS INSERT INTO ft1 (c1,c2,c3) VALUES (1001,101,'foo');
--Testcase 376:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st7;
-- ALTER TABLE "S 1"."T1" RENAME TO "T 0";
-- ALTER FOREIGN TABLE ft1 OPTIONS (SET table 'T 0');
--Testcase 377:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st6;
--Testcase 378:
EXECUTE st6;
--Testcase 379:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st7;
-- ALTER TABLE "S 1"."T 0" RENAME TO T1;
-- ALTER FOREIGN TABLE ft1 OPTIONS (SET table 'T1');

--Testcase 380:
PREPARE st8 AS SELECT count(c3) FROM ft1 t1 WHERE t1.c1 === t1.c2;
--Testcase 381:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st8;
-- ALTER SERVER :DB_SERVERNAME OPTIONS (DROP extensions);
--Testcase 382:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st8;
--Testcase 383:
EXECUTE st8;
-- ALTER SERVER :DB_SERVERNAME OPTIONS (ADD extensions :DB_EXTENSIONNAME);

-- cleanup
DEALLOCATE st1;
DEALLOCATE st2;
DEALLOCATE st3;
DEALLOCATE st4;
DEALLOCATE st5;
DEALLOCATE st6;
DEALLOCATE st7;
DEALLOCATE st8;

-- System columns, except ctid and oid, should not be sent to remote
--Testcase 384:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM ft1 t1 WHERE t1.tableoid = 'pg_class'::regclass LIMIT 1;
--Testcase 385:
SELECT * FROM ft1 t1 WHERE t1.tableoid = 'ft1'::regclass LIMIT 1;
--Testcase 386:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT tableoid::regclass, * FROM ft1 t1 LIMIT 1;
--Testcase 387:
SELECT tableoid::regclass, * FROM ft1 t1 LIMIT 1;
--Testcase 388:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM ft1 t1 WHERE t1.ctid = '(0,2)';
-- Does not support system column ctid
--Testcase 389:
SELECT * FROM ft1 t1 WHERE t1.ctid = '(0,2)';
--Testcase 390:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT ctid, * FROM ft1 t1 LIMIT 1;
--Testcase 391:
SELECT ctid, * FROM ft1 t1 LIMIT 1;

-- ===================================================================
-- used in PL/pgSQL function
-- ===================================================================
--Testcase 392:
CREATE OR REPLACE FUNCTION f_test(p_c1 int) RETURNS int AS $$
DECLARE
	v_c1 int;
BEGIN
--Testcase 393:
    SELECT c1 INTO v_c1 FROM ft1 WHERE c1 = p_c1 LIMIT 1;
    PERFORM c1 FROM ft1 WHERE c1 = p_c1 AND p_c1 = v_c1 LIMIT 1;
    RETURN v_c1;
END;
$$ LANGUAGE plpgsql;
--Testcase 394:
SELECT f_test(100);
--Testcase 395:
DROP FUNCTION f_test(int);

-- ===================================================================
-- REINDEX
-- ===================================================================
-- remote table is not created here
--Testcase 396:
CREATE FOREIGN TABLE reindex_foreign (c1 int, c2 int)
  SERVER :DB_SERVERNAME2 OPTIONS (schema :DB_SCHEMA_PORT_TEST, table 'reindex_local');
REINDEX TABLE reindex_foreign; -- error
REINDEX TABLE CONCURRENTLY reindex_foreign; -- error
--Testcase 397:
DROP FOREIGN TABLE reindex_foreign;
-- partitions and foreign tables
--Testcase 398:
CREATE TABLE reind_fdw_parent (c1 int) PARTITION BY RANGE (c1);
--Testcase 399:
CREATE TABLE reind_fdw_0_10 PARTITION OF reind_fdw_parent
  FOR VALUES FROM (0) TO (10);
--Testcase 400:
CREATE FOREIGN TABLE reind_fdw_10_20 PARTITION OF reind_fdw_parent
  FOR VALUES FROM (10) TO (20)
  SERVER :DB_SERVERNAME OPTIONS (schema :DB_SCHEMA_PORT_TEST, table 'reind_local_10_20');
REINDEX TABLE reind_fdw_parent; -- ok
REINDEX TABLE CONCURRENTLY reind_fdw_parent; -- ok
--Testcase 401:
DROP TABLE reind_fdw_parent;

-- ===================================================================
-- conversion error
-- ===================================================================
--Testcase 402:
ALTER FOREIGN TABLE ft1 ALTER COLUMN c8 TYPE int;
--Testcase 403:
SELECT * FROM ft1 ftx(x1,x2,x3,x4,x5,x6,x7,x8) WHERE x1 = 1;  -- ERROR
--Testcase 404:
SELECT ftx.x1, ft2.c2, ftx.x8 FROM ft1 ftx(x1,x2,x3,x4,x5,x6,x7,x8), ft2
  WHERE ftx.x1 = ft2.c1 AND ftx.x1 = 1; -- ERROR
--Testcase 405:
SELECT ftx.x1, ft2.c2, ftx FROM ft1 ftx(x1,x2,x3,x4,x5,x6,x7,x8), ft2
  WHERE ftx.x1 = ft2.c1 AND ftx.x1 = 1; -- ERROR
--Testcase 406:
SELECT sum(c2), array_agg(c8) FROM ft1 GROUP BY c8; -- ERROR
--Testcase 407:
ALTER FOREIGN TABLE ft1 ALTER COLUMN c8 TYPE text;

-- does not support savepoint
-- ===================================================================
-- subtransaction
--  + local/remote error doesn't break cursor
-- ===================================================================
-- BEGIN;
-- DECLARE c CURSOR FOR SELECT * FROM ft1 ORDER BY c1;
-- FETCH c;
-- SAVEPOINT s;
-- ERROR OUT;          -- ERROR
-- ROLLBACK TO s;
-- FETCH c;
-- SAVEPOINT s;
-- SELECT * FROM ft1 WHERE 1 / (c1 - 1) > 0;  -- ERROR
-- ROLLBACK TO s;
-- FETCH c;
-- SELECT * FROM ft1 ORDER BY c1 LIMIT 1;
-- COMMIT;

-- ===================================================================
-- test handling of collations
-- ===================================================================
-- create table loct3 (f1 text collate "C" unique, f2 text, f3 varchar(10) unique);
--Testcase 408:
create foreign table ft3 (f1 text collate "C", f2 text, f3 varchar(10))
  server :DB_SERVERNAME options (schema :DB_SCHEMA_PORT_TEST, table 'loct3');

-- can be sent to remote
--Testcase 409:
explain (verbose, costs off) select * from ft3 where f1 = 'foo';
--Testcase 410:
explain (verbose, costs off) select * from ft3 where f1 COLLATE "C" = 'foo';
--Testcase 411:
explain (verbose, costs off) select * from ft3 where f2 = 'foo';
--Testcase 412:
explain (verbose, costs off) select * from ft3 where f3 = 'foo';
--Testcase 413:
explain (verbose, costs off) select * from ft3 f, ft3 l
  where f.f3 = l.f3 and l.f1 = 'foo';
-- can't be sent to remote
--Testcase 414:
explain (verbose, costs off) select * from ft3 where f1 COLLATE "POSIX" = 'foo';
--Testcase 415:
explain (verbose, costs off) select * from ft3 where f1 = 'foo' COLLATE "C";
--Testcase 416:
explain (verbose, costs off) select * from ft3 where f2 COLLATE "C" = 'foo';
--Testcase 417:
explain (verbose, costs off) select * from ft3 where f2 = 'foo' COLLATE "C";
--Testcase 418:
explain (verbose, costs off) select * from ft3 f, ft3 l
  where f.f3 = l.f3 COLLATE "POSIX" and l.f1 = 'foo';

-- ===================================================================
-- test writable foreign table stuff
-- ===================================================================
--Testcase 419:
EXPLAIN (verbose, costs off)
INSERT INTO ft2 (c1,c2,c3) SELECT c1+1000,c2+100, c3 || c3 FROM ft2 LIMIT 20;
--Testcase 420:
INSERT INTO ft2 (c1,c2,c3) SELECT c1+1000,c2+100, c3 || c3 FROM ft2 LIMIT 20;
--Testcase 421:
INSERT INTO ft2 (c1,c2,c3)
  VALUES (1101,201,'aaa'), (1102,202,'bbb'), (1103,203,'ccc');
--Testcase 422:
SELECT * FROM ft2 WHERE c1 >= 1101 and c1 <= 1103;
--Testcase 423:
INSERT INTO ft2 (c1,c2,c3) VALUES (1104,204,'ddd'), (1105,205,'eee');
--Testcase 424:
EXPLAIN (verbose, costs off)
UPDATE ft2 SET c2 = c2 + 300, c3 = c3 || '_update3' WHERE c1 % 10 = 3;              -- can be pushed down
--Testcase 425:
UPDATE ft2 SET c2 = c2 + 300, c3 = c3 || '_update3' WHERE c1 % 10 = 3;
--Testcase 426:
EXPLAIN (verbose, costs off)
UPDATE ft2 SET c2 = c2 + 400, c3 = c3 || '_update7' WHERE c1 % 10 = 7;  -- can be pushed down
--Testcase 427:
UPDATE ft2 SET c2 = c2 + 400, c3 = c3 || '_update7' WHERE c1 % 10 = 7;
--Testcase 428:
SELECT * FROM ft2 WHERE c1 % 10 = 7 ORDER BY c1;
--Testcase 429:
EXPLAIN (verbose, costs off)
UPDATE ft2 SET c2 = ft2.c2 + 500, c3 = ft2.c3 || '_update9', c7 = DEFAULT
  FROM ft1 WHERE ft1.c1 = ft2.c2 AND ft1.c1 % 10 = 9;                               -- can be pushed down
--Testcase 430:
UPDATE ft2 SET c2 = ft2.c2 + 500, c3 = ft2.c3 || '_update9', c7 = DEFAULT
  FROM ft1 WHERE ft1.c1 = ft2.c2 AND ft1.c1 % 10 = 9;
--Testcase 431:
EXPLAIN (verbose, costs off)
  DELETE FROM ft2 WHERE c1 % 10 = 5;                               -- can be pushed down
--Testcase 432:
SELECT c1, c4 FROM ft2 WHERE c1 % 10 = 5;
--Testcase 433:
DELETE FROM ft2 WHERE c1 % 10 = 5;
--Testcase 434:
EXPLAIN (verbose, costs off)
DELETE FROM ft2 USING ft1 WHERE ft1.c1 = ft2.c2 AND ft1.c1 % 10 = 2;                -- can be pushed down
--Testcase 435:
DELETE FROM ft2 USING ft1 WHERE ft1.c1 = ft2.c2 AND ft1.c1 % 10 = 2;
--Testcase 436:
SELECT c1,c2,c3,c4 FROM ft2 ORDER BY c1;
--Testcase 437:
EXPLAIN (verbose, costs off)
INSERT INTO ft2 (c1,c2,c3) VALUES (1200,999,'foo');
--Testcase 438:
INSERT INTO ft2 (c1,c2,c3) VALUES (1200,999,'foo');
--Testcase 439:
SELECT tableoid::regclass FROM ft2 WHERE c1 = 1200;
--Testcase 440:
EXPLAIN (verbose, costs off)
UPDATE ft2 SET c3 = 'bar' WHERE c1 = 1200;             -- can be pushed down
--Testcase 441:
UPDATE ft2 SET c3 = 'bar' WHERE c1 = 1200;
--Testcase 442:
SELECT tableoid::regclass FROM ft2 WHERE c1 = 1200;
--Testcase 443:
EXPLAIN (verbose, costs off)
DELETE FROM ft2 WHERE c1 = 1200;                       -- can be pushed down
--Testcase 444:
SELECT tableoid::regclass FROM ft2 WHERE c1 = 1200;
--Testcase 445:
DELETE FROM ft2 WHERE c1 = 1200;

-- Test UPDATE/DELETE with RETURNING on a three-table join
--Testcase 446:
INSERT INTO ft2 (c1,c2,c3)
  SELECT id, id - 1200, to_char(id, 'FM00000') FROM generate_series(1201, 1300) id;
--Testcase 447:
EXPLAIN (verbose, costs off)
UPDATE ft2 SET c3 = 'foo'
  FROM ft4 INNER JOIN ft5 ON (ft4.c1 = ft5.c1)
  WHERE ft2.c1 > 1200 AND ft2.c2 = ft4.c1;       -- can be pushed down
--Testcase 448:
UPDATE ft2 SET c3 = 'foo'
  FROM ft4 INNER JOIN ft5 ON (ft4.c1 = ft5.c1)
  WHERE ft2.c1 > 1200 AND ft2.c2 = ft4.c1;
--Testcase 449:
SELECT ft2, ft2.*, ft4, ft4.* FROM ft2, ft4, ft5 WHERE (ft4.c1 = ft5.c1) AND (ft2.c1 > 1200) AND (ft2.c2 = ft4.c1) ORDER BY ft2.c2;
--Testcase 450:
EXPLAIN (verbose, costs off)
DELETE FROM ft2
  USING ft4 LEFT JOIN ft5 ON (ft4.c1 = ft5.c1)
  WHERE ft2.c1 > 1200 AND ft2.c1 % 10 = 0 AND ft2.c2 = ft4.c1;                          -- can be pushed down
--Testcase 451:
DELETE FROM ft2 
  USING ft4 LEFT JOIN ft5 ON (ft4.c1 = ft5.c1)
  WHERE ft2.c1 > 1200 AND ft2.c1 % 10 = 0 AND ft2.c2 = ft4.c1;
--Testcase 452:
DELETE FROM ft2 WHERE ft2.c1 > 1200;

-- Test UPDATE with a MULTIEXPR sub-select
-- (maybe someday this'll be remotely executable, but not today)
--Testcase 453:
EXPLAIN (verbose, costs off)
UPDATE ft2 AS target SET (c2, c7) = (
    SELECT c2 * 10, c7
        FROM ft2 AS src
        WHERE target.c1 = src.c1
) WHERE c1 > 1100;
--Testcase 454:
UPDATE ft2 AS target SET (c2, c7) = (
    SELECT c2 * 10, c7
        FROM ft2 AS src
        WHERE target.c1 = src.c1
) WHERE c1 > 1100;

--Testcase 455:
UPDATE ft2 AS target SET (c2) = (
    SELECT c2 / 10
        FROM ft2 AS src
        WHERE target.c1 = src.c1
) WHERE c1 > 1100;

-- Test UPDATE involving a join that can be pushed down,
-- but a SET clause that can't be
--Testcase 456:
EXPLAIN (VERBOSE, COSTS OFF)
UPDATE ft2 d SET c2 = CASE WHEN random() >= 0 THEN d.c2 ELSE 0 END
  FROM ft2 AS t WHERE d.c1 = t.c1 AND d.c1 > 1000;
--Testcase 457:
UPDATE ft2 d SET c2 = CASE WHEN random() >= 0 THEN d.c2 ELSE 0 END
  FROM ft2 AS t WHERE d.c1 = t.c1 AND d.c1 > 1000;

-- Test UPDATE/DELETE with WHERE or JOIN/ON conditions containing
-- user-defined operators/functions
-- ALTER SERVER :DB_SERVERNAME OPTIONS (DROP extensions);
--Testcase 458:
INSERT INTO ft2 (c1,c2,c3)
  SELECT id, id % 10, to_char(id, 'FM00000') FROM generate_series(2001, 2010) id;
--Testcase 459:
EXPLAIN (verbose, costs off)
UPDATE ft2 SET c3 = 'bar' WHERE postgres_fdw_abs(c1) > 2000;            -- can't be pushed down
--Testcase 460:
UPDATE ft2 SET c3 = 'bar' WHERE postgres_fdw_abs(c1) > 2000;
--Testcase 461:
SELECT * FROM ft2 WHERE postgres_fdw_abs(c1) > 2000;
--Testcase 462:
EXPLAIN (verbose, costs off)
UPDATE ft2 SET c3 = 'baz'
  FROM ft4 INNER JOIN ft5 ON (ft4.c1 = ft5.c1)
  WHERE ft2.c1 > 2000 AND ft2.c2 === ft4.c1;                                                    -- can't be pushed down
--Testcase 463:
UPDATE ft2 SET c3 = 'baz'
  FROM ft4 INNER JOIN ft5 ON (ft4.c1 = ft5.c1)
  WHERE ft2.c1 > 2000 AND ft2.c2 === ft4.c1;
--Testcase 464:
SELECT ft2.*, ft4.*, ft5.* FROM ft2, ft4, ft5 
  WHERE (ft4.c1 = ft5.c1) AND (ft2.c1 > 2000) AND (ft2.c2 === ft4.c1);
--Testcase 465:
EXPLAIN (verbose, costs off)
DELETE FROM ft2
  USING ft4 INNER JOIN ft5 ON (ft4.c1 === ft5.c1)
  WHERE ft2.c1 > 2000 AND ft2.c2 = ft4.c1;       -- can't be pushed down
--Testcase 466:
DELETE FROM ft2
  USING ft4 INNER JOIN ft5 ON (ft4.c1 === ft5.c1)
  WHERE ft2.c1 > 2000 AND ft2.c2 = ft4.c1;
--Testcase 467:
DELETE FROM ft2 WHERE ft2.c1 > 2000;
-- ALTER SERVER :DB_SERVERNAME OPTIONS (ADD extensions :DB_EXTENSIONNAME);

-- Test that trigger on remote table works as expected
--Testcase 468:
CREATE OR REPLACE FUNCTION F_BRTRIG() RETURNS trigger AS $$
BEGIN
    NEW.c3 = NEW.c3 || '_trig_update';
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
--Testcase 469:
CREATE TRIGGER t1_br_insert BEFORE INSERT OR UPDATE
    ON ft1 FOR EACH ROW EXECUTE PROCEDURE F_BRTRIG();
--Testcase 470:
CREATE TRIGGER t2_br_insert BEFORE INSERT OR UPDATE
    ON ft2 FOR EACH ROW EXECUTE PROCEDURE F_BRTRIG();

--Testcase 471:
INSERT INTO ft2 (c1,c2,c3) VALUES (1208, 818, 'fff');
--Testcase 472:
INSERT INTO ft2 (c1,c2,c3,c6) VALUES (1218, 818, 'ggg', '(--;');
--Testcase 473:
UPDATE ft2 SET c2 = c2 + 600 WHERE c1 % 10 = 8 AND c1 < 1200;
--Testcase 474:
SELECT * FROM ft2 WHERE c1 % 10 = 8 AND c1 < 1200;
-- Test errors thrown on remote side during update
-- Does not support CHECK
--Testcase 475:
ALTER TABLE ft1 ADD CONSTRAINT c2positive CHECK (c2 >= 0);

--Testcase 476:
INSERT INTO ft1(c1, c2) VALUES(11, 12);  -- duplicate key
-- Does not support ON CONFLICT DO NOTHING
--INSERT INTO ft1(c1, c2) VALUES(11, 12) ON CONFLICT DO NOTHING; -- works
--Testcase 477:
INSERT INTO ft1(c1, c2) VALUES(11, 12) ON CONFLICT (c1, c2) DO NOTHING; -- unsupported
--Testcase 478:
INSERT INTO ft1(c1, c2) VALUES(11, 12) ON CONFLICT (c1, c2) DO UPDATE SET c3 = 'ffg'; -- unsupported
--INSERT INTO ft1(c1, c2) VALUES(1111, -2);  -- c2positive
--UPDATE ft1 SET c2 = -c2 WHERE c1 = 1;  -- c2positive

-- Test savepoint/rollback behavior
--Testcase 479:
select c2, count(*) from ft2 where c2 < 500 group by 1 order by 1;
--Testcase 480:
select c2, count(*) from "S 1"."T1" where c2 < 500 group by 1 order by 1;
-- begin;
--Testcase 481:
update ft2 set c2 = 42 where c2 = 0;
--Testcase 482:
select c2, count(*) from ft2 where c2 < 500 group by 1 order by 1;
-- savepoint s1;
--Testcase 483:
update ft2 set c2 = 44 where c2 = 4;
--Testcase 484:
select c2, count(*) from ft2 where c2 < 500 group by 1 order by 1;
-- release savepoint s1;
--Testcase 485:
select c2, count(*) from ft2 where c2 < 500 group by 1 order by 1;
-- savepoint s2;
--Testcase 486:
update ft2 set c2 = 46 where c2 = 6;
--Testcase 487:
select c2, count(*) from ft2 where c2 < 500 group by 1 order by 1;
-- rollback to savepoint s2;
--Testcase 488:
update ft2 set c2 = 6 where c2 = 46; -- rollback testcase 485
select c2, count(*) from ft2 where c2 < 500 group by 1 order by 1;
-- release savepoint s2;
--Testcase 489:
select c2, count(*) from ft2 where c2 < 500 group by 1 order by 1;
-- savepoint s3;
-- update ft2 set c2 = -2 where c2 = 42 and c1 = 10; -- fail on remote side
-- rollback to savepoint s3;
--Testcase 490:
select c2, count(*) from ft2 where c2 < 500 group by 1 order by 1;
-- release savepoint s3;
--Testcase 491:
select c2, count(*) from ft2 where c2 < 500 group by 1 order by 1;
-- none of the above is committed yet remotely
--Testcase 492:
select c2, count(*) from "S 1"."T1" where c2 < 500 group by 1 order by 1;
-- commit;
--Testcase 493:
select c2, count(*) from ft2 where c2 < 500 group by 1 order by 1;
--Testcase 494:
select c2, count(*) from "S 1"."T1" where c2 < 500 group by 1 order by 1;

-- VACUUM ANALYZE "S 1"."T1";

-- Above DMLs add data with c6 as NULL in ft1, so test ORDER BY NULLS LAST and NULLs
-- FIRST behavior here.
-- ORDER BY DESC NULLS LAST options
--Testcase 495:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 ORDER BY c6 DESC NULLS LAST, c1 OFFSET 795 LIMIT 10;
--Testcase 496:
SELECT * FROM ft1 ORDER BY c6 DESC NULLS LAST, c1 OFFSET 795  LIMIT 10;
-- ORDER BY DESC NULLS FIRST options
--Testcase 497:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 ORDER BY c6 DESC NULLS FIRST, c1 OFFSET 15 LIMIT 10;
--Testcase 498:
SELECT * FROM ft1 ORDER BY c6 DESC NULLS FIRST, c1 OFFSET 15 LIMIT 10;
-- ORDER BY ASC NULLS FIRST options
--Testcase 499:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 ORDER BY c6 ASC NULLS FIRST, c1 OFFSET 15 LIMIT 10;
--Testcase 500:
SELECT * FROM ft1 ORDER BY c6 ASC NULLS FIRST, c1 OFFSET 15 LIMIT 10;

-- ===================================================================
-- test check constraints
-- ===================================================================

-- Consistent check constraints provide consistent results
--Testcase 501:
ALTER FOREIGN TABLE ft1 ADD CONSTRAINT ft1_c2positive CHECK (c2 >= 0);
--Testcase 502:
EXPLAIN (VERBOSE, COSTS OFF) SELECT count(*) FROM ft1 WHERE c2 < 0;
--Testcase 503:
SELECT count(*) FROM ft1 WHERE c2 < 0;
--Testcase 504:
SET constraint_exclusion = 'on';
--Testcase 505:
EXPLAIN (VERBOSE, COSTS OFF) SELECT count(*) FROM ft1 WHERE c2 < 0;
--Testcase 506:
SELECT count(*) FROM ft1 WHERE c2 < 0;
--Testcase 507:
RESET constraint_exclusion;
-- check constraint is enforced on the remote side, not locally
--INSERT INTO ft1(c1, c2) VALUES(1111, -2);  -- c2positive
--UPDATE ft1 SET c2 = -c2 WHERE c1 = 1;  -- c2positive
--Testcase 508:
ALTER FOREIGN TABLE ft1 DROP CONSTRAINT ft1_c2positive;

-- But inconsistent check constraints provide inconsistent results
--Testcase 509:
ALTER FOREIGN TABLE ft1 ADD CONSTRAINT ft1_c2negative CHECK (c2 < 0);
--Testcase 510:
EXPLAIN (VERBOSE, COSTS OFF) SELECT count(*) FROM ft1 WHERE c2 >= 0;
--Testcase 511:
SELECT count(*) FROM ft1 WHERE c2 >= 0;
--Testcase 512:
SET constraint_exclusion = 'on';
--Testcase 513:
EXPLAIN (VERBOSE, COSTS OFF) SELECT count(*) FROM ft1 WHERE c2 >= 0;
--Testcase 514:
SELECT count(*) FROM ft1 WHERE c2 >= 0;
--Testcase 515:
RESET constraint_exclusion;
-- local check constraint is not actually enforced
--Testcase 516:
INSERT INTO ft1(c1, c2) VALUES(1111, 2);
--Testcase 517:
UPDATE ft1 SET c2 = c2 + 1 WHERE c1 = 1;
--Testcase 518:
ALTER FOREIGN TABLE ft1 DROP CONSTRAINT ft1_c2negative;

-- ===================================================================
-- test WITH CHECK OPTION constraints
-- ===================================================================
--Testcase 519:
CREATE FUNCTION row_before_insupd_trigfunc() RETURNS trigger AS $$BEGIN NEW.a := NEW.a + 10; RETURN NEW; END$$ LANGUAGE plpgsql;
--Testcase 520:
CREATE FOREIGN TABLE foreign_tbl (a int OPTIONS (key 'true'), b int)
  SERVER :DB_SERVERNAME OPTIONS (schema :DB_SCHEMA_PORT_TEST, table 'base_tbl');
--Testcase 521:
CREATE TRIGGER row_before_insupd_trigger BEFORE INSERT OR UPDATE ON foreign_tbl FOR EACH ROW EXECUTE PROCEDURE row_before_insupd_trigfunc();
--Testcase 522:
CREATE VIEW rw_view AS SELECT * FROM foreign_tbl
  WHERE a < b WITH CHECK OPTION;
--Testcase 523:
\d+ rw_view

--Testcase 524:
EXPLAIN (VERBOSE, COSTS OFF)
INSERT INTO rw_view VALUES (0, 5);
-- Bug: data is inserted to table even FDW reports failed
-- Data is shown at testcase 528
INSERT INTO rw_view VALUES (0, 5); -- should fail
--Testcase 525:
EXPLAIN (VERBOSE, COSTS OFF)
INSERT INTO rw_view VALUES (0, 15);
--Testcase 526:
INSERT INTO rw_view VALUES (0, 15); -- ok
--Testcase 527:
SELECT * FROM foreign_tbl;

--Testcase 528:
EXPLAIN (VERBOSE, COSTS OFF)
UPDATE rw_view SET b = b + 5;
--Testcase 529:
UPDATE rw_view SET b = b + 5; -- should fail
--Testcase 530:
EXPLAIN (VERBOSE, COSTS OFF)
UPDATE rw_view SET b = b + 15;
--Testcase 531:
UPDATE rw_view SET b = b + 15; -- ok
--Testcase 532:
SELECT * FROM foreign_tbl;

--Testcase 533:
DROP FOREIGN TABLE foreign_tbl CASCADE;
-- DROP TRIGGER row_before_insupd_trigger ON base_tbl;
-- DROP TABLE base_tbl;

-- Does not support patition table (regarding tuple routing)
-- test WCO for partitions
--Testcase 534:
CREATE FOREIGN TABLE foreign_tbl (a int, b int, id int OPTIONS (key 'true'))
  SERVER :DB_SERVERNAME OPTIONS (schema :DB_SCHEMA_PORT_TEST, table 'child_tbl');

--Testcase 535:
CREATE TABLE parent_tbl (a int, b int, id int) PARTITION BY RANGE(a);
--Testcase 536:
ALTER TABLE parent_tbl ATTACH PARTITION foreign_tbl FOR VALUES FROM (0) TO (100);

--Testcase 537:
CREATE VIEW rw_view AS SELECT * FROM parent_tbl
  WHERE a < b WITH CHECK OPTION;
--Testcase 538:
\d+ rw_view

--Testcase 539:
EXPLAIN (VERBOSE, COSTS OFF)
INSERT INTO rw_view VALUES (0, 5);
--Testcase 540:
INSERT INTO rw_view VALUES (0, 5); -- should fail
--Testcase 541:
EXPLAIN (VERBOSE, COSTS OFF)
INSERT INTO rw_view VALUES (0, 15);
--Testcase 542:
INSERT INTO rw_view VALUES (0, 15); -- ok
--Testcase 543:
SELECT * FROM foreign_tbl;

--Testcase 544:
EXPLAIN (VERBOSE, COSTS OFF)
UPDATE rw_view SET b = b + 5;
--Testcase 545:
UPDATE rw_view SET b = b + 5; -- should fail
--Testcase 546:
EXPLAIN (VERBOSE, COSTS OFF)
UPDATE rw_view SET b = b + 15;
--Testcase 547:
UPDATE rw_view SET b = b + 15; -- ok
--Testcase 548:
SELECT * FROM foreign_tbl;

--Testcase 549:
DROP FOREIGN TABLE foreign_tbl CASCADE;
-- DROP TRIGGER row_before_insupd_trigger ON child_tbl;
--Testcase 550:
DROP TABLE parent_tbl CASCADE;

--Testcase 551:
DROP FUNCTION row_before_insupd_trigfunc;

-- ===================================================================
-- test serial columns (ie, sequence-based defaults)
-- ===================================================================
--Testcase 552:
create foreign table loc1 (f1 serial OPTIONS (key 'true'), f2 text)
  server :DB_SERVERNAME options(schema :DB_SCHEMA_PORT_TEST, table 'loc1');

--Testcase 553:
create foreign table rem1 (f1 serial OPTIONS (key 'true'), f2 text)
  server :DB_SERVERNAME options(schema :DB_SCHEMA_PORT_TEST, table 'loc1');
--Testcase 554:
select pg_catalog.setval('rem1_f1_seq', 10, false);
--Testcase 555:
insert into loc1(f2) values('hi');
--Testcase 556:
insert into rem1(f2) values('hi remote');
--Testcase 557:
insert into loc1(f2) values('bye');
--Testcase 558:
insert into rem1(f2) values('bye remote');
--Testcase 559:
select f1, f2 from loc1;
--Testcase 560:
select f1, f2 from rem1;

-- ===================================================================
-- test generated columns
-- ===================================================================
-- odbc_fdw does not support generated column like postgres_fdw 14.0
-- data will be generated at FDW layer before inserted to remote table.
--Testcase 561:
create foreign table grem1 (
  a int OPTIONS (key 'true'),
  b int generated always as (a * 2) stored)
  server :DB_SERVERNAME options(schema :DB_SCHEMA_PORT_TEST, table 'gloc1');
--Testcase 562:
explain (verbose, costs off)
insert into grem1 (a) values (1), (2);
--Testcase 563:
insert into grem1 (a) values (1), (2);
--Testcase 564:
explain (verbose, costs off)
update grem1 set a = 22 where a = 2;
--Testcase 565:
update grem1 set a = 22 where a = 2;
--Testcase 566:
select * from grem1;

--Testcase 567:
delete from grem1;

-- test copy from
copy grem1 from stdin;
1
2
\.
--Testcase 568:
select * from grem1;
--Testcase 569:
delete from grem1;

-- test batch insert
-- odbc_fdw does not support batch insert
-- alter server loopback options (add batch_size '10');
-- explain (verbose, costs off)
-- insert into grem1 (a) values (1), (2);
-- insert into grem1 (a) values (1), (2);
-- select * from gloc1;
-- select * from grem1;
-- delete from grem1;
-- alter server loopback options (drop batch_size);

-- ===================================================================
-- test local triggers
-- ===================================================================

-- Trigger functions "borrowed" from triggers regress test.
--Testcase 570:
CREATE FUNCTION trigger_func() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
	RAISE NOTICE 'trigger_func(%) called: action = %, when = %, level = %',
		TG_ARGV[0], TG_OP, TG_WHEN, TG_LEVEL;
	RETURN NULL;
END;$$;

--Testcase 571:
CREATE TRIGGER trig_stmt_before BEFORE DELETE OR INSERT OR UPDATE ON rem1
	FOR EACH STATEMENT EXECUTE PROCEDURE trigger_func();
--Testcase 572:
CREATE TRIGGER trig_stmt_after AFTER DELETE OR INSERT OR UPDATE ON rem1
	FOR EACH STATEMENT EXECUTE PROCEDURE trigger_func();

--Testcase 573:
CREATE OR REPLACE FUNCTION trigger_data()  RETURNS trigger
LANGUAGE plpgsql AS $$

declare
	oldnew text[];
	relid text;
    argstr text;
begin

	relid := TG_relid::regclass;
	argstr := '';
	for i in 0 .. TG_nargs - 1 loop
		if i > 0 then
			argstr := argstr || ', ';
		end if;
		argstr := argstr || TG_argv[i];
	end loop;

    RAISE NOTICE '%(%) % % % ON %',
		tg_name, argstr, TG_when, TG_level, TG_OP, relid;
    oldnew := '{}'::text[];
	if TG_OP != 'INSERT' then
		oldnew := array_append(oldnew, format('OLD: %s', OLD));
	end if;

	if TG_OP != 'DELETE' then
		oldnew := array_append(oldnew, format('NEW: %s', NEW));
	end if;

    RAISE NOTICE '%', array_to_string(oldnew, ',');

	if TG_OP = 'DELETE' then
		return OLD;
	else
		return NEW;
	end if;
end;
$$;

-- Test basic functionality
--Testcase 574:
CREATE TRIGGER trig_row_before
BEFORE INSERT OR UPDATE OR DELETE ON rem1
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 575:
CREATE TRIGGER trig_row_after
AFTER INSERT OR UPDATE OR DELETE ON rem1
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 576:
delete from rem1;
--Testcase 577:
insert into rem1 values(1,'insert');
--Testcase 578:
update rem1 set f2  = 'update' where f1 = 1;
--Testcase 579:
update rem1 set f2 = f2 || f2;


-- cleanup
--Testcase 580:
DROP TRIGGER trig_row_before ON rem1;
--Testcase 581:
DROP TRIGGER trig_row_after ON rem1;
--Testcase 582:
DROP TRIGGER trig_stmt_before ON rem1;
--Testcase 583:
DROP TRIGGER trig_stmt_after ON rem1;

--Testcase 584:
DELETE from rem1;

-- Test multiple AFTER ROW triggers on a foreign table
--Testcase 585:
CREATE TRIGGER trig_row_after1
AFTER INSERT OR UPDATE OR DELETE ON rem1
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 586:
CREATE TRIGGER trig_row_after2
AFTER INSERT OR UPDATE OR DELETE ON rem1
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 587:
insert into rem1 values(1,'insert');
--Testcase 588:
update rem1 set f2  = 'update' where f1 = 1;
--Testcase 589:
update rem1 set f2 = f2 || f2;
--Testcase 590:
delete from rem1;

-- cleanup
--Testcase 591:
DROP TRIGGER trig_row_after1 ON rem1;
--Testcase 592:
DROP TRIGGER trig_row_after2 ON rem1;

-- Test WHEN conditions

--Testcase 593:
CREATE TRIGGER trig_row_before_insupd
BEFORE INSERT OR UPDATE ON rem1
FOR EACH ROW
WHEN (NEW.f2 like '%update%')
EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 594:
CREATE TRIGGER trig_row_after_insupd
AFTER INSERT OR UPDATE ON rem1
FOR EACH ROW
WHEN (NEW.f2 like '%update%')
EXECUTE PROCEDURE trigger_data(23,'skidoo');

-- Insert or update not matching: nothing happens
--Testcase 595:
INSERT INTO rem1 values(1, 'insert');
--Testcase 596:
UPDATE rem1 set f2 = 'test';

-- Insert or update matching: triggers are fired
--Testcase 597:
INSERT INTO rem1 values(2, 'update');
--Testcase 598:
UPDATE rem1 set f2 = 'update update' where f1 = '2';

--Testcase 599:
CREATE TRIGGER trig_row_before_delete
BEFORE DELETE ON rem1
FOR EACH ROW
WHEN (OLD.f2 like '%update%')
EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 600:
CREATE TRIGGER trig_row_after_delete
AFTER DELETE ON rem1
FOR EACH ROW
WHEN (OLD.f2 like '%update%')
EXECUTE PROCEDURE trigger_data(23,'skidoo');

-- Trigger is fired for f1=2, not for f1=1
--Testcase 601:
DELETE FROM rem1;

-- cleanup
--Testcase 602:
DROP TRIGGER trig_row_before_insupd ON rem1;
--Testcase 603:
DROP TRIGGER trig_row_after_insupd ON rem1;
--Testcase 604:
DROP TRIGGER trig_row_before_delete ON rem1;
--Testcase 605:
DROP TRIGGER trig_row_after_delete ON rem1;


-- Test various RETURN statements in BEFORE triggers.

--Testcase 606:
CREATE FUNCTION trig_row_before_insupdate() RETURNS TRIGGER AS $$
  BEGIN
    NEW.f2 := NEW.f2 || ' triggered !';
    RETURN NEW;
  END
$$ language plpgsql;

--Testcase 607:
CREATE TRIGGER trig_row_before_insupd
BEFORE INSERT OR UPDATE ON rem1
FOR EACH ROW EXECUTE PROCEDURE trig_row_before_insupdate();

-- The new values should have 'triggered' appended
--Testcase 608:
INSERT INTO rem1 values(1, 'insert');
--Testcase 609:
SELECT f1, f2 from loc1;
--Testcase 610:
INSERT INTO rem1 values(2, 'insert');
--Testcase 611:
SELECT f1, f2 from loc1;
--Testcase 612:
UPDATE rem1 set f2 = '';
--Testcase 613:
SELECT f1, f2 from loc1;
--Testcase 614:
UPDATE rem1 set f2 = 'skidoo';
--Testcase 615:
SELECT f1, f2 from loc1;

--Testcase 616:
EXPLAIN (verbose, costs off)
UPDATE rem1 set f1 = 10;          -- all columns should be transmitted
--Testcase 617:
UPDATE rem1 set f1 = 10;
--Testcase 618:
SELECT f1, f2 from loc1;

--Testcase 619:
DELETE FROM rem1;

-- Add a second trigger, to check that the changes are propagated correctly
-- from trigger to trigger
--Testcase 620:
CREATE TRIGGER trig_row_before_insupd2
BEFORE INSERT OR UPDATE ON rem1
FOR EACH ROW EXECUTE PROCEDURE trig_row_before_insupdate();

--Testcase 621:
INSERT INTO rem1 values(1, 'insert');
--Testcase 622:
SELECT f1, f2 from loc1;
--Testcase 623:
INSERT INTO rem1 values(2, 'insert');
--Testcase 624:
SELECT f1, f2 from loc1;
--Testcase 625:
UPDATE rem1 set f2 = '';
--Testcase 626:
SELECT f1, f2 from loc1;
--Testcase 627:
UPDATE rem1 set f2 = 'skidoo';
--Testcase 628:
SELECT f1, f2 from loc1;

--Testcase 629:
DROP TRIGGER trig_row_before_insupd ON rem1;
--Testcase 630:
DROP TRIGGER trig_row_before_insupd2 ON rem1;

--Testcase 631:
DELETE from rem1;

--Testcase 632:
INSERT INTO rem1 VALUES (1, 'test');

-- Test with a trigger returning NULL
--Testcase 633:
CREATE FUNCTION trig_null() RETURNS TRIGGER AS $$
  BEGIN
    RETURN NULL;
  END
$$ language plpgsql;

--Testcase 634:
CREATE TRIGGER trig_null
BEFORE INSERT OR UPDATE OR DELETE ON rem1
FOR EACH ROW EXECUTE PROCEDURE trig_null();

-- Nothing should have changed.
--Testcase 635:
INSERT INTO rem1 VALUES (2, 'test2');

--Testcase 636:
SELECT f1, f2 from loc1;

--Testcase 637:
UPDATE rem1 SET f2 = 'test2';

--Testcase 638:
SELECT f1, f2 from loc1;

--Testcase 639:
DELETE from rem1;

--Testcase 640:
SELECT f1, f2 from loc1;

--Testcase 641:
DROP TRIGGER trig_null ON rem1;
--Testcase 642:
DELETE from rem1;

-- Test a combination of local and remote triggers
--Testcase 643:
CREATE TRIGGER trig_row_before
BEFORE INSERT OR UPDATE OR DELETE ON rem1
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 644:
CREATE TRIGGER trig_row_after
AFTER INSERT OR UPDATE OR DELETE ON rem1
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 645:
CREATE TRIGGER trig_local_before BEFORE INSERT OR UPDATE ON loc1
FOR EACH ROW EXECUTE PROCEDURE trig_row_before_insupdate();

--Testcase 646:
INSERT INTO rem1(f2) VALUES ('test');
--Testcase 647:
UPDATE rem1 SET f2 = 'testo';

-- Test returning a system attribute
--Testcase 648:
INSERT INTO rem1(f2) VALUES ('test');

-- cleanup
--Testcase 649:
DROP TRIGGER trig_row_before ON rem1;
--Testcase 650:
DROP TRIGGER trig_row_after ON rem1;
--Testcase 651:
DROP TRIGGER trig_local_before ON loc1;


-- Test direct foreign table modification functionality
--Testcase 652:
EXPLAIN (verbose, costs off)
DELETE FROM rem1;                 -- can be pushed down
--Testcase 653:
EXPLAIN (verbose, costs off)
DELETE FROM rem1 WHERE false;     -- currently can't be pushed down

-- Test with statement-level triggers
--Testcase 654:
CREATE TRIGGER trig_stmt_before
	BEFORE DELETE OR INSERT OR UPDATE ON rem1
	FOR EACH STATEMENT EXECUTE PROCEDURE trigger_func();
--Testcase 655:
EXPLAIN (verbose, costs off)
UPDATE rem1 set f2 = '';          -- can be pushed down
--Testcase 656:
EXPLAIN (verbose, costs off)
DELETE FROM rem1;                 -- can be pushed down
--Testcase 657:
DROP TRIGGER trig_stmt_before ON rem1;

--Testcase 658:
CREATE TRIGGER trig_stmt_after
	AFTER DELETE OR INSERT OR UPDATE ON rem1
	FOR EACH STATEMENT EXECUTE PROCEDURE trigger_func();
--Testcase 659:
EXPLAIN (verbose, costs off)
UPDATE rem1 set f2 = '';          -- can be pushed down
--Testcase 660:
EXPLAIN (verbose, costs off)
DELETE FROM rem1;                 -- can be pushed down
--Testcase 661:
DROP TRIGGER trig_stmt_after ON rem1;

-- Test with row-level ON INSERT triggers
--Testcase 662:
CREATE TRIGGER trig_row_before_insert
BEFORE INSERT ON rem1
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');
--Testcase 663:
EXPLAIN (verbose, costs off)
UPDATE rem1 set f2 = '';          -- can be pushed down
--Testcase 664:
EXPLAIN (verbose, costs off)
DELETE FROM rem1;                 -- can be pushed down
--Testcase 665:
DROP TRIGGER trig_row_before_insert ON rem1;

--Testcase 666:
CREATE TRIGGER trig_row_after_insert
AFTER INSERT ON rem1
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');
--Testcase 667:
EXPLAIN (verbose, costs off)
UPDATE rem1 set f2 = '';          -- can be pushed down
--Testcase 668:
EXPLAIN (verbose, costs off)
DELETE FROM rem1;                 -- can be pushed down
--Testcase 669:
DROP TRIGGER trig_row_after_insert ON rem1;

-- Test with row-level ON UPDATE triggers
--Testcase 670:
CREATE TRIGGER trig_row_before_update
BEFORE UPDATE ON rem1
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');
--Testcase 671:
EXPLAIN (verbose, costs off)
UPDATE rem1 set f2 = '';          -- can't be pushed down
--Testcase 672:
EXPLAIN (verbose, costs off)
DELETE FROM rem1;                 -- can be pushed down
--Testcase 673:
DROP TRIGGER trig_row_before_update ON rem1;

--Testcase 674:
CREATE TRIGGER trig_row_after_update
AFTER UPDATE ON rem1
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');
--Testcase 675:
EXPLAIN (verbose, costs off)
UPDATE rem1 set f2 = '';          -- can't be pushed down
--Testcase 676:
EXPLAIN (verbose, costs off)
DELETE FROM rem1;                 -- can be pushed down
--Testcase 677:
DROP TRIGGER trig_row_after_update ON rem1;

-- Test with row-level ON DELETE triggers
--Testcase 678:
CREATE TRIGGER trig_row_before_delete
BEFORE DELETE ON rem1
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');
--Testcase 679:
EXPLAIN (verbose, costs off)
UPDATE rem1 set f2 = '';          -- can be pushed down
--Testcase 680:
EXPLAIN (verbose, costs off)
DELETE FROM rem1;                 -- can't be pushed down
--Testcase 681:
DROP TRIGGER trig_row_before_delete ON rem1;

--Testcase 682:
CREATE TRIGGER trig_row_after_delete
AFTER DELETE ON rem1
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');
--Testcase 683:
EXPLAIN (verbose, costs off)
UPDATE rem1 set f2 = '';          -- can be pushed down
--Testcase 684:
EXPLAIN (verbose, costs off)
DELETE FROM rem1;                 -- can't be pushed down
--Testcase 685:
DROP TRIGGER trig_row_after_delete ON rem1;

-- ===================================================================
-- test inheritance features
-- ===================================================================

--Testcase 686:
CREATE TABLE a (aa TEXT);
--Testcase 687:
ALTER TABLE a SET (autovacuum_enabled = 'false');
--Testcase 688:
CREATE FOREIGN TABLE b (bb TEXT, id serial OPTIONS (key 'true')) INHERITS (a)
  SERVER :DB_SERVERNAME OPTIONS (schema :DB_SCHEMA_PORT_TEST, table 'loct');

--Testcase 689:
INSERT INTO a(aa) VALUES('aaa');
--Testcase 690:
INSERT INTO a(aa) VALUES('aaaa');
--Testcase 691:
INSERT INTO a(aa) VALUES('aaaaa');

--Testcase 692:
INSERT INTO b(aa) VALUES('bbb');
--Testcase 693:
INSERT INTO b(aa) VALUES('bbbb');
--Testcase 694:
INSERT INTO b(aa) VALUES('bbbbb');

--Testcase 695:
SELECT tableoid::regclass, * FROM a;
--Testcase 696:
SELECT tableoid::regclass, aa, bb FROM b;
--Testcase 697:
SELECT tableoid::regclass, * FROM ONLY a;

--Testcase 698:
UPDATE a SET aa = 'zzzzzz' WHERE aa LIKE 'aaaa%';

--Testcase 699:
SELECT tableoid::regclass, * FROM a;
--Testcase 700:
SELECT tableoid::regclass, aa, bb FROM b;
--Testcase 701:
SELECT tableoid::regclass, * FROM ONLY a;

--Testcase 702:
UPDATE b SET aa = 'new';

--Testcase 703:
SELECT tableoid::regclass, * FROM a;
--Testcase 704:
SELECT tableoid::regclass, aa, bb FROM b;
--Testcase 705:
SELECT tableoid::regclass, * FROM ONLY a;

--Testcase 706:
UPDATE a SET aa = 'newtoo';

--Testcase 707:
SELECT tableoid::regclass, * FROM a;
--Testcase 708:
SELECT tableoid::regclass, aa, bb FROM b;
--Testcase 709:
SELECT tableoid::regclass, * FROM ONLY a;

--Testcase 710:
DELETE FROM a;

--Testcase 711:
SELECT tableoid::regclass, * FROM a;
--Testcase 712:
SELECT tableoid::regclass, aa, bb FROM b;
--Testcase 713:
SELECT tableoid::regclass, * FROM ONLY a;

--Testcase 714:
DROP TABLE a CASCADE;
-- DROP TABLE loct;

-- Check SELECT FOR UPDATE/SHARE with an inherited source table

--Testcase 715:
create table foo (f1 int, f2 int);
--Testcase 716:
create foreign table foo2 (f3 int OPTIONS (key 'true')) inherits (foo)
  server :DB_SERVERNAME options (schema :DB_SCHEMA_PORT_TEST, table 'loct1');
--Testcase 717:
create table bar (f1 int, f2 int);
--Testcase 718:
create foreign table bar2 (f3 int OPTIONS (key 'true')) inherits (bar)
  server :DB_SERVERNAME options (schema :DB_SCHEMA_PORT_TEST, table 'loct2');

--Testcase 719:
alter table foo set (autovacuum_enabled = 'false');
--Testcase 720:
alter table bar set (autovacuum_enabled = 'false');

--Testcase 721:
insert into foo values(1,1);
--Testcase 722:
insert into foo values(3,3);
--Testcase 723:
insert into foo2 values(2,2,2);
--Testcase 724:
insert into foo2 values(4,4,4);
--Testcase 725:
insert into bar values(1,11);
--Testcase 726:
insert into bar values(2,22);
--Testcase 727:
insert into bar values(6,66);
--Testcase 728:
insert into bar2 values(3,33,33);
--Testcase 729:
insert into bar2 values(4,44,44);
--Testcase 730:
insert into bar2 values(7,77,77);

--Testcase 731:
explain (verbose, costs off)
select * from bar where f1 in (select f1 from foo) for update;
--Testcase 732:
select * from bar where f1 in (select f1 from foo) for update;

--Testcase 733:
explain (verbose, costs off)
select * from bar where f1 in (select f1 from foo) for share;
--Testcase 734:
select * from bar where f1 in (select f1 from foo) for share;

-- Now check SELECT FOR UPDATE/SHARE with an inherited source table,
-- where the parent is itself a foreign table
--Testcase 735:
create foreign table foo2child (f3 int) inherits (foo2)
  server :DB_SERVERNAME options (schema :DB_SCHEMA_PORT_TEST, table 'loct4');

--Testcase 736:
explain (verbose, costs off)
select * from bar where f1 in (select f1 from foo2) for share;
--Testcase 737:
select * from bar where f1 in (select f1 from foo2) for share;

--Testcase 738:
drop foreign table foo2child;

-- And with a local child relation of the foreign table parent
--Testcase 739:
create table foo2child (f3 int) inherits (foo2);

--Testcase 740:
explain (verbose, costs off)
select * from bar where f1 in (select f1 from foo2) for share;
--Testcase 741:
select * from bar where f1 in (select f1 from foo2) for share;

--Testcase 742:
drop table foo2child;

-- Check UPDATE with inherited target and an inherited source table
--Testcase 743:
explain (verbose, costs off)
update bar set f2 = f2 + 100 where f1 in (select f1 from foo);
--Testcase 744:
update bar set f2 = f2 + 100 where f1 in (select f1 from foo);

--Testcase 745:
select tableoid::regclass, * from bar order by 1,2;

-- Check UPDATE with inherited target and an appendrel subquery
--Testcase 746:
explain (verbose, costs off)
update bar set f2 = f2 + 100
from
  ( select f1 from foo union all select f1+3 from foo ) ss
where bar.f1 = ss.f1;
--Testcase 747:
update bar set f2 = f2 + 100
from
  ( select f1 from foo union all select f1+3 from foo ) ss
where bar.f1 = ss.f1;

--Testcase 748:
select tableoid::regclass, * from bar order by 1,2;

-- Test forcing the remote server to produce sorted data for a merge join,
-- but the foreign table is an inheritance child.
-- truncate table loct1;
--Testcase 749:
delete from foo2;
truncate table only foo;
\set num_rows_foo 2000
--Testcase 750:
insert into foo2 select generate_series(0, :num_rows_foo, 2), generate_series(0, :num_rows_foo, 2), generate_series(0, :num_rows_foo, 2);
--Testcase 751:
insert into foo select generate_series(1, :num_rows_foo, 2), generate_series(1, :num_rows_foo, 2);
--Testcase 752:
SET enable_hashjoin to false;
--Testcase 753:
SET enable_nestloop to false;
--alter foreign table foo2 options (use_remote_estimate 'true'); -- does not support this option
--create index i_foo2_f1 on foo2(f1);
--Testcase 754:
create index i_foo_f1 on foo(f1);
analyze foo;
-- analyze foo2;
-- inner join; expressions in the clauses appear in the equivalence class list
--Testcase 755:
explain (verbose, costs off)
	select foo.f1, foo2.f1 from foo join foo2 on (foo.f1 = foo2.f1) order by foo.f2 offset 10 limit 10;
--Testcase 756:
select foo.f1, foo2.f1 from foo join foo2 on (foo.f1 = foo2.f1) order by foo.f2 offset 10 limit 10;
-- outer join; expressions in the clauses do not appear in equivalence class
-- list but no output change as compared to the previous query
--Testcase 757:
explain (verbose, costs off)
	select foo.f1, foo2.f1 from foo left join foo2 on (foo.f1 = foo2.f1) order by foo.f2 offset 10 limit 10;
--Testcase 758:
select foo.f1, foo2.f1 from foo left join foo2 on (foo.f1 = foo2.f1) order by foo.f2 offset 10 limit 10;
--Testcase 759:
RESET enable_hashjoin;
--Testcase 760:
RESET enable_nestloop;

-- Test that WHERE CURRENT OF is not supported
-- begin;
-- declare c cursor for select * from bar where f1 = 7;
-- fetch from c;
-- update bar set f2 = null where current of c;
-- rollback;

--Testcase 761:
explain (verbose, costs off)
delete from foo where f1 < 5;
--Testcase 762:
delete from foo where f1 < 5;
--Testcase 763:
explain (verbose, costs off)
update bar set f2 = f2 + 100;
--Testcase 764:
update bar set f2 = f2 + 100;

-- Test that UPDATE/DELETE with inherited target works with row-level triggers
--Testcase 765:
CREATE TRIGGER trig_row_before
BEFORE UPDATE OR DELETE ON bar2
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 766:
CREATE TRIGGER trig_row_after
AFTER UPDATE OR DELETE ON bar2
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 767:
explain (verbose, costs off)
update bar set f2 = f2 + 100;
--Testcase 768:
update bar set f2 = f2 + 100;

--Testcase 769:
explain (verbose, costs off)
delete from bar where f2 < 400;
--Testcase 770:
delete from bar where f2 < 400;

-- cleanup
--Testcase 771:
drop table foo cascade;
--Testcase 772:
drop table bar cascade;
-- drop table loct1;
-- drop table loct2;

-- Test pushing down UPDATE/DELETE joins to the remote server
--Testcase 773:
create table parent (a int, b text);
--Testcase 774:
create foreign table loct1_2 (a int, b text)
  server :DB_SERVERNAME options (schema :DB_SCHEMA_PORT_TEST, table 'loct1_2');
--Testcase 775:
create foreign table loct2_2 (a int, b text)
  server :DB_SERVERNAME options (schema :DB_SCHEMA_PORT_TEST, table 'loct2_2');
--Testcase 776:
create foreign table remt1 (a int OPTIONS (key 'true'), b text)
  server :DB_SERVERNAME options (schema :DB_SCHEMA_PORT_TEST, table 'loct1_2');
--Testcase 777:
create foreign table remt2 (a int, b text)
  server :DB_SERVERNAME options (schema :DB_SCHEMA_PORT_TEST, table 'loct2_2');
--Testcase 778:
alter foreign table remt1 inherit parent;

--Testcase 779:
insert into remt1 values (1, 'foo');
--Testcase 780:
insert into remt1 values (2, 'bar');
--Testcase 781:
insert into remt2 values (1, 'foo');
--Testcase 782:
insert into remt2 values (2, 'bar');

--analyze remt1;
--analyze remt2;

--Testcase 783:
explain (verbose, costs off)
update parent set b = parent.b || remt2.b from remt2 where parent.a = remt2.a;
--Testcase 784:
update parent set b = parent.b || remt2.b from remt2 where parent.a = remt2.a;
--Testcase 785:
explain (verbose, costs off)
delete from parent using remt2 where parent.a = remt2.a;
--Testcase 786:
delete from parent using remt2 where parent.a = remt2.a;

-- cleanup
--Testcase 787:
drop foreign table remt1;
--Testcase 788:
drop foreign table remt2;
--Testcase 789:
drop table parent;

-- Does not support tuple routing/COPY
-- ===================================================================
-- test tuple routing for foreign-table partitions
-- ===================================================================

-- Test insert tuple routing
--Testcase 790:
create table itrtest (a int, b text, id int) partition by list (a);
--Testcase 791:
create foreign table loct1_3 (a int check (a in (1)), b text, id int OPTIONS (key 'true')) server :DB_SERVERNAME options (schema :DB_SCHEMA_PORT_TEST, table 'loct1_3');
--Testcase 792:
create foreign table remp1 (a int check (a in (1)), b text, id int OPTIONS (key 'true')) server :DB_SERVERNAME options (schema :DB_SCHEMA_PORT_TEST, table 'loct1_3');
--Testcase 793:
create foreign table loct2_3 (b text, a int check (a in (2))) server :DB_SERVERNAME options (schema :DB_SCHEMA_PORT_TEST, table 'loct2_3');
--Testcase 794:
create foreign table remp2 (b text, a int check (a in (2)), id int OPTIONS (key 'true')) server :DB_SERVERNAME options (schema :DB_SCHEMA_PORT_TEST, table 'loct2_3');
--Testcase 795:
alter table itrtest attach partition remp1 for values in (1);
--Testcase 796:
alter table itrtest attach partition remp2 for values in (2);

--Testcase 797:
insert into itrtest(a, b) values (1, 'foo');
--Testcase 798:
insert into itrtest values (1, 'bar');
--Testcase 799:
insert into itrtest values (2, 'baz');
--Testcase 800:
insert into itrtest values (2, 'qux');
--Testcase 801:
insert into itrtest values (1, 'test1'), (2, 'test2');

--Testcase 802:
select tableoid::regclass, a, b FROM itrtest;
--Testcase 803:
select tableoid::regclass, a, b FROM remp1;
--Testcase 804:
select tableoid::regclass, a, b FROM remp2;

--Testcase 805:
delete from itrtest;

--Testcase 806:
create unique index loct1_idx on loct1_3 (a);

-- DO NOTHING without an inference specification is supported
--Testcase 807:
insert into itrtest values (1, 'foo') on conflict do nothing;
--Testcase 808:
insert into itrtest values (1, 'foo') on conflict do nothing;

-- But other cases are not supported
--Testcase 809:
insert into itrtest values (1, 'bar') on conflict (a) do nothing;
--Testcase 810:
insert into itrtest values (1, 'bar') on conflict (a) do update set b = excluded.b;

--Testcase 811:
select tableoid::regclass, * FROM itrtest;

--Testcase 812:
delete from itrtest;

--Testcase 813:
drop index loct1_idx;

-- -- Test that remote triggers work with insert tuple routing
--Testcase 814:
create function br_insert_trigfunc() returns trigger as $$
begin
	new.b := new.b || ' triggered !';
	return new;
end
$$ language plpgsql;
--Testcase 815:
create trigger loct1_br_insert_trigger before insert on loct1_3
	for each row execute procedure br_insert_trigfunc();
--Testcase 816:
create trigger loct2_br_insert_trigger before insert on loct2_3
	for each row execute procedure br_insert_trigfunc();

-- The new values are concatenated with ' triggered !'
--Testcase 817:
insert into itrtest values (1, 'foo');
--Testcase 818:
insert into itrtest values (2, 'qux');
--Testcase 819:
insert into itrtest values (1, 'test1'), (2, 'test2');
--Testcase 820:
with result as (insert into itrtest values (1, 'test1'), (2, 'test2')) select * from result;

--Testcase 821:
drop trigger loct1_br_insert_trigger on loct1_3;
--Testcase 822:
drop trigger loct2_br_insert_trigger on loct2_3;

--Testcase 823:
drop table itrtest;
-- drop table loct1;
-- drop table loct2;

-- Test update tuple routing
--Testcase 824:
create table utrtest (a int, b text, id int) partition by list (a);
--Testcase 825:
create foreign table loct_2 (a int check (a in (1)), b text, id int OPTIONS (key 'true')) server :DB_SERVERNAME options (schema :DB_SCHEMA_PORT_TEST, table 'loct_2');
--Testcase 826:
create foreign table remp (a int check (a in (1)), b text, id int OPTIONS (key 'true')) server :DB_SERVERNAME options (schema :DB_SCHEMA_PORT_TEST, table 'loct_2');
--Testcase 827:
create table locp (a int check (a in (2)), b text, id int);
--Testcase 828:
alter table utrtest attach partition remp for values in (1);
--Testcase 829:
alter table utrtest attach partition locp for values in (2);

--Testcase 830:
insert into utrtest values (1, 'foo');
--Testcase 831:
insert into utrtest values (2, 'qux');

--Testcase 832:
select tableoid::regclass, * FROM utrtest;
--Testcase 833:
select tableoid::regclass, * FROM remp;
--Testcase 834:
select tableoid::regclass, * FROM locp;

-- It's not allowed to move a row from a partition that is foreign to another
--Testcase 835:
update utrtest set a = 2 where b = 'foo';

-- But the reverse is allowed
--Testcase 836:
update utrtest set a = 1 where b = 'qux';

--Testcase 837:
select tableoid::regclass, * FROM utrtest;
--Testcase 838:
select tableoid::regclass, * FROM remp;
--Testcase 839:
select tableoid::regclass, * FROM locp;

-- The executor should not let unexercised FDWs shut down
--Testcase 840:
update utrtest set a = 1 where b = 'foo';

-- Test that remote triggers work with update tuple routing
--Testcase 841:
create trigger loct_br_insert_trigger before insert on loct_2
	for each row execute procedure br_insert_trigfunc();

--Testcase 842:
delete from utrtest;
--Testcase 843:
insert into utrtest values (2, 'qux');

-- Check case where the foreign partition is a subplan target rel
--Testcase 844:
explain (verbose, costs off)
update utrtest set a = 1 where a = 1 or a = 2;
-- The new values are concatenated with ' triggered !'
--Testcase 845:
update utrtest set a = 1 where a = 1 or a = 2;

--Testcase 846:
delete from utrtest;
--Testcase 847:
insert into utrtest values (2, 'qux');

-- Check case where the foreign partition isn't a subplan target rel
--Testcase 848:
explain (verbose, costs off)
update utrtest set a = 1 where a = 2;
-- The new values are concatenated with ' triggered !'
--Testcase 849:
update utrtest set a = 1 where a = 2;

--Testcase 850:
drop trigger loct_br_insert_trigger on loct_2;

-- We can move rows to a foreign partition that has been updated already,
-- but can't move rows to a foreign partition that hasn't been updated yet

--Testcase 851:
delete from utrtest;
--Testcase 852:
insert into utrtest values (1, 'foo');
--Testcase 853:
insert into utrtest values (2, 'qux');

-- Test the former case:
-- with a direct modification plan
--Testcase 854:
explain (verbose, costs off)
update utrtest set a = 1;
--Testcase 855:
update utrtest set a = 1;

--Testcase 856:
delete from utrtest;
--Testcase 857:
insert into utrtest values (1, 'foo');
--Testcase 858:
insert into utrtest values (2, 'qux');

-- with a non-direct modification plan
--Testcase 859:
explain (verbose, costs off)
update utrtest set a = 1 from (values (1), (2)) s(x) where a = s.x;
--Testcase 860:
update utrtest set a = 1 from (values (1), (2)) s(x) where a = s.x;

-- Change the definition of utrtest so that the foreign partition get updated
-- after the local partition
--Testcase 861:
delete from utrtest;
--Testcase 862:
alter table utrtest detach partition remp;
--Testcase 863:
drop foreign table remp;
--Testcase 864:
alter foreign table loct_2 drop constraint loct_2_a_check;
--Testcase 865:
alter foreign table loct_2 add check (a in (3));
--Testcase 866:
create foreign table remp (a int check (a in (3)), b text, id int OPTIONS (key 'true')) server :DB_SERVERNAME options (schema :DB_SCHEMA_PORT_TEST, table 'loct_2');
--Testcase 867:
alter table utrtest attach partition remp for values in (3);
--Testcase 868:
insert into utrtest values (2, 'qux');
--Testcase 869:
insert into utrtest values (3, 'xyzzy');

-- Test the latter case:
-- with a direct modification plan
--Testcase 870:
explain (verbose, costs off)
update utrtest set a = 3;
--Testcase 871:
update utrtest set a = 3; -- ERROR

-- with a non-direct modification plan
--Testcase 872:
explain (verbose, costs off)
update utrtest set a = 3 from (values (2), (3)) s(x) where a = s.x;
--Testcase 873:
update utrtest set a = 3 from (values (2), (3)) s(x) where a = s.x; -- ERROR

--Testcase 874:
drop table utrtest;
-- drop table loct;

-- Test copy tuple routing
--Testcase 875:
create table ctrtest (a int, b text, id int) partition by list (a);
--Testcase 876:
create foreign table loct1_4 (a int check (a in (1)), b text, id int OPTIONS (key 'true')) server :DB_SERVERNAME options (schema :DB_SCHEMA_PORT_TEST, table 'loct1_4');
--Testcase 877:
create foreign table remp1 (a int check (a in (1)), b text, id int OPTIONS (key 'true')) server :DB_SERVERNAME options (schema :DB_SCHEMA_PORT_TEST, table 'loct1_4');
--Testcase 878:
create foreign table loct2_4 (b text, a int check (a in (2)), id int OPTIONS (key 'true')) server :DB_SERVERNAME options (schema :DB_SCHEMA_PORT_TEST, table 'loct2_4');
--Testcase 879:
create foreign table remp2 (b text, a int check (a in (2)), id int OPTIONS (key 'true')) server :DB_SERVERNAME options (schema :DB_SCHEMA_PORT_TEST, table 'loct2_4');
--Testcase 880:
alter table ctrtest attach partition remp1 for values in (1);
--Testcase 881:
alter table ctrtest attach partition remp2 for values in (2);

copy ctrtest from stdin;
1	foo	1
2	qux	2
\.

--Testcase 882:
select tableoid::regclass, * FROM ctrtest;
--Testcase 883:
select tableoid::regclass, * FROM remp1;
--Testcase 884:
select tableoid::regclass, * FROM remp2;

-- Copying into foreign partitions directly should work as well
copy remp1 from stdin;
1	bar	1
\.

--Testcase 885:
select tableoid::regclass, * FROM remp1;

--Testcase 886:
drop table ctrtest;
-- drop table loct1;
-- drop table loct2;

-- ===================================================================
-- test COPY FROM
-- ===================================================================

--Testcase 887:
create foreign table loc2 (f1 int, f2 text, id int OPTIONS (key 'true')) server :DB_SERVERNAME options(schema :DB_SCHEMA_PORT_TEST, table 'loc2');
--Testcase 888:
create foreign table rem2 (f1 int, f2 text, id int OPTIONS (key 'true')) server :DB_SERVERNAME options(schema :DB_SCHEMA_PORT_TEST, table 'loc2');

-- Test basic functionality
copy rem2 from stdin;
1	foo	1
2	bar	2
\.
--Testcase 889:
select * from rem2;

--Testcase 890:
delete from rem2;

-- Test check constraints
--Testcase 891:
alter foreign table loc2 add constraint loc2_f1positive check (f1 >= 0);
--Testcase 892:
alter foreign table rem2 add constraint rem2_f1positive check (f1 >= 0);

-- check constraint is enforced on the remote side, not locally
copy rem2 from stdin;
1	foo	1
2	bar	2
\.
copy rem2 from stdin; -- ERROR
-1	xyzzy	3
\.
--Testcase 893:
select * from rem2;

--Testcase 894:
alter foreign table rem2 drop constraint rem2_f1positive;
--Testcase 895:
alter foreign table loc2 drop constraint loc2_f1positive;

--Testcase 896:
delete from rem2;

-- Test local triggers
--Testcase 897:
create trigger trig_stmt_before before insert on rem2
	for each statement execute procedure trigger_func();
--Testcase 898:
create trigger trig_stmt_after after insert on rem2
	for each statement execute procedure trigger_func();
--Testcase 899:
create trigger trig_row_before before insert on rem2
	for each row execute procedure trigger_data(23,'skidoo');
--Testcase 900:
create trigger trig_row_after after insert on rem2
	for each row execute procedure trigger_data(23,'skidoo');

copy rem2 from stdin;
1	foo	1
2	bar	2
\.
--Testcase 901:
select * from rem2;

--Testcase 902:
drop trigger trig_row_before on rem2;
--Testcase 903:
drop trigger trig_row_after on rem2;
--Testcase 904:
drop trigger trig_stmt_before on rem2;
--Testcase 905:
drop trigger trig_stmt_after on rem2;

--Testcase 906:
delete from rem2;

--Testcase 907:
create trigger trig_row_before_insert before insert on rem2
	for each row execute procedure trig_row_before_insupdate();

-- The new values are concatenated with ' triggered !'
copy rem2 from stdin;
1	foo	1
2	bar	2
\.
--Testcase 908:
select * from rem2;

--Testcase 909:
drop trigger trig_row_before_insert on rem2;

--Testcase 910:
delete from rem2;

--Testcase 911:
create trigger trig_null before insert on rem2
	for each row execute procedure trig_null();

-- Nothing happens
copy rem2 from stdin;
1	foo	1
2	bar	2
\.
--Testcase 912:
select * from rem2;

--Testcase 913:
drop trigger trig_null on rem2;

--Testcase 914:
delete from rem2;

-- Test remote triggers
--Testcase 915:
create trigger trig_row_before_insert before insert on loc2
	for each row execute procedure trig_row_before_insupdate();

-- The new values are concatenated with ' triggered !'
copy rem2 from stdin;
1	foo	1
2	bar	2
\.
--Testcase 916:
select * from rem2;

--Testcase 917:
drop trigger trig_row_before_insert on loc2;

--Testcase 918:
delete from rem2;

--Testcase 919:
create trigger trig_null before insert on loc2
	for each row execute procedure trig_null();

-- Nothing happens
copy rem2 from stdin;
1	foo	1
2	bar	2
\.
--Testcase 920:
select * from rem2;

--Testcase 921:
drop trigger trig_null on loc2;

--Testcase 922:
delete from rem2;

-- Test a combination of local and remote triggers
--Testcase 923:
create trigger rem2_trig_row_before before insert on rem2
	for each row execute procedure trigger_data(23,'skidoo');
--Testcase 924:
create trigger rem2_trig_row_after after insert on rem2
	for each row execute procedure trigger_data(23,'skidoo');
--Testcase 925:
create trigger loc2_trig_row_before_insert before insert on loc2
	for each row execute procedure trig_row_before_insupdate();

copy rem2 from stdin;
1	foo	1
2	bar	2
\.
--Testcase 926:
select * from rem2;

--Testcase 927:
drop trigger rem2_trig_row_before on rem2;
--Testcase 928:
drop trigger rem2_trig_row_after on rem2;
--Testcase 929:
drop trigger loc2_trig_row_before_insert on loc2;

--Testcase 930:
delete from rem2;

-- test COPY FROM with foreign table created in the same transaction
-- begin;
--Testcase 931:
create foreign table loc3 (f1 int, f2 text, id int OPTIONS (key 'true'))
	server :DB_SERVERNAME options(schema :DB_SCHEMA_PORT_TEST, table 'loc3');
--Testcase 932:
create foreign table rem3 (f1 int, f2 text, id int OPTIONS (key 'true'))
	server :DB_SERVERNAME options(schema :DB_SCHEMA_PORT_TEST, table 'loc3');
copy rem3 from stdin;
1	foo	1
2	bar	2
\.
-- commit;
--Testcase 933:
select * from rem3;
--Testcase 934:
drop foreign table rem3;
-- drop table loc3;

-- ===================================================================
-- test for TRUNCATE
-- odbc_fdw does not support truncate command
-- ===================================================================
-- CREATE TABLE tru_rtable0 (id int primary key);
-- CREATE FOREIGN TABLE tru_ftable (id int)
--        SERVER loopback OPTIONS (table_name 'tru_rtable0');
-- INSERT INTO tru_rtable0 (SELECT x FROM generate_series(1,10) x);

-- CREATE TABLE tru_ptable (id int) PARTITION BY HASH(id);
-- CREATE TABLE tru_ptable__p0 PARTITION OF tru_ptable
--                             FOR VALUES WITH (MODULUS 2, REMAINDER 0);
-- CREATE TABLE tru_rtable1 (id int primary key);
-- CREATE FOREIGN TABLE tru_ftable__p1 PARTITION OF tru_ptable
--                                     FOR VALUES WITH (MODULUS 2, REMAINDER 1)
--        SERVER loopback OPTIONS (table_name 'tru_rtable1');
-- INSERT INTO tru_ptable (SELECT x FROM generate_series(11,20) x);

-- CREATE TABLE tru_pk_table(id int primary key);
-- CREATE TABLE tru_fk_table(fkey int references tru_pk_table(id));
-- INSERT INTO tru_pk_table (SELECT x FROM generate_series(1,10) x);
-- INSERT INTO tru_fk_table (SELECT x % 10 + 1 FROM generate_series(5,25) x);
-- CREATE FOREIGN TABLE tru_pk_ftable (id int)
--        SERVER loopback OPTIONS (table_name 'tru_pk_table');

-- CREATE TABLE tru_rtable_parent (id int);
-- CREATE TABLE tru_rtable_child (id int);
-- CREATE FOREIGN TABLE tru_ftable_parent (id int)
--        SERVER loopback OPTIONS (table_name 'tru_rtable_parent');
-- CREATE FOREIGN TABLE tru_ftable_child () INHERITS (tru_ftable_parent)
--        SERVER loopback OPTIONS (table_name 'tru_rtable_child');
-- INSERT INTO tru_rtable_parent (SELECT x FROM generate_series(1,8) x);
-- INSERT INTO tru_rtable_child  (SELECT x FROM generate_series(10, 18) x);

-- -- normal truncate
-- SELECT sum(id) FROM tru_ftable;        -- 55
-- TRUNCATE tru_ftable;
-- SELECT count(*) FROM tru_rtable0;		-- 0
-- SELECT count(*) FROM tru_ftable;		-- 0

-- -- 'truncatable' option
-- ALTER SERVER loopback OPTIONS (ADD truncatable 'false');
-- TRUNCATE tru_ftable;			-- error
-- ALTER FOREIGN TABLE tru_ftable OPTIONS (ADD truncatable 'true');
-- TRUNCATE tru_ftable;			-- accepted
-- ALTER FOREIGN TABLE tru_ftable OPTIONS (SET truncatable 'false');
-- TRUNCATE tru_ftable;			-- error
-- ALTER SERVER loopback OPTIONS (DROP truncatable);
-- ALTER FOREIGN TABLE tru_ftable OPTIONS (SET truncatable 'false');
-- TRUNCATE tru_ftable;			-- error
-- ALTER FOREIGN TABLE tru_ftable OPTIONS (SET truncatable 'true');
-- TRUNCATE tru_ftable;			-- accepted

-- -- partitioned table with both local and foreign tables as partitions
-- SELECT sum(id) FROM tru_ptable;        -- 155
-- TRUNCATE tru_ptable;
-- SELECT count(*) FROM tru_ptable;		-- 0
-- SELECT count(*) FROM tru_ptable__p0;	-- 0
-- SELECT count(*) FROM tru_ftable__p1;	-- 0
-- SELECT count(*) FROM tru_rtable1;		-- 0

-- -- 'CASCADE' option
-- SELECT sum(id) FROM tru_pk_ftable;      -- 55
-- TRUNCATE tru_pk_ftable;	-- failed by FK reference
-- TRUNCATE tru_pk_ftable CASCADE;
-- SELECT count(*) FROM tru_pk_ftable;    -- 0
-- SELECT count(*) FROM tru_fk_table;		-- also truncated,0

-- -- truncate two tables at a command
-- INSERT INTO tru_ftable (SELECT x FROM generate_series(1,8) x);
-- INSERT INTO tru_pk_ftable (SELECT x FROM generate_series(3,10) x);
-- SELECT count(*) from tru_ftable; -- 8
-- SELECT count(*) from tru_pk_ftable; -- 8
-- TRUNCATE tru_ftable, tru_pk_ftable CASCADE;
-- SELECT count(*) from tru_ftable; -- 0
-- SELECT count(*) from tru_pk_ftable; -- 0

-- -- truncate with ONLY clause
-- -- Since ONLY is specified, the table tru_ftable_child that inherits
-- -- tru_ftable_parent locally is not truncated.
-- TRUNCATE ONLY tru_ftable_parent;
-- SELECT sum(id) FROM tru_ftable_parent;  -- 126
-- TRUNCATE tru_ftable_parent;
-- SELECT count(*) FROM tru_ftable_parent; -- 0

-- -- in case when remote table has inherited children
-- CREATE TABLE tru_rtable0_child () INHERITS (tru_rtable0);
-- INSERT INTO tru_rtable0 (SELECT x FROM generate_series(5,9) x);
-- INSERT INTO tru_rtable0_child (SELECT x FROM generate_series(10,14) x);
-- SELECT sum(id) FROM tru_ftable;   -- 95

-- -- Both parent and child tables in the foreign server are truncated
-- -- even though ONLY is specified because ONLY has no effect
-- -- when truncating a foreign table.
-- TRUNCATE ONLY tru_ftable;
-- SELECT count(*) FROM tru_ftable;   -- 0

-- INSERT INTO tru_rtable0 (SELECT x FROM generate_series(21,25) x);
-- INSERT INTO tru_rtable0_child (SELECT x FROM generate_series(26,30) x);
-- SELECT sum(id) FROM tru_ftable;		-- 255
-- TRUNCATE tru_ftable;			-- truncate both of parent and child
-- SELECT count(*) FROM tru_ftable;    -- 0

-- -- cleanup
-- DROP FOREIGN TABLE tru_ftable_parent, tru_ftable_child, tru_pk_ftable,tru_ftable__p1,tru_ftable;
-- DROP TABLE tru_rtable0, tru_rtable1, tru_ptable, tru_ptable__p0, tru_pk_table, tru_fk_table,
-- tru_rtable_parent,tru_rtable_child, tru_rtable0_child;

-- ===================================================================
-- test IMPORT FOREIGN SCHEMA
-- ===================================================================
--Testcase 935:
CREATE SERVER mysql_svr FOREIGN DATA WRAPPER :DB_EXTENSIONNAME
  OPTIONS (odbc_DRIVER :DB_DRIVERNAME,
          odbc_SERVER :DB_SERVER,
          odbc_PORT :DB_PORT,
          odbc_DATABASE 'import_source');
--Testcase 936:
CREATE USER MAPPING FOR public SERVER mysql_svr OPTIONS(odbc_UID :DB_USER, odbc_PWD :DB_PASS);
--Testcase 937:
CREATE SCHEMA import_dest1;
IMPORT FOREIGN SCHEMA import_source FROM SERVER mysql_svr INTO import_dest1; --fail for postgres
IMPORT FOREIGN SCHEMA import_source FROM SERVER :DB_SERVERNAME INTO import_dest1; --fail for mysql
--Testcase 938:
\det+ import_dest1.*
--Testcase 939:
\d import_dest1.*

/*
-- Does not support options
-- Options
CREATE SCHEMA import_dest2;
IMPORT FOREIGN SCHEMA import_source FROM SERVER :DB_SERVERNAME INTO import_dest2
  OPTIONS (import_default 'true');
\det+ import_dest2.*
\d import_dest2.*
CREATE SCHEMA import_dest3;
IMPORT FOREIGN SCHEMA import_source FROM SERVER :DB_SERVERNAME INTO import_dest3
  OPTIONS (import_collate 'false', import_not_null 'false');
\det+ import_dest3.*
\d import_dest3.*

-- Check LIMIT TO and EXCEPT
CREATE SCHEMA import_dest4;
IMPORT FOREIGN SCHEMA import_source LIMIT TO (t1, nonesuch)
  FROM SERVER :DB_SERVERNAME INTO import_dest4;
\det+ import_dest4.*
IMPORT FOREIGN SCHEMA import_source EXCEPT (t1, "x 4", nonesuch)
  FROM SERVER :DB_SERVERNAME INTO import_dest4;
\det+ import_dest4.*

-- Assorted error cases
IMPORT FOREIGN SCHEMA import_source FROM SERVER :DB_SERVERNAME INTO import_dest4;
IMPORT FOREIGN SCHEMA nonesuch FROM SERVER :DB_SERVERNAME INTO import_dest4;
IMPORT FOREIGN SCHEMA nonesuch FROM SERVER :DB_SERVERNAME INTO notthere;
IMPORT FOREIGN SCHEMA nonesuch FROM SERVER nowhere INTO notthere;

-- Check case of a type present only on the remote server.
-- We can fake this by dropping the type locally in our transaction.
CREATE TYPE "Colors" AS ENUM ('red', 'green', 'blue');
CREATE TABLE import_source.t5 (c1 int, c2 text collate "C", "Col" "Colors");

CREATE SCHEMA import_dest5;
-- BEGIN;
DROP TYPE "Colors" CASCADE;
IMPORT FOREIGN SCHEMA import_source LIMIT TO (t5)
  FROM SERVER :DB_SERVERNAME INTO import_dest5;  -- ERROR
-- ROLLBACK;
*/
/*
-- Does not support fetch_size option
-- BEGIN;
CREATE SERVER fetch101 FOREIGN DATA WRAPPER :DB_EXTENSIONNAME OPTIONS( fetch_size '101' );

SELECT count(*)
FROM pg_foreign_server
WHERE srvname = 'fetch101'
AND srvoptions @> array['fetch_size=101'];

ALTER SERVER fetch101 OPTIONS( SET fetch_size '202' );

SELECT count(*)
FROM pg_foreign_server
WHERE srvname = 'fetch101'
AND srvoptions @> array['fetch_size=101'];

SELECT count(*)
FROM pg_foreign_server
WHERE srvname = 'fetch101'
AND srvoptions @> array['fetch_size=202'];

CREATE FOREIGN TABLE table30000 ( x int ) SERVER fetch101 OPTIONS ( fetch_size '30000' );

SELECT COUNT(*)
FROM pg_foreign_table
WHERE ftrelid = 'table30000'::regclass
AND ftoptions @> array['fetch_size=30000'];

ALTER FOREIGN TABLE table30000 OPTIONS ( SET fetch_size '60000');

SELECT COUNT(*)
FROM pg_foreign_table
WHERE ftrelid = 'table30000'::regclass
AND ftoptions @> array['fetch_size=30000'];

SELECT COUNT(*)
FROM pg_foreign_table
WHERE ftrelid = 'table30000'::regclass
AND ftoptions @> array['fetch_size=60000'];

-- ROLLBACK;
*/
/*
-- Does not support partition table
-- ===================================================================
-- test partitionwise joins
-- ===================================================================
SET enable_partitionwise_join=on;

CREATE TABLE fprt1 (a int, b int, c varchar) PARTITION BY RANGE(a);
CREATE FOREIGN TABLE ftprt1_p1 PARTITION OF fprt1 FOR VALUES FROM (0) TO (250)
	SERVER :DB_SERVERNAME OPTIONS (schema :DB_SCHEMA_PORT_TEST, table 'fprt1_p1', use_remote_estimate 'true');
CREATE FOREIGN TABLE ftprt1_p2 PARTITION OF fprt1 FOR VALUES FROM (250) TO (500)
	SERVER :DB_SERVERNAME OPTIONS (schema :DB_SCHEMA_PORT_TEST, table 'fprt1_p2');
-- ANALYZE fprt1;
-- ANALYZE fprt1_p1;
-- ANALYZE fprt1_p2;

CREATE TABLE fprt2 (a int, b int, c varchar) PARTITION BY RANGE(b);
CREATE FOREIGN TABLE ftprt2_p1 (b int, c varchar, a int)
	SERVER :DB_SERVERNAME OPTIONS (schema :DB_SCHEMA_PORT_TEST, table 'fprt2_p1', use_remote_estimate 'true');
ALTER TABLE fprt2 ATTACH PARTITION ftprt2_p1 FOR VALUES FROM (0) TO (250);
CREATE FOREIGN TABLE ftprt2_p2 PARTITION OF fprt2 FOR VALUES FROM (250) TO (500)
	SERVER :DB_SERVERNAME OPTIONS (schema :DB_SCHEMA_PORT_TEST, table 'fprt2_p2', use_remote_estimate 'true');

-- inner join three tables
EXPLAIN (COSTS OFF)
SELECT t1.a,t2.b,t3.c FROM fprt1 t1 INNER JOIN fprt2 t2 ON (t1.a = t2.b) INNER JOIN fprt1 t3 ON (t2.b = t3.a) WHERE t1.a % 25 =0 ORDER BY 1,2,3;
SELECT t1.a,t2.b,t3.c FROM fprt1 t1 INNER JOIN fprt2 t2 ON (t1.a = t2.b) INNER JOIN fprt1 t3 ON (t2.b = t3.a) WHERE t1.a % 25 =0 ORDER BY 1,2,3;

-- left outer join + nullable clause
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.a,t2.b,t2.c FROM fprt1 t1 LEFT JOIN (SELECT * FROM fprt2 WHERE a < 10) t2 ON (t1.a = t2.b and t1.b = t2.a) WHERE t1.a < 10 ORDER BY 1,2,3;
SELECT t1.a,t2.b,t2.c FROM fprt1 t1 LEFT JOIN (SELECT * FROM fprt2 WHERE a < 10) t2 ON (t1.a = t2.b and t1.b = t2.a) WHERE t1.a < 10 ORDER BY 1,2,3;

-- with whole-row reference; partitionwise join does not apply
EXPLAIN (COSTS OFF)
SELECT t1.wr, t2.wr FROM (SELECT t1 wr, a FROM fprt1 t1 WHERE t1.a % 25 = 0) t1 FULL JOIN (SELECT t2 wr, b FROM fprt2 t2 WHERE t2.b % 25 = 0) t2 ON (t1.a = t2.b) ORDER BY 1,2;
SELECT t1.wr, t2.wr FROM (SELECT t1 wr, a FROM fprt1 t1 WHERE t1.a % 25 = 0) t1 FULL JOIN (SELECT t2 wr, b FROM fprt2 t2 WHERE t2.b % 25 = 0) t2 ON (t1.a = t2.b) ORDER BY 1,2;

-- join with lateral reference
EXPLAIN (COSTS OFF)
SELECT t1.a,t1.b FROM fprt1 t1, LATERAL (SELECT t2.a, t2.b FROM fprt2 t2 WHERE t1.a = t2.b AND t1.b = t2.a) q WHERE t1.a%25 = 0 ORDER BY 1,2;
SELECT t1.a,t1.b FROM fprt1 t1, LATERAL (SELECT t2.a, t2.b FROM fprt2 t2 WHERE t1.a = t2.b AND t1.b = t2.a) q WHERE t1.a%25 = 0 ORDER BY 1,2;

-- with PHVs, partitionwise join selected but no join pushdown
EXPLAIN (COSTS OFF)
SELECT t1.a, t1.phv, t2.b, t2.phv FROM (SELECT 't1_phv' phv, * FROM fprt1 WHERE a % 25 = 0) t1 FULL JOIN (SELECT 't2_phv' phv, * FROM fprt2 WHERE b % 25 = 0) t2 ON (t1.a = t2.b) ORDER BY t1.a, t2.b;
SELECT t1.a, t1.phv, t2.b, t2.phv FROM (SELECT 't1_phv' phv, * FROM fprt1 WHERE a % 25 = 0) t1 FULL JOIN (SELECT 't2_phv' phv, * FROM fprt2 WHERE b % 25 = 0) t2 ON (t1.a = t2.b) ORDER BY t1.a, t2.b;

-- test FOR UPDATE; partitionwise join does not apply
EXPLAIN (COSTS OFF)
SELECT t1.a, t2.b FROM fprt1 t1 INNER JOIN fprt2 t2 ON (t1.a = t2.b) WHERE t1.a % 25 = 0 ORDER BY 1,2 FOR UPDATE OF t1;
SELECT t1.a, t2.b FROM fprt1 t1 INNER JOIN fprt2 t2 ON (t1.a = t2.b) WHERE t1.a % 25 = 0 ORDER BY 1,2 FOR UPDATE OF t1;

RESET enable_partitionwise_join;


-- ===================================================================
-- test partitionwise aggregates
-- ===================================================================

CREATE TABLE pagg_tab (a int, b int, c text) PARTITION BY RANGE(a);

-- Create foreign partitions
CREATE FOREIGN TABLE fpagg_tab_p1 PARTITION OF pagg_tab FOR VALUES FROM (0) TO (10) SERVER :DB_SERVERNAME OPTIONS (schema :DB_SCHEMA_PORT_TEST, table 'pagg_tab_p1');
CREATE FOREIGN TABLE fpagg_tab_p2 PARTITION OF pagg_tab FOR VALUES FROM (10) TO (20) SERVER :DB_SERVERNAME OPTIONS (schema :DB_SCHEMA_PORT_TEST, table 'pagg_tab_p2');;
CREATE FOREIGN TABLE fpagg_tab_p3 PARTITION OF pagg_tab FOR VALUES FROM (20) TO (30) SERVER :DB_SERVERNAME OPTIONS (schema :DB_SCHEMA_PORT_TEST, table 'pagg_tab_p3');;


-- When GROUP BY clause matches with PARTITION KEY.
-- Plan with partitionwise aggregates is disabled
SET enable_partitionwise_aggregate TO false;
EXPLAIN (COSTS OFF)
SELECT a, sum(b), min(b), count(*) FROM pagg_tab GROUP BY a HAVING avg(b) < 22 ORDER BY 1;

-- Plan with partitionwise aggregates is enabled
SET enable_partitionwise_aggregate TO true;
EXPLAIN (COSTS OFF)
SELECT a, sum(b), min(b), count(*) FROM pagg_tab GROUP BY a HAVING avg(b) < 22 ORDER BY 1;
SELECT a, sum(b), min(b), count(*) FROM pagg_tab GROUP BY a HAVING avg(b) < 22 ORDER BY 1;

-- Check with whole-row reference
-- Should have all the columns in the target list for the given relation
EXPLAIN (VERBOSE, COSTS OFF)
SELECT a, count(t1) FROM pagg_tab t1 GROUP BY a HAVING avg(b) < 22 ORDER BY 1;
SELECT a, count(t1) FROM pagg_tab t1 GROUP BY a HAVING avg(b) < 22 ORDER BY 1;

-- When GROUP BY clause does not match with PARTITION KEY.
EXPLAIN (COSTS OFF)
SELECT b, avg(a), max(a), count(*) FROM pagg_tab GROUP BY b HAVING sum(a) < 700 ORDER BY 1;
*/
-- Does not support rights
-- ===================================================================
-- access rights and superuser
-- ===================================================================

-- -- Non-superuser cannot create a FDW without a password in the connstr
-- CREATE ROLE regress_nosuper NOSUPERUSER;

-- GRANT USAGE ON FOREIGN DATA WRAPPER :DB_EXTENSIONNAME TO regress_nosuper;

-- SET ROLE regress_nosuper;

-- SHOW is_superuser;

-- -- This will be OK, we can create the FDW
-- DO $d$
--     BEGIN
--         EXECUTE $$CREATE SERVER loopback_nopw FOREIGN DATA WRAPPER :DB_EXTENSIONNAME
--             OPTIONS (dbname '$$||current_database()||$$',
--                      port '$$||current_setting('port')||$$'
--             )$$;
--     END;
-- $d$;

-- -- But creation of user mappings for non-superusers should fail
-- CREATE USER MAPPING FOR public SERVER loopback_nopw;
-- CREATE USER MAPPING FOR CURRENT_USER SERVER loopback_nopw;

-- CREATE FOREIGN TABLE ft1_nopw (
-- 	c1 int NOT NULL,
-- 	c2 int NOT NULL,
-- 	c3 text,
-- 	c4 timestamptz,
-- 	c5 timestamp,
-- 	c6 varchar(10),
-- 	c7 char(10) default 'ft1',
-- 	c8 user_enum
-- ) SERVER loopback_nopw OPTIONS (schema_name 'public', table 'ft1');

-- SELECT * FROM ft1_nopw LIMIT 1;

-- -- If we add a password to the connstr it'll fail, because we don't allow passwords
-- -- in connstrs only in user mappings.

-- DO $d$
--     BEGIN
--         EXECUTE $$ALTER SERVER loopback_nopw OPTIONS (ADD password 'dummypw')$$;
--     END;
-- $d$;

-- -- If we add a password for our user mapping instead, we should get a different
-- -- error because the password wasn't actually *used* when we run with trust auth.
-- --
-- -- This won't work with installcheck, but neither will most of the FDW checks.

-- ALTER USER MAPPING FOR CURRENT_USER SERVER loopback_nopw OPTIONS (ADD password 'dummypw');

-- SELECT * FROM ft1_nopw LIMIT 1;

-- -- Unpriv user cannot make the mapping passwordless
-- ALTER USER MAPPING FOR CURRENT_USER SERVER loopback_nopw OPTIONS (ADD password_required 'false');


-- SELECT * FROM ft1_nopw LIMIT 1;

-- RESET ROLE;

-- -- But the superuser can
-- ALTER USER MAPPING FOR regress_nosuper SERVER loopback_nopw OPTIONS (ADD password_required 'false');

-- SET ROLE regress_nosuper;

-- -- Should finally work now
-- SELECT * FROM ft1_nopw LIMIT 1;

-- -- unpriv user also cannot set sslcert / sslkey on the user mapping
-- -- first set password_required so we see the right error messages
-- ALTER USER MAPPING FOR CURRENT_USER SERVER loopback_nopw OPTIONS (SET password_required 'true');
-- ALTER USER MAPPING FOR CURRENT_USER SERVER loopback_nopw OPTIONS (ADD sslcert 'foo.crt');
-- ALTER USER MAPPING FOR CURRENT_USER SERVER loopback_nopw OPTIONS (ADD sslkey 'foo.key');

-- -- We're done with the role named after a specific user and need to check the
-- -- changes to the public mapping.
-- DROP USER MAPPING FOR CURRENT_USER SERVER loopback_nopw;

-- -- This will fail again as it'll resolve the user mapping for public, which
-- -- lacks password_required=false
-- SELECT * FROM ft1_nopw LIMIT 1;

-- RESET ROLE;

-- -- The user mapping for public is passwordless and lacks the password_required=false
-- -- mapping option, but will work because the current user is a superuser.
-- SELECT * FROM ft1_nopw LIMIT 1;

-- -- cleanup
-- DROP USER MAPPING FOR public SERVER loopback_nopw;
-- DROP OWNED BY regress_nosuper;
-- DROP ROLE regress_nosuper;

-- -- Clean-up
-- RESET enable_partitionwise_aggregate;

-- -- Two-phase transactions are not supported.
-- BEGIN;
-- SELECT count(*) FROM ft1;
-- -- error here
-- PREPARE TRANSACTION 'fdw_tpc';
-- ROLLBACK;

-- odbd_fdw does not support new feature from postgres_fdw 14.0
-- -- ===================================================================
-- -- reestablish new connection
-- -- ===================================================================

-- -- Change application_name of remote connection to special one
-- -- so that we can easily terminate the connection later.
-- ALTER SERVER loopback OPTIONS (application_name 'fdw_retry_check');

-- -- If debug_discard_caches is active, it results in
-- -- dropping remote connections after every transaction, making it
-- -- impossible to test termination meaningfully.  So turn that off
-- -- for this test.
-- SET debug_discard_caches = 0;

-- -- Make sure we have a remote connection.
-- SELECT 1 FROM ft1 LIMIT 1;

-- -- Terminate the remote connection and wait for the termination to complete.
-- SELECT pg_terminate_backend(pid, 180000) FROM pg_stat_activity
-- 	WHERE application_name = 'fdw_retry_check';

-- -- This query should detect the broken connection when starting new remote
-- -- transaction, reestablish new connection, and then succeed.
-- BEGIN;
-- SELECT 1 FROM ft1 LIMIT 1;

-- -- If we detect the broken connection when starting a new remote
-- -- subtransaction, we should fail instead of establishing a new connection.
-- -- Terminate the remote connection and wait for the termination to complete.
-- SELECT pg_terminate_backend(pid, 180000) FROM pg_stat_activity
-- 	WHERE application_name = 'fdw_retry_check';
-- SAVEPOINT s;
-- -- The text of the error might vary across platforms, so only show SQLSTATE.
-- \set VERBOSITY sqlstate
-- SELECT 1 FROM ft1 LIMIT 1;    -- should fail
-- \set VERBOSITY default
-- COMMIT;

-- RESET debug_discard_caches;

-- -- =============================================================================
-- -- test connection invalidation cases and postgres_fdw_get_connections function
-- -- =============================================================================
-- -- Let's ensure to close all the existing cached connections.
-- SELECT 1 FROM postgres_fdw_disconnect_all();
-- -- No cached connections, so no records should be output.
-- SELECT server_name FROM postgres_fdw_get_connections() ORDER BY 1;
-- -- This test case is for closing the connection in pgfdw_xact_callback
-- BEGIN;
-- -- Connection xact depth becomes 1 i.e. the connection is in midst of the xact.
-- SELECT 1 FROM ft1 LIMIT 1;
-- SELECT 1 FROM ft7 LIMIT 1;
-- -- List all the existing cached connections. loopback and loopback3 should be
-- -- output.
-- SELECT server_name FROM postgres_fdw_get_connections() ORDER BY 1;
-- -- Connections are not closed at the end of the alter and drop statements.
-- -- That's because the connections are in midst of this xact,
-- -- they are just marked as invalid in pgfdw_inval_callback.
-- ALTER SERVER loopback OPTIONS (ADD use_remote_estimate 'off');
-- DROP SERVER loopback3 CASCADE;
-- -- List all the existing cached connections. loopback and loopback3
-- -- should be output as invalid connections. Also the server name for
-- -- loopback3 should be NULL because the server was dropped.
-- SELECT * FROM postgres_fdw_get_connections() ORDER BY 1;
-- -- The invalid connections get closed in pgfdw_xact_callback during commit.
-- COMMIT;
-- -- All cached connections were closed while committing above xact, so no
-- -- records should be output.
-- SELECT server_name FROM postgres_fdw_get_connections() ORDER BY 1;

-- -- =======================================================================
-- -- test postgres_fdw_disconnect and postgres_fdw_disconnect_all functions
-- -- =======================================================================
-- BEGIN;
-- -- Ensure to cache loopback connection.
-- SELECT 1 FROM ft1 LIMIT 1;
-- -- Ensure to cache loopback2 connection.
-- SELECT 1 FROM ft6 LIMIT 1;
-- -- List all the existing cached connections. loopback and loopback2 should be
-- -- output.
-- SELECT server_name FROM postgres_fdw_get_connections() ORDER BY 1;
-- -- Issue a warning and return false as loopback connection is still in use and
-- -- can not be closed.
-- SELECT postgres_fdw_disconnect('loopback');
-- -- List all the existing cached connections. loopback and loopback2 should be
-- -- output.
-- SELECT server_name FROM postgres_fdw_get_connections() ORDER BY 1;
-- -- Return false as connections are still in use, warnings are issued.
-- -- But disable warnings temporarily because the order of them is not stable.
-- SET client_min_messages = 'ERROR';
-- SELECT postgres_fdw_disconnect_all();
-- RESET client_min_messages;
-- COMMIT;
-- -- Ensure that loopback2 connection is closed.
-- SELECT 1 FROM postgres_fdw_disconnect('loopback2');
-- SELECT server_name FROM postgres_fdw_get_connections() WHERE server_name = 'loopback2';
-- -- Return false as loopback2 connection is closed already.
-- SELECT postgres_fdw_disconnect('loopback2');
-- -- Return an error as there is no foreign server with given name.
-- SELECT postgres_fdw_disconnect('unknownserver');
-- -- Let's ensure to close all the existing cached connections.
-- SELECT 1 FROM postgres_fdw_disconnect_all();
-- -- No cached connections, so no records should be output.
-- SELECT server_name FROM postgres_fdw_get_connections() ORDER BY 1;

-- -- =============================================================================
-- -- test case for having multiple cached connections for a foreign server
-- -- =============================================================================
-- CREATE ROLE regress_multi_conn_user1 SUPERUSER;
-- CREATE ROLE regress_multi_conn_user2 SUPERUSER;
-- CREATE USER MAPPING FOR regress_multi_conn_user1 SERVER loopback;
-- CREATE USER MAPPING FOR regress_multi_conn_user2 SERVER loopback;

-- BEGIN;
-- -- Will cache loopback connection with user mapping for regress_multi_conn_user1
-- SET ROLE regress_multi_conn_user1;
-- SELECT 1 FROM ft1 LIMIT 1;
-- RESET ROLE;

-- -- Will cache loopback connection with user mapping for regress_multi_conn_user2
-- SET ROLE regress_multi_conn_user2;
-- SELECT 1 FROM ft1 LIMIT 1;
-- RESET ROLE;

-- -- Should output two connections for loopback server
-- SELECT server_name FROM postgres_fdw_get_connections() ORDER BY 1;
-- COMMIT;
-- -- Let's ensure to close all the existing cached connections.
-- SELECT 1 FROM postgres_fdw_disconnect_all();
-- -- No cached connections, so no records should be output.
-- SELECT server_name FROM postgres_fdw_get_connections() ORDER BY 1;

-- -- Clean up
-- DROP USER MAPPING FOR regress_multi_conn_user1 SERVER loopback;
-- DROP USER MAPPING FOR regress_multi_conn_user2 SERVER loopback;
-- DROP ROLE regress_multi_conn_user1;
-- DROP ROLE regress_multi_conn_user2;

-- -- ===================================================================
-- -- Test foreign server level option keep_connections
-- -- ===================================================================
-- -- By default, the connections associated with foreign server are cached i.e.
-- -- keep_connections option is on. Set it to off.
-- ALTER SERVER loopback OPTIONS (keep_connections 'off');
-- -- connection to loopback server is closed at the end of xact
-- -- as keep_connections was set to off.
-- SELECT 1 FROM ft1 LIMIT 1;
-- -- No cached connections, so no records should be output.
-- SELECT server_name FROM postgres_fdw_get_connections() ORDER BY 1;
-- ALTER SERVER loopback OPTIONS (SET keep_connections 'on');

-- -- ===================================================================
-- -- batch insert
-- -- ===================================================================

-- BEGIN;

-- CREATE SERVER batch10 FOREIGN DATA WRAPPER postgres_fdw OPTIONS( batch_size '10' );

-- SELECT count(*)
-- FROM pg_foreign_server
-- WHERE srvname = 'batch10'
-- AND srvoptions @> array['batch_size=10'];

-- ALTER SERVER batch10 OPTIONS( SET batch_size '20' );

-- SELECT count(*)
-- FROM pg_foreign_server
-- WHERE srvname = 'batch10'
-- AND srvoptions @> array['batch_size=10'];

-- SELECT count(*)
-- FROM pg_foreign_server
-- WHERE srvname = 'batch10'
-- AND srvoptions @> array['batch_size=20'];

-- CREATE FOREIGN TABLE table30 ( x int ) SERVER batch10 OPTIONS ( batch_size '30' );

-- SELECT COUNT(*)
-- FROM pg_foreign_table
-- WHERE ftrelid = 'table30'::regclass
-- AND ftoptions @> array['batch_size=30'];

-- ALTER FOREIGN TABLE table30 OPTIONS ( SET batch_size '40');

-- SELECT COUNT(*)
-- FROM pg_foreign_table
-- WHERE ftrelid = 'table30'::regclass
-- AND ftoptions @> array['batch_size=30'];

-- SELECT COUNT(*)
-- FROM pg_foreign_table
-- WHERE ftrelid = 'table30'::regclass
-- AND ftoptions @> array['batch_size=40'];

-- ROLLBACK;

-- CREATE TABLE batch_table ( x int );

-- CREATE FOREIGN TABLE ftable ( x int ) SERVER loopback OPTIONS ( table_name 'batch_table', batch_size '10' );
-- EXPLAIN (VERBOSE, COSTS OFF) INSERT INTO ftable SELECT * FROM generate_series(1, 10) i;
-- INSERT INTO ftable SELECT * FROM generate_series(1, 10) i;
-- INSERT INTO ftable SELECT * FROM generate_series(11, 31) i;
-- INSERT INTO ftable VALUES (32);
-- INSERT INTO ftable VALUES (33), (34);
-- SELECT COUNT(*) FROM ftable;
-- TRUNCATE batch_table;
-- DROP FOREIGN TABLE ftable;

-- -- try if large batches exceed max number of bind parameters
-- CREATE FOREIGN TABLE ftable ( x int ) SERVER loopback OPTIONS ( table_name 'batch_table', batch_size '100000' );
-- INSERT INTO ftable SELECT * FROM generate_series(1, 70000) i;
-- SELECT COUNT(*) FROM ftable;
-- TRUNCATE batch_table;
-- DROP FOREIGN TABLE ftable;

-- -- Disable batch insert
-- CREATE FOREIGN TABLE ftable ( x int ) SERVER loopback OPTIONS ( table_name 'batch_table', batch_size '1' );
-- EXPLAIN (VERBOSE, COSTS OFF) INSERT INTO ftable VALUES (1), (2);
-- INSERT INTO ftable VALUES (1), (2);
-- SELECT COUNT(*) FROM ftable;
-- DROP FOREIGN TABLE ftable;
-- DROP TABLE batch_table;

-- -- Use partitioning
-- CREATE TABLE batch_table ( x int ) PARTITION BY HASH (x);

-- CREATE TABLE batch_table_p0 (LIKE batch_table);
-- CREATE FOREIGN TABLE batch_table_p0f
-- 	PARTITION OF batch_table
-- 	FOR VALUES WITH (MODULUS 3, REMAINDER 0)
-- 	SERVER loopback
-- 	OPTIONS (table_name 'batch_table_p0', batch_size '10');

-- CREATE TABLE batch_table_p1 (LIKE batch_table);
-- CREATE FOREIGN TABLE batch_table_p1f
-- 	PARTITION OF batch_table
-- 	FOR VALUES WITH (MODULUS 3, REMAINDER 1)
-- 	SERVER loopback
-- 	OPTIONS (table_name 'batch_table_p1', batch_size '1');

-- CREATE TABLE batch_table_p2
-- 	PARTITION OF batch_table
-- 	FOR VALUES WITH (MODULUS 3, REMAINDER 2);

-- INSERT INTO batch_table SELECT * FROM generate_series(1, 66) i;
-- SELECT COUNT(*) FROM batch_table;

-- -- Check that enabling batched inserts doesn't interfere with cross-partition
-- -- updates
-- CREATE TABLE batch_cp_upd_test (a int) PARTITION BY LIST (a);
-- CREATE TABLE batch_cp_upd_test1 (LIKE batch_cp_upd_test);
-- CREATE FOREIGN TABLE batch_cp_upd_test1_f
-- 	PARTITION OF batch_cp_upd_test
-- 	FOR VALUES IN (1)
-- 	SERVER loopback
-- 	OPTIONS (table_name 'batch_cp_upd_test1', batch_size '10');
-- CREATE TABLE batch_cp_up_test1 PARTITION OF batch_cp_upd_test
-- 	FOR VALUES IN (2);
-- INSERT INTO batch_cp_upd_test VALUES (1), (2);

-- -- The following moves a row from the local partition to the foreign one
-- UPDATE batch_cp_upd_test t SET a = 1 FROM (VALUES (1), (2)) s(a) WHERE t.a = s.a;
-- SELECT tableoid::regclass, * FROM batch_cp_upd_test;

-- -- Clean up
-- DROP TABLE batch_table, batch_cp_upd_test, batch_table_p0, batch_table_p1 CASCADE;

-- -- Use partitioning
-- ALTER SERVER loopback OPTIONS (ADD batch_size '10');

-- CREATE TABLE batch_table ( x int, field1 text, field2 text) PARTITION BY HASH (x);

-- CREATE TABLE batch_table_p0 (LIKE batch_table);
-- ALTER TABLE batch_table_p0 ADD CONSTRAINT p0_pkey PRIMARY KEY (x);
-- CREATE FOREIGN TABLE batch_table_p0f
-- 	PARTITION OF batch_table
-- 	FOR VALUES WITH (MODULUS 2, REMAINDER 0)
-- 	SERVER loopback
-- 	OPTIONS (table_name 'batch_table_p0');

-- CREATE TABLE batch_table_p1 (LIKE batch_table);
-- ALTER TABLE batch_table_p1 ADD CONSTRAINT p1_pkey PRIMARY KEY (x);
-- CREATE FOREIGN TABLE batch_table_p1f
-- 	PARTITION OF batch_table
-- 	FOR VALUES WITH (MODULUS 2, REMAINDER 1)
-- 	SERVER loopback
-- 	OPTIONS (table_name 'batch_table_p1');

-- INSERT INTO batch_table SELECT i, 'test'||i, 'test'|| i FROM generate_series(1, 50) i;
-- SELECT COUNT(*) FROM batch_table;
-- SELECT * FROM batch_table ORDER BY x;

-- ALTER SERVER loopback OPTIONS (DROP batch_size);

-- -- ===================================================================
-- -- test asynchronous execution
-- -- ===================================================================

-- ALTER SERVER loopback OPTIONS (DROP extensions);
-- ALTER SERVER loopback OPTIONS (ADD async_capable 'true');
-- ALTER SERVER loopback2 OPTIONS (ADD async_capable 'true');

-- CREATE TABLE async_pt (a int, b int, c text) PARTITION BY RANGE (a);
-- CREATE TABLE base_tbl1 (a int, b int, c text);
-- CREATE TABLE base_tbl2 (a int, b int, c text);
-- CREATE FOREIGN TABLE async_p1 PARTITION OF async_pt FOR VALUES FROM (1000) TO (2000)
--   SERVER loopback OPTIONS (table_name 'base_tbl1');
-- CREATE FOREIGN TABLE async_p2 PARTITION OF async_pt FOR VALUES FROM (2000) TO (3000)
--   SERVER loopback2 OPTIONS (table_name 'base_tbl2');
-- INSERT INTO async_p1 SELECT 1000 + i, i, to_char(i, 'FM0000') FROM generate_series(0, 999, 5) i;
-- INSERT INTO async_p2 SELECT 2000 + i, i, to_char(i, 'FM0000') FROM generate_series(0, 999, 5) i;
-- ANALYZE async_pt;

-- -- simple queries
-- CREATE TABLE result_tbl (a int, b int, c text);

-- EXPLAIN (VERBOSE, COSTS OFF)
-- INSERT INTO result_tbl SELECT * FROM async_pt WHERE b % 100 = 0;
-- INSERT INTO result_tbl SELECT * FROM async_pt WHERE b % 100 = 0;

-- SELECT * FROM result_tbl ORDER BY a;
-- DELETE FROM result_tbl;

-- EXPLAIN (VERBOSE, COSTS OFF)
-- INSERT INTO result_tbl SELECT * FROM async_pt WHERE b === 505;
-- INSERT INTO result_tbl SELECT * FROM async_pt WHERE b === 505;

-- SELECT * FROM result_tbl ORDER BY a;
-- DELETE FROM result_tbl;

-- -- Check case where multiple partitions use the same connection
-- CREATE TABLE base_tbl3 (a int, b int, c text);
-- CREATE FOREIGN TABLE async_p3 PARTITION OF async_pt FOR VALUES FROM (3000) TO (4000)
--   SERVER loopback2 OPTIONS (table_name 'base_tbl3');
-- INSERT INTO async_p3 SELECT 3000 + i, i, to_char(i, 'FM0000') FROM generate_series(0, 999, 5) i;
-- ANALYZE async_pt;

-- EXPLAIN (VERBOSE, COSTS OFF)
-- INSERT INTO result_tbl SELECT * FROM async_pt WHERE b === 505;
-- INSERT INTO result_tbl SELECT * FROM async_pt WHERE b === 505;

-- SELECT * FROM result_tbl ORDER BY a;
-- DELETE FROM result_tbl;

-- DROP FOREIGN TABLE async_p3;
-- DROP TABLE base_tbl3;

-- -- Check case where the partitioned table has local/remote partitions
-- CREATE TABLE async_p3 PARTITION OF async_pt FOR VALUES FROM (3000) TO (4000);
-- INSERT INTO async_p3 SELECT 3000 + i, i, to_char(i, 'FM0000') FROM generate_series(0, 999, 5) i;
-- ANALYZE async_pt;

-- EXPLAIN (VERBOSE, COSTS OFF)
-- INSERT INTO result_tbl SELECT * FROM async_pt WHERE b === 505;
-- INSERT INTO result_tbl SELECT * FROM async_pt WHERE b === 505;

-- SELECT * FROM result_tbl ORDER BY a;
-- DELETE FROM result_tbl;

-- -- partitionwise joins
-- SET enable_partitionwise_join TO true;

-- CREATE TABLE join_tbl (a1 int, b1 int, c1 text, a2 int, b2 int, c2 text);

-- EXPLAIN (VERBOSE, COSTS OFF)
-- INSERT INTO join_tbl SELECT * FROM async_pt t1, async_pt t2 WHERE t1.a = t2.a AND t1.b = t2.b AND t1.b % 100 = 0;
-- INSERT INTO join_tbl SELECT * FROM async_pt t1, async_pt t2 WHERE t1.a = t2.a AND t1.b = t2.b AND t1.b % 100 = 0;

-- SELECT * FROM join_tbl ORDER BY a1;
-- DELETE FROM join_tbl;

-- RESET enable_partitionwise_join;

-- -- Test rescan of an async Append node with do_exec_prune=false
-- SET enable_hashjoin TO false;

-- EXPLAIN (VERBOSE, COSTS OFF)
-- INSERT INTO join_tbl SELECT * FROM async_p1 t1, async_pt t2 WHERE t1.a = t2.a AND t1.b = t2.b AND t1.b % 100 = 0;
-- INSERT INTO join_tbl SELECT * FROM async_p1 t1, async_pt t2 WHERE t1.a = t2.a AND t1.b = t2.b AND t1.b % 100 = 0;

-- SELECT * FROM join_tbl ORDER BY a1;
-- DELETE FROM join_tbl;

-- RESET enable_hashjoin;

-- -- Test interaction of async execution with plan-time partition pruning
-- EXPLAIN (VERBOSE, COSTS OFF)
-- SELECT * FROM async_pt WHERE a < 3000;

-- EXPLAIN (VERBOSE, COSTS OFF)
-- SELECT * FROM async_pt WHERE a < 2000;

-- -- Test interaction of async execution with run-time partition pruning
-- SET plan_cache_mode TO force_generic_plan;

-- PREPARE async_pt_query (int, int) AS
--   INSERT INTO result_tbl SELECT * FROM async_pt WHERE a < $1 AND b === $2;

-- EXPLAIN (VERBOSE, COSTS OFF)
-- EXECUTE async_pt_query (3000, 505);
-- EXECUTE async_pt_query (3000, 505);

-- SELECT * FROM result_tbl ORDER BY a;
-- DELETE FROM result_tbl;

-- EXPLAIN (VERBOSE, COSTS OFF)
-- EXECUTE async_pt_query (2000, 505);
-- EXECUTE async_pt_query (2000, 505);

-- SELECT * FROM result_tbl ORDER BY a;
-- DELETE FROM result_tbl;

-- RESET plan_cache_mode;

-- CREATE TABLE local_tbl(a int, b int, c text);
-- INSERT INTO local_tbl VALUES (1505, 505, 'foo'), (2505, 505, 'bar');
-- ANALYZE local_tbl;

-- CREATE INDEX base_tbl1_idx ON base_tbl1 (a);
-- CREATE INDEX base_tbl2_idx ON base_tbl2 (a);
-- CREATE INDEX async_p3_idx ON async_p3 (a);
-- ANALYZE base_tbl1;
-- ANALYZE base_tbl2;
-- ANALYZE async_p3;

-- ALTER FOREIGN TABLE async_p1 OPTIONS (use_remote_estimate 'true');
-- ALTER FOREIGN TABLE async_p2 OPTIONS (use_remote_estimate 'true');

-- EXPLAIN (VERBOSE, COSTS OFF)
-- SELECT * FROM local_tbl, async_pt WHERE local_tbl.a = async_pt.a AND local_tbl.c = 'bar';
-- EXPLAIN (ANALYZE, COSTS OFF, SUMMARY OFF, TIMING OFF)
-- SELECT * FROM local_tbl, async_pt WHERE local_tbl.a = async_pt.a AND local_tbl.c = 'bar';
-- SELECT * FROM local_tbl, async_pt WHERE local_tbl.a = async_pt.a AND local_tbl.c = 'bar';

-- ALTER FOREIGN TABLE async_p1 OPTIONS (DROP use_remote_estimate);
-- ALTER FOREIGN TABLE async_p2 OPTIONS (DROP use_remote_estimate);

-- DROP TABLE local_tbl;
-- DROP INDEX base_tbl1_idx;
-- DROP INDEX base_tbl2_idx;
-- DROP INDEX async_p3_idx;

-- -- Test that pending requests are processed properly
-- SET enable_mergejoin TO false;
-- SET enable_hashjoin TO false;

-- EXPLAIN (VERBOSE, COSTS OFF)
-- SELECT * FROM async_pt t1, async_p2 t2 WHERE t1.a = t2.a AND t1.b === 505;
-- SELECT * FROM async_pt t1, async_p2 t2 WHERE t1.a = t2.a AND t1.b === 505;

-- CREATE TABLE local_tbl (a int, b int, c text);
-- INSERT INTO local_tbl VALUES (1505, 505, 'foo');
-- ANALYZE local_tbl;

-- EXPLAIN (VERBOSE, COSTS OFF)
-- SELECT * FROM local_tbl t1 LEFT JOIN (SELECT *, (SELECT count(*) FROM async_pt WHERE a < 3000) FROM async_pt WHERE a < 3000) t2 ON t1.a = t2.a;
-- EXPLAIN (ANALYZE, COSTS OFF, SUMMARY OFF, TIMING OFF)
-- SELECT * FROM local_tbl t1 LEFT JOIN (SELECT *, (SELECT count(*) FROM async_pt WHERE a < 3000) FROM async_pt WHERE a < 3000) t2 ON t1.a = t2.a;
-- SELECT * FROM local_tbl t1 LEFT JOIN (SELECT *, (SELECT count(*) FROM async_pt WHERE a < 3000) FROM async_pt WHERE a < 3000) t2 ON t1.a = t2.a;

-- EXPLAIN (VERBOSE, COSTS OFF)
-- SELECT * FROM async_pt t1 WHERE t1.b === 505 LIMIT 1;
-- EXPLAIN (ANALYZE, COSTS OFF, SUMMARY OFF, TIMING OFF)
-- SELECT * FROM async_pt t1 WHERE t1.b === 505 LIMIT 1;
-- SELECT * FROM async_pt t1 WHERE t1.b === 505 LIMIT 1;

-- -- Check with foreign modify
-- CREATE TABLE base_tbl3 (a int, b int, c text);
-- CREATE FOREIGN TABLE remote_tbl (a int, b int, c text)
--   SERVER loopback OPTIONS (table_name 'base_tbl3');
-- INSERT INTO remote_tbl VALUES (2505, 505, 'bar');

-- CREATE TABLE base_tbl4 (a int, b int, c text);
-- CREATE FOREIGN TABLE insert_tbl (a int, b int, c text)
--   SERVER loopback OPTIONS (table_name 'base_tbl4');

-- EXPLAIN (VERBOSE, COSTS OFF)
-- INSERT INTO insert_tbl (SELECT * FROM local_tbl UNION ALL SELECT * FROM remote_tbl);
-- INSERT INTO insert_tbl (SELECT * FROM local_tbl UNION ALL SELECT * FROM remote_tbl);

-- SELECT * FROM insert_tbl ORDER BY a;

-- -- Check with direct modify
-- EXPLAIN (VERBOSE, COSTS OFF)
-- WITH t AS (UPDATE remote_tbl SET c = c || c RETURNING *)
-- INSERT INTO join_tbl SELECT * FROM async_pt LEFT JOIN t ON (async_pt.a = t.a AND async_pt.b = t.b) WHERE async_pt.b === 505;
-- WITH t AS (UPDATE remote_tbl SET c = c || c RETURNING *)
-- INSERT INTO join_tbl SELECT * FROM async_pt LEFT JOIN t ON (async_pt.a = t.a AND async_pt.b = t.b) WHERE async_pt.b === 505;

-- SELECT * FROM join_tbl ORDER BY a1;
-- DELETE FROM join_tbl;

-- DROP TABLE local_tbl;
-- DROP FOREIGN TABLE remote_tbl;
-- DROP FOREIGN TABLE insert_tbl;
-- DROP TABLE base_tbl3;
-- DROP TABLE base_tbl4;

-- RESET enable_mergejoin;
-- RESET enable_hashjoin;

-- -- Test that UPDATE/DELETE with inherited target works with async_capable enabled
-- EXPLAIN (VERBOSE, COSTS OFF)
-- UPDATE async_pt SET c = c || c WHERE b = 0 RETURNING *;
-- UPDATE async_pt SET c = c || c WHERE b = 0 RETURNING *;
-- EXPLAIN (VERBOSE, COSTS OFF)
-- DELETE FROM async_pt WHERE b = 0 RETURNING *;
-- DELETE FROM async_pt WHERE b = 0 RETURNING *;

-- -- Check EXPLAIN ANALYZE for a query that scans empty partitions asynchronously
-- DELETE FROM async_p1;
-- DELETE FROM async_p2;
-- DELETE FROM async_p3;

-- EXPLAIN (ANALYZE, COSTS OFF, SUMMARY OFF, TIMING OFF)
-- SELECT * FROM async_pt;

-- -- Clean up
-- DROP TABLE async_pt;
-- DROP TABLE base_tbl1;
-- DROP TABLE base_tbl2;
-- DROP TABLE result_tbl;
-- DROP TABLE join_tbl;

-- ALTER SERVER loopback OPTIONS (DROP async_capable);
-- ALTER SERVER loopback2 OPTIONS (DROP async_capable);

-- -- ===================================================================
-- -- test invalid server and foreign table options
-- -- ===================================================================
-- -- Invalid fdw_startup_cost option
-- CREATE SERVER inv_scst FOREIGN DATA WRAPPER postgres_fdw
-- 	OPTIONS(fdw_startup_cost '100$%$#$#');
-- -- Invalid fdw_tuple_cost option
-- CREATE SERVER inv_scst FOREIGN DATA WRAPPER postgres_fdw
-- 	OPTIONS(fdw_tuple_cost '100$%$#$#');
-- -- Invalid fetch_size option
-- CREATE FOREIGN TABLE inv_fsz (c1 int )
-- 	SERVER loopback OPTIONS (fetch_size '100$%$#$#');
-- -- Invalid batch_size option
-- CREATE FOREIGN TABLE inv_bsz (c1 int )
-- 	SERVER loopback OPTIONS (batch_size '100$%$#$#');

--Testcase 940:
SET client_min_messages TO warning;
--Testcase 941:
DROP SCHEMA "S 1" CASCADE;
--Testcase 942:
DROP EXTENSION :DB_EXTENSIONNAME CASCADE;

--Testcase 943:
DROP FUNCTION trigger_func;
--Testcase 944:
DROP FUNCTION trig_row_before_insupdate;
--Testcase 945:
DROP FUNCTION trig_null;
--Testcase 946:
DROP FUNCTION br_insert_trigfunc;

--Testcase 947:
DROP SCHEMA import_dest1 CASCADE;
--Testcase 948:
DROP TYPE user_enum;
