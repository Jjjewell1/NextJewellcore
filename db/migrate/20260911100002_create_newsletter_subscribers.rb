class CreateNewsletterSubscribers < ActiveRecord::Migration[7.1]
  def change
    create_table :newsletter_subscribers do |t|
      t.string :email, null: false
      t.string :unsubscribe_token, null: false
      t.boolean :confirmed, default: false
      t.datetime :confirmed_at
      t.datetime :unsubscribed_at

      t.timestamps
    end

    add_index :newsletter_subscribers, :email, unique: true
    add_index :newsletter_subscribers, :unsubscribe_token, unique: true
  end
end