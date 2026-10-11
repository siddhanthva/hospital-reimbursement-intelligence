#!/bin/sh
# Parses DATABASE_URL (the same single env var used everywhere else in this
# project -- .env, Day 9's ci_profiles test script) into the four NEON_*
# vars docker_profiles/profiles.yml expects, so no credentials need to be
# duplicated into a second format just for Docker.
set -e

if [ -z "$DATABASE_URL" ]; then
  echo "entrypoint.sh: DATABASE_URL is not set (expected via --env-file .env)" >&2
  exit 1
fi

eval "$(python3 -c '
import os
from urllib.parse import urlparse
u = urlparse(os.environ["DATABASE_URL"])
print(f"export NEON_HOST=\"{u.hostname}\"")
print(f"export NEON_USER=\"{u.username}\"")
print(f"export NEON_PASSWORD=\"{u.password}\"")
print(f"export NEON_DBNAME=\"{u.path.lstrip(chr(47))}\"")
')"

exec "$@"
