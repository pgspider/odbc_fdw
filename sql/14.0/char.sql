--
-- CHAR
--
--Testcase 1:
CREATE EXTENSION :DB_EXTENSIONNAME;
--Testcase 2:
CREATE SERVER :DB_SERVERNAME FOREIGN DATA WRAPPER :DB_EXTENSIONNAME
  OPTIONS (odbc_DRIVER :DB_DRIVERNAME, odbc_SERVER :DB_SERVER, odbc_port :DB_PORT, odbc_DATABASE :DB_DATABASE);
--Testcase 3:
CREATE USER MAPPING FOR public SERVER :DB_SERVERNAME OPTIONS (odbc_UID :DB_USER, odbc_PWD :DB_PASS);  

-- fixed-length by value
-- internally passed by value if <= 4 bytes in storage
--Testcase 4:
EXPLAIN VERBOSE SELECT char 'c' = char 'c' AS true;
--Testcase 5:
SELECT char 'c' = char 'c' AS true;

--
-- Build a table for testing
--

--Testcase 6:
CREATE FOREIGN TABLE CHAR_TBL (f1 char, id serial OPTIONS (key 'true')) SERVER :DB_SERVERNAME OPTIONS (schema :DB_SCHEMA, table 'char_tbl');
--Testcase 7:
EXPLAIN VERBOSE
INSERT INTO char_tbl VALUES ('a');
--Testcase 8:
INSERT INTO char_tbl VALUES ('a');
--Testcase 9:
EXPLAIN VERBOSE
INSERT INTO char_tbl VALUES ('A');
--Testcase 10:
INSERT INTO char_tbl VALUES ('A');
-- any of the following three input formats are acceptable
--Testcase 11:
EXPLAIN VERBOSE
INSERT INTO char_tbl VALUES ('1');
--Testcase 12:
INSERT INTO char_tbl VALUES ('1');
--Testcase 13:
EXPLAIN VERBOSE
INSERT INTO char_tbl VALUES (2);
--Testcase 14:
INSERT INTO char_tbl VALUES (2);
--Testcase 15:
EXPLAIN VERBOSE
INSERT INTO char_tbl VALUES ('3');
--Testcase 16:
INSERT INTO char_tbl VALUES ('3');
-- zero-length char
--Testcase 17:
EXPLAIN VERBOSE
INSERT INTO char_tbl VALUES ('');
--Testcase 18:
INSERT INTO char_tbl VALUES ('');
-- try char's of greater than 1 length
--Testcase 19:
EXPLAIN VERBOSE
INSERT INTO char_tbl VALUES ('cd');
--Testcase 20:
INSERT INTO char_tbl VALUES ('cd');
--Testcase 21:
EXPLAIN VERBOSE
INSERT INTO char_tbl VALUES ('c     ');
--Testcase 22:
INSERT INTO char_tbl VALUES ('c     ');

--Testcase 23:
EXPLAIN VERBOSE
SELECT f1 FROM CHAR_TBL;
--Testcase 24:
SELECT f1 FROM CHAR_TBL;
--Testcase 25:
EXPLAIN VERBOSE
SELECT c.f1
   FROM CHAR_TBL c
   WHERE c.f1 <> 'a';
--Testcase 26:
SELECT c.f1
   FROM CHAR_TBL c
   WHERE c.f1 <> 'a';
--Testcase 27:
EXPLAIN VERBOSE
SELECT c.f1
   FROM CHAR_TBL c
   WHERE c.f1 = 'a';
--Testcase 28:
SELECT c.f1
   FROM CHAR_TBL c
   WHERE c.f1 = 'a';
--Testcase 29:
EXPLAIN VERBOSE
SELECT c.f1
   FROM CHAR_TBL c
   WHERE c.f1 < 'a';
--Testcase 30:
SELECT c.f1
   FROM CHAR_TBL c
   WHERE c.f1 < 'a';
--Testcase 31:
EXPLAIN VERBOSE
SELECT c.f1
   FROM CHAR_TBL c
   WHERE c.f1 <= 'a';
--Testcase 32:
SELECT c.f1
   FROM CHAR_TBL c
   WHERE c.f1 <= 'a';
--Testcase 33:
EXPLAIN VERBOSE
SELECT c.f1
   FROM CHAR_TBL c
   WHERE c.f1 > 'a';
--Testcase 34:
SELECT c.f1
   FROM CHAR_TBL c
   WHERE c.f1 > 'a';
--Testcase 35:
EXPLAIN VERBOSE
SELECT c.f1
   FROM CHAR_TBL c
   WHERE c.f1 >= 'a';
--Testcase 36:
SELECT c.f1
   FROM CHAR_TBL c
   WHERE c.f1 >= 'a';
--Testcase 37:
DROP FOREIGN TABLE CHAR_TBL;

--
-- Now test longer arrays of char
--

--Testcase 38:
CREATE FOREIGN TABLE CHAR_TBL(f1 char(4), id serial OPTIONS (key 'true')) SERVER :DB_SERVERNAME OPTIONS (schema :DB_SCHEMA, table 'char_tbl_2');
--Testcase 39:
EXPLAIN VERBOSE
INSERT INTO CHAR_TBL VALUES ('a');
--Testcase 40:
INSERT INTO CHAR_TBL VALUES ('a');
--Testcase 41:
EXPLAIN VERBOSE
INSERT INTO CHAR_TBL VALUES ('ab');
--Testcase 42:
INSERT INTO CHAR_TBL VALUES ('ab');
--Testcase 43:
EXPLAIN VERBOSE
INSERT INTO CHAR_TBL VALUES ('abcd');
--Testcase 44:
INSERT INTO CHAR_TBL VALUES ('abcd');
--Testcase 45:
EXPLAIN VERBOSE
INSERT INTO CHAR_TBL VALUES ('abcde');
--Testcase 46:
INSERT INTO CHAR_TBL VALUES ('abcde');
--Testcase 47:
EXPLAIN VERBOSE
INSERT INTO CHAR_TBL VALUES ('abcd    ');
--Testcase 48:
INSERT INTO CHAR_TBL VALUES ('abcd    ');
--Testcase 49:
EXPLAIN VERBOSE SELECT f1 FROM CHAR_TBL;
--Testcase 50:
SELECT f1 FROM CHAR_TBL;

--Testcase 51:
DROP SERVER :DB_SERVERNAME CASCADE;
--Testcase 52:
DROP EXTENSION :DB_EXTENSIONNAME CASCADE;
