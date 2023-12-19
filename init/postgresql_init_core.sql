\ir ../sql/configs/postgreSql_parameters.conf
DROP TABLE IF EXISTS onek;
DROP TABLE IF EXISTS onek2;
DROP TABLE IF EXISTS aggtest;
DROP TABLE IF EXISTS tenk1;
DROP TABLE IF EXISTS multi_arg_agg;
DROP TABLE IF EXISTS int4_tbl;
DROP TABLE IF EXISTS int4_tbl_tmp;
DROP TABLE IF EXISTS int4_tbl_tmp2;
DROP TABLE IF EXISTS int8_tbl;
DROP TABLE IF EXISTS int8_tbl_tmp;
DROP TABLE IF EXISTS int8_tbl_tmp2;
DROP TABLE IF EXISTS float8_tbl;
DROP TABLE IF EXISTS float8_tmp;
DROP TABLE IF EXISTS float8_tbl_tmp;
DROP TABLE IF EXISTS float8_tbl_tmp2;
DROP TABLE IF EXISTS float4_tbl;
DROP TABLE IF EXISTS float4_tbl_tmp;
DROP TABLE IF EXISTS bitwise_test;
DROP TABLE IF EXISTS bool_test_a;
DROP TABLE IF EXISTS bool_test_b;
DROP TABLE IF EXISTS bool_test;
DROP TABLE IF EXISTS minmaxtest;
DROP TABLE IF EXISTS agg_t1;
DROP TABLE IF EXISTS agg_t2;
DROP TABLE IF EXISTS test_data;
DROP TABLE IF EXISTS inserttest01;
DROP TABLE IF EXISTS department;
DROP TABLE IF EXISTS employee;
DROP TABLE IF EXISTS numbers;
DROP TABLE IF EXISTS shorty;
DROP TABLE IF EXISTS evennumbers;
DROP TABLE IF EXISTS person;
DROP TABLE IF EXISTS bar;
DROP TABLE IF EXISTS foo;
DROP TABLE IF EXISTS update_test;
DROP TABLE IF EXISTS char_tbl;
DROP TABLE IF EXISTS char_tbl_2;
DROP TABLE IF EXISTS non_error_throwing_api;
DROP TABLE IF EXISTS date_tbl;
DROP TABLE IF EXISTS regr_test;
DROP TABLE IF EXISTS string_agg1;
DROP TABLE IF EXISTS string_agg2;
DROP TABLE IF EXISTS string_agg3;
DROP TABLE IF EXISTS string_agg4;
DROP TABLE IF EXISTS bytea_test_table;
DROP TABLE IF EXISTS agg_fns_1;
DROP TABLE IF EXISTS agg_fns_2;
DROP TABLE IF EXISTS delete_test;
DROP TABLE IF EXISTS inserttest;
DROP TABLE IF EXISTS upsert_test;
DROP TABLE IF EXISTS tenk;
DROP TABLE IF EXISTS timestamp_tbl;
DROP TABLE IF EXISTS timestamp_tmp;
DROP TABLE IF EXISTS nocols;
DROP TABLE IF EXISTS generate_timestamp1;
DROP TABLE IF EXISTS generate_timestamp2;
DROP TABLE IF EXISTS generate_timestamp3;


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
CREATE TABLE int4_tbl_tmp(id int4 PRIMARY KEY, f1 int4);
CREATE TABLE int4_tbl_tmp2(id SERIAL PRIMARY KEY , a int4, b int4);
CREATE TABLE int8_tbl(id SERIAL PRIMARY KEY, q1 int8, q2 int8);
CREATE TABLE int8_tbl_tmp(id SERIAL PRIMARY KEY, q1 int8, q2 int8);
CREATE TABLE float8_tbl (f1 float8, id SERIAL PRIMARY KEY);
CREATE TABLE float8_tmp (f1 float8, f2 float8, id SERIAL PRIMARY KEY);
CREATE TABLE float8_tbl_tmp (f1 float8, id SERIAL PRIMARY KEY);
CREATE TABLE float8_tbl_tmp2 (id SERIAL PRIMARY KEY, f1 float8, f2 float8);
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
CREATE TABLE update_test (
    a   INT DEFAULT 10,
    b   INT,
    c   TEXT,
	id  SERIAL PRIMARY KEY);

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


CREATE TABLE char_tbl (id int primary key, f1 char);
CREATE TABLE char_tbl_2 (id SERIAL PRIMARY KEY, f1 char(4));
CREATE TABLE non_error_throwing_api (id SERIAL PRIMARY KEY, f1 text);
CREATE TABLE date_tbl (id int primary key, f1 date);
CREATE TABLE regr_test(id int, x float8, y float8);

INSERT INTO bool_test VALUES (1, TRUE,null,FALSE,null);
INSERT INTO bool_test VALUES (2, FALSE,TRUE,null,null);
INSERT INTO bool_test VALUES (3, null,TRUE,FALSE,null);
CREATE TABLE string_agg1(id int, a text);
INSERT INTO string_agg1 VALUES (1, 'aaaa');
INSERT INTO string_agg1 VALUES (2, 'bbbb');
INSERT INTO string_agg1 VALUES (3, 'cccc');

CREATE TABLE string_agg2(id int, a text);
INSERT INTO string_agg2 VALUES (1, 'aaaa');
INSERT INTO string_agg2 VALUES (2, null);
INSERT INTO string_agg2 VALUES (3, 'bbbb');
INSERT INTO string_agg2 VALUES (4, 'cccc');
CREATE TABLE string_agg3(id int, a text);
INSERT INTO string_agg3 VALUES (1, null);
INSERT INTO string_agg3 VALUES (2, null);
INSERT INTO string_agg3 VALUES (3, 'bbbb');
INSERT INTO string_agg3 VALUES (4, 'cccc');
CREATE TABLE string_agg4(id int, a text);
INSERT INTO string_agg4 VALUES (1, null);
INSERT INTO string_agg4 VALUES (2, null);

create table bytea_test_table(id int primary key, v bytea);
CREATE TABLE agg_fns_1 (id int, a int);
INSERT INTO agg_fns_1 VALUES (1, 1);
INSERT INTO agg_fns_1 VALUES (2, 2);
INSERT INTO agg_fns_1 VALUES (3, 1);
INSERT INTO agg_fns_1 VALUES (4, 3);
INSERT INTO agg_fns_1 VALUES (5, null);
INSERT INTO agg_fns_1 VALUES (6, 2);

CREATE TABLE agg_fns_2 (a int, b int, c text);
INSERT INTO agg_fns_2 VALUES (1, 3, 'foo');
INSERT INTO agg_fns_2 VALUES (0, null, null);
INSERT INTO agg_fns_2 VALUES (2, 2, 'bar');
INSERT INTO agg_fns_2 VALUES (3, 1, 'baz');

CREATE TABLE delete_test (id SERIAL PRIMARY KEY, a INT, b text);

CREATE TABLE inserttest (col1 int4, col2 int4 NOT NULL, col3 text default 'testing', id int primary key);
INSERT INTO foo (f1) VALUES (42),(3),(10),(7),(null),(null),(1);
CREATE TABLE upsert_test (a INT PRIMARY KEY, b text);
CREATE TABLE timestamp_tbl (id int primary key, d1 timestamp(2) without time zone);
CREATE TABLE timestamp_tmp (id int primary key, d1 timestamp(6) without time zone, d2 timestamp(6) without time zone);

CREATE TABLE nocols();
CREATE TABLE generate_timestamp1 (d1 timestamp without time zone);
CREATE TABLE generate_timestamp2 (d1 timestamp without time zone);
CREATE TABLE generate_timestamp3 (d1 timestamp without time zone);
-- import data from data file
\cd data
\copy onek from 'onek.data' with delimiter E'\t';
\copy onek2 from 'onek.data' with delimiter E'\t';
\copy aggtest from 'agg.data' with delimiter E'\t';
\copy tenk1 from 'tenk.data' with delimiter E'\t';
\copy person from 'person.data' with delimiter E'\t';
\copy tenk from 'tenk.data' with delimiter E'\t';
\copy regr_test from 'regr_test.data' with delimiter E'\t';
\copy int4_tbl from 'int4_tbl.data' with delimiter E'\t';
\copy int8_tbl from 'int8_tbl.data' with delimiter E'\t';
