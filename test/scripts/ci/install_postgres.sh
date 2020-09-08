#!/bin/bash

# echo commands
set -x

# exit on error
set -e

# Install the Postgresql release that we need
apt-get install -y --allow-unauthenticated --no-install-recommends --no-install-suggests postgresql-$POSTGRESQL_VERSION postgresql-client-$POSTGRESQL_VERSION postgresql-server-dev-$POSTGRESQL_VERSION postgresql-common

# Recreate the cluster with the config we need
for i in $(pg_lsclusters  | tail -n +2 | awk '{print $1}'); do pg_dropcluster --stop $i main; done;
rm -rf /etc/postgresql/$POSTGRESQL_VERSION /var/lib/postgresql/$POSTGRESQL_VERSION /var/ramfs/postgresql/$POSTGRESQL_VERSION
pg_createcluster -u postgres --locale C $POSTGRESQL_VERSION main --start -p 5432 -- -A trust
