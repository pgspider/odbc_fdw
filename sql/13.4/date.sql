--
-- DATE
--
--Testcase 1:
CREATE EXTENSION :DB_EXTENSIONNAME;
--Testcase 2:
CREATE SERVER :DB_SERVERNAME FOREIGN DATA WRAPPER :DB_EXTENSIONNAME
  OPTIONS (odbc_DRIVER :DB_DRIVERNAME, odbc_SERVER :DB_SERVER, odbc_port :DB_PORT, odbc_DATABASE :DB_DATABASE);
--Testcase 3:
CREATE USER MAPPING FOR public SERVER :DB_SERVERNAME OPTIONS (odbc_UID :DB_USER, odbc_PWD :DB_PASS);

--Testcase 4:
CREATE FOREIGN TABLE DATE_TBL (f1 date, id serial OPTIONS (key 'true')) SERVER :DB_SERVERNAME OPTIONS (schema :DB_SCHEMA, table 'date_tbl');

--Testcase 5:
INSERT INTO DATE_TBL VALUES ('1957-04-09');
--Testcase 6:
INSERT INTO DATE_TBL VALUES ('1957-06-13');
--Testcase 7:
INSERT INTO DATE_TBL VALUES ('1996-02-28');
--Testcase 8:
INSERT INTO DATE_TBL VALUES ('1996-02-29');
--Testcase 9:
INSERT INTO DATE_TBL VALUES ('1996-03-01');
--Testcase 10:
INSERT INTO DATE_TBL VALUES ('1996-03-02');
--Testcase 11:
INSERT INTO DATE_TBL VALUES ('1997-02-28');
--Testcase 12:
INSERT INTO DATE_TBL VALUES ('1997-02-29');
--Testcase 13:
INSERT INTO DATE_TBL VALUES ('1997-03-01');
--Testcase 14:
INSERT INTO DATE_TBL VALUES ('1997-03-02');
--Testcase 15:
INSERT INTO DATE_TBL VALUES ('2000-04-01');
--Testcase 16:
INSERT INTO DATE_TBL VALUES ('2000-04-02');
--Testcase 17:
INSERT INTO DATE_TBL VALUES ('2000-04-03');
--Testcase 18:
INSERT INTO DATE_TBL VALUES ('2038-04-08');
--Testcase 19:
INSERT INTO DATE_TBL VALUES ('2039-04-09');
--Testcase 20:
INSERT INTO DATE_TBL VALUES ('2040-04-10');

--Testcase 21:
SELECT f1 AS "Fifteen" FROM DATE_TBL;

--Testcase 22:
SELECT f1 AS "Nine" FROM DATE_TBL WHERE f1 < '2000-01-01';

--Testcase 23:
SELECT f1 AS "Three" FROM DATE_TBL
  WHERE f1 BETWEEN '2000-01-01' AND '2001-01-01';

--
-- Check all the documented input formats
--
--Testcase 24:
SET datestyle TO iso;  -- display results in ISO
--Testcase 25:
RESET datestyle;

--
-- Simple math
-- Leave most of it for the horology tests
--

--Testcase 26:
SELECT f1 - date '2000-01-01' AS "Days From 2K" FROM DATE_TBL;

--Testcase 27:
SELECT f1 - date 'epoch' AS "Days From Epoch" FROM DATE_TBL;

--
-- test extract!
--
--Testcase 28:
EXPLAIN VERBOSE
SELECT f1 as "date",
    date_part('year', f1) AS year,
    date_part('month', f1) AS month,
    date_part('day', f1) AS day,
    date_part('quarter', f1) AS quarter,
    date_part('decade', f1) AS decade,
    date_part('century', f1) AS century,
    date_part('millennium', f1) AS millennium,
    date_part('isoyear', f1) AS isoyear,
    date_part('week', f1) AS week,
    date_part('dow', f1) AS dow,
    date_part('isodow', f1) AS isodow,
    date_part('doy', f1) AS doy,
    date_part('julian', f1) AS julian,
    date_part('epoch', f1) AS epoch
    FROM date_tbl;

--Testcase 29:
SELECT f1 as "date",
    date_part('year', f1) AS year,
    date_part('month', f1) AS month,
    date_part('day', f1) AS day,
    date_part('quarter', f1) AS quarter,
    date_part('decade', f1) AS decade,
    date_part('century', f1) AS century,
    date_part('millennium', f1) AS millennium,
    date_part('isoyear', f1) AS isoyear,
    date_part('week', f1) AS week,
    date_part('dow', f1) AS dow,
    date_part('isodow', f1) AS isodow,
    date_part('doy', f1) AS doy,
    date_part('julian', f1) AS julian,
    date_part('epoch', f1) AS epoch
    FROM date_tbl;

--Testcase 30:
DROP SERVER :DB_SERVERNAME CASCADE;
--Testcase 31:
DROP EXTENSION :DB_EXTENSIONNAME CASCADE;
