if @idea
  json.date @idea.idea_date
  json.title @idea.title
  json.description @idea.description
  json.category @idea.category
  json.difficulty @idea.difficulty_level
  json.expected_income @idea.expected_income
  json.tools_needed @idea.tools_needed
  json.how_to_start @idea.how_to_start.to_s.split("\n").reject(&:blank?)
  json.game_plan @idea.game_plan.to_s.split("\n").reject(&:blank?)
  json.starter_prompt @idea.starter_prompt
  json.trends @idea.trends_list
  json.net_votes @idea.net_votes
  json.url "#{request.base_url}#{business_idea_path(date: @idea.idea_date)}"
  json.source_articles @idea.source_articles.first(5) do |article|
    json.title article.title
    json.source article.source.name
    json.url article.url
    json.internal_url "#{request.base_url}#{article_path(article)}"
  end
else
  json.set! :message, "No business idea available yet. Ideas generate daily at 06:30 UTC from analysis of the latest AI news."
end