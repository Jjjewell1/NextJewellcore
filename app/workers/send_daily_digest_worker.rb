class SendDailyDigestWorker
  include Sidekiq::Job
  sidekiq_options queue: :default, retry: 2

  def perform
    unless EmailService.available?
      Rails.logger.info "[Digest] Skipping daily digest: RESEND_API_KEY not set"
      return
    end

    subscribers = NewsletterSubscriber.confirmed
    return Rails.logger.info("[Digest] No confirmed subscribers") if subscribers.empty?

    idea = BusinessIdea.today || BusinessIdea.recent.first
    articles = Article.where("published_at > ?", 24.hours.ago)
                      .order(published_at: :desc)
                      .limit(10)

    subject = build_subject(idea)
    base = EmailService.base_url

    subscribers.find_each do |subscriber|
      html = ApplicationController.renderer.render(
        template: "newsletter_mailer/digest",
        assigns: {
          idea: idea,
          articles: articles,
          base_url: base,
          unsubscribe_url: "#{base}/newsletter/unsubscribe?token=#{subscriber.unsubscribe_token}"
        },
        layout: false
      )
      EmailService.send!(to: subscriber.email, subject: subject, html: html)
    end

    Rails.logger.info "[Digest] Sent daily digest to #{subscribers.size} subscribers"
  end

  private

  def build_subject(idea)
    title = idea ? idea.title.truncate(60) : "Top AI stories"
    "Today in AI: #{title} — #{Date.current.strftime('%b %d')}"
  end
end