class PagesController < ApplicationController
  def home
    @categories = Category.by_position.includes(:articles)
    @recent_articles = Article.recent.includes(:source, :category).limit(21)
    @featured_articles = Article.featured.recent.includes(:source, :category).limit(2)
    @business_idea = BusinessIdea.today || BusinessIdea.recent.first
    @category_counts = Category.left_joins(:articles).group(:slug).count(:articles)
  end

  def category
    @category = Category.find_by!(slug: params[:slug])
    base = Article.for_category(params[:slug]).recent.includes(:source, :category)
    @articles = Pagination.apply(base, params[:page])
    @category_counts = Category.left_joins(:articles).group(:slug).count(:articles)
  end

  def search
    @query = params[:q].to_s.strip
    @articles = if @query.present?
                  Pagination.apply(
                    Article.search_content(@query).recent.includes(:source, :category),
                    params[:page]
                  )
                else
                  Article.none
                end
    @category_counts = Category.left_joins(:articles).group(:slug).count(:articles)
  end

  def article
    @article = Article.find(params[:id])
    @article.increment_views!
    @related_articles = Article.where(category_id: @article.category_id)
                              .where.not(id: @article.id)
                              .recent
                              .includes(:source, :category)
                              .limit(4)
    @category_counts = Category.left_joins(:articles).group(:slug).count(:articles)
  end

  def business_idea
    @idea = if params[:date].present?
              BusinessIdea.for_date(Date.parse(params[:date]))
            else
              BusinessIdea.today || BusinessIdea.recent.first
            end
    @recent_ideas = BusinessIdea.recent.limit(6)
    @category_counts = Category.left_joins(:articles).group(:slug).count(:articles)
  rescue Date::Error
    redirect_to business_idea_path
  end
end