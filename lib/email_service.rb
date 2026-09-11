require "httparty"

class EmailService
  ENDPOINT = "https://api.resend.com/emails"

  class UnavailableError < StandardError; end

  def self.available?
    ENV["RESEND_API_KEY"].present?
  end

  def self.base_url
    ENV["APP_URL"].presence || "https://next.jewellcore.com"
  end

  def self.default_from
    ENV["NEWSLETTER_FROM"].presence || "Next: AI for Money <digest@next.jewellcore.com>"
  end

  def self.send!(to:, subject:, html:, from: nil)
    raise UnavailableError, "RESEND_API_KEY not set" unless available?

    response = HTTParty.post(
      ENDPOINT,
      headers: {
        "Authorization" => "Bearer #{ENV['RESEND_API_KEY']}",
        "Content-Type" => "application/json"
      },
      body: { from: from || default_from, to: to, subject: subject, html: html }.to_json,
      timeout: 20
    )

    unless response.success?
      Rails.logger.error("[Email] Resend failed (#{response.code}): #{response.body.first(500)}")
      return false
    end

    Rails.logger.info("[Email] Sent #{subject.inspect} to #{to}")
    true
  rescue HTTParty::Error, Net::OpenTimeout, Net::ReadTimeout => e
    Rails.logger.error("[Email] Resend error: #{e.class}: #{e.message}")
    false
  end
end