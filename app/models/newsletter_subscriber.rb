class NewsletterSubscriber < ApplicationRecord
  before_validation :generate_unsubscribe_token

  validates :email, presence: true
  validates :email, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  scope :confirmed, -> { where(confirmed: true, unsubscribed_at: nil) }

  def confirmed?
    confirmed
  end

  def resubscribable?
    unsubscribed_at.present?
  end

  def confirm!
    update!(confirmed: true, confirmed_at: confirmed_at || Time.current, unsubscribed_at: nil)
  end

  def unsubscribe!
    update!(unsubscribed_at: Time.current)
  end

  private

  def generate_unsubscribe_token
    self.unsubscribe_token ||= SecureRandom.hex(16)
  end
end