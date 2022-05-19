ODBC FDW for PostgreSQL 9.5+ 
============================
This PostgreSQL extension implements a Foreign Data Wrapper (FDW) for
remote databases using Open Database Connectivity [ODBC](http://msdn.microsoft.com/en-us/library/ms714562(v=VS.85).aspx).

This code is based on [`odbc_fdw`][1]created by CARTO, Gunnar "Nick" Bluth and Zheng Yang.

Requirements
------------

To compile and install this extension, assuming a Linux OS,
the libraries and header files for ODBC and PostgreSQL are needed,
e.g. in Ubuntu this can be provided by the `unixodbc-dev`
and `postgresql-server-dev-9.5` system packages.

To make use of the extension ODBC drivers for the data sources to
be used must be installed in the system and reflected
in the `/etc/odbcinst.ini` file.

Driver requirements
--------------------

- odbc-postgresql: >= 9.x
- libmyodbc: >=  5.1
- FreeTDS: >= 1.0
- hive-odbc-native: >= 2.1

Building and Installing
-----------------------

The extension can be built and installed with:

```sh
make
sudo make install
```

Feature
-------
#### Write-able FDW
The existing odbc FDWs are only read-only, this version provides the write capability.  
The user can now issue an insert, update, and delete statement for the foreign tables using the odbc_fdw. 

#### WHERE clause push-down
The odbc_fdw will push-down the foreign table where clause to the foreign server.  
The where condition on the foreign table will be executed on the foreign server,   
hence there will be fewer rows to bring across to PostgreSQL.  
This is a performance feature.

#### Column push-down
The existing odbc FDWs are fetching all the columns from the target foreign table.  
The latest version does the column push-down and only brings back the columns   
that are part of the select target list.  
This is a performance feature.

#### Aggregate function push-down
List of aggregate functions push-down:
```
  avg, bit_and, bit_or, count, max, min, stddev_pop, stddev_samp, sum, var_pop, var_samp,
  sum(DISTINCT), avg(DISTINCT), max(DISTINCT), min(DISTINCT), count(DISTINCT)
```

#### Function push-down
The function can be push-down in WHERE clauses.
List of builtin functions of PostgreSQL can be pushed-down:
 - Flow Control Functions:
   ```
   nullif
   ```
 - Numeric functions:
   ```
   abs, acos, asin, atan, atan2, ceil, ceiling, cos, cot, degrees, div, exp, floor, ln, log, log10, mod,   
   pow, power, radians, round, sign, sin, sqrt, tan,
   ```
 - String functions:
   ```
   ascii, bit_length, char_length, character_length, concat, concat_ws, left, length, lower, lpad,   
   octet_length, repeat, replace, reverse, right, rpad, position, regexp_replace, substr, substring,   
   upper,
   ```
   - For `bit_length`: postgre's core will optimize `bit_length(str)` to `octet_length(str) * 8` and push it down to remote server.
 - Date and Time functions
   ```
   date
   ```
 - Explicit cast functions:   
   | Postgres explicit cast  |      ODBC coressponding syntax      |
   |----------|:-------------|
   |col::float4|CAST(col AS real)|
   |col::date|CAST(col AS date)|
   |col::time|CAST(col AS time)|

Usage
-----

The `OPTION` clause of the `CREATE SERVER`, `CREATE FOREIGN TABLE`
and  `IMPORT FOREIGN SCHEMA` commands is used to define both
the ODBC attributes to define a connection to an ODBC data source
and some additional parameters to specify the table or query that
will be accessed as a foreign table.

The following options to define ODBC attributes should be defined in
the server definition (`CREATE SERVER`).

option   | description
-------- | -----------
`dsn`    | The Database Source Name of the foreign database system you're connecting to.
`driver` | The name of the ODBC driver to use (needed if no dsn is used)

Any other ODBC connection attribute is driver-dependent, and should be defined by
an option named as the attribute prepended by the prefix `odbc_`.
For example `odbc_server`,   `odbc_port`, `odbc_uid`, `odbc_pwd`, etc.

The DSN and Driver can also be defined by the prefixed options
`odbc_DSN`  and `odbc_DRIVER` repectively.

The odbc_ prefixed options can be defined either in the server, user mapping
or foreign table statements.

If the ODBC driver requires case-sensitive attribute names, the
`odbc_` option names will have to be quoted with double quotes (`""`),
for example `OPTIONS ( "odbc_SERVER" '127.0.0.1' )`.
Attributes `DSN`, `DRIVER`, `UID` and `PWD` are automatically uppercased
and don't need quoting.

If an ODBC attribute value contains special characters such as `=` or `;`
it will require quoting with curly braces (`{}`), for example:
for example `OPTIONS ( "odbc_PWD" '{xyz=abc}' )`.

odbc_ option names may need to be quoted with "" if the driver
requires case-sensitive names (otherwise the names are passed as lowercase,
except for UID & PWD)
odbc_ option values may need to be quoted with {} if they contain
characters such as =; ...
(but PG driver doesn't seem to support them)
(the driver name and DNS should always support this quoting, since they aren't
handled by the driver)


Usually you'll want to define authentication-related attributes
in a `CREATE USER MAPPING` statement, so that they are determined by
the connected PostgreSQL role, but that's not a requirement: any attribute
can be define in any of the statements; when a foreign table is access
the SERVER, USER MAPPING and FOREIGN TABLE options will be combined
to produce an ODBC connection string.

The next options are used to define the table or query to connect a
foreign table to. They should be defined either in `CREATE FOREIGN TABLE`
or `IMPORT FOREIGN SCHEMA` statements:

option     | description
---------- | -----------
`schema`   | The schema of the database to query.
`table`    | The name of the table to query. Also the name of the foreign table to create in the case of queries.
`sql_query`| Optional: User defined SQL statement for querying the foreign table(s). This overrides the `table` parameters. This should use the syntax of ODBC driver used.
`sql_count`| Optional: User defined SQL statement for counting number of records in the foreign table(s). This should use the syntax of ODBC driver used.
`prefix`   | For IMPORT FOREIGN SCHEMA: a prefix for foreign table names. This can be used to prepend a prefix to the names of tables imported from an external database.

Note that if the `prefix` option is used and only one specific foreign table is to be imported,
the `table` option is necessary (to specify the unprefixed, remote table name). In this case
it is better not to include a `LIMIT TO` clause (otherwise it has to reference the *prefixed* table name).

The below options are used with a column in `CREATE FOREIGN TABLE` or `IMPORT FOREIGN SCHEMA` statements:

option     | description
---------- | -----------
`column`   | The name of column to query. If this option is omitted, same name with the foreign table's is used.
`key`      | The column with this option identifies each record in a table like primary keys.

Example
-------

Assuming that the `odbc_fdw` is installed and available
in your database (`CREATE EXTENSION odbc_fdw`), and that
you have a DNS `test` defined for some ODBC datasource which
has a table named `dblist` in a schema named `test`:

```sql
CREATE SERVER odbc_server
  FOREIGN DATA WRAPPER odbc_fdw
  OPTIONS (dsn 'test');

CREATE FOREIGN TABLE
  odbc_table (
    id integer,
    name varchar(255),
    desc text,
    users float4,
    createdtime timestamp
  )
  SERVER odbc_server
  OPTIONS (
    odbc_DATABASE 'myplace',
    schema 'test',
    sql_query 'select description,id,name,created_datetime,sd,users from `test`.`dblist`',
    sql_count 'select count(id) from `test`.`dblist`'
  );

CREATE USER MAPPING FOR postgres
  SERVER odbc_server
  OPTIONS (odbc_UID 'root', odbc_PWD '');
```

Note that no DSN is required; we can define connection attributes,
including the name of the ODBC driver, individually:

```sql
CREATE SERVER odbc_server
  FOREIGN DATA WRAPPER odbc_fdw
  OPTIONS (
    odbc_DRIVER 'MySQL',
	odbc_SERVER '192.168.1.17',
	encoding 'iso88591'
  );
```

The need to know about the columns of the table(s) to be queried
ad its types can be obviated by using the `IMPORT FOREIGN SCHEMA`
statement. By using the same OPTIONS as for `CREATE FOREIGN TABLE`
we can import as a foreign table the results of an arbitrary
query performed through the ODBC driver:

```sql
IMPORT FOREIGN SCHEMA test
  FROM SERVER odbc_server
  INTO public
  OPTIONS (
    odbc_DATABASE 'myplace',
    table 'odbc_table', -- this will be the name of the created foreign table
    sql_query 'select description,id,name,created_datetime,sd,users from `test`.`dblist`'
  );
```

If you want to update tables, please add OPTIONS (key 'true') to a primary key or unique key like the following:

```sql
CREATE FOREIGN TABLE
  odbc_table (
    id integer OPTIONS (key 'true'),
    name varchar(255),
    desc text,
    users float4,
    createdtime timestamp
  )
  SERVER odbc_server
  OPTIONS (
    odbc_DATABASE 'myplace',
    schema 'test',
  );
```

LIMITATIONS
-----------

* Column, schema, table names should not be longer than the limit stablished by
  PostgreSQL ([NAMEDATALEN](https://www.postgresql.org/docs/9.5/static/sql-syntax-lexical.html#SQL-SYNTAX-IDENTIFIERS))
* Only the following column types are currently fully suported:

   type             | select | insert/update/delete
   -----------------|--------|-------
   SQL_CHAR         | x      | -
   SQL_WCHAR        | x      | -
   SQL_VARCHAR      | x      | x
   SQL_WVARCHAR     | x      | -
   SQL_LONGVARCHAR  | x      | -
   SQL_WLONGVARCHAR | x      | -
   SQL_DECIMAL      | x      | -
   SQL_NUMERIC      | x      | x
   SQL_INTEGER      | x      | x
   SQL_REAL         | x      | -
   SQL_FLOAT        | x      | -
   SQL_DOUBLE       | x      | x
   SQL_SMALLINT     | x      | x
   SQL_TINYINT      | x      | -
   SQL_BIGINT       | x      | x
   SQL_DATE         | x      | x
   SQL_TYPE_TIME    | x      | -
   SQL_TIME         | x      | x
   SQL_TIMESTAMP    | x      | x
   SQL_GUID         | x      | -

* Foreign encodings are supported with the  `encoding` option
  for any enconding supported by PostgreSQL and compatible with the
  local database. The encoding must be identified with the
  name used by [PostgreSQL](https://www.postgresql.org/docs/9.5/static/multibyte.html).

* Concatenation Operator
The `||` operator as a concatenation operator is standard SQL, however in MySQL, it represents the OR operator (logical operator)
If the PIPES_AS_CONCAT SQL mode is enabled, || signifies the SQL-standard string concatenation operator (like CONCAT()).
User needs to enable PIPES_AS_CONCAT mode in MySQL for concatenation.

* Floating-point value comparison
Floating-point numbers are approximate and not stored as exact values. A floating-point value as written in an SQL statement may not be the same as the value represented internally.

   For example:

   ```
   SELECT float4.f1 FROM FLOAT4_TBL tbl06 WHERE float4.f1 <> '1004.3';
        f1      
   -------------
              0
         1004.3
         -34.84
    1.23457e+20
    1.23457e-20
   (5 rows)
   ```
   In order to get correct result, can decide on an acceptable tolerance for differences between the numbers and then do the comparison against the tolerance value to that can get the correct result.
   ```
   SELECT float4.f1 FROM tbl06 float4 WHERE float4.f1 <> '1004.3' GROUP BY float4.id, float4.f1 HAVING abs(f1 - 1004.3) > 0.001 ORDER BY float4.id;
        f1      
   -------------
              0
         -34.84
    1.23457e+20
    1.23457e-20
   (4 rows)
   ```
 * Functions push-down:
   * For `log`: Just push down `log(b, x)`, the `log(x)` does not push-down to remote server because of different functionality in the remote side (Mysql ODBC datasource)
   * For `regexp_replace`: Just push-down `regexp_replace(source, pattern, eplacement_string)`, does not push-down the other signature of `regexp_replace` (these signatures is not support by Mysql ODBC datasource)

[1]:https://github.com/CartoDB/odbc_fdw