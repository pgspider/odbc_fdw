--
-- TIMESTAMP
--
--Testcase 1:
CREATE EXTENSION :DB_EXTENSIONNAME;
--Testcase 2:
CREATE SERVER :DB_SERVERNAME FOREIGN DATA WRAPPER :DB_EXTENSIONNAME
  OPTIONS (odbc_DRIVER :DB_DRIVERNAME, odbc_SERVER :DB_SERVER, odbc_port :DB_PORT, odbc_DATABASE :DB_DATABASE);
--Testcase 3:
CREATE USER MAPPING FOR public SERVER :DB_SERVERNAME OPTIONS (odbc_UID :DB_USER, odbc_PWD :DB_PASS);

--Testcase 4:
CREATE FOREIGN TABLE TIMESTAMP_TBL (id int OPTIONS (key 'true'), d1 timestamp(2) without time zone) SERVER :DB_SERVERNAME OPTIONS (schema :DB_SCHEMA, table 'timestamp_tbl');

-- Test shorthand input values
-- We can't just "select" the results since they aren't constants; test for
-- equality instead.  We can do that by running the test inside a transaction
-- block, within which the value of 'now' shouldn't change, and so these
-- related values shouldn't either.

BEGIN;

--Testcase 5:
INSERT INTO TIMESTAMP_TBL VALUES (1, 'today');
--Testcase 6:
INSERT INTO TIMESTAMP_TBL VALUES (2, 'yesterday');
--Testcase 7:
INSERT INTO TIMESTAMP_TBL VALUES (3, 'tomorrow');
-- time zone should be ignored by this data type
--Testcase 8:
INSERT INTO TIMESTAMP_TBL VALUES (4, 'tomorrow EST');
--Testcase 9:
INSERT INTO TIMESTAMP_TBL VALUES (5, 'tomorrow zulu');

--Testcase 10:
SELECT count(*) AS One FROM TIMESTAMP_TBL WHERE d1 = timestamp without time zone 'today';
--Testcase 11:
SELECT count(*) AS Three FROM TIMESTAMP_TBL WHERE d1 = timestamp without time zone 'tomorrow';
--Testcase 12:
SELECT count(*) AS One FROM TIMESTAMP_TBL WHERE d1 = timestamp without time zone 'yesterday';

COMMIT;

--Testcase 13:
DELETE FROM TIMESTAMP_TBL;

-- Verify that 'now' *does* change over a reasonable interval such as 100 msec,
-- and that it doesn't change over the same interval within a transaction block

--Testcase 14:
INSERT INTO TIMESTAMP_TBL VALUES (1, 'now');
--Testcase 15:
SELECT pg_sleep(0.1);

BEGIN;
--Testcase 16:
INSERT INTO TIMESTAMP_TBL VALUES (2, 'now');
--Testcase 17:
SELECT pg_sleep(0.1);
--Testcase 18:
INSERT INTO TIMESTAMP_TBL VALUES (3, 'now');
--Testcase 19:
SELECT pg_sleep(0.1);
--Testcase 20:
SELECT count(*) AS two FROM TIMESTAMP_TBL WHERE d1 = timestamp(2) without time zone 'now';
--Testcase 21:
SELECT count(d1) AS three, count(DISTINCT d1) AS two FROM TIMESTAMP_TBL;
COMMIT;

--TRUNCATE TIMESTAMP_TBL; --does not support TRUNCATE
DELETE FROM TIMESTAMP_TBL;

-- Special values
--Testcase 22:
INSERT INTO TIMESTAMP_TBL VALUES (4, '-infinity');
--Testcase 23:
INSERT INTO TIMESTAMP_TBL VALUES (5, 'infinity');
--Testcase 24:
INSERT INTO TIMESTAMP_TBL VALUES (6, 'epoch');

-- Postgres v6.0 standard output format
--Testcase 25:
INSERT INTO TIMESTAMP_TBL VALUES (7, 'Mon Feb 10 17:32:01 1997 PST');

-- Variations on Postgres v6.1 standard output format
--Testcase 26:
INSERT INTO TIMESTAMP_TBL VALUES (8, 'Mon Feb 10 17:32:01.000001 1997 PST');
--Testcase 27:
INSERT INTO TIMESTAMP_TBL VALUES (9, 'Mon Feb 10 17:32:01.999999 1997 PST');
--Testcase 28:
INSERT INTO TIMESTAMP_TBL VALUES (10, 'Mon Feb 10 17:32:01.4 1997 PST');
--Testcase 29:
INSERT INTO TIMESTAMP_TBL VALUES (11, 'Mon Feb 10 17:32:01.5 1997 PST');
--Testcase 30:
INSERT INTO TIMESTAMP_TBL VALUES (12, 'Mon Feb 10 17:32:01.6 1997 PST');

-- ISO 8601 format
--Testcase 31:
INSERT INTO TIMESTAMP_TBL VALUES (13, '1997-01-02');
--Testcase 32:
INSERT INTO TIMESTAMP_TBL VALUES (14, '1997-01-02 03:04:05');
--Testcase 33:
INSERT INTO TIMESTAMP_TBL VALUES (15, '1997-02-10 17:32:01-08');
--Testcase 34:
INSERT INTO TIMESTAMP_TBL VALUES (16, '1997-02-10 17:32:01-0800');
--Testcase 35:
INSERT INTO TIMESTAMP_TBL VALUES (17, '1997-02-10 17:32:01 -08:00');
--Testcase 36:
INSERT INTO TIMESTAMP_TBL VALUES (18, '19970210 173201 -0800');
--Testcase 37:
INSERT INTO TIMESTAMP_TBL VALUES (19, '1997-06-10 17:32:01 -07:00');
--Testcase 38:
INSERT INTO TIMESTAMP_TBL VALUES (20, '2001-09-22T18:19:20');

-- POSIX format (note that the timezone abbrev is just decoration here)
--Testcase 39:
INSERT INTO TIMESTAMP_TBL VALUES (21, '2000-03-15 08:14:01 GMT+8');
--Testcase 40:
INSERT INTO TIMESTAMP_TBL VALUES (22, '2000-03-15 13:14:02 GMT-1');
--Testcase 41:
INSERT INTO TIMESTAMP_TBL VALUES (23, '2000-03-15 12:14:03 GMT-2');
--Testcase 42:
INSERT INTO TIMESTAMP_TBL VALUES (24, '2000-03-15 03:14:04 PST+8');
--Testcase 43:
INSERT INTO TIMESTAMP_TBL VALUES (25, '2000-03-15 02:14:05 MST+7:00');

-- Variations for acceptable input formats
--Testcase 44:
INSERT INTO TIMESTAMP_TBL VALUES (26, 'Feb 10 17:32:01 1997 -0800');
--Testcase 45:
INSERT INTO TIMESTAMP_TBL VALUES (27, 'Feb 10 17:32:01 1997');
--Testcase 46:
INSERT INTO TIMESTAMP_TBL VALUES (28, 'Feb 10 5:32PM 1997');
--Testcase 47:
INSERT INTO TIMESTAMP_TBL VALUES (29, '1997/02/10 17:32:01-0800');
--Testcase 48:
INSERT INTO TIMESTAMP_TBL VALUES (30, '1997-02-10 17:32:01 PST');
--Testcase 49:
INSERT INTO TIMESTAMP_TBL VALUES (31, 'Feb-10-1997 17:32:01 PST');
--Testcase 50:
INSERT INTO TIMESTAMP_TBL VALUES (32, '02-10-1997 17:32:01 PST');
--Testcase 51:
INSERT INTO TIMESTAMP_TBL VALUES (33, '19970210 173201 PST');
--Testcase 52:
set datestyle to ymd;
--Testcase 53:
INSERT INTO TIMESTAMP_TBL VALUES (34, '97FEB10 5:32:01PM UTC');
--Testcase 54:
INSERT INTO TIMESTAMP_TBL VALUES (35, '97/02/10 17:32:01 UTC');
--Testcase 55:
reset datestyle;
--Testcase 56:
INSERT INTO TIMESTAMP_TBL VALUES (36, '1997.041 17:32:01 UTC');
--Testcase 57:
INSERT INTO TIMESTAMP_TBL VALUES (37, '19970210 173201 America/New_York');
-- this fails (even though TZ is a no-op, we still look it up)
--Testcase 58:
INSERT INTO TIMESTAMP_TBL VALUES (38, '19970710 173201 America/Does_not_exist');

-- Check date conversion and date arithmetic
--Testcase 59:
INSERT INTO TIMESTAMP_TBL VALUES (39, '1997-06-10 18:32:01 PDT');

--Testcase 60:
INSERT INTO TIMESTAMP_TBL VALUES (40, 'Feb 10 17:32:01 1997');
--Testcase 61:
INSERT INTO TIMESTAMP_TBL VALUES (41, 'Feb 11 17:32:01 1997');
--Testcase 62:
INSERT INTO TIMESTAMP_TBL VALUES (42, 'Feb 12 17:32:01 1997');
--Testcase 63:
INSERT INTO TIMESTAMP_TBL VALUES (43, 'Feb 13 17:32:01 1997');
--Testcase 64:
INSERT INTO TIMESTAMP_TBL VALUES (44, 'Feb 14 17:32:01 1997');
--Testcase 65:
INSERT INTO TIMESTAMP_TBL VALUES (45, 'Feb 15 17:32:01 1997');
--Testcase 66:
INSERT INTO TIMESTAMP_TBL VALUES (46, 'Feb 16 17:32:01 1997');

--Testcase 67:
INSERT INTO TIMESTAMP_TBL VALUES (47, 'Feb 16 17:32:01 0097 BC');
--Testcase 68:
INSERT INTO TIMESTAMP_TBL VALUES (48, 'Feb 16 17:32:01 0097');
--Testcase 69:
INSERT INTO TIMESTAMP_TBL VALUES (49, 'Feb 16 17:32:01 0597');
--Testcase 70:
INSERT INTO TIMESTAMP_TBL VALUES (50, 'Feb 16 17:32:01 1097');
--Testcase 71:
INSERT INTO TIMESTAMP_TBL VALUES (51, 'Feb 16 17:32:01 1697');
--Testcase 72:
INSERT INTO TIMESTAMP_TBL VALUES (52, 'Feb 16 17:32:01 1797');
--Testcase 73:
INSERT INTO TIMESTAMP_TBL VALUES (53, 'Feb 16 17:32:01 1897');
--Testcase 74:
INSERT INTO TIMESTAMP_TBL VALUES (54, 'Feb 16 17:32:01 1997');
--Testcase 75:
INSERT INTO TIMESTAMP_TBL VALUES (55, 'Feb 16 17:32:01 2097');

--Testcase 76:
INSERT INTO TIMESTAMP_TBL VALUES (56, 'Feb 28 17:32:01 1996');
--Testcase 77:
INSERT INTO TIMESTAMP_TBL VALUES (57, 'Feb 29 17:32:01 1996');
--Testcase 78:
INSERT INTO TIMESTAMP_TBL VALUES (58, 'Mar 01 17:32:01 1996');
--Testcase 79:
INSERT INTO TIMESTAMP_TBL VALUES (59, 'Dec 30 17:32:01 1996');
--Testcase 80:
INSERT INTO TIMESTAMP_TBL VALUES (60, 'Dec 31 17:32:01 1996');
--Testcase 81:
INSERT INTO TIMESTAMP_TBL VALUES (61, 'Jan 01 17:32:01 1997');
--Testcase 82:
INSERT INTO TIMESTAMP_TBL VALUES (62, 'Feb 28 17:32:01 1997');
--Testcase 83:
INSERT INTO TIMESTAMP_TBL VALUES (63, 'Feb 29 17:32:01 1997');
--Testcase 84:
INSERT INTO TIMESTAMP_TBL VALUES (64, 'Mar 01 17:32:01 1997');
--Testcase 85:
INSERT INTO TIMESTAMP_TBL VALUES (65, 'Dec 30 17:32:01 1997');
--Testcase 86:
INSERT INTO TIMESTAMP_TBL VALUES (66, 'Dec 31 17:32:01 1997');
--Testcase 87:
INSERT INTO TIMESTAMP_TBL VALUES (67, 'Dec 31 17:32:01 1999');
--Testcase 88:
INSERT INTO TIMESTAMP_TBL VALUES (68, 'Jan 01 17:32:01 2000');
--Testcase 89:
INSERT INTO TIMESTAMP_TBL VALUES (69, 'Dec 31 17:32:01 2000');
--Testcase 90:
INSERT INTO TIMESTAMP_TBL VALUES (70, 'Jan 01 17:32:01 2001');

-- Currently unsupported syntax and ranges
--Testcase 91:
INSERT INTO TIMESTAMP_TBL VALUES (71, 'Feb 16 17:32:01 -0097');
--Testcase 92:
INSERT INTO TIMESTAMP_TBL VALUES (72, 'Feb 16 17:32:01 5097 BC');

--Testcase 93:
SELECT d1 FROM TIMESTAMP_TBL;

-- Demonstrate functions and operators
--Testcase 94:
SELECT d1 FROM TIMESTAMP_TBL
   WHERE d1 > timestamp without time zone '1997-01-02';

--Testcase 95:
SELECT d1 FROM TIMESTAMP_TBL
   WHERE d1 < timestamp without time zone '1997-01-02';

--Testcase 96:
SELECT d1 FROM TIMESTAMP_TBL
   WHERE d1 = timestamp without time zone '1997-01-02';

--Testcase 97:
SELECT d1 FROM TIMESTAMP_TBL
   WHERE d1 != timestamp without time zone '1997-01-02';

--Testcase 98:
SELECT d1 FROM TIMESTAMP_TBL
   WHERE d1 <= timestamp without time zone '1997-01-02';

--Testcase 99:
SELECT d1 FROM TIMESTAMP_TBL
   WHERE d1 >= timestamp without time zone '1997-01-02';

--Testcase 100:
SELECT d1 - timestamp without time zone '1997-01-02' AS diff
   FROM TIMESTAMP_TBL WHERE d1 BETWEEN '1902-01-01' AND '2038-01-01';

-- Test casting within a BETWEEN qualifier
--Testcase 101:
SELECT d1 - timestamp without time zone '1997-01-02' AS diff
  FROM TIMESTAMP_TBL
  WHERE d1 BETWEEN timestamp without time zone '1902-01-01'
   AND timestamp without time zone '2038-01-01';

-- DATE_PART (timestamp_part)
--Testcase 102:
SELECT d1 as "timestamp",
   date_part( 'year', d1) AS year, date_part( 'month', d1) AS month,
   date_part( 'day', d1) AS day, date_part( 'hour', d1) AS hour,
   date_part( 'minute', d1) AS minute, date_part( 'second', d1) AS second
   FROM TIMESTAMP_TBL;

--Testcase 103:
SELECT d1 as "timestamp",
   date_part( 'quarter', d1) AS quarter, date_part( 'msec', d1) AS msec,
   date_part( 'usec', d1) AS usec
   FROM TIMESTAMP_TBL;

--Testcase 104:
SELECT d1 as "timestamp",
   date_part( 'isoyear', d1) AS isoyear, date_part( 'week', d1) AS week,
   date_part( 'isodow', d1) AS isodow, date_part( 'dow', d1) AS dow,
   date_part( 'doy', d1) AS doy
   FROM TIMESTAMP_TBL;

--Testcase 105:
SELECT d1 as "timestamp",
   date_part( 'decade', d1) AS decade,
   date_part( 'century', d1) AS century,
   date_part( 'millennium', d1) AS millennium,
   round(date_part( 'julian', d1)) AS julian,
   date_part( 'epoch', d1) AS epoch
   FROM TIMESTAMP_TBL;

-- extract implementation is mostly the same as date_part, so only
-- test a few cases for additional coverage.
--Testcase 106:
SELECT d1 as "timestamp",
   extract(microseconds from d1) AS microseconds,
   extract(milliseconds from d1) AS milliseconds,
   extract(seconds from d1) AS seconds,
   round(extract(julian from d1)) AS julian,
   extract(epoch from d1) AS epoch
   FROM TIMESTAMP_TBL;

-- TO_CHAR()
--Testcase 107:
SELECT to_char(d1, 'DAY Day day DY Dy dy MONTH Month month RM MON Mon mon')
   FROM TIMESTAMP_TBL;

--Testcase 108:
SELECT to_char(d1, 'FMDAY FMDay FMday FMMONTH FMMonth FMmonth FMRM')
   FROM TIMESTAMP_TBL;

--Testcase 109:
SELECT to_char(d1, 'Y,YYY YYYY YYY YY Y CC Q MM WW DDD DD D J')
   FROM TIMESTAMP_TBL;

--Testcase 110:
SELECT to_char(d1, 'FMY,YYY FMYYYY FMYYY FMYY FMY FMCC FMQ FMMM FMWW FMDDD FMDD FMD FMJ')
   FROM TIMESTAMP_TBL;

--Testcase 111:
SELECT to_char(d1, 'HH HH12 HH24 MI SS SSSS')
   FROM TIMESTAMP_TBL;

--Testcase 112:
SELECT to_char(d1, E'"HH:MI:SS is" HH:MI:SS "\\"text between quote marks\\""')
   FROM TIMESTAMP_TBL;

--Testcase 113:
SELECT to_char(d1, 'HH24--text--MI--text--SS')
   FROM TIMESTAMP_TBL;

--Testcase 114:
SELECT to_char(d1, 'YYYYTH YYYYth Jth')
   FROM TIMESTAMP_TBL;

--Testcase 115:
SELECT to_char(d1, 'YYYY A.D. YYYY a.d. YYYY bc HH:MI:SS P.M. HH:MI:SS p.m. HH:MI:SS pm')
   FROM TIMESTAMP_TBL;

--Testcase 116:
SELECT to_char(d1, 'IYYY IYY IY I IW IDDD ID')
   FROM TIMESTAMP_TBL;

--Testcase 117:
SELECT to_char(d1, 'FMIYYY FMIYY FMIY FMI FMIW FMIDDD FMID')
   FROM TIMESTAMP_TBL;

--Testcase 118:
DROP SERVER :DB_SERVERNAME CASCADE;
--Testcase 119:
DROP EXTENSION :DB_EXTENSIONNAME CASCADE;
