class BusinessIdea < ApplicationRecord
  validates :title, presence: true
  validates :description, presence: true
  validates :idea_date, presence: true, uniqueness: true

  scope :recent, -> { order(idea_date: :desc) }
  scope :featured, -> { where(featured: true) }

  def self.today
    find_by(idea_date: Date.current)
  end

  def self.for_date(date)
    find_by(idea_date: date)
  end

  def source_articles
    return [] if source_article_ids.blank?
    Article.where(id: source_article_ids.split(","))
  end

  def difficulty_level
    difficulty || "Beginner"
  end
end
