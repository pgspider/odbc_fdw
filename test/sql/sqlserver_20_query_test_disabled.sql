SELECT * FROM sqlserver_test_table;
SELECT * FROM ODBCTablesList('sqlserver_fdw', 1);
SELECT * FROM ODBCTableSize('sqlserver_fdw', 'sqlserver_test_table');
SELECT * FROM ODBCQuerySize('sqlserver_fdw', 'select * from sqlserver_test_table');
SELECT * FROM sqlserver_test_table_with_unsupported_initial_column;