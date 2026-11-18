class Bid < ApplicationRecord
  belongs_to :auction
  belongs_to :bidder, class_name: "User"

  validates :amount_usd, numericality: { only_integer: true, greater_than: 0 }
end
