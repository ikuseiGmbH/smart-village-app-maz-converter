#!/bin/sh

set -e

DB=${DB_HOST:-db:5432}

dockerize -wait tcp://$DB -timeout 30s

npm set audit false
bundle exec rake db:create db:migrate

exec "$@"
