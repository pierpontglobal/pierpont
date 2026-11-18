class AddProfileToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :name, :string, null: false, default: ""
    add_column :users, :demo, :boolean, null: false, default: false
    add_column :users, :bot, :boolean, null: false, default: false
  end
end
