--
-- function push-down
--
--Testcase 1:
CREATE EXTENSION IF NOT EXISTS :DB_EXTENSIONNAME;
--Testcase 2:
CREATE SERVER :DB_SERVERNAME FOREIGN DATA WRAPPER :DB_EXTENSIONNAME
  OPTIONS (odbc_DRIVER :DB_DRIVERNAME, odbc_SERVER :DB_SERVER, odbc_port :DB_PORT, odbc_DATABASE :DB_DATABASE);
--Testcase 3:
CREATE USER MAPPING FOR CURRENT_USER SERVER :DB_SERVERNAME OPTIONS (odbc_UID :DB_USER, odbc_PWD :DB_PASS);


--Testcase 4:
CREATE FOREIGN TABLE s1(id int, tag1 text, value1 float, value2 int, value3 float, value4 int, value5 numeric, str1 text, str2 text)
  SERVER :DB_SERVERNAME OPTIONS (schema :DB_SCHEMA, table 's1');

--Testcase 5:
CREATE FOREIGN TABLE tbl04 (id int OPTIONS (key 'true'),  c1 float8, c2 bigint, c3 text, c4 boolean, c5 timestamp)
  SERVER :DB_SERVERNAME OPTIONS (schema :DB_SCHEMA, table 'tbl04');

--Testcase 6:
EXPLAIN VERBOSE
SELECT NULLIF(value2, 100) FROM s1 WHERE NULLIF(value2, 100) IS NULL;
--Testcase 7:
SELECT NULLIF(value2, 100) FROM s1 WHERE NULLIF(value2, 100) IS NULL;

-- numeric function
--Testcase 8:
EXPLAIN VERBOSE
SELECT abs(value1) FROM s1 WHERE abs(value1) > 1;
--Testcase 9:
SELECT abs(value1) FROM s1 WHERE abs(value1) > 1;

--Testcase 10:
EXPLAIN VERBOSE
SELECT acos(value1) FROM s1 WHERE value1 < 1 AND acos(value1) > 1;
--Testcase 11:
SELECT acos(value1) FROM s1 WHERE value1 < 1 AND acos(value1) > 1;

--Testcase 12:
EXPLAIN VERBOSE
SELECT asin(value1) FROM s1 WHERE value1 < 1 AND asin(value1) < 1;
--Testcase 13:
SELECT asin(value1) FROM s1 WHERE value1 < 1 AND asin(value1) < 1;

--Testcase 14:
EXPLAIN VERBOSE
SELECT atan(id) FROM s1 WHERE atan(id) > 0.2;
--Testcase 15:
SELECT atan(id) FROM s1 WHERE atan(id) > 0.2;

--Testcase 16:
EXPLAIN VERBOSE
SELECT atan2(PI(), id) FROM s1 WHERE atan2(PI(), id) > 0.2;
--Testcase 17:
SELECT atan2(PI(), id) FROM s1 WHERE atan2(PI(), id) > 0.2;

--Testcase 18:
EXPLAIN VERBOSE
SELECT ceil(value1) FROM s1 WHERE ceil(value1) > 0;
--Testcase 19:
SELECT ceil(value1) FROM s1 WHERE ceil(value1) > 0;

--Testcase 20:
EXPLAIN VERBOSE
SELECT ceiling(value1) FROM s1 WHERE ceiling(value1) > 0;
--Testcase 21:
SELECT ceiling(value1) FROM s1 WHERE ceiling(value1) > 0;

--Testcase 22:
EXPLAIN VERBOSE
SELECT cos(value1) FROM s1 WHERE cos(value1) > 0;
--Testcase 23:
SELECT cos(value1) FROM s1 WHERE cos(value1) > 0;

--Testcase 24:
EXPLAIN VERBOSE
SELECT cot(value1) FROM s1 WHERE cot(value1) > 0;
--Testcase 25:
SELECT cot(value1) FROM s1 WHERE cot(value1) > 0;

--Testcase 26:
EXPLAIN VERBOSE
SELECT degrees(value1) FROM s1 WHERE degrees(value1) > 0;
--Testcase 27:
SELECT degrees(value1) FROM s1 WHERE degrees(value1) > 0;

--Testcase 28:
EXPLAIN VERBOSE
SELECT exp(value1) FROM s1 WHERE exp(value1) > 0;
--Testcase 29:
SELECT exp(value1) FROM s1 WHERE exp(value1) > 0;

--Testcase 30:
EXPLAIN VERBOSE
SELECT floor(value1) FROM s1 WHERE floor(value1) > 0;
--Testcase 31:
SELECT floor(value1) FROM s1 WHERE floor(value1) > 0;

--Testcase 32:
EXPLAIN VERBOSE
SELECT ln(value1) FROM s1 WHERE ln(value1) > 0;
--Testcase 33:
SELECT ln(value1) FROM s1 WHERE ln(value1) > 0;

--Testcase 34:
EXPLAIN VERBOSE
SELECT value5, log(2, value5) FROM s1 WHERE log(2, value5) > 0;
--Testcase 35:
SELECT value5, log(2, value5) FROM s1 WHERE log(2, value5) > 0;

--Testcase 37:
EXPLAIN VERBOSE
SELECT log(value1) FROM s1 WHERE log(value1) > 0; -- Does not push down
--Testcase 38:
SELECT log(value1) FROM s1 WHERE log(value1) > 0; -- Does not push down

--Testcase 39:
EXPLAIN VERBOSE
SELECT log10(value1) FROM s1 WHERE log10(value1) > 0;
--Testcase 40:
SELECT log10(value1) FROM s1 WHERE log10(value1) > 0;

--Testcase 41:
EXPLAIN VERBOSE
SELECT mod(value2, id + 1) FROM s1 WHERE mod(value2, id + 1) > 0;
--Testcase 42:
SELECT mod(value2, id + 1) FROM s1 WHERE mod(value2, id + 1) > 0;

--Testcase 43:
EXPLAIN VERBOSE
SELECT pow(value2, id) FROM s1 WHERE pow(value2, id) > 0;
--Testcase 44:
SELECT pow(value2, id) FROM s1 WHERE pow(value2, id) > 0;

--Testcase 45:
EXPLAIN VERBOSE
SELECT power(value2, id) FROM s1 WHERE power(value2, id) > 0;
--Testcase 46:
SELECT power(value2, id) FROM s1 WHERE power(value2, id) > 0;

--Testcase 47:
EXPLAIN VERBOSE
SELECT radians(value1) FROM s1 WHERE radians(value1) > 0;
--Testcase 48:
SELECT radians(value1) FROM s1 WHERE radians(value1) > 0;

--Testcase 49:
EXPLAIN VERBOSE
SELECT round(value1) FROM s1 WHERE round(value1) > 0;
--Testcase 50:
SELECT round(value1) FROM s1 WHERE round(value1) > 0;

--Testcase 51:
EXPLAIN VERBOSE
SELECT sign(value3), value3 FROM s1 WHERE sign(value3) = -1;
--Testcase 52:
SELECT sign(value3), value3 FROM s1 WHERE sign(value3) = -1;

--Testcase 53:
EXPLAIN VERBOSE
SELECT sin(value1) FROM s1 WHERE sin(value1) > 0;
--Testcase 54:
SELECT sin(value1) FROM s1 WHERE sin(value1) > 0;

--Testcase 55:
EXPLAIN VERBOSE
SELECT sqrt(value1) FROM s1 WHERE sqrt(value1) > 0;
--Testcase 56:
SELECT sqrt(value1) FROM s1 WHERE sqrt(value1) > 0;

--Testcase 57:
EXPLAIN VERBOSE
SELECT tan(value1) FROM s1 WHERE tan(value1) > 0;
--Testcase 58:
SELECT tan(value1) FROM s1 WHERE tan(value1) > 0;

--Testcase 59:
EXPLAIN VERBOSE
SELECT round(value1) FROM s1 WHERE round(value1) > 0;
--Testcase 60:
SELECT round(value1) FROM s1 WHERE round(value1) > 0;

-- date/time function:
--Testcase 61:
EXPLAIN VERBOSE
SELECT date(c5) FROM tbl04 WHERE date(c5) > '1970-01-01';
--Testcase 62:
SELECT date(c5) FROM tbl04 WHERE date(c5) > '1970-01-01';

-- string function:
--Testcase 63:
EXPLAIN VERBOSE
SELECT ascii(str1), ascii(str2) FROM s1 WHERE ascii(str1) > 0;
--Testcase 64:
SELECT ascii(str1), ascii(str2) FROM s1 WHERE ascii(str1) > 0;

--Testcase 65:
-- for bit_length() function, postgre's core will optimize it to octet_length() * 8 and push it down
EXPLAIN VERBOSE
SELECT bit_length(str1), bit_length(str2) FROM s1 WHERE bit_length(str1) > 0;
--Testcase 66:
SELECT bit_length(str1), bit_length(str2) FROM s1 WHERE bit_length(str1) > 0;

--Testcase 67:
EXPLAIN VERBOSE
SELECT btrim(str2) FROM s1 WHERE btrim(str2) LIKE 'XYZ'; -- Does not push-down
--Testcase 68:
SELECT btrim(str2) FROM s1 WHERE btrim(str2) LIKE 'XYZ'; -- Does not push-down

--Testcase 69:
EXPLAIN VERBOSE
SELECT btrim(str2, ' ') FROM s1 WHERE btrim(str2, ' ') LIKE 'XYZ'; -- Does not push-down
--Testcase 70:
SELECT btrim(str2, ' ') FROM s1 WHERE btrim(str2, ' ') LIKE 'XYZ'; -- Does not push-down

--Testcase 71:
EXPLAIN VERBOSE
SELECT char_length(str1), char_length(str2) FROM s1 WHERE char_length(str1) > 0;
--Testcase 72:
SELECT char_length(str1), char_length(str2) FROM s1 WHERE char_length(str1) > 0;

--Testcase 73:
EXPLAIN VERBOSE
SELECT character_length(str1), character_length(str2) FROM s1 WHERE character_length(str1) > 0;
--Testcase 74:
SELECT character_length(str1), character_length(str2) FROM s1 WHERE character_length(str1) > 0;

--Testcase 75:
EXPLAIN VERBOSE
SELECT concat(str1, str2) FROM s1 WHERE concat(str1, str2) LIKE '---XYZ---   XYZ   ';
--Testcase 76:
SELECT concat(str1, str2) FROM s1 WHERE concat(str1, str2) LIKE '---XYZ---   XYZ   ';

--Testcase 77:
EXPLAIN VERBOSE
SELECT concat_ws(',', str1, str2) FROM s1 WHERE concat_ws(',', str1, str2) LIKE '---XYZ---,   XYZ   ';
--Testcase 78:
SELECT concat_ws(',', str1, str2) FROM s1 WHERE concat_ws(',', str1, str2) LIKE '---XYZ---,   XYZ   ';

--Testcase 79:
EXPLAIN VERBOSE
SELECT left(str1, 3) FROM s1 WHERE left(str1, 3) LIKE '---';
--Testcase 80:
SELECT left(str1, 3) FROM s1 WHERE left(str1, 3) LIKE '---';

--Testcase 81:
EXPLAIN VERBOSE
SELECT length(str1), length(str2) FROM s1 WHERE length(str1) > 0;
--Testcase 82:
SELECT length(str1), length(str2) FROM s1 WHERE length(str1) > 0;

--Testcase 83:
EXPLAIN VERBOSE
SELECT lower(str1), lower(str2) FROM s1 WHERE lower(str1) LIKE '%xyz%';
--Testcase 84:
SELECT lower(str1), lower(str2) FROM s1 WHERE lower(str1) LIKE '%xyz%';

--Testcase 85:
EXPLAIN VERBOSE
SELECT lpad(str1, 20, 'ABCD'), lpad(str2, 20, 'ABCD') FROM s1 WHERE lpad(str1, 20, 'ABCD') LIKE '%XYZ%';
--Testcase 86:
SELECT lpad(str1, 20, 'ABCD'), lpad(str2, 20, 'ABCD') FROM s1 WHERE lpad(str1, 20, 'ABCD') LIKE '%XYZ%';

--Testcase 87:
EXPLAIN VERBOSE
SELECT ltrim(str2) FROM s1 WHERE ltrim(str2) LIKE 'XYZ   '; -- Does not push-down
--Testcase 88:
SELECT ltrim(str2) FROM s1 WHERE ltrim(str2) LIKE 'XYZ   '; -- Does not push-down

--Testcase 89:
EXPLAIN VERBOSE
SELECT ltrim(str2, ' ') FROM s1 WHERE ltrim(str2, ' ') LIKE 'XYZ   '; -- Does not push-down
--Testcase 90:
SELECT ltrim(str2, ' ') FROM s1 WHERE ltrim(str2, ' ') LIKE 'XYZ   '; -- Does not push-down

--Testcase 91:
EXPLAIN VERBOSE
SELECT octet_length(str1), octet_length(str2) FROM s1 WHERE octet_length(str1) > 0;
--Testcase 92:
SELECT octet_length(str1), octet_length(str2) FROM s1 WHERE octet_length(str1) > 0;

--Testcase 93:
EXPLAIN VERBOSE
SELECT position('X' IN str1) FROM s1 WHERE position('X' IN str1) > 0;
--Testcase 94:
SELECT position('X' IN str1) FROM s1 WHERE position('X' IN str1) > 0;

--Testcase 95:
EXPLAIN VERBOSE
SELECT regexp_replace(str1, 'X..', 'xyz') FROM s1 WHERE regexp_replace(str1, 'X..', 'xyz') LIKE '%xyz%';
--Testcase 96:
SELECT regexp_replace(str1, 'X..', 'xyz') FROM s1 WHERE regexp_replace(str1, 'X..', 'xyz') LIKE '%xyz%';

--Testcase 97:
EXPLAIN VERBOSE
SELECT regexp_replace(str1, '[Y]', 'y', 'i') FROM s1 WHERE regexp_replace(str1, '[Y]', 'y', 'i') LIKE '%XyZ%';
--Testcase 98:
SELECT regexp_replace(str1, '[Y]', 'y', 'i') FROM s1 WHERE regexp_replace(str1, '[Y]', 'y', 'i') LIKE '%XyZ%';

--Testcase 99:
EXPLAIN VERBOSE
SELECT repeat(str1, 3), repeat(str2, 3) FROM s1 WHERE repeat(str2, 3) LIKE '%X%';
--Testcase 100:
SELECT repeat(str1, 3), repeat(str2, 3) FROM s1 WHERE repeat(str2, 3) LIKE '%X%';

--Testcase 101:
EXPLAIN VERBOSE
SELECT replace(str1, 'XYZ', 'ABC') FROM s1 WHERE replace(str1, 'XYZ', 'ABC') LIKE '%A%';
--Testcase 102:
SELECT replace(str1, 'XYZ', 'ABC') FROM s1 WHERE replace(str1, 'XYZ', 'ABC') LIKE '%A%';

--Testcase 103:
EXPLAIN VERBOSE
SELECT reverse(str1), reverse(str2) FROM s1 WHERE reverse(str1) LIKE '%ZYX%';
--Testcase 104:
SELECT reverse(str1), reverse(str2) FROM s1 WHERE reverse(str1) LIKE '%ZYX%';

--Testcase 105:
EXPLAIN VERBOSE
SELECT right(str1, 4), right(str2, 4) FROM s1 WHERE right(str1, 4) LIKE 'Z%';
--Testcase 106:
SELECT right(str1, 4), right(str2, 4) FROM s1 WHERE right(str1, 4) LIKE 'Z%';

--Testcase 107:
EXPLAIN VERBOSE
SELECT rpad(str1, 16, str2), rpad(str1, 4, str2) FROM s1 WHERE rpad(str1, 16, str2) LIKE '---XYZ---%';
--Testcase 108:
SELECT rpad(str1, 16, str2), rpad(str1, 4, str2) FROM s1 WHERE rpad(str1, 16, str2) LIKE '---XYZ---%';

--Testcase 109:
EXPLAIN VERBOSE
SELECT rtrim(str2) FROM s1 WHERE rtrim(str2) LIKE '%XYZ'; -- Does not push-down
--Testcase 110:
SELECT rtrim(str2) FROM s1 WHERE rtrim(str2) LIKE '%XYZ'; -- Does not push-down


--Testcase 111:
EXPLAIN VERBOSE
SELECT rtrim(str2, ' ') FROM s1 WHERE rtrim(str2, ' ') LIKE '%XYZ'; -- Does not push-down
--Testcase 112:
SELECT rtrim(str2, ' ') FROM s1 WHERE rtrim(str2, ' ') LIKE '%XYZ'; -- Does not push-down

--Testcase 113:
EXPLAIN VERBOSE
SELECT substr(str1, 3) FROM s1 WHERE substr(str1, 3) LIKE '-XYZ---';
--Testcase 114:
SELECT substr(str1, 3) FROM s1 WHERE substr(str1, 3) LIKE '-XYZ---';

--Testcase 115:
EXPLAIN VERBOSE
SELECT substr(str2, 3, 4) FROM s1 WHERE substr(str2, 3, 4) LIKE ' XYZ';
--Testcase 116:
SELECT substr(str2, 3, 4) FROM s1 WHERE substr(str2, 3, 4) LIKE ' XYZ';

--Testcase 117:
EXPLAIN VERBOSE
SELECT substring(str1, 3) FROM s1 WHERE substring(str1, 3) LIKE '-XYZ---';
--Testcase 118:
SELECT substring(str1, 3) FROM s1 WHERE substring(str1, 3) LIKE '-XYZ---';

--Testcase 119:
EXPLAIN VERBOSE
SELECT substring(str2, 3, 4) FROM s1 WHERE substring(str2, 3, 4) LIKE ' XYZ';
--Testcase 120:
SELECT substring(str2, 3, 4) FROM s1 WHERE substring(str2, 3, 4) LIKE ' XYZ';

--Testcase 121:
EXPLAIN VERBOSE
SELECT substring(str1 FROM 3) FROM s1 WHERE substring(str1 FROM 3) LIKE '-XYZ---';
--Testcase 122:
SELECT substring(str1 FROM 3) FROM s1 WHERE substring(str1 FROM 3) LIKE '-XYZ---';

--Testcase 123:
EXPLAIN VERBOSE
SELECT substring(str2 FROM 3 FOR 4) FROM s1 WHERE substring(str2 FROM 3 FOR 4) LIKE ' XYZ';
--Testcase 124:
SELECT substring(str2 FROM 3 FOR 4) FROM s1 WHERE substring(str2 FROM 3 FOR 4) LIKE ' XYZ';

--Testcase 125:
EXPLAIN VERBOSE
SELECT trim(str2) FROM s1 WHERE trim(str2) LIKE 'XYZ'; -- Does not push-down
--Testcase 126:
SELECT trim(str2) FROM s1 WHERE trim(str2) LIKE 'XYZ'; -- Does not push-down

--Testcase 127:
EXPLAIN VERBOSE
SELECT trim('-' FROM str1) FROM s1 WHERE trim('-' FROM str1) LIKE 'XYZ'; -- Does not push-down
--Testcase 128:
SELECT trim('-' FROM str1) FROM s1 WHERE trim('-' FROM str1) LIKE 'XYZ'; -- Does not push-down

--Testcase 129:
EXPLAIN VERBOSE
SELECT trim(LEADING '-' FROM str1) FROM s1 WHERE trim(LEADING '-' FROM str1) LIKE 'XYZ---'; -- Does not push-down
--Testcase 130:
SELECT trim(LEADING '-' FROM str1) FROM s1 WHERE trim(LEADING '-' FROM str1) LIKE 'XYZ---'; -- Does not push-down

--Testcase 131:
EXPLAIN VERBOSE
SELECT trim(BOTH '-' FROM str1) FROM s1 WHERE trim(BOTH '-' FROM str1) LIKE 'XYZ'; -- Does not push-down
--Testcase 132:
SELECT trim(BOTH '-' FROM str1) FROM s1 WHERE trim(BOTH '-' FROM str1) LIKE 'XYZ'; -- Does not push-down

--Testcase 133:
EXPLAIN VERBOSE
SELECT trim(TRAILING '-' FROM str1) FROM s1 WHERE trim(TRAILING '-' FROM str1) LIKE '---XYZ'; -- Does not push-down
--Testcase 134:
SELECT trim(TRAILING '-' FROM str1) FROM s1 WHERE trim(TRAILING '-' FROM str1) LIKE '---XYZ'; -- Does not push-down

--Testcase 135:
EXPLAIN VERBOSE
SELECT upper(tag1) FROM s1 WHERE upper(tag1) LIKE 'A';
--Testcase 136:
SELECT upper(tag1) FROM s1 WHERE upper(tag1) LIKE 'A';

-- explicit cast function:
--Testcase 137:
EXPLAIN VERBOSE
SELECT cos(value1::decimal), value1::decimal FROM s1 WHERE cos(value1::decimal) > 0; -- Does not push down
--Testcase 138:
SELECT cos(value1::decimal), value1::decimal FROM s1 WHERE cos(value1::decimal) > 0; -- Does not push down

--Testcase 139:
EXPLAIN VERBOSE
SELECT cos(value1::decimal(10,0)), value1::decimal(10,0) FROM s1 WHERE cos(value1::decimal(10,0)) > 0; -- Does not push down
--Testcase 140:
SELECT cos(value1::decimal(10,0)), value1::decimal(10,0) FROM s1 WHERE cos(value1::decimal(10,0)) > 0; -- Does not push down

--Testcase 141:
EXPLAIN VERBOSE
SELECT cos(value1::numeric), value1::numeric FROM s1 WHERE cos(value1::numeric) > 0; -- Does not push down
--Testcase 142:
SELECT cos(value1::numeric), value1::numeric FROM s1 WHERE cos(value1::numeric) > 0; -- Does not push down

--Testcase 143:
EXPLAIN VERBOSE
SELECT cos(value1::numeric(10,1)), value1::numeric(10,1) FROM s1 WHERE cos(value1::numeric(10,1)) > 0; -- Does not push down
--Testcase 144:
SELECT cos(value1::numeric(10,1)), value1::numeric(10,1) FROM s1 WHERE cos(value1::numeric(10,1)) > 0; -- Does not push down

--Testcase 145:
EXPLAIN VERBOSE
SELECT value2::char FROM s1 WHERE value2::char LIKE '1'; -- Does not push down
--Testcase 146:
SELECT value2::char FROM s1 WHERE value2::char LIKE '1'; -- Does not push down

--Testcase 147:
EXPLAIN VERBOSE
SELECT value2::varchar FROM s1 WHERE value2::varchar LIKE '100'; -- Does not push down
--Testcase 148:
SELECT value2::varchar FROM s1 WHERE value2::varchar LIKE '100'; -- Does not push down

--Testcase 149:
EXPLAIN VERBOSE
SELECT value2::char(6) FROM s1 WHERE value2::char(6) LIKE '100   '; -- Does not push down
--Testcase 150:
SELECT value2::char(6) FROM s1 WHERE value2::char(6) LIKE '100   '; -- Does not push down

--Testcase 151:
EXPLAIN VERBOSE
SELECT value2::varchar(6) FROM s1 WHERE value2::varchar(6) LIKE '100'; -- Does not push down
--Testcase 152:
SELECT value2::varchar(6) FROM s1 WHERE value2::varchar(6) LIKE '100'; -- Does not push down

--Testcase 153:
EXPLAIN VERBOSE
SELECT value2::text FROM s1 WHERE value2::text LIKE '100'; -- Does not push down
--Testcase 154:
SELECT value2::text FROM s1 WHERE value2::text LIKE '100'; -- Does not push down

--Testcase 155:
EXPLAIN VERBOSE
SELECT value2::smallint FROM s1 WHERE value2::smallint > 20; -- Does not push down
--Testcase 156:
SELECT value2::smallint FROM s1 WHERE value2::smallint > 20; -- Does not push down

--Testcase 157:
EXPLAIN VERBOSE
SELECT c1::int FROM tbl04 WHERE c1::int > 20; -- Does not push down
--Testcase 158:
SELECT c1::int FROM tbl04 WHERE c1::int > 20; -- Does not push down

--Testcase 159:
EXPLAIN VERBOSE
SELECT c2::double precision FROM tbl04 WHERE c2::double precision > 20; -- Does not push down
--Testcase 160:
SELECT c2::double precision FROM tbl04 WHERE c2::double precision > 20; -- Does not push down

--Testcase 161:
EXPLAIN VERBOSE
SELECT c2::real FROM tbl04 WHERE c2::real > 20;
--Testcase 162:
SELECT c2::real FROM tbl04 WHERE c2::real > 20;

--Testcase 163:
EXPLAIN VERBOSE
SELECT c2::float4 FROM tbl04 WHERE c2::float4 > 20;
--Testcase 164:
SELECT c2::float4 FROM tbl04 WHERE c2::float4 > 20;

--Testcase 165:
EXPLAIN VERBOSE
SELECT c5::date FROM tbl04 WHERE c5::date > '2001-01-01'::date;
--Testcase 166:
SELECT c5::date FROM tbl04 WHERE c5::date > '2001-01-01'::date;

--Testcase 167:
EXPLAIN VERBOSE
SELECT c5::time FROM tbl04 WHERE c5::time > '00:00:00'::time;
--Testcase 168:
SELECT c5::time FROM tbl04 WHERE c5::time > '00:00:00'::time;

--Testcase 169:
DROP FOREIGN TABLE s1;
--Testcase 170:
DROP FOREIGN TABLE tbl04;

--Testcase 171:
DROP USER MAPPING FOR CURRENT_USER SERVER :DB_SERVERNAME;
--Testcase 172:
DROP SERVER :DB_SERVERNAME CASCADE;
--Testcase 173:
DROP EXTENSION :DB_EXTENSIONNAME CASCADE;
