class CreateAuctions < ActiveRecord::Migration[8.1]
  def change
    create_table :auctions do |t|
      t.references :vehicle, null: false, foreign_key: true
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false, index: true
      t.integer :starting_bid_usd, null: false
      t.integer :reserve_usd
      t.integer :current_bid_usd
      t.integer :bids_count, null: false, default: 0
      t.string :status, null: false, default: "live", index: true
      t.references :winner, foreign_key: { to_table: :users }
      t.boolean :demo, null: false, default: false
      t.timestamps
    end
  end
end
