--
-- new tcs
--
--Testcase 1:
CREATE EXTENSION IF NOT EXISTS :DB_EXTENSIONNAME;
--Testcase 2:
CREATE SERVER :DB_SERVERNAME FOREIGN DATA WRAPPER :DB_EXTENSIONNAME
  OPTIONS (odbc_DRIVER :DB_DRIVERNAME, odbc_SERVER :DB_SERVER, odbc_port :DB_PORT, odbc_DATABASE :DB_DATABASE);
--Testcase 3:
CREATE USER MAPPING FOR public SERVER :DB_SERVERNAME OPTIONS (odbc_UID :DB_USER, odbc_PWD :DB_PASS);  

--Primary key options
--Testcase 4:
CREATE FOREIGN TABLE tbl01 (id bigint  OPTIONS (key 'true'), c1 int) 
  SERVER :DB_SERVERNAME OPTIONS (schema :DB_SCHEMA, table 'tbl01');
--Testcase 5:
EXPLAIN VERBOSE
INSERT INTO tbl01 VALUES (166565, 1);
--Testcase 6:
INSERT INTO tbl01 VALUES (166565, 1);
--Testcase 7:
EXPLAIN VERBOSE
INSERT INTO tbl01 (c1) VALUES (3);
--Testcase 8:
INSERT INTO tbl01 (c1) VALUES (3); --fail
--Testcase 9:
EXPLAIN VERBOSE
INSERT INTO tbl01 VALUES (null, 4);
--Testcase 10:
INSERT INTO tbl01 VALUES (null, 4); --fail
--Testcase 11:
EXPLAIN VERBOSE
INSERT INTO tbl01 VALUES (166565, 7);
--Testcase 12:
INSERT INTO tbl01 VALUES (166565, 7); --fail, duplicate key
--Testcase 13:
CREATE FOREIGN TABLE tbl02 (id char(255)  OPTIONS (key 'true'), c1 INT, c2 float8, c3 boolean)
  SERVER :DB_SERVERNAME OPTIONS (schema :DB_SCHEMA, table 'tbl02');
--Testcase 14:
EXPLAIN VERBOSE
INSERT INTO tbl02 VALUES (repeat('a', 255), 1, 12112.12, true);
--Testcase 15:
INSERT INTO tbl02 VALUES (repeat('a', 255), 1, 12112.12, true);
--Testcase 16:
EXPLAIN VERBOSE
INSERT INTO tbl02 VALUES (NULL, 2, -12.23, false);
--Testcase 17:
INSERT INTO tbl02 VALUES (NULL, 2, -12.23, false); --fail
--Testcase 18:
EXPLAIN VERBOSE
INSERT INTO tbl02(c1) VALUES (3);
--Testcase 19:
INSERT INTO tbl02(c1) VALUES (3); --fail

--NULL test
--Testcase 75
ALTER FOREIGN TABLE tbl02 OPTIONS (SET table 'tbl02_tmp01');
--Testcase 20:
ALTER FOREIGN TABLE tbl02 ALTER COLUMN c2 SET NOT NULL;
\dS+ tbl02
--Testcase 21:
INSERT INTO tbl02(id, c2) VALUES ('b', NULL); -- fail
--Testcase 22:
SELECT * FROM tbl02; -- no result

--multiple key test
--Testcase 76
ALTER FOREIGN TABLE tbl02 OPTIONS (SET table 'tbl02_tmp02');

--Testcase 23:
ALTER FOREIGN TABLE tbl02 ALTER c1 OPTIONS (key 'true'); -- now, id and c1 are key
\dS+ tbl02
--Testcase 73
INSERT INTO tbl02(id, c1) VALUES ('a', 12112.12); -- ok
INSERT INTO tbl02(id, c1) VALUES ('a', 12112.12); -- fail
--Testcase 74
INSERT INTO tbl02(id, c1) VALUES ('a', 13113.13); -- ok
--Testcase 24:
EXPLAIN VERBOSE
SELECT * FROM tbl02;
--Testcase 25:
SELECT * FROM tbl02;

--Testcase 32:
CREATE FOREIGN TABLE tbl03 (id timestamp  OPTIONS (key 'true'), c1 int)
  SERVER :DB_SERVERNAME OPTIONS (schema :DB_SCHEMA, table 'tbl03');
--Testcase 33:
EXPLAIN VERBOSE
INSERT INTO tbl03 VALUES ('2000-01-01 00:00:00', 0);
--Testcase 34:
INSERT INTO tbl03 VALUES ('2000-01-01 00:00:00', 0);
--Testcase 35:
EXPLAIN VERBOSE
INSERT INTO tbl03 VALUES ('2000-01-01 00:00:00', 1);
--Testcase 36:
INSERT INTO tbl03 VALUES ('2000-01-01 00:00:00', 1); --fail
--WHERE clause push-down with functions in WHERE
--Testcase 37:
CREATE FOREIGN TABLE tbl04 (id INT  OPTIONS (key 'true'),  c1 float8, c2 bigint, c3 text, c4 boolean, c5 timestamp)
  SERVER :DB_SERVERNAME OPTIONS (schema :DB_SCHEMA, table 'tbl04');
--Testcase 38:
EXPLAIN VERBOSE
SELECT * FROM tbl04 WHERE abs(c1) > 3233;
--Testcase 39:
SELECT * FROM tbl04 WHERE abs(c1) > 3233;
--Testcase 40:
EXPLAIN VERBOSE
SELECT id, c1, c2 FROM tbl04 WHERE sqrt(c2) > sqrt(c1) AND c1 >= 0 AND c2 > 0;
--Testcase 41:
SELECT id, c1, c2 FROM tbl04 WHERE sqrt(c2) > sqrt(c1) AND c1 >= 0 AND c2 > 0;
--Testcase 42:
EXPLAIN VERBOSE
SELECT c1, c2 FROM tbl04 WHERE c3 || c3 != 'things thing';
--Testcase 43:
SELECT c1, c2 FROM tbl04 WHERE c3 || c3 != 'things thing';
--Testcase 44:
EXPLAIN VERBOSE
SELECT c1, id, c3 || c3 FROM tbl04 WHERE abs(c2) <> abs(c1);
--Testcase 45:
SELECT c1, id, c3 || c3 FROM tbl04 WHERE abs(c2) <> abs(c1);
--Testcase 46:
EXPLAIN VERBOSE
SELECT id + id, c2, c3 || 'afas' FROM tbl04 WHERE floor(c2) > 0;
--Testcase 47:
SELECT id + id, c2, c3 || 'afas' FROM tbl04 WHERE floor(c2) > 0;
--Testcase 48:
EXPLAIN VERBOSE
SELECT c2, c3, c4, c5 FROM tbl04 WHERE c5 > '2000-01-01';
--Testcase 49:
SELECT c2, c3, c4, c5 FROM tbl04 WHERE c5 > '2000-01-01';
--Testcase 50:
EXPLAIN VERBOSE
SELECT c5, c4, c2 FROM tbl04 WHERE c5 IN ('2000-01-01', '2010-11-01 00:00:00');
--Testcase 51:
SELECT c5, c4, c2 FROM tbl04 WHERE c5 IN ('2000-01-01', '2010-11-01 00:00:00');
--Testcase 52:
EXPLAIN VERBOSE
SELECT c3, c5, c1 FROM tbl04 WHERE c1 > ALL(SELECT id FROM tbl04 WHERE c4 = true);
--Testcase 53:
SELECT c3, c5, c1 FROM tbl04 WHERE c1 > ALL(SELECT id FROM tbl04 WHERE c4 = true);
--Testcase 54:
EXPLAIN VERBOSE
SELECT c1, c5, c3, c2 FROM tbl04 WHERE c1 = ANY (SELECT c1 FROM tbl04 WHERE c4 != false) AND c1 > 0 OR c2 < 0;
--Testcase 55:
SELECT c1, c5, c3, c2 FROM tbl04 WHERE c1 = ANY (SELECT c1 FROM tbl04 WHERE c4 != false) AND c1 > 0 OR c2 < 0;
--aggregation function push-down: add variance
--Testcase 56:
EXPLAIN VERBOSE
SELECT variance(c1), variance(c2) FROM tbl04;
--Testcase 57:
SELECT variance(c1), variance(c2) FROM tbl04;
--Testcase 58:
EXPLAIN VERBOSE
SELECT variance(c1) FROM tbl04 WHERE c3 <> 'aef';
--Testcase 59:
SELECT variance(c1) FROM tbl04 WHERE c3 <> 'aef';
--Testcase 60:
EXPLAIN VERBOSE
SELECT max(id), min(c1), variance(c2) FROM tbl04;
--Testcase 61:
SELECT max(id), min(c1), variance(c2) FROM tbl04;
--Testcase 62:
EXPLAIN VERBOSE
SELECT variance(c2), variance(c1) FROM tbl04;
--Testcase 63:
SELECT variance(c2), variance(c1) FROM tbl04;
--Testcase 64:
EXPLAIN VERBOSE
SELECT sum(c1), variance(c1) FROM tbl04 WHERE id <= 10;
--Testcase 65:
SELECT sum(c1), variance(c1) FROM tbl04 WHERE id <= 10;
--aggregation function push-down: having
--Testcase 66:
EXPLAIN VERBOSE
SELECT count(c1), sum(c2), variance(c2) FROM tbl04 HAVING (count(c1) > 0);
--Testcase 67:
SELECT count(c1), sum(c2), variance(c2) FROM tbl04 HAVING (count(c1) > 0);
--Testcase 68:
EXPLAIN VERBOSE
SELECT count(c1) + sum (c2), variance(c2)/2.12 FROM tbl04 HAVING count(c4) != 0 AND variance(c2) > 55.54;
--Testcase 69:
SELECT count(c1) + sum (c2), variance(c2)/2.12 FROM tbl04 HAVING count(c4) != 0 AND variance(c2) > 55.54;

--Testcase 70:
DROP SERVER :DB_SERVERNAME CASCADE;
--Testcase 71:
DROP EXTENSION :DB_EXTENSIONNAME CASCADE;
