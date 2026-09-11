# Next — AI News & Insights

A beautiful Ruby on Rails AI news aggregator that scrapes the web hourly for the hottest AI tech, model news, and ways to make money using AI. Features a daily Business Idea of the Day crafted from scraped data.

## Features

- **Hourly scraping** from 20+ curated RSS feeds and web sources
- **Categories**: AI Tech, Models & Releases, Make Money with AI, Tutorials & Guides
- **Full-text search** across all articles
- **Business Idea of the Day** — a feasible, low-cost, doable money-making idea generated daily from real AI trends
- **Hotwire/Turbo** powered, mobile-first, dark-themed UI
- **Sidekiq** background jobs with cron scheduling

## Stack

- Ruby on Rails 7.1
- PostgreSQL 16
- Redis + Sidekiq
- Tailwind CSS
- Feedjira + Nokogiri + Mechanize

## Setup

```bash
bundle install
rails db:create db:migrate db:seed
rails tailwindcss:build
# Start web + worker
bundle exec puma -p 3000
bundle exec sidekiq -C config/sidekiq.yml
```

## Manual triggers

```bash
rails scrape:all                 # scrape all sources now
SOURCE_ID=1 rails scrape:source  # scrape one source
rails business_idea:generate     # generate today's business idea
```

## Deployment

This deploys via Docker Compose on Coolify. The compose file runs three containers:

- **web** — Puma on port 3000 (Traefik-routed to `next.jewellcore.com`)
- **sidekiq** — background worker for scraping + cron
- **redis** — job queue + cache