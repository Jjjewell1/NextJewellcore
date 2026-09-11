class CreateSources < ActiveRecord::Migration[7.1]
  def change
    create_table :sources do |t|
      t.string :name, null: false
      t.string :url, null: false
      t.string :source_type, null: false, default: "rss"
      t.references :category, null: false, foreign_key: true
      t.boolean :active, default: true
      t.datetime :last_scraped_at
      t.text :scrape_config

      t.timestamps
    end

    add_index :sources, :active
    add_index :sources, :source_type
  end
end
