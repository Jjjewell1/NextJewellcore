class Category < ApplicationRecord
  has_many :sources, dependent: :destroy
  has_many :articles, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  scope :by_position, -> { order(:position) }

  def article_count
    articles.count
  end
end
