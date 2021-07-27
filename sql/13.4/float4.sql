--Testcase 1:
CREATE EXTENSION IF NOT EXISTS :DB_EXTENSIONNAME;
--Testcase 2:
CREATE SERVER :DB_SERVERNAME FOREIGN DATA WRAPPER :DB_EXTENSIONNAME OPTIONS(
		odbc_DRIVER :DB_DRIVERNAME,
		odbc_SERVER :DB_SERVER,
		odbc_PORT :DB_PORT,
		odbc_DATABASE :DB_DATABASE
);
--Testcase 3:
CREATE USER MAPPING FOR public SERVER :DB_SERVERNAME OPTIONS(odbc_UID :DB_USER, odbc_PWD :DB_PASS);

--Testcase 4:
CREATE FOREIGN TABLE FLOAT4_TBL(f1 float4, id serial OPTIONS (key 'true'))
   SERVER :DB_SERVERNAME OPTIONS (schema :DB_SCHEMA, table 'float4_tbl');

--Testcase 5:
DELETE FROM FLOAT4_TBL;

--Testcase 6:
INSERT INTO FLOAT4_TBL(f1) VALUES ('    0.0');
--Testcase 7:
INSERT INTO FLOAT4_TBL(f1) VALUES ('1004.30   ');
--Testcase 8:
INSERT INTO FLOAT4_TBL(f1) VALUES ('     -34.84    ');
--Testcase 9:
INSERT INTO FLOAT4_TBL(f1) VALUES ('1.2345678901234e+20');
--Testcase 10:
INSERT INTO FLOAT4_TBL(f1) VALUES ('1.2345678901234e-20');

-- test for over and under flow
--Testcase 11:
INSERT INTO FLOAT4_TBL(f1) VALUES ('10e70');
--Testcase 12:
INSERT INTO FLOAT4_TBL(f1) VALUES ('-10e70');
--Testcase 13:
INSERT INTO FLOAT4_TBL(f1) VALUES ('10e-70');
--Testcase 14:
INSERT INTO FLOAT4_TBL(f1) VALUES ('-10e-70');

--Testcase 15:
INSERT INTO FLOAT4_TBL(f1) VALUES ('10e70'::float8);
--Testcase 16:
INSERT INTO FLOAT4_TBL(f1) VALUES ('-10e70'::float8);
--Testcase 17:
INSERT INTO FLOAT4_TBL(f1) VALUES ('10e-70'::float8);
--Testcase 18:
INSERT INTO FLOAT4_TBL(f1) VALUES ('-10e-70'::float8);
--Testcase 19:
INSERT INTO FLOAT4_TBL(f1) VALUES ('10e400');
--Testcase 20:
INSERT INTO FLOAT4_TBL(f1) VALUES ('-10e400');
--Testcase 21:
INSERT INTO FLOAT4_TBL(f1) VALUES ('10e-400');
--Testcase 22:
INSERT INTO FLOAT4_TBL(f1) VALUES ('-10e-400');

-- bad input
--Testcase 23:
INSERT INTO FLOAT4_TBL(f1) VALUES ('');
--Testcase 24:
INSERT INTO FLOAT4_TBL(f1) VALUES ('       ');
--Testcase 25:
INSERT INTO FLOAT4_TBL(f1) VALUES ('xyz');
--Testcase 26:
INSERT INTO FLOAT4_TBL(f1) VALUES ('5.0.0');
--Testcase 27:
INSERT INTO FLOAT4_TBL(f1) VALUES ('5 . 0');
--Testcase 28:
INSERT INTO FLOAT4_TBL(f1) VALUES ('5.   0');
--Testcase 29:
INSERT INTO FLOAT4_TBL(f1) VALUES ('     - 3.0');
--Testcase 30:
INSERT INTO FLOAT4_TBL(f1) VALUES ('123            5');

-- special inputs
--
--Testcase 31:
ALTER FOREIGN TABLE FLOAT4_TBL OPTIONS (SET table 'float4_tbl_tmp');
--Testcase 32:
INSERT INTO FLOAT4_TBL(f1) VALUES ('NaN'::float4);
--Testcase 33:
SELECT f1 AS float4 FROM FLOAT4_TBL;
--Testcase 34:
DELETE FROM FLOAT4_TBL;
--Testcase 35:
INSERT INTO FLOAT4_TBL(f1) VALUES ('nan'::float4);
--Testcase 36:
SELECT f1 AS float4 FROM FLOAT4_TBL;
--Testcase 37:
DELETE FROM FLOAT4_TBL;
--Testcase 38:
INSERT INTO FLOAT4_TBL(f1) VALUES ('   NAN  '::float4);
--Testcase 39:
SELECT f1 AS float4 FROM FLOAT4_TBL;
--Testcase 40:
DELETE FROM FLOAT4_TBL;
--Testcase 41:
INSERT INTO FLOAT4_TBL(f1) VALUES ('infinity'::float4);
--Testcase 42:
SELECT f1 AS float4 FROM FLOAT4_TBL;
--Testcase 43:
DELETE FROM FLOAT4_TBL;
--Testcase 44:
INSERT INTO FLOAT4_TBL(f1) VALUES ('          -INFINiTY   '::float4);
--Testcase 45:
SELECT f1 AS float4 FROM FLOAT4_TBL;
-- bad special inputs
--Testcase 46:
INSERT INTO FLOAT4_TBL(f1) VALUES ('N A N'::float4);
--Testcase 47:
INSERT INTO FLOAT4_TBL(f1) VALUES ('NaN x'::float4);
--Testcase 48:
INSERT INTO FLOAT4_TBL(f1) VALUES (' INFINITY    x'::float4);

--
--Testcase 49:
DELETE FROM FLOAT4_TBL;
--Testcase 50:
INSERT INTO FLOAT4_TBL(f1) VALUES ('Infinity'::float4);
--Testcase 51:
SELECT (f1::float4 + 100.0) AS float4 FROM FLOAT4_TBL;
--
--Testcase 52:
DELETE FROM FLOAT4_TBL;
--Testcase 53:
INSERT INTO FLOAT4_TBL(f1) VALUES ('Infinity'::float4);
--Testcase 54:
SELECT (f1::float4 / 'Infinity'::float4) AS float4 FROM FLOAT4_TBL;
--
--Testcase 55:
DELETE FROM FLOAT4_TBL;
--Testcase 56:
INSERT INTO FLOAT4_TBL(f1) VALUES ('nan'::float4);
--Testcase 57:
SELECT (f1::float4 / 'nan'::float4) AS float4 FROM FLOAT4_TBL;
--
--Testcase 58:
DELETE FROM FLOAT4_TBL;
--Testcase 59:
INSERT INTO FLOAT4_TBL(f1) VALUES ('nan'::numeric);
--Testcase 60:
SELECT (f1::float4) AS float4 FROM FLOAT4_TBL;
--

--Testcase 61:
ALTER FOREIGN TABLE FLOAT4_TBL OPTIONS (SET table 'float4_tbl');
--Testcase 62:
SELECT '' AS five, f1 FROM FLOAT4_TBL;
--Testcase 63:
SELECT '' AS four, f1 FROM FLOAT4_TBL f WHERE f.f1 <> '1004.3';
--Testcase 64:
SELECT '' AS one, f1 FROM FLOAT4_TBL f WHERE f.f1 = '1004.3';
--Testcase 65:
SELECT '' AS three, f1 FROM FLOAT4_TBL f WHERE '1004.3' > f.f1;
--Testcase 66:
SELECT '' AS three, f1 FROM FLOAT4_TBL f WHERE  f.f1 < '1004.3';

--Testcase 67:
SELECT '' AS four, f.f1 FROM FLOAT4_TBL f WHERE '1004.3' >= f.f1;

--Testcase 68:
SELECT '' AS four, f.f1 FROM FLOAT4_TBL f WHERE  f.f1 <= '1004.3';

--Testcase 69:
SELECT '' AS three, f.f1, f.f1 * '-10' AS x FROM FLOAT4_TBL f
   WHERE f.f1 > '0.0';

--Testcase 70:
SELECT '' AS three, f.f1, f.f1 + '-10' AS x FROM FLOAT4_TBL f
   WHERE f.f1 > '0.0';

--Testcase 71:
SELECT '' AS three, f.f1, f.f1 / '-10' AS x FROM FLOAT4_TBL f
   WHERE f.f1 > '0.0';

--Testcase 72:
SELECT '' AS three, f.f1, f.f1 - '-10' AS x FROM FLOAT4_TBL f
   WHERE f.f1 > '0.0';

-- test divide by zero
--Testcase 73:
SELECT '' AS bad, f.f1 / '0.0' from FLOAT4_TBL f;

--Testcase 74:
SELECT '' AS five, f1 FROM FLOAT4_TBL;

-- test the unary float4abs operator
--Testcase 75:
SELECT '' AS five, f.f1, @f.f1 AS abs_f1 FROM FLOAT4_TBL f;

--Testcase 76:
UPDATE FLOAT4_TBL
   SET f1 = FLOAT4_TBL.f1 * '-1'
   WHERE FLOAT4_TBL.f1 > '0.0';

--Testcase 77:
SELECT '' AS five, f1 FROM FLOAT4_TBL;

-- test edge-case coercions to integer
--
--Testcase 78:
ALTER FOREIGN TABLE FLOAT4_TBL OPTIONS (SET table 'float4_tbl_tmp');
--Testcase 79:
DELETE FROM FLOAT4_TBL;
--Testcase 80:
INSERT INTO FLOAT4_TBL(f1) VALUES ('32767.4'::float4);
--Testcase 81:
SELECT f1::int2 as int2 FROM FLOAT4_TBL;
--
--Testcase 82:
DELETE FROM FLOAT4_TBL;
--Testcase 83:
INSERT INTO FLOAT4_TBL(f1) VALUES ('32767.6'::float4);
--Testcase 84:
SELECT f1::int2 FROM FLOAT4_TBL;
--
--Testcase 85:
DELETE FROM FLOAT4_TBL;
--Testcase 86:
INSERT INTO FLOAT4_TBL(f1) VALUES ('-32768.4'::float4);
--Testcase 87:
SELECT f1::int2 as int2 FROM FLOAT4_TBL;
--
--Testcase 88:
DELETE FROM FLOAT4_TBL;
--Testcase 89:
INSERT INTO FLOAT4_TBL(f1) VALUES ('-32768.6'::float4);
--Testcase 90:
SELECT f1::int2 FROM FLOAT4_TBL;
--
--Testcase 91:
DELETE FROM FLOAT4_TBL;
--Testcase 92:
INSERT INTO FLOAT4_TBL(f1) VALUES ('2147483520'::float4);
--Testcase 93:
SELECT f1::int4 FROM FLOAT4_TBL;
--
--Testcase 94:
DELETE FROM FLOAT4_TBL;
--Testcase 95:
INSERT INTO FLOAT4_TBL(f1) VALUES ('2147483647'::float4);
--Testcase 96:
SELECT f1::int4 FROM FLOAT4_TBL;
--
--Testcase 97:
DELETE FROM FLOAT4_TBL;
--Testcase 98:
INSERT INTO FLOAT4_TBL(f1) VALUES ('-2147483648.5'::float4);
--Testcase 99:
SELECT f1::int4  as int4 FROM FLOAT4_TBL;
--
--Testcase 100:
DELETE FROM FLOAT4_TBL;
--Testcase 101:
INSERT INTO FLOAT4_TBL(f1) VALUES ('-2147483900'::float4);
--Testcase 102:
SELECT f1::int4 FROM FLOAT4_TBL;
--
--Testcase 103:
DELETE FROM FLOAT4_TBL;
--Testcase 104:
INSERT INTO FLOAT4_TBL(f1) VALUES ('9223369837831520256'::float4);
--Testcase 105:
SELECT f1::int8 as int8 FROM FLOAT4_TBL;
--
--Testcase 106:
DELETE FROM FLOAT4_TBL;
--Testcase 107:
INSERT INTO FLOAT4_TBL(f1) VALUES ('9223372036854775807'::float4);
--Testcase 108:
SELECT f1::int8 FROM FLOAT4_TBL;
--
--Testcase 109:
DELETE FROM FLOAT4_TBL;
--Testcase 110:
INSERT INTO FLOAT4_TBL(f1) VALUES ('-9223372036854775808.5'::float4);
--Testcase 111:
SELECT f1::int8 as int8 FROM FLOAT4_TBL;
--
--Testcase 112:
DELETE FROM FLOAT4_TBL;
--Testcase 113:
INSERT INTO FLOAT4_TBL(f1) VALUES ('-9223380000000000000'::float4);
--Testcase 114:
SELECT f1::int8 FROM FLOAT4_TBL;

-- Test for correct input rounding in edge cases.
-- These lists are from Paxson 1991, excluding subnormals and
-- inputs of over 9 sig. digits.
--Testcase 115:
DELETE FROM FLOAT4_TBL;
--Testcase 116:
INSERT INTO FLOAT4_TBL(f1) VALUES ('5e-20'::float4);
--Testcase 117:
INSERT INTO FLOAT4_TBL(f1) VALUES ('67e14'::float4);
--Testcase 118:
INSERT INTO FLOAT4_TBL(f1) VALUES ('985e15'::float4);
--Testcase 119:
INSERT INTO FLOAT4_TBL(f1) VALUES ('55895e-16'::float4);
--Testcase 120:
INSERT INTO FLOAT4_TBL(f1) VALUES ('7038531e-32'::float4);
--Testcase 121:
INSERT INTO FLOAT4_TBL(f1) VALUES ('702990899e-20'::float4);

--Testcase 122:
INSERT INTO FLOAT4_TBL(f1) VALUES ('3e-23'::float4);
--Testcase 123:
INSERT INTO FLOAT4_TBL(f1) VALUES ('57e18'::float4);
--Testcase 124:
INSERT INTO FLOAT4_TBL(f1) VALUES ('789e-35'::float4);
--Testcase 125:
INSERT INTO FLOAT4_TBL(f1) VALUES ('2539e-18'::float4);
--Testcase 126:
INSERT INTO FLOAT4_TBL(f1) VALUES ('76173e28'::float4);
--Testcase 127:
INSERT INTO FLOAT4_TBL(f1) VALUES ('887745e-11'::float4);
--Testcase 128:
INSERT INTO FLOAT4_TBL(f1) VALUES ('5382571e-37'::float4);
--Testcase 129:
INSERT INTO FLOAT4_TBL(f1) VALUES ('82381273e-35'::float4);
--Testcase 130:
INSERT INTO FLOAT4_TBL(f1) VALUES ('750486563e-38'::float4);
--Testcase 131:
SELECT float4send(f1) FROM FLOAT4_TBL;

-- Test that the smallest possible normalized input value inputs
-- correctly, either in 9-significant-digit or shortest-decimal
-- format.
--
-- exact val is             1.1754943508...
-- shortest val is          1.1754944000
-- midpoint to next val is  1.1754944208...

--Testcase 132:
DELETE FROM FLOAT4_TBL;
--Testcase 133:
INSERT INTO FLOAT4_TBL(f1) VALUES ('1.17549435e-38'::float4);
--Testcase 134:
INSERT INTO FLOAT4_TBL(f1) VALUES ('1.1754944e-38'::float4);
--Testcase 135:
SELECT float4send(f1) FROM FLOAT4_TBL;
-- test output (and round-trip safety) of various values.
-- To ensure we're testing what we think we're testing, start with
-- float values specified by bit patterns (as a useful side effect,
-- this means we'll fail on non-IEEE platforms).

--Testcase 136:
DROP FOREIGN TABLE FLOAT4_TBL;
--Testcase 137:
DROP SERVER :DB_SERVERNAME CASCADE;
--Testcase 138:
DROP EXTENSION :DB_EXTENSIONNAME CASCADE;
