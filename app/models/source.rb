class Source < ApplicationRecord
  belongs_to :category
  has_many :articles, dependent: :destroy

  validates :name, presence: true
  validates :url, presence: true
  validates :source_type, presence: true, inclusion: { in: %w[rss web] }

  scope :active, -> { where(active: true) }
  scope :due_for_scrape, -> { active.where("last_scraped_at IS NULL OR last_scraped_at < ?", 1.hour.ago) }

  def mark_scraped!
    update!(last_scraped_at: Time.current)
  end
end
