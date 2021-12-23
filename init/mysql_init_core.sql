DROP DATABASE IF EXISTS odbc_fdw_regress;
CREATE DATABASE odbc_fdw_regress;
SET GLOBAL validate_password.policy = LOW;
SET GLOBAL validate_password.length = 1;
SET GLOBAL validate_password.mixed_case_count = 0;
SET GLOBAL validate_password.number_count = 0;
SET GLOBAL validate_password.special_char_count = 0;

SET GLOBAL time_zone = '-8:00';
SET GLOBAL log_bin_trust_function_creators = 1;
SET GLOBAL local_infile=1;

USE odbc_fdw_regress;

CREATE TABLE onek (
	unique1		int4,
	unique2		int4,
	two			int4,
	four		int4,
	ten			int4,
	twenty		int4,
	hundred		int4,
	thousand	int4,
	twothousand	int4,
	fivethous	int4,
	tenthous	int4,
	odd			int4,
	even		int4,
	stringu1	varchar(64),
	stringu2	varchar(64),
	string4		varchar(64)
);

CREATE TABLE onek2 (
	unique1		int4,
	unique2		int4,
	two			int4,
	four		int4,
	ten			int4,
	twenty		int4,
	hundred		int4,
	thousand	int4,
	twothousand	int4,
	fivethous	int4,
	tenthous	int4,
	odd			int4,
	even		int4,
	stringu1	varchar(64),
	stringu2	varchar(64),
	string4		varchar(64)
);

CREATE TABLE aggtest (
	id 			int4 PRIMARY KEY,
	a 			int2,
	b 			float4
);
CREATE TABLE tenk1 (
	unique1		int4,
	unique2		int4,
	two			int4,
	four		int4,
	ten			int4,
	twenty		int4,
	hundred		int4,
	thousand	int4,
	twothousand	int4,
	fivethous	int4,
	tenthous	int4,
	odd			int4,
	even		int4,
	stringu1	varchar(64),
	stringu2	varchar(64),
	string4		varchar(64)
);

CREATE TABLE multi_arg_agg (a int4 PRIMARY KEY, b int, c text);
CREATE TABLE int4_tbl(id int4 PRIMARY KEY, f1 int4);
CREATE TABLE int4_tmp(id SERIAL PRIMARY KEY , a int4, b int4);
CREATE TABLE int4_tbl_tmp(id int4 PRIMARY KEY, f1 int4);
CREATE TABLE int4_tbl_tmp2(id SERIAL PRIMARY KEY , a int4, b int4);
CREATE TABLE int8_tbl(id SERIAL PRIMARY KEY, q1 int8, q2 int8);
CREATE TABLE int8_tbl_tmp(id SERIAL PRIMARY KEY, q1 int8, q2 int8);
CREATE TABLE float8_tbl (f1 float8, id SERIAL PRIMARY KEY);
CREATE TABLE float8_tmp (id SERIAL PRIMARY KEY, f1 float8, f2 float8);
CREATE TABLE float8_tbl_tmp (id SERIAL PRIMARY KEY, f1 float8);
CREATE TABLE float4_tbl (f1 float4, id SERIAL PRIMARY KEY);
CREATE TABLE float4_tbl_tmp (f1 float4, id SERIAL PRIMARY KEY);

CREATE TABLE bitwise_test (
	id			SERIAL PRIMARY KEY,
	i2			INT2,
	i4			INT4,
	i8			INT8,
	i			INTEGER,
	x			INT2,
	y			text
);

CREATE TABLE bool_test_a (
	id			SERIAL PRIMARY KEY,
	a1			BOOL,
	a2			BOOL,
	a3			BOOL,
	a4			BOOL,
	a5			BOOL,
	a6			BOOL,
	a7			BOOL,
	a8			BOOL,
	a9			BOOL
);
CREATE TABLE bool_test_b (
	id			SERIAL PRIMARY KEY,
	b1			BOOL,
	b2			BOOL,
	b3			BOOL,
	b4			BOOL,
	b5			BOOL,
	b6			BOOL,
	b7			BOOL,
	b8			BOOL,
	b9			BOOL
);
CREATE TABLE bool_test (
	id			SERIAL PRIMARY KEY,
	b1			BOOL,
	b2			BOOL,
	b3			BOOL,
	b4			BOOL
);
CREATE TABLE minmaxtest (f1 int);
CREATE TABLE agg_t1 (a int PRIMARY KEY, b int, c int, d int);
CREATE TABLE agg_t2 (x int PRIMARY KEY, y int, z int);
CREATE TABLE test_data (id SERIAL PRIMARY KEY, bits text);
CREATE TABLE inserttest01 (id SERIAL PRIMARY KEY, col1 int4, col2 int4 NOT NULL, col3 text);
CREATE TABLE department (department_id integer PRIMARY KEY, department_name text);
CREATE TABLE employee (emp_id integer PRIMARY KEY, emp_name text, emp_dept_id integer);
CREATE TABLE numbers (a integer PRIMARY KEY, b text);
CREATE TABLE shorty (id integer PRIMARY KEY, c text);
CREATE TABLE evennumbers (a integer PRIMARY KEY, b text);
CREATE TABLE person (name text, age int4, location text);
CREATE TABLE bar (id SERIAL PRIMARY KEY, a text, b int, c int);
CREATE TABLE foo (id SERIAL PRIMARY KEY, f1 int);
CREATE TABLE update_test (    id  SERIAL PRIMARY KEY,
    a   INT DEFAULT 10,
    b   INT,
    c   TEXT);

CREATE TABLE tenk (
	unique1		int4,
	unique2		int4,
	two			int4,
	four		int4,
	ten			int4,
	twenty		int4,
	hundred		int4,
	thousand	int4,
	twothousand	int4,
	fivethous	int4,
	tenthous	int4,
	odd			int4,
	even		int4,
	stringu1	varchar(64),
	stringu2	varchar(64),
	string4		varchar(64)
);

CREATE TABLE char_tbl (f1 char, id int primary key auto_increment);
CREATE TABLE char_tbl_2 (f1 char(4), id int primary key auto_increment);
CREATE TABLE date_tbl (f1 date, id int primary key auto_increment);
CREATE TABLE regr_test(id int, x double, y double);

INSERT INTO bool_test VALUES (1, TRUE,null,FALSE,null);
INSERT INTO bool_test VALUES (2, FALSE,TRUE,null,null);
INSERT INTO bool_test VALUES (3, null,TRUE,FALSE,null);
CREATE TABLE string_agg1(id int, a char(10));
INSERT INTO string_agg1 VALUES (1, 'aaaa');
INSERT INTO string_agg1 VALUES (2, 'bbbb');
INSERT INTO string_agg1 VALUES (3, 'cccc');

CREATE TABLE string_agg2(id int, a char(10));
INSERT INTO string_agg2 VALUES (1, 'aaaa');
INSERT INTO string_agg2 VALUES (2, null);
INSERT INTO string_agg2 VALUES (3, 'bbbb');
INSERT INTO string_agg2 VALUES (4, 'cccc');
CREATE TABLE string_agg3(id int, a char(10));
INSERT INTO string_agg3 VALUES (1, null);
INSERT INTO string_agg3 VALUES (2, null);
INSERT INTO string_agg3 VALUES (3, 'bbbb');
INSERT INTO string_agg3 VALUES (4, 'cccc');
CREATE TABLE string_agg4(id int, a char(10));
INSERT INTO string_agg4 VALUES (1, null);
INSERT INTO string_agg4 VALUES (2, null);

create table bytea_test_table(id int primary key, v VARBINARY(10));
CREATE TABLE agg_fns_1 (id int, a int);
INSERT INTO agg_fns_1 VALUES (1, 1);
INSERT INTO agg_fns_1 VALUES (2, 2);
INSERT INTO agg_fns_1 VALUES (3, 1);
INSERT INTO agg_fns_1 VALUES (4, 3);
INSERT INTO agg_fns_1 VALUES (5, null);
INSERT INTO agg_fns_1 VALUES (6, 2);

CREATE TABLE agg_fns_2 (a int, b int, c char(10));
INSERT INTO agg_fns_2 VALUES (1, 3, 'foo');
INSERT INTO agg_fns_2 VALUES (0, null, null);
INSERT INTO agg_fns_2 VALUES (2, 2, 'bar');
INSERT INTO agg_fns_2 VALUES (3, 1, 'baz');

CREATE TABLE delete_test (id SERIAL, a INT, b varchar(10000));

CREATE TABLE inserttest (col1 int4, col2 int4 not null, col3 varchar(10000), id int primary key auto_increment);
INSERT INTO foo (f1) VALUES (42),(3),(10),(7),(null),(null),(1);
CREATE TABLE upsert_test (a INT PRIMARY KEY, b varchar(10));
CREATE TABLE timestamp_tbl (id int primary key, d1 timestamp(2));
CREATE TABLE timestamp_tmp (id int primary key, d1 timestamp(6), d2 timestamp(6));

-- import data from csv file
LOAD DATA LOCAL INFILE './data/onek.data' INTO TABLE onek FIELDS TERMINATED BY '\t' LINES TERMINATED BY '\n';
LOAD DATA LOCAL INFILE './data/onek.data' INTO TABLE onek2 FIELDS TERMINATED BY '\t' LINES TERMINATED BY '\n';
LOAD DATA LOCAL INFILE './data/agg.data' INTO TABLE aggtest FIELDS TERMINATED BY '\t' LINES TERMINATED BY '\n';
LOAD DATA LOCAL INFILE './data/tenk.data' INTO TABLE tenk1 FIELDS TERMINATED BY '\t' LINES TERMINATED BY '\n';
LOAD DATA LOCAL INFILE './data/person.data' INTO TABLE person FIELDS TERMINATED BY '\t' LINES TERMINATED BY '\n';
LOAD DATA LOCAL INFILE './data/tenk.data' INTO TABLE tenk FIELDS TERMINATED BY '\t' LINES TERMINATED BY '\n';
LOAD DATA LOCAL INFILE './data/regr_test.data' INTO TABLE regr_test FIELDS TERMINATED BY '\t' LINES TERMINATED BY '\n';
LOAD DATA LOCAL INFILE './data/int4_tbl.data' INTO TABLE int4_tbl FIELDS TERMINATED BY '\t' LINES TERMINATED BY '\n';
LOAD DATA LOCAL INFILE './data/int8_tbl.data' INTO TABLE int8_tbl FIELDS TERMINATED BY '\t' LINES TERMINATED BY '\n';
