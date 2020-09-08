#!/bin/bash

# echo commands
set -x

# exit on error
set -e

# Remove all PgSQL versions
service postgresql stop;
apt-get purge postgresql* -y

# Install the Postgresql release that we need
apt-get install -y --allow-unauthenticated --no-install-recommends --no-install-suggests postgresql-$POSTGRESQL_VERSION postgresql-client-$POSTGRESQL_VERSION postgresql-server-dev-$POSTGRESQL_VERSION postgresql-common

# Recreate the cluster with the config we need
rm -rf /etc/postgresql/$POSTGRESQL_VERSION /var/lib/postgresql/$POSTGRESQL_VERSION
pg_createcluster -u postgres --locale C $POSTGRESQL_VERSION main -- -A trust

# Start the service
/etc/init.d/postgresql start $POSTGRESQL_VERSION || sudo journalctl -xe
