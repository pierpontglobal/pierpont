class CreateBids < ActiveRecord::Migration[8.1]
  def change
    create_table :bids do |t|
      t.references :auction, null: false, foreign_key: true
      t.references :bidder, null: false, foreign_key: { to_table: :users }
      t.integer :amount_usd, null: false
      t.timestamps
    end
    add_index :bids, [ :auction_id, :amount_usd ], unique: true
  end
end
