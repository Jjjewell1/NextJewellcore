# Be sure to restart your server when you modify this file.

# Register cron jobs via sidekiq-cron. Guarded so this never takes down the
# web server or the docker image build: if Redis is unreachable (e.g. during
# `assets:precompile` in a build stage with no REDIS_URL), skip registration.
if ENV["REDIS_URL"].present? && defined?(Sidekiq::Cron)
  begin
    Sidekiq::Cron::Job.load_from_hash(
      {
        "scrape_ai_news" => {
          "cron" => "0 * * * *",
          "class" => "ScrapeAiNewsWorker"
        },
        "generate_business_idea" => {
          "cron" => "30 6 * * *",
          "class" => "GenerateBusinessIdeaWorker"
        }
      }
    )
  rescue => e
    Rails.logger.warn("Sidekiq cron registration skipped: #{e.message}")
  end
end