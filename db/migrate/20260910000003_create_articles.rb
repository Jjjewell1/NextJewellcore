class CreateArticles < ActiveRecord::Migration[7.1]
  def change
    create_table :articles do |t|
      t.string :title, null: false
      t.text :summary
      t.text :content
      t.string :url, null: false
      t.string :image_url
      t.references :source, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.datetime :published_at
      t.datetime :scraped_at
      t.boolean :featured, default: false
      t.integer :view_count, default: 0

      t.timestamps
    end

    add_index :articles, :url, unique: true
    add_index :articles, :published_at
    add_index :articles, :featured
    add_index :articles, [:category_id, :published_at]
  end
end
