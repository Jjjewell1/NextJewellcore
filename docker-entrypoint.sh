#!/bin/bash
set -e

echo "==> Running database migrations..."
bundle exec rails db:prepare 2>/dev/null || bundle exec rails db:migrate

echo "==> Seeding initial data if missing..."
bundle exec rails db:seed

echo "==> Starting application..."
exec "$@"