# Be sure to restart your server when you modify this file.

# Add configuration for Sidekiq cron jobs
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
