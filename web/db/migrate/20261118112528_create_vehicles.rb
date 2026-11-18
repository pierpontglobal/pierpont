class CreateVehicles < ActiveRecord::Migration[8.1]
  def change
    create_table :vehicles do |t|
      t.references :seller, null: false, foreign_key: { to_table: :users }
      t.string :vin, null: false, index: true
      t.integer :year, null: false
      t.string :make, null: false
      t.string :model, null: false
      t.string :trim
      t.integer :mileage, null: false
      t.string :body_style
      t.string :color
      t.text :description
      t.string :photo_credit
      t.integer :estimate_usd
      t.integer :estimate_low_usd
      t.integer :estimate_high_usd
      t.string :estimate_version
      t.timestamps
    end
  end
end
