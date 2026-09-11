source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.3.1"

gem "rails", "~> 7.1.5"
gem "pg", "~> 1.5"
gem "puma", ">= 5.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "sprockets-rails"
gem "tailwindcss-rails", "~> 2.5"
gem "jbuilder"
gem "redis", ">= 4.0.1"
gem "tzinfo-data", platforms: %i[ windows jruby ]
gem "bootsnap", require: false

# Scraping
gem "feedjira", "~> 3.2"
gem "nokogiri", "~> 1.16"
gem "httparty", "~> 0.22"
gem "mechanize", "~> 2.10"

# Background jobs
gem "sidekiq", "~> 7.3"
gem "sidekiq-cron", "~> 1.12"
# Pin below 3.0: sidekiq 7.3.9's scheduler calls TimedStack#pop(positional),
# which connection_pool 3.0 changed to keyword-only args, crashing the cron poller thread.
gem "connection_pool", "~> 2.4"

# Search
gem "pg_search", "~> 2.3"

# Image handling
gem "image_processing", "~> 1.12"

group :development, :test do
  gem "debug", platforms: %i[ mri windows ]
  gem "rspec-rails"
end

group :development do
  gem "web-console"
end
