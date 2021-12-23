#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo "Usage: test.sh --[post | mysql | all]"
    exit
fi

if [[ "--post" == $1 ]]
then
    ./init/postgresql_init.sh --start

    sed -i 's/REGRESS =.*/REGRESS = postgresql\/new_test postgresql\/char postgresql\/date postgresql\/delete postgresql\/float4 postgresql\/float8 postgresql\/insert postgresql\/int4 postgresql\/int8 postgresql\/select postgresql\/timestamp postgresql\/update postgresql\/ported_postgres_fdw /' Makefile

elif [[ "--mysql" == $1 ]]
then
    ./init/mysql_init.sh --start

    sed -i 's/REGRESS =.*/REGRESS = mysql\/new_test mysql\/char mysql\/date mysql\/delete mysql\/float4 mysql\/float8 mysql\/insert mysql\/int4 mysql\/int8 mysql\/select mysql\/timestamp mysql\/update mysql\/ported_postgres_fdw /' Makefile
elif [[ "--all" == $1 ]]
then
    ./init/mysql_init.sh --start
    ./init/postgresql_init.sh --start

    sed -i 's/REGRESS =.*/REGRESS = postgresql\/new_test postgresql\/char postgresql\/date postgresql\/delete postgresql\/float4 postgresql\/float8 postgresql\/insert postgresql\/int4 postgresql\/int8 postgresql\/select postgresql\/timestamp postgresql\/update postgresql\/ported_postgres_fdw mysql\/new_test mysql\/char mysql\/date mysql\/delete mysql\/float4 mysql\/float8 mysql\/insert mysql\/int4 mysql\/int8 mysql\/select mysql\/timestamp mysql\/update mysql\/ported_postgres_fdw /' Makefile

fi

make clean
make
make check | tee make_check.out
