#!/bin/sh
export MYSQL_PWD="Mysql_1234"
MYSQL_HOST="localhost"
MYSQL_PORT="3306"
MYSQL_USER_NAME="root"
MYSQL_DB_NAME="odbc_fdw_regress"
export PGS_SRC_DIR="/home/test/workplace/postgresql-13.0"

# Below commands must be run first time to create mysql_db
# --connect to mysql with root user
# mysql -u root -p

# --run below
# CREATE DATABASE mysql_db;
# SET GLOBAL validate_password.policy = LOW;
# SET GLOBAL validate_password.length = 1;
# SET GLOBAL validate_password.mixed_case_count = 0;
# SET GLOBAL validate_password.number_count = 0;
# SET GLOBAL validate_password.special_char_count = 0;

# Set time zone to default time zone of make check PST.
# SET GLOBAL time_zone = '-8:00';
# SET GLOBAL log_bin_trust_function_creators = 1;
# SET GLOBAL local_infile=1;
# -- Use "||" operator as CONCAT operator
# SET GLOBAL sql_mode=(SELECT CONCAT(@@sql_mode, ',PIPES_AS_CONCAT'));

mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D $MYSQL_DB_NAME --local-infile=1 < $PGS_SRC_DIR/contrib/odbc_fdw/init/mysql_init_core.sql
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D $MYSQL_DB_NAME --local-infile=1 < $PGS_SRC_DIR/contrib/odbc_fdw/init/mysql_init_post.sql
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D $MYSQL_DB_NAME --local-infile=1 < $PGS_SRC_DIR/contrib/odbc_fdw/init/mysql_init_extra.sql

