class NewsletterController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :create

  def create
    email = params[:email].to_s.strip.downcase
    subscriber = NewsletterSubscriber.find_or_initialize_by(email: email)

    if subscriber.resubscribable?
      subscriber.unsubscribed_at = nil
    end

    if subscriber.save
      if subscriber.confirmed?
        render json: { status: "subscribed", message: "You're on the list. Your first digest arrives tomorrow morning." }
      else
        send_confirmation(subscriber)
        render json: { status: "confirm", message: "Almost done — check your inbox to confirm your subscription." }
      end
    else
      render json: { status: "error", message: subscriber.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  def confirm
    subscriber = NewsletterSubscriber.find_by(unsubscribe_token: params[:token].to_s)
    if subscriber
      subscriber.confirm!
      render html: newsletter_message(
        "You're confirmed 🎉",
        "Your first daily briefing with the AI news roundup and Business Idea of the Day is on its way."
      )
    else
      render html: newsletter_message("Link invalid", "This confirmation link is invalid or has expired."), status: :not_found
    end
  end

  def unsubscribe
    subscriber = NewsletterSubscriber.find_by(unsubscribe_token: params[:token].to_s)
    if subscriber
      subscriber.unsubscribe!
      render html: newsletter_message("You're unsubscribed 👋", "Sorry to see you go. You won't receive any more digests.")
    else
      render html: newsletter_message("Link invalid", "This unsubscribe link is invalid."), status: :not_found
    end
  end

  private

  def send_confirmation(subscriber)
    html = ApplicationController.renderer.render(
      template: "newsletter_mailer/confirm",
      assigns: { confirm_url: "#{EmailService.base_url}/newsletter/confirm?token=#{subscriber.unsubscribe_token}" },
      layout: false
    )
    EmailService.send!(to: subscriber.email, subject: "Confirm your Next subscription", html: html)
  end

  def newsletter_message(title, body)
    "<!DOCTYPE html><html><head><title>Next</title></head><body style='margin:0;padding:0;background:#07070d;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;color:#e5e7eb;'>
      <div style='max-width:600px;margin:0 auto;padding:80px 24px;'>
        <h1 style='font-size:24px;font-weight:800;margin:0 0 10px;color:#ffffff;'>#{title}</h1>
        <p style='font-size:15px;line-height:1.6;color:#9ca3af;margin:0;'>#{body} <a href='/' style='color:#818cf8;'>Back home</a></p>
      </div></body></html>"
  end
end