-- This fixture is going to be executed with TSQL

begin
-- Drop constraints and tables, dropping the database and recreating it would reset pricing tier in Azure
    DECLARE @sql NVARCHAR(max)=''

	SELECT @sql += ' ALTER TABLE ' + QUOTENAME(TABLE_SCHEMA) + '.'+ QUOTENAME(TABLE_NAME) +    ' NOCHECK CONSTRAINT all; '
	FROM   INFORMATION_SCHEMA.TABLES
	WHERE TABLE_TYPE = 'BASE TABLE'

	Exec Sp_executesql @sql

	select @sql = ''

	SELECT @sql += ' Drop table ' + QUOTENAME(TABLE_SCHEMA) + '.'+ QUOTENAME(TABLE_NAME) + '; '
	FROM   INFORMATION_SCHEMA.TABLES
	WHERE TABLE_TYPE = 'BASE TABLE'
	Exec Sp_executesql @sql



-- Create fixture
    create table sqlserver_test_table(id int, name text);
    insert into sqlserver_test_table values (1, 'aaaa');

    create table sqlserver_test_table_with_unsupported_initial_column(ignored varbinary(10), id int, name text);
    insert into sqlserver_test_table_with_unsupported_initial_column(id, name) values (1, 'aaaa');

end
go
