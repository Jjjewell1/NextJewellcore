# =============================================================================
# Multi-stage Dockerfile for Rails 7.1 + Tailwind + Sidekiq
# =============================================================================

# ---------------- Stage 1: Build assets ----------------
FROM ruby:3.3.1-slim AS assets

ENV RAILS_ENV=production \
    BUNDLE_WITHOUT=development:test \
    NODE_ENV=production \
    SECRET_KEY_BASE=dummy-for-assets

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    build-essential libpq-dev nodejs npm git ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile* ./
RUN bundle install --jobs 4 --retry 3

# Tailwind needs its binary; install node deps if package.json present
COPY package.json ./
RUN npm install --no-save 2>/dev/null || true

COPY . .

RUN chmod +x bin/rails bin/rake

# Compile Tailwind CSS (app/assets/builds/tailwind.css) + fingerprint JS/CSS
RUN ./bin/rails tailwindcss:build
RUN ./bin/rails assets:precompile

# =============================================================================
# ---------------- Stage 2: Runtime ----------------
FROM ruby:3.3.1-slim

ENV RAILS_ENV=production \
    BUNDLE_WITHOUT=development:test \
    RAILS_LOG_TO_STDOUT=true \
    RAILS_SERVE_STATIC_FILES=true

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    build-essential libpq-dev git ca-certificates curl libvips \
  && rm -rf /var/lib/apt/lists/* \
  && apt-get clean

WORKDIR /app

COPY --from=assets /usr/local/bundle /usr/local/bundle
COPY --from=assets /app /app

COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh \
 && chmod +x /app/bin/rails /app/bin/rake

EXPOSE 3000

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["bundle", "exec", "puma", "-p", "3000", "-e", "production"]