--
-- FLOAT8
--

--Testcase 1:
CREATE EXTENSION :DB_EXTENSIONNAME;
--Testcase 2:
CREATE SERVER :DB_SERVERNAME FOREIGN DATA WRAPPER :DB_EXTENSIONNAME
  OPTIONS (odbc_DRIVER :DB_DRIVERNAME, odbc_SERVER :DB_SERVER, odbc_port :DB_PORT, odbc_DATABASE :DB_DATABASE);
--Testcase 3:
CREATE USER MAPPING FOR public SERVER :DB_SERVERNAME OPTIONS (odbc_UID :DB_USER, odbc_PWD :DB_PASS);  

--Testcase 4:
CREATE FOREIGN TABLE FLOAT8_TBL(f1 float8, id serial OPTIONS (key 'true')) SERVER :DB_SERVERNAME OPTIONS (schema :DB_SCHEMA, table 'float8_tbl');
--Testcase 5:
CREATE FOREIGN TABLE FLOAT8_TMP( id serial OPTIONS (key 'true'), f1 float8, f2 float8) SERVER :DB_SERVERNAME OPTIONS (schema :DB_SCHEMA, table 'float8_tmp');

--Testcase 6:
EXPLAIN VERBOSE
INSERT INTO FLOAT8_TBL(f1) VALUES ('    0.0   ');
--Testcase 7:
INSERT INTO FLOAT8_TBL(f1) VALUES ('    0.0   ');
--Testcase 8:
EXPLAIN VERBOSE
INSERT INTO FLOAT8_TBL(f1) VALUES ('1004.30  ');
--Testcase 9:
INSERT INTO FLOAT8_TBL(f1) VALUES ('1004.30  ');
--Testcase 10:
EXPLAIN VERBOSE
INSERT INTO FLOAT8_TBL(f1) VALUES ('   -34.84');
--Testcase 11:
INSERT INTO FLOAT8_TBL(f1) VALUES ('   -34.84');
--Testcase 12:
EXPLAIN VERBOSE
INSERT INTO FLOAT8_TBL(f1) VALUES ('1.2345678901234e+200');
--Testcase 13:
INSERT INTO FLOAT8_TBL(f1) VALUES ('1.2345678901234e+200');
--Testcase 14:
EXPLAIN VERBOSE
INSERT INTO FLOAT8_TBL(f1) VALUES ('1.2345678901234e-200');
--Testcase 15:
INSERT INTO FLOAT8_TBL(f1) VALUES ('1.2345678901234e-200');
-- bad input
--Testcase 16:
EXPLAIN VERBOSE
INSERT INTO FLOAT8_TBL(f1) VALUES ('');
--Testcase 17:
INSERT INTO FLOAT8_TBL(f1) VALUES ('');
--Testcase 18:
EXPLAIN VERBOSE
INSERT INTO FLOAT8_TBL(f1) VALUES ('     ');
--Testcase 19:
INSERT INTO FLOAT8_TBL(f1) VALUES ('     ');
--Testcase 20:
EXPLAIN VERBOSE
INSERT INTO FLOAT8_TBL(f1) VALUES ('xyz');
--Testcase 21:
INSERT INTO FLOAT8_TBL(f1) VALUES ('xyz');
--Testcase 22:
EXPLAIN VERBOSE
INSERT INTO FLOAT8_TBL(f1) VALUES ('5.0.0');
--Testcase 23:
INSERT INTO FLOAT8_TBL(f1) VALUES ('5.0.0');
--Testcase 24:
EXPLAIN VERBOSE
INSERT INTO FLOAT8_TBL(f1) VALUES ('5 . 0');
--Testcase 25:
INSERT INTO FLOAT8_TBL(f1) VALUES ('5 . 0');
--Testcase 26:
EXPLAIN VERBOSE
INSERT INTO FLOAT8_TBL(f1) VALUES ('5.   0');
--Testcase 27:
INSERT INTO FLOAT8_TBL(f1) VALUES ('5.   0');
--Testcase 28:
EXPLAIN VERBOSE
INSERT INTO FLOAT8_TBL(f1) VALUES ('    - 3');
--Testcase 29:
INSERT INTO FLOAT8_TBL(f1) VALUES ('    - 3');
--Testcase 30:
EXPLAIN VERBOSE
INSERT INTO FLOAT8_TBL(f1) VALUES ('123           5');
--Testcase 31:
INSERT INTO FLOAT8_TBL(f1) VALUES ('123           5');

-- special inputs
--Testcase 32:
ALTER FOREIGN TABLE FLOAT8_TBL OPTIONS (SET table 'float8_tbl_tmp');
--Testcase 33:
INSERT INTO FLOAT8_TBL(f1) VALUES ('NaN'::float4);
--Testcase 34:
SELECT f1 AS float4 FROM FLOAT8_TBL;
--Testcase 35:
DELETE FROM FLOAT8_TBL;
--Testcase 36:
INSERT INTO FLOAT8_TBL(f1) VALUES ('nan'::float4);
--Testcase 37:
SELECT f1 AS float4 FROM FLOAT8_TBL;
--Testcase 38:
DELETE FROM FLOAT8_TBL;
--Testcase 39:
INSERT INTO FLOAT8_TBL(f1) VALUES ('   NAN  '::float4);
--Testcase 40:
SELECT f1 AS float4 FROM FLOAT8_TBL;
--Testcase 41:
DELETE FROM FLOAT8_TBL;
--Testcase 42:
INSERT INTO FLOAT8_TBL(f1) VALUES ('infinity'::float4);
--Testcase 43:
SELECT f1 AS float4 FROM FLOAT8_TBL;
--Testcase 44:
DELETE FROM FLOAT8_TBL;
--Testcase 45:
INSERT INTO FLOAT8_TBL(f1) VALUES ('          -INFINiTY   '::float4);
--Testcase 46:
SELECT f1 AS float4 FROM FLOAT8_TBL;
-- bad special inputs
--Testcase 47:
INSERT INTO FLOAT8_TBL(f1) VALUES ('N A N'::float4);
--Testcase 48:
INSERT INTO FLOAT8_TBL(f1) VALUES ('NaN x'::float4);
--Testcase 49:
INSERT INTO FLOAT8_TBL(f1) VALUES (' INFINITY    x'::float4);

--Testcase 50:
DELETE FROM FLOAT8_TBL;
--Testcase 51:
INSERT INTO FLOAT8_TBL(f1) VALUES ('Infinity'::float4);
--Testcase 52:
SELECT (f1::float4 + 100.0) AS float4 FROM FLOAT8_TBL;

--Testcase 53:
DELETE FROM FLOAT8_TBL;
--Testcase 54:
INSERT INTO FLOAT8_TBL(f1) VALUES ('Infinity'::float4);
--Testcase 55:
SELECT (f1::float4 / 'Infinity'::float4) AS float4 FROM FLOAT8_TBL;

--Testcase 56:
DELETE FROM FLOAT8_TBL;
--Testcase 57:
INSERT INTO FLOAT8_TBL(f1) VALUES ('42'::float4);
--Testcase 58:
SELECT (f1::float4 / 'Infinity'::float4) AS float4 FROM FLOAT8_TBL;

--Testcase 59:
DELETE FROM FLOAT8_TBL;
--Testcase 60:
INSERT INTO FLOAT8_TBL(f1) VALUES ('nan'::float4);
--Testcase 61:
SELECT (f1::float4 / 'nan'::float4) AS float4 FROM FLOAT8_TBL;

--Testcase 62:
DELETE FROM FLOAT8_TBL;
--Testcase 63:
INSERT INTO FLOAT8_TBL(f1) VALUES ('nan'::float4);
--Testcase 64:
SELECT (f1::float4 / '0'::float4) AS float4 FROM FLOAT8_TBL;

--Testcase 65:
DELETE FROM FLOAT8_TBL;
--Testcase 66:
INSERT INTO FLOAT8_TBL(f1) VALUES ('nan'::numeric);
--Testcase 67:
SELECT (f1::float4) AS float4 FROM FLOAT8_TBL;
--Testcase 68:
DELETE FROM FLOAT8_TBL;
--Testcase 69:
ALTER FOREIGN TABLE FLOAT8_TBL OPTIONS (SET table 'float8_tbl');

--Testcase 70:
EXPLAIN VERBOSE
SELECT f1 FROM FLOAT8_TBL;
--Testcase 71:
SELECT f1 FROM FLOAT8_TBL;
--Testcase 72:
EXPLAIN VERBOSE
SELECT f.f1 FROM FLOAT8_TBL f WHERE f.f1 <> '1004.3';
--Testcase 73:
SELECT f.f1 FROM FLOAT8_TBL f WHERE f.f1 <> '1004.3';
--Testcase 74:
EXPLAIN VERBOSE
SELECT f.f1 FROM FLOAT8_TBL f WHERE f.f1 = '1004.3';
--Testcase 75:
SELECT f.f1 FROM FLOAT8_TBL f WHERE f.f1 = '1004.3';
--Testcase 76:
EXPLAIN VERBOSE
SELECT f.f1 FROM FLOAT8_TBL f WHERE '1004.3' > f.f1;
--Testcase 77:
SELECT f.f1 FROM FLOAT8_TBL f WHERE '1004.3' > f.f1;
--Testcase 78:
EXPLAIN VERBOSE
SELECT f.f1 FROM FLOAT8_TBL f WHERE  f.f1 < '1004.3';
--Testcase 79:
SELECT f.f1 FROM FLOAT8_TBL f WHERE  f.f1 < '1004.3';
--Testcase 80:
EXPLAIN VERBOSE
SELECT f.f1 FROM FLOAT8_TBL f WHERE '1004.3' >= f.f1;
--Testcase 81:
SELECT f.f1 FROM FLOAT8_TBL f WHERE '1004.3' >= f.f1;
--Testcase 82:
EXPLAIN VERBOSE
SELECT f.f1 FROM FLOAT8_TBL f WHERE  f.f1 <= '1004.3';
--Testcase 83:
SELECT f.f1 FROM FLOAT8_TBL f WHERE  f.f1 <= '1004.3';
--Testcase 84:
EXPLAIN VERBOSE
SELECT f.f1, f.f1 * '-10' AS x
   FROM FLOAT8_TBL f
   WHERE f.f1 > '0.0';
--Testcase 85:
SELECT f.f1, f.f1 * '-10' AS x
   FROM FLOAT8_TBL f
   WHERE f.f1 > '0.0';
--Testcase 86:
EXPLAIN VERBOSE
SELECT f.f1, f.f1 + '-10' AS x
   FROM FLOAT8_TBL f
   WHERE f.f1 > '0.0';
--Testcase 87:
SELECT f.f1, f.f1 + '-10' AS x
   FROM FLOAT8_TBL f
   WHERE f.f1 > '0.0';
--Testcase 88:
EXPLAIN VERBOSE
SELECT f.f1, f.f1 / '-10' AS x
   FROM FLOAT8_TBL f
   WHERE f.f1 > '0.0';
--Testcase 89:
SELECT f.f1, f.f1 / '-10' AS x
   FROM FLOAT8_TBL f
   WHERE f.f1 > '0.0';
--Testcase 90:
EXPLAIN VERBOSE
SELECT f.f1, f.f1 - '-10' AS x
   FROM FLOAT8_TBL f
   WHERE f.f1 > '0.0';
--Testcase 91:
SELECT f.f1, f.f1 - '-10' AS x
   FROM FLOAT8_TBL f
   WHERE f.f1 > '0.0';
--Testcase 92:
EXPLAIN VERBOSE
SELECT f.f1 ^ '2.0' AS square_f1
   FROM FLOAT8_TBL f where f.f1 = '1004.3';
--Testcase 93:
SELECT f.f1 ^ '2.0' AS square_f1
   FROM FLOAT8_TBL f where f.f1 = '1004.3';
-- absolute value
--Testcase 94:
EXPLAIN VERBOSE
SELECT f.f1, @f.f1 AS abs_f1
   FROM FLOAT8_TBL f;
--Testcase 95:
SELECT f.f1, @f.f1 AS abs_f1
   FROM FLOAT8_TBL f;
-- truncate
--Testcase 96:
EXPLAIN VERBOSE
SELECT f.f1, trunc(f.f1) AS trunc_f1
   FROM FLOAT8_TBL f;
--Testcase 97:
SELECT f.f1, trunc(f.f1) AS trunc_f1
   FROM FLOAT8_TBL f;
-- round
--Testcase 98:
EXPLAIN VERBOSE
SELECT f.f1, round(f.f1) AS round_f1
   FROM FLOAT8_TBL f;
--Testcase 99:
SELECT f.f1, round(f.f1) AS round_f1
   FROM FLOAT8_TBL f;
-- ceil / ceiling
--Testcase 100:
EXPLAIN VERBOSE
select ceil(f1) as ceil_f1 from float8_tbl f;
--Testcase 101:
select ceil(f1) as ceil_f1 from float8_tbl f;
--Testcase 102:
EXPLAIN VERBOSE
select ceiling(f1) as ceiling_f1 from float8_tbl f;
--Testcase 103:
select ceiling(f1) as ceiling_f1 from float8_tbl f;
-- floor
--Testcase 104:
EXPLAIN VERBOSE
select floor(f1) as floor_f1 from float8_tbl f;
--Testcase 105:
select floor(f1) as floor_f1 from float8_tbl f;
-- sign
--Testcase 106:
EXPLAIN VERBOSE
select sign(f1) as sign_f1 from float8_tbl f;
--Testcase 107:
select sign(f1) as sign_f1 from float8_tbl f;
-- avoid bit-exact output here because operations may not be bit-exact.
--Testcase 108:
SET extra_float_digits = 0;
-- square root
--Testcase 109:
EXPLAIN VERBOSE
SELECT sqrt(float8 '64') AS eight;
--Testcase 110:
SELECT sqrt(float8 '64') AS eight;
--Testcase 111:
EXPLAIN VERBOSE
SELECT |/ float8 '64' AS eight;
--Testcase 112:
SELECT |/ float8 '64' AS eight;
--Testcase 113:
EXPLAIN VERBOSE
SELECT f.f1, |/f.f1 AS sqrt_f1
   FROM FLOAT8_TBL f
   WHERE f.f1 > '0.0';
--Testcase 114:
SELECT f.f1, |/f.f1 AS sqrt_f1
   FROM FLOAT8_TBL f
   WHERE f.f1 > '0.0';

-- power
--Testcase 115:
DELETE FROM FLOAT8_TMP;
--Testcase 116:
INSERT INTO FLOAT8_TMP(f1, f2) VALUES (float8 '144', float8 '0.5');
--Testcase 117:
SELECT power(f1, f2) FROM FLOAT8_TMP;

--Testcase 118:
DELETE FROM FLOAT8_TMP;
--Testcase 119:
INSERT INTO FLOAT8_TMP(f1, f2) VALUES (float8 'NaN', float8 '0.5');
--Testcase 120:
SELECT power(f1, f2) FROM FLOAT8_TMP;

--Testcase 121:
DELETE FROM FLOAT8_TMP;
--Testcase 122:
INSERT INTO FLOAT8_TMP(f1, f2) VALUES (float8 '144', float8 'NaN');
--Testcase 123:
SELECT power(f1, f2) FROM FLOAT8_TMP;

--Testcase 124:
DELETE FROM FLOAT8_TMP;
--Testcase 125:
INSERT INTO FLOAT8_TMP(f1, f2) VALUES (float8 'NaN', float8 'NaN');
--Testcase 126:
SELECT power(f1, f2) FROM FLOAT8_TMP;

--Testcase 127:
DELETE FROM FLOAT8_TMP;
--Testcase 128:
INSERT INTO FLOAT8_TMP(f1, f2) VALUES (float8 '-1', float8 'NaN');
--Testcase 129:
SELECT power(f1, f2) FROM FLOAT8_TMP;

--Testcase 130:
DELETE FROM FLOAT8_TMP;
--Testcase 131:
INSERT INTO FLOAT8_TMP(f1, f2) VALUES (float8 '1', float8 'NaN');
--Testcase 132:
SELECT power(f1, f2) FROM FLOAT8_TMP;

--Testcase 133:
DELETE FROM FLOAT8_TMP;
--Testcase 134:
INSERT INTO FLOAT8_TMP(f1, f2) VALUES (float8 'NaN', float8 '0');
--Testcase 135:
SELECT power(f1, f2) FROM FLOAT8_TMP;

--Testcase 136:
DELETE FROM FLOAT8_TMP;
--Testcase 137:
INSERT INTO FLOAT8_TMP(f1, f2) VALUES (float8 'inf', float8 '0');
--Testcase 138:
SELECT power(f1, f2) FROM FLOAT8_TMP;

--Testcase 139:
DELETE FROM FLOAT8_TMP;
--Testcase 140:
INSERT INTO FLOAT8_TMP(f1, f2) VALUES (float8 '-inf', float8 '0');
--Testcase 141:
SELECT power(f1, f2) FROM FLOAT8_TMP;

--Testcase 142:
DELETE FROM FLOAT8_TMP;
--Testcase 143:
INSERT INTO FLOAT8_TMP(f1, f2) VALUES (float8 '0', float8 'inf');
--Testcase 144:
SELECT power(f1, f2) FROM FLOAT8_TMP;

--Testcase 145:
DELETE FROM FLOAT8_TMP;
--Testcase 146:
INSERT INTO FLOAT8_TMP(f1, f2) VALUES (float8 '0', float8 '-inf');
--Testcase 147:
SELECT power(f1, f2) FROM FLOAT8_TMP;

--Testcase 148:
DELETE FROM FLOAT8_TMP;
--Testcase 149:
INSERT INTO FLOAT8_TMP(f1, f2) VALUES (float8 '1', float8 'inf');
--Testcase 150:
SELECT power(f1, f2) FROM FLOAT8_TMP;

--Testcase 151:
DELETE FROM FLOAT8_TMP;
--Testcase 152:
INSERT INTO FLOAT8_TMP(f1, f2) VALUES (float8 '1', float8 '-inf');
--Testcase 153:
SELECT power(f1, f2) FROM FLOAT8_TMP;

--Testcase 154:
DELETE FROM FLOAT8_TMP;
--Testcase 155:
INSERT INTO FLOAT8_TMP(f1, f2) VALUES (float8 '-1', float8 'inf');
--Testcase 156:
SELECT power(f1, f2) FROM FLOAT8_TMP;

--Testcase 157:
DELETE FROM FLOAT8_TMP;
--Testcase 158:
INSERT INTO FLOAT8_TMP(f1, f2) VALUES (float8 '-1', float8 '-inf');
--Testcase 159:
SELECT power(f1, f2) FROM FLOAT8_TMP;

--Testcase 160:
DELETE FROM FLOAT8_TMP;
--Testcase 161:
INSERT INTO FLOAT8_TMP(f1, f2) VALUES (float8 '0.1', float8 'inf');
--Testcase 162:
SELECT power(f1, f2) FROM FLOAT8_TMP;

--Testcase 163:
DELETE FROM FLOAT8_TMP;
--Testcase 164:
INSERT INTO FLOAT8_TMP(f1, f2) VALUES (float8 '-0.1', float8 'inf');
--Testcase 165:
SELECT power(f1, f2) FROM FLOAT8_TMP;

--Testcase 166:
DELETE FROM FLOAT8_TMP;
--Testcase 167:
INSERT INTO FLOAT8_TMP(f1, f2) VALUES (float8 '1.1', float8 'inf');
--Testcase 168:
SELECT power(f1, f2) FROM FLOAT8_TMP;

--Testcase 169:
DELETE FROM FLOAT8_TMP;
--Testcase 170:
INSERT INTO FLOAT8_TMP(f1, f2) VALUES (float8 '-1.1', float8 'inf');
--Testcase 171:
SELECT power(f1, f2) FROM FLOAT8_TMP;

--Testcase 172:
DELETE FROM FLOAT8_TMP;
--Testcase 173:
INSERT INTO FLOAT8_TMP(f1, f2) VALUES (float8 '0.1', float8 '-inf');
--Testcase 174:
SELECT power(f1, f2) FROM FLOAT8_TMP;

--Testcase 175:
DELETE FROM FLOAT8_TMP;
--Testcase 176:
INSERT INTO FLOAT8_TMP(f1, f2) VALUES (float8 '-0.1', float8 '-inf');
--Testcase 177:
SELECT power(f1, f2) FROM FLOAT8_TMP;

--Testcase 178:
DELETE FROM FLOAT8_TMP;
--Testcase 179:
INSERT INTO FLOAT8_TMP(f1, f2) VALUES (float8 '1.1', float8 '-inf');
--Testcase 180:
SELECT power(f1, f2) FROM FLOAT8_TMP;

--Testcase 181:
DELETE FROM FLOAT8_TMP;
--Testcase 182:
INSERT INTO FLOAT8_TMP(f1, f2) VALUES (float8 '-1.1', float8 '-inf');
--Testcase 183:
SELECT power(f1, f2) FROM FLOAT8_TMP;

--Testcase 184:
DELETE FROM FLOAT8_TMP;
--Testcase 185:
INSERT INTO FLOAT8_TMP(f1, f2) VALUES (float8 'inf', float8 '-2');
--Testcase 186:
SELECT power(f1, f2) FROM FLOAT8_TMP;

--Testcase 187:
DELETE FROM FLOAT8_TMP;
--Testcase 188:
INSERT INTO FLOAT8_TMP(f1, f2) VALUES (float8 'inf', float8 '2');
--Testcase 189:
SELECT power(f1, f2) FROM FLOAT8_TMP;

--Testcase 190:
DELETE FROM FLOAT8_TMP;
--Testcase 191:
INSERT INTO FLOAT8_TMP(f1, f2) VALUES (float8 'inf', float8 'inf');
--Testcase 192:
SELECT power(f1, f2) FROM FLOAT8_TMP;

--Testcase 193:
DELETE FROM FLOAT8_TMP;
--Testcase 194:
INSERT INTO FLOAT8_TMP(f1, f2) VALUES (float8 'inf', float8 '-inf');
--Testcase 195:
SELECT power(f1, f2) FROM FLOAT8_TMP;

-- Intel's icc misoptimizes the code that controls the sign of this result,
-- even with -mp1.  Pending a fix for that, only test for "is it zero".
--Testcase 196:
DELETE FROM FLOAT8_TMP;
--Testcase 197:
INSERT INTO FLOAT8_TMP(f1, f2) VALUES (float8 '-inf', float8 '-2');
--Testcase 198:
SELECT power(f1, f2) = '0' FROM FLOAT8_TMP;

--Testcase 199:
DELETE FROM FLOAT8_TMP;
--Testcase 200:
INSERT INTO FLOAT8_TMP(f1, f2) VALUES (float8 '-inf', float8 '-3');
--Testcase 201:
SELECT power(f1, f2) FROM FLOAT8_TMP;

--Testcase 202:
DELETE FROM FLOAT8_TMP;
--Testcase 203:
INSERT INTO FLOAT8_TMP(f1, f2) VALUES (float8 '-inf', float8 '2');
--Testcase 204:
SELECT power(f1, f2) FROM FLOAT8_TMP;

--Testcase 205:
DELETE FROM FLOAT8_TMP;
--Testcase 206:
INSERT INTO FLOAT8_TMP(f1, f2) VALUES (float8 '-inf', float8 '3');
--Testcase 207:
SELECT power(f1, f2) FROM FLOAT8_TMP;

--Testcase 208:
DELETE FROM FLOAT8_TMP;
--Testcase 209:
INSERT INTO FLOAT8_TMP(f1, f2) VALUES (float8 '-inf', float8 '3.5');
--Testcase 210:
SELECT power(f1, f2) FROM FLOAT8_TMP;

--Testcase 211:
DELETE FROM FLOAT8_TMP;
--Testcase 212:
INSERT INTO FLOAT8_TMP(f1, f2) VALUES (float8 '-inf', float8 'inf');
--Testcase 213:
SELECT power(f1, f2) FROM FLOAT8_TMP;

--Testcase 214:
DELETE FROM FLOAT8_TMP;
--Testcase 215:
INSERT INTO FLOAT8_TMP(f1, f2) VALUES (float8 '-inf', float8 '-inf');
--Testcase 216:
SELECT power(f1, f2) FROM FLOAT8_TMP;

-- take exp of ln(f.f1)
--Testcase 217:
EXPLAIN VERBOSE
SELECT f.f1, exp(ln(f.f1)) AS exp_ln_f1
   FROM FLOAT8_TBL f
   WHERE f.f1 > '0.0';
--Testcase 218:
SELECT f.f1, exp(ln(f.f1)) AS exp_ln_f1
   FROM FLOAT8_TBL f
   WHERE f.f1 > '0.0';
--Testcase 219:
EXPLAIN VERBOSE
SELECT f.f1, ||/f.f1 AS cbrt_f1 FROM FLOAT8_TBL f;
--Testcase 220:
SELECT f.f1, ||/f.f1 AS cbrt_f1 FROM FLOAT8_TBL f;
--Testcase 221:
EXPLAIN VERBOSE
SELECT f1 FROM FLOAT8_TBL;
--Testcase 222:
SELECT f1 FROM FLOAT8_TBL;
--Testcase 223:
EXPLAIN VERBOSE
UPDATE FLOAT8_TBL
   SET f1 = FLOAT8_TBL.f1 * '-1'
   WHERE FLOAT8_TBL.f1 > '0.0';
--Testcase 224:
UPDATE FLOAT8_TBL
   SET f1 = FLOAT8_TBL.f1 * '-1'
   WHERE FLOAT8_TBL.f1 > '0.0';
--Testcase 225:
EXPLAIN VERBOSE
SELECT f.f1 * '1e200' from FLOAT8_TBL f;
--Testcase 226:
SELECT f.f1 * '1e200' from FLOAT8_TBL f;
--Testcase 227:
EXPLAIN VERBOSE
SELECT f.f1 ^ '1e200' from FLOAT8_TBL f;
--Testcase 228:
SELECT f.f1 ^ '1e200' from FLOAT8_TBL f;
-- EXPLAIN VERBOSE
-- SELECT 0 ^ 0 + 0 ^ 1 + 0 ^ 0.0 + 0 ^ 0.5; -- comment out because of no foreign table
-- SELECT 0 ^ 0 + 0 ^ 1 + 0 ^ 0.0 + 0 ^ 0.5; -- comment out because of no foreign table
--Testcase 229:
EXPLAIN VERBOSE
SELECT ln(f.f1) from FLOAT8_TBL f where f.f1 = '0.0' ;
--Testcase 230:
SELECT ln(f.f1) from FLOAT8_TBL f where f.f1 = '0.0' ;
--Testcase 231:
EXPLAIN VERBOSE
SELECT ln(f.f1) from FLOAT8_TBL f where f.f1 < '0.0' ;
--Testcase 232:
SELECT ln(f.f1) from FLOAT8_TBL f where f.f1 < '0.0' ;
--Testcase 233:
EXPLAIN VERBOSE
SELECT exp(f.f1) from FLOAT8_TBL f;
--Testcase 234:
SELECT exp(f.f1) from FLOAT8_TBL f;
--Testcase 235:
EXPLAIN VERBOSE
SELECT f.f1 / '0.0' from FLOAT8_TBL f;
--Testcase 236:
SELECT f.f1 / '0.0' from FLOAT8_TBL f;
--Testcase 237:
EXPLAIN VERBOSE
SELECT f1 FROM FLOAT8_TBL;
--Testcase 238:
SELECT f1 FROM FLOAT8_TBL;
--Testcase 239:
RESET extra_float_digits;
-- test for over- and underflow
--Testcase 240:
EXPLAIN VERBOSE
INSERT INTO FLOAT8_TBL(f1) VALUES ('10e400');
--Testcase 241:
INSERT INTO FLOAT8_TBL(f1) VALUES ('10e400');
--Testcase 242:
EXPLAIN VERBOSE
INSERT INTO FLOAT8_TBL(f1) VALUES ('-10e400');
--Testcase 243:
INSERT INTO FLOAT8_TBL(f1) VALUES ('-10e400');
--Testcase 244:
EXPLAIN VERBOSE
INSERT INTO FLOAT8_TBL(f1) VALUES ('10e-400');
--Testcase 245:
INSERT INTO FLOAT8_TBL(f1) VALUES ('10e-400');
--Testcase 246:
EXPLAIN VERBOSE
INSERT INTO FLOAT8_TBL(f1) VALUES ('-10e-400');
--Testcase 247:
INSERT INTO FLOAT8_TBL(f1) VALUES ('-10e-400');
-- maintain external table consistency across platforms
-- delete all values and reinsert well-behaved ones
--Testcase 248:
EXPLAIN VERBOSE
DELETE FROM FLOAT8_TBL;
--Testcase 249:
DELETE FROM FLOAT8_TBL;
--Testcase 250:
EXPLAIN VERBOSE
INSERT INTO FLOAT8_TBL(f1) VALUES ('0.0');
--Testcase 251:
INSERT INTO FLOAT8_TBL(f1) VALUES ('0.0');
--Testcase 252:
EXPLAIN VERBOSE
INSERT INTO FLOAT8_TBL(f1) VALUES ('-34.84');
--Testcase 253:
INSERT INTO FLOAT8_TBL(f1) VALUES ('-34.84');
--Testcase 254:
EXPLAIN VERBOSE
INSERT INTO FLOAT8_TBL(f1) VALUES ('-1004.30');
--Testcase 255:
INSERT INTO FLOAT8_TBL(f1) VALUES ('-1004.30');
--Testcase 256:
EXPLAIN VERBOSE
INSERT INTO FLOAT8_TBL(f1) VALUES ('-1.2345678901234e+200');
--Testcase 257:
INSERT INTO FLOAT8_TBL(f1) VALUES ('-1.2345678901234e+200');
--Testcase 258:
EXPLAIN VERBOSE
INSERT INTO FLOAT8_TBL(f1) VALUES ('-1.2345678901234e-200');
--Testcase 259:
INSERT INTO FLOAT8_TBL(f1) VALUES ('-1.2345678901234e-200');
--Testcase 260:
EXPLAIN VERBOSE
SELECT f1 FROM FLOAT8_TBL;
--Testcase 261:
SELECT f1 FROM FLOAT8_TBL;
--Testcase 262:
DROP SERVER :DB_SERVERNAME CASCADE;
--Testcase 263:
DROP EXTENSION :DB_EXTENSIONNAME CASCADE;
