class CreateBusinessIdeaVotes < ActiveRecord::Migration[7.1]
  def change
    create_table :business_idea_votes do |t|
      t.references :business_idea, null: false, foreign_key: true
      t.integer :vote, null: false
      t.string :session_id, null: false

      t.timestamps
    end

    add_index :business_idea_votes,
      [:business_idea_id, :session_id],
      unique: true,
      name: "index_business_idea_votes_on_idea_id_and_session"
  end
end