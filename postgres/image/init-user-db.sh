#!/bin/bash
set -e

if psql -lqt | cut -d \| -f 1 | grep -qw "$POSTGRES_USER"; then
  echo "Database $POSTGRES_USER already exists, Skipping creation."
else
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
  CREATE DATABASE "$POSTGRES_USER";
  GRANT ALL PRIVILEGES ON DATABASE "$POSTGRES_USER" TO "$POSTGRES_USER";
EOSQL
fi
