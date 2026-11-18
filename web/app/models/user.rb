class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :vehicles, foreign_key: :seller_id, inverse_of: :seller, dependent: :destroy
  has_many :bids, foreign_key: :bidder_id, inverse_of: :bidder, dependent: :destroy
  has_many :won_auctions, class_name: "Auction", foreign_key: :winner_id, inverse_of: :winner, dependent: :nullify

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true, length: { maximum: 60 }
  validates :password, length: { minimum: 10 }, allow_nil: true

  scope :bots, -> { where(bot: true) }

  def display_name = name.presence || email_address.split("@").first
end
