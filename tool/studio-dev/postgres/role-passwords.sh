#!/bin/sh
# Sets the passwords of app_owner and studio_reader (seed.sql) from APP_OWNER_PASSWORD and STUDIO_READER_PASSWORD,
# which only the compose file holds. NOT FOR PRODUCTION. Runs once, after seed.sql, when the postgres service starts on
# an empty volume.
set -eu
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres \
  -v owner="$APP_OWNER_PASSWORD" -v reader="$STUDIO_READER_PASSWORD" <<'SQL'
ALTER ROLE app_owner PASSWORD :'owner';
ALTER ROLE studio_reader PASSWORD :'reader';
SQL
