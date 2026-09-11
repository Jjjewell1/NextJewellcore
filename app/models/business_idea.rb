class BusinessIdea < ApplicationRecord
  has_many :votes, class_name: "BusinessIdeaVote", dependent: :destroy

  validates :title, presence: true
  validates :description, presence: true
  validates :idea_date, presence: true, uniqueness: true

  scope :recent, -> { order(idea_date: :desc) }
  scope :featured, -> { where(featured: true) }
  scope :popular, -> {
    select("business_ideas.*, COALESCE(SUM(business_idea_votes.vote), 0) AS vote_sum")
      .left_joins(:votes)
      .group("business_ideas.id")
      .order("vote_sum DESC, business_ideas.idea_date DESC")
  }

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

  def trends_list
    trends.to_s.split("\n").map(&:strip).reject(&:blank?)
  end

  def net_votes
    votes.sum(:vote)
  end

  def increment_views!
    increment!(:view_count)
  end
end