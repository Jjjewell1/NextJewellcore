class CreateBusinessIdeas < ActiveRecord::Migration[7.1]
  def change
    create_table :business_ideas do |t|
      t.string :title, null: false
      t.text :description, null: false
      t.text :how_to_start
      t.text :tools_needed
      t.text :expected_income
      t.text :difficulty
      t.string :category
      t.text :source_article_ids
      t.boolean :featured, default: false
      t.date :idea_date, null: false

      t.timestamps
    end

    add_index :business_ideas, :idea_date, unique: true
    add_index :business_ideas, :featured
  end
end
