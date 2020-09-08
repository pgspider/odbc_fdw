#!/bin/bash

# echo commands
set -x

# exit on error
set -e

# Install the Postgresql release that we need
apt-get install -y --allow-unauthenticated --no-install-recommends --no-install-suggests postgresql-$POSTGRESQL_VERSION postgresql-client-$POSTGRESQL_VERSION postgresql-server-dev-$POSTGRESQL_VERSION postgresql-common

# Recreate the cluster with the config we need
sudo pg_dropcluster --stop $POSTGRESQL_VERSION main
rm -rf /etc/postgresql/$POSTGRESQL_VERSION /var/lib/postgresql/$POSTGRESQL_VERSION /var/ramfs/postgresql/$POSTGRESQL_VERSION
pg_createcluster -u postgres --locale C $POSTGRESQL_VERSION main --start -- -A trust
