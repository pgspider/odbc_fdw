--Testcase 1:
CREATE EXTENSION IF NOT EXISTS :DB_EXTENSIONNAME;
--Testcase 2:
CREATE SERVER :DB_SERVERNAME FOREIGN DATA WRAPPER :DB_EXTENSIONNAME
            OPTIONS (odbc_DRIVER :DB_DRIVERNAME,
                    odbc_SERVER :DB_SERVER,
					odbc_PORT :DB_PORT,
					odbc_DATABASE :DB_DATABASE
			);
--Testcase 3:
CREATE USER MAPPING FOR public SERVER :DB_SERVERNAME OPTIONS(odbc_UID :DB_USER, odbc_PWD :DB_PASS);

-- Create foreign table without table option
--Testcase 4:
CREATE FOREIGN TABLE INT4_TBL(id serial OPTIONS (key 'true'), f1 int4) SERVER :DB_SERVERNAME OPTIONS (schema :DB_SCHEMA);
--Testcase 5:
CREATE FOREIGN TABLE INT4_TMP(id serial OPTIONS (key 'true'), a int4, b int4) SERVER :DB_SERVERNAME OPTIONS (schema :DB_SCHEMA, table 'int4_tbl_tmp2');

--Testcase 6:
DELETE FROM INT4_TBL;
--Testcase 7:
DELETE FROM INT4_TMP;

--Testcase 8:
INSERT INTO INT4_TBL(f1) VALUES ('   0  ');

--Testcase 9:
INSERT INTO INT4_TBL(f1) VALUES ('123456     ');

--Testcase 10:
INSERT INTO INT4_TBL(f1) VALUES ('    -123456');

--Testcase 11:
INSERT INTO INT4_TBL(f1) VALUES ('34.5');

-- largest and smallest values
--Testcase 12:
INSERT INTO INT4_TBL(f1) VALUES ('2147483647');

--Testcase 13:
INSERT INTO INT4_TBL(f1) VALUES ('-2147483647');

-- bad input values -- should give errors
--Testcase 14:
INSERT INTO INT4_TBL(f1) VALUES ('1000000000000');
--Testcase 15:
INSERT INTO INT4_TBL(f1) VALUES ('asdf');
--Testcase 16:
INSERT INTO INT4_TBL(f1) VALUES ('     ');
--Testcase 17:
INSERT INTO INT4_TBL(f1) VALUES ('   asdf   ');
--Testcase 18:
INSERT INTO INT4_TBL(f1) VALUES ('- 1234');
--Testcase 19:
INSERT INTO INT4_TBL(f1) VALUES ('123       5');
--Testcase 20:
INSERT INTO INT4_TBL(f1) VALUES ('');

--Testcase 21:
SELECT f1 FROM INT4_TBL;

--Testcase 22:
SELECT i.f1 FROM INT4_TBL i WHERE i.f1 <> int2 '0';

--Testcase 23:
SELECT i.f1 FROM INT4_TBL i WHERE i.f1 <> int4 '0';

--Testcase 24:
SELECT i.f1 FROM INT4_TBL i WHERE i.f1 = int2 '0';

--Testcase 25:
SELECT i.f1 FROM INT4_TBL i WHERE i.f1 = int4 '0';

--Testcase 26:
SELECT i.f1 FROM INT4_TBL i WHERE i.f1 < int2 '0';

--Testcase 27:
SELECT i.f1 FROM INT4_TBL i WHERE i.f1 < int4 '0';

--Testcase 28:
SELECT i.f1 FROM INT4_TBL i WHERE i.f1 <= int2 '0';

--Testcase 29:
SELECT i.f1 FROM INT4_TBL i WHERE i.f1 <= int4 '0';

--Testcase 30:
SELECT i.f1 FROM INT4_TBL i WHERE i.f1 > int2 '0';

--Testcase 31:
SELECT i.f1 FROM INT4_TBL i WHERE i.f1 > int4 '0';

--Testcase 32:
SELECT i.f1 FROM INT4_TBL i WHERE i.f1 >= int2 '0';

--Testcase 33:
SELECT i.f1 FROM INT4_TBL i WHERE i.f1 >= int4 '0';

-- positive odds
--Testcase 34:
SELECT i.f1 FROM INT4_TBL i WHERE (i.f1 % int2 '2') = int2 '1';

-- any evens
--Testcase 35:
SELECT i.f1 FROM INT4_TBL i WHERE (i.f1 % int4 '2') = int2 '0';

--Testcase 36:
SELECT i.f1, i.f1 * int2 '2' AS x FROM INT4_TBL i;

--Testcase 37:
SELECT i.f1, i.f1 * int2 '2' AS x FROM INT4_TBL i
WHERE abs(f1) < 1073741824;

--Testcase 38:
SELECT i.f1, i.f1 * int4 '2' AS x FROM INT4_TBL i;

--Testcase 39:
SELECT i.f1, i.f1 * int4 '2' AS x FROM INT4_TBL i
WHERE abs(f1) < 1073741824;

--Testcase 40:
SELECT i.f1, i.f1 + int2 '2' AS x FROM INT4_TBL i;

--Testcase 41:
SELECT i.f1, i.f1 + int2 '2' AS x FROM INT4_TBL i
WHERE f1 < 2147483646;

--Testcase 42:
SELECT i.f1, i.f1 + int4 '2' AS x FROM INT4_TBL i;

--Testcase 43:
SELECT i.f1, i.f1 + int4 '2' AS x FROM INT4_TBL i
WHERE f1 < 2147483646;

--Testcase 44:
SELECT i.f1, i.f1 - int2 '2' AS x FROM INT4_TBL i;

--Testcase 45:
SELECT i.f1, i.f1 - int2 '2' AS x FROM INT4_TBL i
WHERE f1 > -2147483647;

--Testcase 46:
SELECT i.f1, i.f1 - int4 '2' AS x FROM INT4_TBL i;

--Testcase 47:
SELECT i.f1, i.f1 - int4 '2' AS x FROM INT4_TBL i
WHERE f1 > -2147483647;

--Testcase 48:
SELECT i.f1, i.f1 / int2 '2' AS x FROM INT4_TBL i;

--Testcase 49:
SELECT i.f1, i.f1 / int4 '2' AS x FROM INT4_TBL i;

--
-- more complex expressions
--
-- variations on unary minus parsing
--Testcase 50:
ALTER FOREIGN TABLE INT4_TBL OPTIONS (table 'int4_tbl_tmp');
--Testcase 51:
INSERT INTO INT4_TBL(f1) VALUES (-2);
--Testcase 52:
SELECT (f1+3) as one FROM INT4_TBL;

--Testcase 53:
DELETE FROM INT4_TBL;
--Testcase 54:
INSERT INTO INT4_TBL(f1) VALUES (4);
--Testcase 55:
SELECT (f1-2) as two FROM INT4_TBL;

--Testcase 56:
DELETE FROM INT4_TBL;
--Testcase 57:
INSERT INTO INT4_TBL(f1) VALUES (2);
--Testcase 58:
SELECT (f1- -1) as three FROM INT4_TBL;

--Testcase 59:
DELETE FROM INT4_TBL;
--Testcase 60:
INSERT INTO INT4_TBL(f1) VALUES (2);
--Testcase 61:
SELECT (f1 - -2) as four FROM INT4_TBL;

--Testcase 62:
DELETE FROM INT4_TMP;
--Testcase 63:
INSERT INTO INT4_TMP(a, b) VALUES (int2 '2' * int2 '2', int2 '16' / int2 '4');
--Testcase 64:
SELECT (a = b) as true FROM INT4_TMP;

--Testcase 65:
DELETE FROM INT4_TMP;
--Testcase 66:
INSERT INTO INT4_TMP(a, b) VALUES (int4 '2' * int2 '2', int2 '16' / int4 '4');
--Testcase 67:
SELECT (a = b) as true FROM INT4_TMP;

--Testcase 68:
DELETE FROM INT4_TMP;
--Testcase 69:
INSERT INTO INT4_TMP(a, b) VALUES (int2 '2' * int4 '2', int4 '16' / int2 '4');
--Testcase 70:
SELECT (a = b) as true FROM INT4_TMP;

--Testcase 71:
DELETE FROM INT4_TMP;
--Testcase 72:
INSERT INTO INT4_TMP(a, b) VALUES (int4 '1000', int4 '999');
--Testcase 73:
SELECT (a < b) as false FROM INT4_TMP;

--Testcase 74:
DELETE FROM INT4_TBL;
--Testcase 75:
INSERT INTO INT4_TBL(f1) VALUES (1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1);
--Testcase 76:
SELECT f1 as ten FROM INT4_TBL;

--Testcase 77:
DELETE FROM INT4_TBL;
--Testcase 78:
INSERT INTO INT4_TBL(f1) VALUES (2 + 2 / 2);
--Testcase 79:
SELECT f1 as three FROM INT4_TBL;

--Testcase 80:
DELETE FROM INT4_TBL;
--Testcase 81:
INSERT INTO INT4_TBL(f1) VALUES ((2 + 2) / 2);
--Testcase 82:
SELECT f1 as two FROM INT4_TBL;

-- corner case
--Testcase 83:
DELETE FROM INT4_TBL;
--Testcase 84:
INSERT INTO INT4_TBL(f1) VALUES ((-1::int4<<31));
--Testcase 85:
SELECT f1::text AS text FROM INT4_TBL;
--Testcase 86:
SELECT (f1+1)::text FROM INT4_TBL;

-- check sane handling of INT_MIN overflow cases
--Testcase 87:
DELETE FROM INT4_TBL;
--Testcase 88:
INSERT INTO INT4_TBL(f1) VALUES ((-2147483648)::int4);
--Testcase 89:
SELECT (f1 * (-1)::int4) FROM INT4_TBL;

--Testcase 90:
DELETE FROM INT4_TBL;
--Testcase 91:
INSERT INTO INT4_TBL(f1) VALUES ((-2147483648)::int4);
--Testcase 92:
SELECT (f1 / (-1)::int4) FROM INT4_TBL;

--Testcase 93:
DELETE FROM INT4_TBL;
--Testcase 94:
INSERT INTO INT4_TBL(f1) VALUES ((-2147483648)::int4);
--Testcase 95:
SELECT (f1 % (-1)::int4) FROM INT4_TBL;

--Testcase 96:
DELETE FROM INT4_TBL;
--Testcase 97:
INSERT INTO INT4_TBL(f1) VALUES ((-2147483648)::int4);
--Testcase 98:
SELECT (f1 * (-1)::int2) FROM INT4_TBL;

--Testcase 99:
DELETE FROM INT4_TBL;
--Testcase 100:
INSERT INTO INT4_TBL(f1) VALUES ((-2147483648)::int4);
--Testcase 101:
SELECT (f1 / (-1)::int2) FROM INT4_TBL;

--Testcase 102:
DELETE FROM INT4_TBL;
--Testcase 103:
INSERT INTO INT4_TBL(f1) VALUES ((-2147483648)::int4);
--Testcase 104:
SELECT (f1 % (-1)::int2) FROM INT4_TBL;

-- check rounding when casting from float
--Testcase 105:
CREATE FOREIGN TABLE FLOAT8_TBL(id serial OPTIONS (key 'true'), f1 float8) SERVER :DB_SERVERNAME OPTIONS (schema :DB_SCHEMA, table 'float8_tbl_tmp'); 

--Testcase 106:
DELETE FROM FLOAT8_TBL;
--Testcase 107:
INSERT INTO FLOAT8_TBL(f1) VALUES
	(-2.5::float8),
        (-1.5::float8),
        (-0.5::float8),
        (0.0::float8),
        (0.5::float8),
        (1.5::float8),
        (2.5::float8);
--Testcase 108:
SELECT f1 as x, f1::int4 AS int4_value FROM FLOAT8_TBL;

-- check rounding when casting from numeric
--Testcase 109:
DELETE FROM FLOAT8_TBL;
--Testcase 110:
INSERT INTO FLOAT8_TBL(f1) VALUES
	(-2.5::numeric),
        (-1.5::numeric),
        (-0.5::numeric),
        (0.0::numeric),
        (0.5::numeric),
        (1.5::numeric),
        (2.5::numeric);
--Testcase 111:
SELECT f1::numeric as x, f1::numeric::int4 AS int4_value FROM FLOAT8_TBL;

-- test gcd()
--Testcase 112:
DELETE FROM INT4_TMP;
--Testcase 113:
INSERT INTO INT4_TMP(a, b) VALUES (0::int4, 0::int4);
--Testcase 114:
INSERT INTO INT4_TMP(a, b) VALUES (0::int4, 6410818::int4);
--Testcase 115:
INSERT INTO INT4_TMP(a, b) VALUES (61866666::int4, 6410818::int4);
--Testcase 116:
INSERT INTO INT4_TMP(a, b) VALUES (-61866666::int4, 6410818::int4);
--Testcase 117:
INSERT INTO INT4_TMP(a, b) VALUES ((-2147483648)::int4, 1::int4);
--Testcase 118:
INSERT INTO INT4_TMP(a, b) VALUES ((-2147483648)::int4, 2147483647::int4);
--Testcase 119:
INSERT INTO INT4_TMP(a, b) VALUES ((-2147483648)::int4, 1073741824::int4);
--Testcase 120:
SELECT a, b, gcd(a, b), gcd(a, -b), gcd(b, a), gcd(-b, a) FROM INT4_TMP;

--Testcase 121:
DELETE FROM INT4_TMP;
--Testcase 122:
INSERT INTO INT4_TMP(a, b) VALUES ((-2147483648)::int4, 0::int4);
--Testcase 123:
SELECT gcd(a, b) FROM INT4_TMP;    -- overflow

--Testcase 124:
DELETE FROM INT4_TMP;
--Testcase 125:
INSERT INTO INT4_TMP(a, b) VALUES ((-2147483648)::int4, (-2147483648)::int4);
--Testcase 126:
SELECT gcd(a, b) FROM INT4_TMP;    -- overflow

-- test lcm()
--Testcase 127:
DELETE FROM INT4_TMP;
--Testcase 128:
INSERT INTO INT4_TMP(a, b) VALUES (0::int4, 0::int4);
--Testcase 129:
INSERT INTO INT4_TMP(a, b) VALUES (0::int4, 42::int4);
--Testcase 130:
INSERT INTO INT4_TMP(a, b) VALUES (42::int4, 42::int4);
--Testcase 131:
INSERT INTO INT4_TMP(a, b) VALUES (330::int4, 462::int4);
--Testcase 132:
INSERT INTO INT4_TMP(a, b) VALUES (-330::int4, 462::int4);
--Testcase 133:
INSERT INTO INT4_TMP(a, b) VALUES ((-2147483648)::int4, 0::int4);
--Testcase 134:
SELECT a, b, lcm(a, b), lcm(a, -b), lcm(b, a), lcm(-b, a) FROM INT4_TMP;

--Testcase 135:
DELETE FROM INT4_TMP;
--Testcase 136:
INSERT INTO INT4_TMP(a, b) VALUES ((-2147483648)::int4, 1::int4);
--Testcase 137:
SELECT lcm(a, b) FROM INT4_TMP;    -- overflow

--Testcase 138:
DELETE FROM INT4_TMP;
--Testcase 139:
INSERT INTO INT4_TMP(a, b) VALUES (2147483647::int4, 2147483646::int4);
--Testcase 140:
SELECT lcm(a, b) FROM INT4_TMP;    -- overflow

--Testcase 141:
DELETE FROM INT4_TBL;
--Testcase 142:
DELETE FROM INT4_TMP;
--Testcase 143:
DELETE FROM FLOAT8_TBL;

--Testcase 144:
DROP FOREIGN TABLE INT4_TMP;
--Testcase 145:
DROP FOREIGN TABLE INT4_TBL;
--Testcase 146:
DROP FOREIGN TABLE FLOAT8_TBL;
--Testcase 147:
DROP USER MAPPING FOR public SERVER :DB_SERVERNAME;
--Testcase 148:
DROP SERVER :DB_SERVERNAME;
--Testcase 149:
DROP EXTENSION :DB_EXTENSIONNAME CASCADE;
