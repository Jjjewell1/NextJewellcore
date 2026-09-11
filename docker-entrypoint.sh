#!/bin/bash
set -e

echo "==> Preparing database..."
bundle exec ruby bin/rails db:prepare

echo "==> Seeding initial data..."
bundle exec ruby bin/rails db:seed

echo "==> Starting application..."
exec "$@"