class VotesController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    idea = BusinessIdea.find(params[:business_idea_id])
    vote_value = params[:vote].to_i.zero? ? 1 : (params[:vote].to_i > 0 ? 1 : -1)

    vote = idea.votes.find_or_initialize_by(session_id: visitor_id)
    vote.vote = vote_value
    vote.save!

    render json: { net: idea.net_votes, vote: vote_value }
  rescue ActiveRecord::RecordNotUnique
    idea = BusinessIdea.find(params[:business_idea_id])
    idea.votes.find_by(session_id: visitor_id)&.update!(vote: vote_value)
    render json: { net: idea.net_votes, vote: vote_value }
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Idea not found" }, status: :not_found
  end

  private

  def visitor_id
    session[:visitor_id] ||= SecureRandom.urlsafe_base64(16)
  end
end