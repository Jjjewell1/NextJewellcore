class ScrapeWebSourceJob
  include Sidekiq::Job
  sidekiq_options queue: :scraping, retry: 2

  def perform(source_id)
    source = Source.find(source_id)
    Rails.logger.info "[Web] Scraping #{source.name}: #{source.url}"

    config = JSON.parse(source.scrape_config || "{}", symbolize_names: true)

    response = HTTParty.get(source.url, headers: {
      "User-Agent" => "NextJewellcore/1.0 (AI News Aggregator)",
      "Accept" => "text/html,application/xhtml+xml"
    })

    doc = Nokogiri::HTML(response.body)

    articles_data = extract_articles(doc, config)

    articles_data.each do |article_data|
      next if article_data[:url].blank?
      next if Article.exists?(url: article_data[:url])

      Article.create!(
        title: article_data[:title].to_s.strip,
        summary: article_data[:summary].to_s.strip.truncate(500),
        content: article_data[:content] || "",
        url: article_data[:url],
        image_url: article_data[:image_url],
        source: source,
        category: source.category,
        published_at: article_data[:published_at] || Time.current,
        scraped_at: Time.current
      )
    end

    Rails.logger.info "[Web] Imported #{articles_data.size} articles from #{source.name}"
  rescue => e
    Rails.logger.error "[Web] Error scraping #{source&.name}: #{e.message}"
    raise
  end

  private

  def extract_articles(doc, config)
    articles = []
    container_selector = config[:container] || ".post, .article, .entry, article, .story"
    title_selector = config[:title] || "h2 a, h3 a, .title a"
    summary_selector = config[:summary] || "p, .summary, .excerpt, .description"
    link_selector = config[:link] || "a"

    doc.css(container_selector).each do |container|
      title_el = container.at_css(title_selector)
      link_el = container.at_css(link_selector)

      next if title_el.nil? || link_el.nil?

      url = link_el["href"]
      url = URI.join(source.url, url).to_s if url.present? && !url.start_with?("http")

      summary_el = container.at_css(summary_selector)
      image_el = container.at_css("img")

      articles << {
        title: title_el.text.strip,
        summary: summary_el&.text&.strip,
        url: url,
        image_url: image_el&.[]("src"),
        published_at: Time.current
      }
    end

    articles.first(10)
  end
end
