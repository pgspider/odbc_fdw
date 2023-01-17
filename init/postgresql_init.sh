#!/bin/sh
export PDB_PORT="5444"
export PDB_NAME1="odbc_fdw_regress"
export PDB_NAME2="odbc_fdw_post"
export PGS_BIN_DIR="/home/test/workplace/postgresql-15.0/install"
export FDW_DIR="/home/test/workplace/postgresql-15.0/contrib/odbc_fdw"

CURR_PATH=$(pwd)

cd $PGS_BIN_DIR/bin

if [[ "--start" == $1 ]]
then
    #Start Postgres
    if ! [ -d "../test_odbc_database" ];
    then
        ./initdb ../test_odbc_database
        sed -i "s~#port = 5432.*~port = $PDB_PORT~g" ../test_odbc_database/postgresql.conf
        ./pg_ctl -D ../test_odbc_database -l /dev/null start
        sleep 2
        ./createdb -p $PDB_PORT $PDB_NAME1
        ./createdb -p $PDB_PORT $PDB_NAME2
    fi
    if ! ./pg_isready -p $PDB_PORT
    then
        echo "Start PostgreSQL"
        ./pg_ctl -D ../test_odbc_database -l /dev/null start
        sleep 2
    fi
fi

cd $CURR_PATH
$PGS_BIN_DIR/bin/psql -q -A -t -d $PDB_NAME1 -p $PDB_PORT -f $FDW_DIR/init/postgresql_init_core.sql
$PGS_BIN_DIR/bin/psql -q -A -t -d $PDB_NAME2 -p $PDB_PORT -f $FDW_DIR/init/postgresql_init_post.sql
$PGS_BIN_DIR/bin/psql -q -A -t -d $PDB_NAME1 -p $PDB_PORT -f $FDW_DIR/init/postgresql_init_extra.sql
