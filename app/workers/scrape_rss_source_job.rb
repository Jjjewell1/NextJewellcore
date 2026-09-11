class ScrapeRssSourceJob
  include Sidekiq::Job
  sidekiq_options queue: :scraping, retry: 2

  def perform(source_id)
    source = Source.find(source_id)
    Rails.logger.info "[RSS] Parsing #{source.name}: #{source.url}"

    feed = Feedjira.parse(HTTParty.get(source.url, headers: {
      "User-Agent" => "NextJewellcore/1.0 (AI News Aggregator)"
    }).body)

    feed.entries.each do |entry|
      next if entry.url.blank?
      next if Article.exists?(url: entry.url)

      published = entry.published || entry.updated || Time.current

      Article.create!(
        title: entry.title.to_s.strip,
        summary: sanitize(entry.summary || entry.description || ""),
        content: entry.content || entry.summary || "",
        url: entry.url,
        image_url: extract_image(entry),
        source: source,
        category: source.category,
        published_at: published,
        scraped_at: Time.current
      )
    end

    Rails.logger.info "[RSS] Imported #{feed.entries.size} entries from #{source.name}"
  rescue => e
    Rails.logger.error "[RSS] Error parsing #{source&.name}: #{e.message}"
    raise
  end

  private

  def extract_image(entry)
    return nil unless entry.respond_to?(:image) && entry.image.present?
    entry.image
  end

  def sanitize(html)
    return "" if html.blank?
    Nokogiri::HTML.fragment(html).text.strip.truncate(500)
  end
end
