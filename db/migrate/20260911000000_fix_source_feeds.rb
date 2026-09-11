class FixSourceFeeds < ActiveRecord::Migration[7.1]
  def up
    return unless table_exists?(:sources)

    # OpenAI moved its blog feed to /news/rss.xml; the old path now 307s.
    update_feed("OpenAI Blog", "https://openai.com/news/rss.xml", "OpenAI Blog")

    # Anthropic does not publish an RSS feed (404s). Swap in MIT News AI.
    update_feed("Anthropic News", "https://news.mit.edu/rss/topic/artificial-intelligence2", "MIT News AI")

    # hnrss.org was unreliable (502s); hn.algolia.com serves a stable Atom feed.
    update_feed("Hacker News", "https://hn.algolia.com/rss?query=AI", "Hacker News")
  end

  def down
    return unless table_exists?(:sources)

    update_feed("MIT News AI", "https://www.anthropic.com/rss.xml", "Anthropic News")
  end

  private

  def update_feed(current_name, new_url, new_name)
    source = Source.find_by(name: current_name)
    return unless source

    source.update!(url: new_url, name: new_name)
    Rails.logger.info "[migration] Fixed feed: #{new_name} -> #{new_url}"
  end
end