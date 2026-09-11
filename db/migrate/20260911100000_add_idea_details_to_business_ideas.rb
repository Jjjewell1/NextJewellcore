class AddIdeaDetailsToBusinessIdeas < ActiveRecord::Migration[7.1]
  def change
    add_column :business_ideas, :trends, :text
    add_column :business_ideas, :game_plan, :text
    add_column :business_ideas, :starter_prompt, :text
    add_column :business_ideas, :view_count, :integer, default: 0
  end
end