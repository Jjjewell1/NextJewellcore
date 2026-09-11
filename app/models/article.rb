class Article < ApplicationRecord
  include PgSearch::Model

  belongs_to :source
  belongs_to :category

  validates :title, presence: true
  validates :url, presence: true, uniqueness: true

  scope :recent, -> { order(published_at: :desc) }
  scope :featured, -> { where(featured: true) }
  scope :for_category, ->(slug) { joins(:category).where(categories: { slug: slug }) }

  pg_search_scope :search_content,
    against: [:title, :summary],
    using: { tsearch: { prefix: true, dictionary: "english" } }

  def self.find_or_create_by_url(article_attrs)
    find_or_create_by!(url: article_attrs[:url]) do |article|
      article.assign_attributes(article_attrs)
    end
  rescue ActiveRecord::RecordNotUnique
    find_by!(url: article_attrs[:url])
  end

  def increment_views!
    increment!(:view_count)
  end
end
