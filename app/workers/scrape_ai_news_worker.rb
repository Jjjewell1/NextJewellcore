class ScrapeAiNewsWorker
  include Sidekiq::Job
  sidekiq_options queue: :scraping, retry: 3

  def perform
    Rails.logger.info "[Scraper] Starting AI news scrape at #{Time.current}"

    Source.active.find_each do |source|
      begin
        case source.source_type
        when "rss"
          ScrapeRssSourceJob.new.perform(source.id)
        when "web"
          ScrapeWebSourceJob.new.perform(source.id)
        end
        source.mark_scraped!
        Rails.logger.info "[Scraper] Completed #{source.name}"
      rescue => e
        Rails.logger.error "[Scraper] Failed #{source.name}: #{e.message}"
      end
    end

    Rails.logger.info "[Scraper] Scrape complete at #{Time.current}"
  end
end
