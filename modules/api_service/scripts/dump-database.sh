#!/bin/sh
set -eu

umask 077
pg_dump --no-password --format=custom --file=/backup/database.dump
pg_restore --list /backup/database.dump >/dev/null
