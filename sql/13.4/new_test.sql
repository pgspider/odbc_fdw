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
--Testcase 77:
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
--Testcase 78:
\dS+ tbl02
--Testcase 73
INSERT INTO tbl02(id, c1) VALUES ('a', 12112.12); -- ok
--Testcase 79:
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

--Testcase 245:
EXPLAIN VERBOSE
SELECT * FROM tbl04 WHERE id IN (1, 2, 3);
--Testcase 246:
SELECT * FROM tbl04 WHERE id IN (1, 2, 3);
--Testcase 247:
EXPLAIN VERBOSE
SELECT * FROM tbl04 WHERE id NOT IN (1, 2, 3);
--Testcase 248:
SELECT * FROM tbl04 WHERE id NOT IN (1, 2, 3);

--Testcase 249:
EXPLAIN VERBOSE
SELECT * FROM tbl04 WHERE id IN (1, c2, 3);
--Testcase 250:
SELECT * FROM tbl04 WHERE id IN (1, c2, 3);
--Testcase 251:
EXPLAIN VERBOSE
SELECT * FROM tbl04 WHERE id NOT IN (1, c2, 3);
--Testcase 252:
SELECT * FROM tbl04 WHERE id NOT IN (1, c2, 3);

--Testcase 253:
EXPLAIN VERBOSE
SELECT * FROM tbl04 WHERE id <> ALL(ARRAY[c2, 2, 3]);
--Testcase 254:
SELECT * FROM tbl04 WHERE id <> ALL(ARRAY[c2, 2, 3]);
--Testcase 255:
EXPLAIN VERBOSE
SELECT * FROM tbl04 WHERE id = ALL(ARRAY[c2, 2, 3]);
--Testcase 256:
SELECT * FROM tbl04 WHERE id = ALL(ARRAY[c2, 2, 3]);
--Testcase 257:
EXPLAIN VERBOSE
SELECT * FROM tbl04 WHERE id <> ANY(ARRAY[c2, 2, 3]);
--Testcase 258:
SELECT * FROM tbl04 WHERE id <> ANY(ARRAY[c2, 2, 3]);
--Testcase 259:
EXPLAIN VERBOSE
SELECT * FROM tbl04 WHERE id = ANY(ARRAY[c2, 2, 3]);
--Testcase 260:
SELECT * FROM tbl04 WHERE id = ANY(ARRAY[c2, 2, 3]);

--Testcase 261:
EXPLAIN VERBOSE
SELECT * FROM tbl04 WHERE id <> ALL(ARRAY[1, 2, 3]);
--Testcase 262:
SELECT * FROM tbl04 WHERE id <> ALL(ARRAY[1, 2, 3]);
--Testcase 263:
EXPLAIN VERBOSE
SELECT * FROM tbl04 WHERE id = ALL(ARRAY[1, 2, 3]);
--Testcase 264:
SELECT * FROM tbl04 WHERE id = ALL(ARRAY[1, 2, 3]);
--Testcase 265:
EXPLAIN VERBOSE
SELECT * FROM tbl04 WHERE id <> ANY(ARRAY[1, 2, 3]);
--Testcase 266:
SELECT * FROM tbl04 WHERE id <> ANY(ARRAY[1, 2, 3]);
--Testcase 267:
EXPLAIN VERBOSE
SELECT * FROM tbl04 WHERE id = ANY(ARRAY[1, 2, 3]);
--Testcase 268:
SELECT * FROM tbl04 WHERE id = ANY(ARRAY[1, 2, 3]);

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
--Testcase 241:
EXPLAIN VERBOSE
SELECT count(c1), sum(c2) FROM tbl04 HAVING (count(c1) > 0);
--Testcase 242:
SELECT count(c1), sum(c2) FROM tbl04 HAVING (count(c1) > 0);
--Testcase 243:
EXPLAIN VERBOSE
SELECT count(c1) + sum (c2) FROM tbl04 HAVING count(c4) != 0 AND avg(c2) > 55.54;
--Testcase 244:
SELECT count(c1) + sum (c2) FROM tbl04 HAVING count(c4) != 0 AND avg(c2) > 55.54;

--aggregation function push-down:
-- avg
--Testcase 80:
EXPLAIN VERBOSE
SELECT avg(c1), avg(c2) + 1 FROM tbl04;
--Testcase 81:
SELECT avg(c1), avg(c2) + 1 FROM tbl04;
-- avg(DISTINCT)
--Testcase 82:
EXPLAIN VERBOSE
SELECT avg(DISTINCT c1), avg(DISTINCT c2) FROM tbl04;
--Testcase 83:
SELECT avg(DISTINCT c1), avg(DISTINCT c2) FROM tbl04;

-- bit_and
--Testcase 84:
EXPLAIN VERBOSE
SELECT bit_and(id), bit_and(c2) + 1 FROM tbl04;
--Testcase 85:
SELECT bit_and(id), bit_and(c2) + 1 FROM tbl04;
-- bit_and(DISTINCT)
--Testcase 86:
EXPLAIN VERBOSE
SELECT bit_and(DISTINCT id), bit_and(DISTINCT c2) FROM tbl04;
--Testcase 87:
SELECT bit_and(DISTINCT id), bit_and(DISTINCT c2) FROM tbl04;

-- bit_or
--Testcase 88:
EXPLAIN VERBOSE
SELECT bit_or(id), bit_or(c2) + 1 FROM tbl04;
--Testcase 89:
SELECT bit_or(id), bit_or(c2) + 1 FROM tbl04;
-- bit_or(DISTINCT)
--Testcase 90:
EXPLAIN VERBOSE
SELECT bit_or(DISTINCT id), bit_or(DISTINCT c2) FROM tbl04;
--Testcase 91:
SELECT bit_or(DISTINCT id), bit_or(DISTINCT c2) FROM tbl04;

-- count
--Testcase 92:
EXPLAIN VERBOSE
SELECT count(c1), count(c2), count(c3) FROM tbl04;
--Testcase 93:
SELECT count(c1), count(c2), count(c3) FROM tbl04;
-- count(DISTINCT)
--Testcase 94:
EXPLAIN VERBOSE
SELECT count(DISTINCT c1), count(DISTINCT c2), count(DISTINCT c3) FROM tbl04;
--Testcase 95:
SELECT count(DISTINCT c1), count(DISTINCT c2), count(DISTINCT c3) FROM tbl04;

-- max/min
--Testcase 241:
EXPLAIN VERBOSE
SELECT max(c1), min(c1) FROM tbl04;
--Testcase 242:
SELECT max(c1), min(c1) FROM tbl04;

-- max/min (DISTINCT)
--Testcase 243:
EXPLAIN VERBOSE
SELECT max(DISTINCT c1), min(DISTINCT c1) FROM tbl04;
--Testcase 244:
SELECT max(DISTINCT c1), min(DISTINCT c1) FROM tbl04;

-- stddev
--Testcase 96:
EXPLAIN VERBOSE
SELECT stddev(c1), stddev(c2) + 1 FROM tbl04;
--Testcase 97:
SELECT stddev(c1), stddev(c2) + 1 FROM tbl04;
-- stddev(DISTINCT)
--Testcase 98:
EXPLAIN VERBOSE
SELECT stddev(DISTINCT c1), stddev(DISTINCT c2) FROM tbl04;
--Testcase 99:
SELECT stddev(DISTINCT c1), stddev(DISTINCT c2) FROM tbl04;

-- stddev_pop
--Testcase 100:
EXPLAIN VERBOSE
SELECT stddev_pop(c1), stddev_pop(c2) + 1 FROM tbl04;
--Testcase 101:
SELECT stddev_pop(c1), stddev_pop(c2) + 1 FROM tbl04;
-- stddev_pop(DISTINCT)
--Testcase 102:
EXPLAIN VERBOSE
SELECT stddev_pop(DISTINCT c1), stddev_pop(DISTINCT c2) FROM tbl04;
--Testcase 103:
SELECT stddev_pop(DISTINCT c1), stddev_pop(DISTINCT c2) FROM tbl04;

-- stddev_samp
--Testcase 104:
EXPLAIN VERBOSE
SELECT stddev_samp(c1), stddev_samp(c2) + 1 FROM tbl04;
--Testcase 105:
SELECT stddev_samp(c1), stddev_samp(c2) + 1 FROM tbl04;
-- stddev_samp(DISTINCT)
--Testcase 106:
EXPLAIN VERBOSE
SELECT stddev_samp(DISTINCT c1), stddev_samp(DISTINCT c2) FROM tbl04;
--Testcase 107:
SELECT stddev_samp(DISTINCT c1), stddev_samp(DISTINCT c2) FROM tbl04;

-- sum
--Testcase 108:
EXPLAIN VERBOSE
SELECT sum(c1), sum(c2) + 1 FROM tbl04;
--Testcase 109:
SELECT sum(c1), sum(c2) + 1 FROM tbl04;
-- sum(DISTINCT)
--Testcase 110:
EXPLAIN VERBOSE
SELECT sum(DISTINCT c1), sum(DISTINCT c2) FROM tbl04;
--Testcase 111:
SELECT sum(DISTINCT c1), sum(DISTINCT c2) FROM tbl04;

-- var_pop
--Testcase 112:
EXPLAIN VERBOSE
SELECT var_pop(c1), var_pop(c2) + 1 FROM tbl04;
--Testcase 113:
SELECT var_pop(c1), var_pop(c2) + 1 FROM tbl04;
-- var_pop(DISTINCT)
--Testcase 114:
EXPLAIN VERBOSE
SELECT var_pop(DISTINCT c1), var_pop(DISTINCT c2) FROM tbl04;
--Testcase 115:
SELECT var_pop(DISTINCT c1), var_pop(DISTINCT c2) FROM tbl04;

-- var_samp
--Testcase 116:
EXPLAIN VERBOSE
SELECT var_samp(c1), var_samp(c2) + 1 FROM tbl04;
--Testcase 117:
SELECT var_samp(c1), var_samp(c2) + 1 FROM tbl04;
-- var_samp(DISTINCT)
--Testcase 118:
EXPLAIN VERBOSE
SELECT var_samp(DISTINCT c1), var_samp(DISTINCT c2) FROM tbl04;
--Testcase 119:
SELECT var_samp(DISTINCT c1), var_samp(DISTINCT c2) FROM tbl04;

-- variance(DISTINCT)
--Testcase 120:
EXPLAIN VERBOSE
SELECT variance(DISTINCT c1), variance(DISTINCT c2) FROM tbl04;
--Testcase 121:
SELECT variance(DISTINCT c1), variance(DISTINCT c2) FROM tbl04;

-- non-push down case:
--Testcase 122:
EXPLAIN VERBOSE
SELECT corr(id, c1) FROM tbl04;
--Testcase 123:
SELECT corr(id, c1) FROM tbl04;

-- ===================================================================
-- WHERE push-down
-- ===================================================================
-- add some null record
--Testcase 124:
INSERT INTO tbl04 VALUES (11, -1.12, NULL, '(!)JAWLFJ', false, '2010-11-01 00:00:00');
--Testcase 125:
INSERT INTO tbl04 VALUES (12, 45021.21, 2121, 'example', NULL, '1999-10-01 00:00:00');
--Testcase 126:
INSERT INTO tbl04 VALUES (13, 121.9741, 23241, 'thing', NULL, '2010-10-01 00:00:00');
--Testcase 127:
INSERT INTO tbl04 VALUES (14, 75, 316, 'example', NULL, '1999-10-01 10:10:00');
--Testcase 128:
INSERT INTO tbl04 VALUES (15, 6867.34, 8916, NULL, false, '2010-10-01 10:10:00');
-- Logical operator
--Testcase 129:
EXPLAIN VERBOSE
SELECT id, c1, c2 FROM tbl04 WHERE c1 >= 0 OR c2 > 0 AND NOT c4;
--Testcase 130:
SELECT id, c1, c2 FROM tbl04 WHERE c1 >= 0 OR c2 > 0 AND NOT c4;

--Testcase 131:
EXPLAIN VERBOSE
SELECT id, c1, c2 FROM tbl04 WHERE c1 >= 0 OR c4;
--Testcase 132:
SELECT id, c1, c2 FROM tbl04 WHERE c1 >= 0 OR c4;

--Testcase 133:
EXPLAIN VERBOSE
SELECT id, c1, c2 FROM tbl04 WHERE c1 >= 0 AND c4;
--Testcase 134:
SELECT id, c1, c2 FROM tbl04 WHERE c1 >= 0 AND c4;

--Testcase 135:
EXPLAIN VERBOSE
SELECT id, c1, c2 FROM tbl04 WHERE NOT c4;
--Testcase 136:
SELECT id, c1, c2 FROM tbl04 WHERE NOT c4;

-- Comparison operator
--Testcase 137:
EXPLAIN VERBOSE
SELECT id, c1, c2 FROM tbl04 WHERE id > 1;
--Testcase 138:
SELECT id, c1, c2 FROM tbl04 WHERE id > 1;

--Testcase 139:
EXPLAIN VERBOSE
SELECT id, c1, c2 FROM tbl04 WHERE id >= 1;
--Testcase 140:
SELECT id, c1, c2 FROM tbl04 WHERE id >= 1;

--Testcase 141:
EXPLAIN VERBOSE
SELECT id, c1, c2 FROM tbl04 WHERE id < 2;
--Testcase 142:
SELECT id, c1, c2 FROM tbl04 WHERE id < 2;

--Testcase 143:
EXPLAIN VERBOSE
SELECT id, c1, c2 FROM tbl04 WHERE id <= 2;
--Testcase 144:
SELECT id, c1, c2 FROM tbl04 WHERE id <= 2;

--Testcase 145:
EXPLAIN VERBOSE
SELECT id, c1, c2 FROM tbl04 WHERE id = 2;
--Testcase 146:
SELECT id, c1, c2 FROM tbl04 WHERE id = 2;

--Testcase 147:
EXPLAIN VERBOSE
SELECT id, c1, c2 FROM tbl04 WHERE id <> 2;
--Testcase 148:
SELECT id, c1, c2 FROM tbl04 WHERE id <> 2;

--Testcase 149:
EXPLAIN VERBOSE
SELECT id, c1, c2 FROM tbl04 WHERE id != 2;
--Testcase 150:
SELECT id, c1, c2 FROM tbl04 WHERE id != 2;

--Testcase 151:
EXPLAIN VERBOSE
SELECT id, c1, c2 FROM tbl04 WHERE id NOT BETWEEN 1 AND 5;
--Testcase 152:
SELECT id, c1, c2 FROM tbl04 WHERE id NOT BETWEEN 1 AND 5;

--Testcase 153:
EXPLAIN VERBOSE
SELECT id, c1, c2 FROM tbl04 WHERE id BETWEEN c1 AND c2;
--Testcase 154:
SELECT id, c1, c2 FROM tbl04 WHERE id BETWEEN c1 AND c2;

--Testcase 155:
EXPLAIN VERBOSE
SELECT id, c1, c2 FROM tbl04 WHERE id NOT BETWEEN SYMMETRIC 1 AND 5;
--Testcase 156:
SELECT id, c1, c2 FROM tbl04 WHERE id NOT BETWEEN SYMMETRIC 1 AND 5;

--Testcase 157:
EXPLAIN VERBOSE
SELECT id, c1, c2 FROM tbl04 WHERE id BETWEEN SYMMETRIC c1 AND c2;
--Testcase 158:
SELECT id, c1, c2 FROM tbl04 WHERE id BETWEEN SYMMETRIC c1 AND c2;

--Testcase 159:
EXPLAIN VERBOSE
SELECT id, c1, c2 FROM tbl04 WHERE c1 IS DISTINCT FROM 2; -- does not push down
--Testcase 160:
SELECT id, c1, c2 FROM tbl04 WHERE c1 IS DISTINCT FROM 2; -- does not push down

--Testcase 161:
EXPLAIN VERBOSE
SELECT id, c1, c2 FROM tbl04 WHERE c1 IS DISTINCT FROM id; -- does not push down
--Testcase 162:
SELECT id, c1, c2 FROM tbl04 WHERE c1 IS DISTINCT FROM id; -- does not push down

--Testcase 163:
EXPLAIN VERBOSE
SELECT id, c1, c2 FROM tbl04 WHERE c3 IS NULL;
--Testcase 164:
SELECT id, c1, c2 FROM tbl04 WHERE c3 IS NULL;

--Testcase 165:
EXPLAIN VERBOSE
SELECT id, c1, c2 FROM tbl04 WHERE c3 IS NOT NULL;
--Testcase 166:
SELECT id, c1, c2 FROM tbl04 WHERE c3 IS NOT NULL;

--Testcase 167:
EXPLAIN VERBOSE
SELECT id, c1, c2 FROM tbl04 WHERE c4 IS TRUE;
--Testcase 168:
SELECT id, c1, c2 FROM tbl04 WHERE c4 IS TRUE;

--Testcase 169:
EXPLAIN VERBOSE
SELECT id, c1, c2 FROM tbl04 WHERE c4 IS FALSE;
--Testcase 170:
SELECT id, c1, c2 FROM tbl04 WHERE c4 IS FALSE;

--Testcase 171:
EXPLAIN VERBOSE
SELECT id, c1, c2 FROM tbl04 WHERE c4 IS NOT TRUE;
--Testcase 172:
SELECT id, c1, c2 FROM tbl04 WHERE c4 IS NOT TRUE;

--Testcase 173:
EXPLAIN VERBOSE
SELECT id, c1, c2 FROM tbl04 WHERE c4 IS NOT FALSE;
--Testcase 174:
SELECT id, c1, c2 FROM tbl04 WHERE c4 IS NOT FALSE;

--Testcase 175:
EXPLAIN VERBOSE
SELECT id, c1, c4 FROM tbl04 WHERE c4 IS UNKNOWN; -- does not push down
--Testcase 176:
SELECT id, c1, c4 FROM tbl04 WHERE c4 IS UNKNOWN; -- does not push down

--Testcase 177:
EXPLAIN VERBOSE
SELECT id, c1, c4 FROM tbl04 WHERE c4 IS NOT UNKNOWN; -- does not push down
--Testcase 178:
SELECT id, c1, c4 FROM tbl04 WHERE c4 IS NOT UNKNOWN; -- does not push down
-- Mathematical operator
--Testcase 179:
EXPLAIN VERBOSE
SELECT id, c1, c2 FROM tbl04 WHERE id * 100 + 100 > c2;
--Testcase 180:
SELECT id, c1, c2 FROM tbl04 WHERE c1 * 100 + 100 > c2;

--Testcase 181:
EXPLAIN VERBOSE
SELECT id, c1, c2 FROM tbl04 WHERE c2 - c1 < 0;
--Testcase 182:
SELECT id, c1, c2 FROM tbl04 WHERE c2 - c1 < 0;

--Testcase 183:
EXPLAIN VERBOSE
SELECT id, c1, c2 FROM tbl04 WHERE c2 / 100 > 0; -- does not push down
--Testcase 184:
SELECT id, c1, c2 FROM tbl04 WHERE c2 / 100 > 0; -- does not push down

--Testcase 185:
EXPLAIN VERBOSE
SELECT id, c1, c2 FROM tbl04 WHERE c2 % 2 = 1; -- does not push down
--Testcase 186:
SELECT id, c1, c2 FROM tbl04 WHERE c2 % 2 = 1; -- does not push down

--Testcase 187:
EXPLAIN VERBOSE
SELECT id, id ^ 2 FROM tbl04 WHERE id ^ 2 > 4; -- does not push down
--Testcase 188:
SELECT id, id ^ 2 FROM tbl04 WHERE id ^ 2 > 4; -- does not push down

--Testcase 189:
EXPLAIN VERBOSE
SELECT id, |/id FROM tbl04 WHERE |/id < 4; -- does not push down
--Testcase 190:
SELECT id, |/id FROM tbl04 WHERE |/id < 4; -- does not push down

--Testcase 191:
EXPLAIN VERBOSE
SELECT id, ||/id FROM tbl04 WHERE ||/id < 4; -- does not push down
--Testcase 192:
SELECT id, ||/id FROM tbl04 WHERE ||/id < 4; -- does not push down

--Testcase 193:
EXPLAIN VERBOSE
SELECT id, @c2 FROM tbl04 WHERE @c2 < 1000; -- does not push down
--Testcase 194:
SELECT id, @c2 FROM tbl04 WHERE @c2 < 1000; -- does not push down

--Testcase 195:
EXPLAIN VERBOSE
SELECT id, id & 123 FROM tbl04 WHERE id & 123 < 4; -- does not push down
--Testcase 196:
SELECT id, id & 123 FROM tbl04 WHERE id & 123 < 4; -- does not push down

--Testcase 197:
EXPLAIN VERBOSE
SELECT id, 123 | c2 FROM tbl04 WHERE 123 | c2 > 4; -- does not push down
--Testcase 198:
SELECT id, 123 | c2 FROM tbl04 WHERE 123 | c2 > 4; -- does not push down

--Testcase 199:
EXPLAIN VERBOSE
SELECT id, id # 324 FROM tbl04 WHERE id # 324 > 4; -- does not push down
--Testcase 200:
SELECT id, id # 324 FROM tbl04 WHERE id # 324 > 4; -- does not push down

--Testcase 201:
EXPLAIN VERBOSE
SELECT id, ~id FROM tbl04 WHERE ~id < -2; -- does not push down
--Testcase 202:
SELECT id, ~id FROM tbl04 WHERE ~id < -2; -- does not push down

--Testcase 203:
EXPLAIN VERBOSE
SELECT id, id << 2 FROM tbl04 WHERE id << 2 < 10; -- does not push down
--Testcase 204:
SELECT id, id << 2 FROM tbl04 WHERE id << 2 < 10; -- does not push down

--Testcase 205:
EXPLAIN VERBOSE
SELECT id, id >> 2 FROM tbl04 WHERE id >> 2 = 0; -- does not push down
--Testcase 206:
SELECT id, id >> 2 FROM tbl04 WHERE id >> 2 = 0; -- does not push down

-- String operator
--Testcase 207:
EXPLAIN VERBOSE
SELECT c3 FROM tbl04 WHERE c3 IS NFC NORMALIZED; -- does not push down
--Testcase 208:
SELECT c3 FROM tbl04 WHERE c3 IS NFC NORMALIZED; -- does not push down

--Testcase 209:
EXPLAIN VERBOSE
SELECT c3 FROM tbl04 WHERE c3 IS NOT NFKC NORMALIZED; -- does not push down
--Testcase 210:
SELECT c3 FROM tbl04 WHERE c3 IS NOT NFKC NORMALIZED; -- does not push down

-- Pattern matching operator
--Testcase 211:
EXPLAIN VERBOSE
SELECT c3 FROM tbl04 WHERE c3 LIKE '%hi%';
--Testcase 212:
SELECT c3 FROM tbl04 WHERE c3 LIKE '%hi%';

--Testcase 213:
EXPLAIN VERBOSE
SELECT c3 FROM tbl04 WHERE c3 NOT LIKE '%hi%';
--Testcase 214:
SELECT c3 FROM tbl04 WHERE c3 NOT LIKE '%hi%';

--Testcase 215:
EXPLAIN VERBOSE
SELECT c3 FROM tbl04 WHERE c3 ILIKE '%Hi%'; -- does not push down
--Testcase 216:
SELECT c3 FROM tbl04 WHERE c3 ILIKE '%Hi%'; -- does not push down

--Testcase 217:
EXPLAIN VERBOSE
SELECT c3 FROM tbl04 WHERE c3 NOT ILIKE '%Hi%'; -- does not push down
--Testcase 218:
SELECT c3 FROM tbl04 WHERE c3 NOT ILIKE '%Hi%'; -- does not push down

--Testcase 219:
EXPLAIN VERBOSE
SELECT c3 FROM tbl04 WHERE c3 SIMILAR TO '%(y|w)%'; -- does not push down
--Testcase 220:
SELECT c3 FROM tbl04 WHERE c3 SIMILAR TO '%(y|w)%'; -- does not push down

--Testcase 221:
EXPLAIN VERBOSE
SELECT c3 FROM tbl04 WHERE c3 NOT SIMILAR TO '%(y|w)%'; -- does not push down
--Testcase 222:
SELECT c3 FROM tbl04 WHERE c3 NOT SIMILAR TO '%(y|w)%'; -- does not push down

--Testcase 223:
EXPLAIN VERBOSE
SELECT c3 FROM tbl04 WHERE c3 ~ 'any.*'; -- does not push down
--Testcase 224:
SELECT c3 FROM tbl04 WHERE c3 ~ 'any.*'; -- does not push down

--Testcase 225:
EXPLAIN VERBOSE
SELECT c3 FROM tbl04 WHERE c3 ~* 'ANY.*'; -- does not push down
--Testcase 226:
SELECT c3 FROM tbl04 WHERE c3 ~* 'ANY.*'; -- does not push down


--Testcase 227:
EXPLAIN VERBOSE
SELECT c3 FROM tbl04 WHERE c3 !~ 'any.*'; -- does not push down
--Testcase 228:
SELECT c3 FROM tbl04 WHERE c3 !~ 'any.*'; -- does not push down

--Testcase 229:
EXPLAIN VERBOSE
SELECT c3 FROM tbl04 WHERE c3 !~* 'ANY.*'; -- does not push down
--Testcase 230:
SELECT c3 FROM tbl04 WHERE c3 !~* 'ANY.*'; -- does not push down

-- test for specific type
--Testcase 231:
ALTER TABLE tbl04 ALTER COLUMN c3 TYPE inet;
--Testcase 232:
EXPLAIN VERBOSE
SELECT id FROM tbl04 WHERE c3 + 1 > inet '192.168.1.100'; -- does not push down

--Testcase 233:
ALTER TABLE tbl04 ALTER COLUMN c3 TYPE json;
--Testcase 234:
EXPLAIN VERBOSE
SELECT id FROM tbl04 WHERE c3->>'tag' = 'test data'; -- does not push down

--Testcase 235:
ALTER TABLE tbl04 ALTER COLUMN c3 TYPE jsonb;
--Testcase 236:
EXPLAIN VERBOSE
SELECT id FROM tbl04 WHERE c3->>'tag' = 'test data'; -- does not push down

--Testcase 237:
ALTER TABLE tbl04 ALTER COLUMN c3 TYPE point;
--Testcase 238:
EXPLAIN VERBOSE
SELECT id FROM tbl04 WHERE c3 >> point '(1, 3)'; -- does not push down
-- reset c3 column type
--Testcase 239:
ALTER TABLE tbl04 ALTER COLUMN c3 TYPE text;

-- Reset data for tbl04;
--Testcase 240:
DELETE FROM tbl04 WHERE id > 10;

--Testcase 70:
DROP SERVER :DB_SERVERNAME CASCADE;
--Testcase 71:
DROP EXTENSION :DB_EXTENSIONNAME CASCADE;
