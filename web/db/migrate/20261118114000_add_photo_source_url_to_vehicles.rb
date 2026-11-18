class AddPhotoSourceUrlToVehicles < ActiveRecord::Migration[8.1]
  def change
    add_column :vehicles, :photo_source_url, :string
  end
end
