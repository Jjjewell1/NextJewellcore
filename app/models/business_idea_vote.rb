class BusinessIdeaVote < ApplicationRecord
  belongs_to :business_idea

  validates :vote, inclusion: { in: [-1, 1] }
  validates :session_id, presence: true
end