namespace :scrape do
  desc "Scrape all sources now (manual trigger)"
  task all: :environment do
    Rails.logger.info "[rake] Manual scrape requested"
    ScrapeAiNewsWorker.new.perform
  end

  desc "Scrape a specific source"
  task source: :environment do
    id = ENV["SOURCE_ID"].to_i
    raise "Set SOURCE_ID env var" unless id > 0
    source = Source.find(id)
    Rails.logger.info "[rake] Scraping #{source.name}"
    case source.source_type
    when "rss" then ScrapeRssSourceJob.new.perform(source.id)
    when "web" then ScrapeWebSourceJob.new.perform(source.id)
    end
    source.mark_scraped!
  end
end

namespace :business_idea do
  desc "Generate today's business idea"
  task generate: :environment do
    Rails.logger.info "[rake] Manual business idea generation requested"
    GenerateBusinessIdeaWorker.new.perform
  end
end