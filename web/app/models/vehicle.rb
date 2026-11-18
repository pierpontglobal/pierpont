class Vehicle < ApplicationRecord
  BODY_STYLES = [ "sedan", "SUV", "pickup truck", "coupe", "convertible", "hatchback", "minivan", "station wagon", "cargo van" ].freeze

  belongs_to :seller, class_name: "User"
  has_one :auction, dependent: :destroy
  has_one_attached :photo do |a|
    a.variant :card, resize_to_fill: [ 640, 420 ], format: :webp, saver: { quality: 78 }
    a.variant :hero, resize_to_limit: [ 1400, 900 ], format: :webp, saver: { quality: 82 }
  end

  normalizes :vin, with: ->(v) { v.to_s.upcase.delete("^A-Z0-9") }
  validates :vin, presence: true, length: { is: 17 }, format: { with: /\A[A-HJ-NPR-Z0-9]{17}\z/, message: "is not a valid VIN" }
  validates :year, numericality: { only_integer: true, in: 1980..(Date.current.year + 1) }
  validates :make, :model, presence: true, length: { maximum: 60 }
  validates :mileage, numericality: { only_integer: true, in: 0..500_000 }
  validates :body_style, inclusion: { in: BODY_STYLES }, allow_blank: true
  validate :photo_is_an_image
  validate :vin_not_in_live_auction, on: :create

  def title = [ year, make, model, trim.presence ].compact.join(" ")

  def refresh_estimate!(client = PricingClient.new)
    e = client.estimate(make:, model:, year:, mileage:)
    return unless e
    update!(estimate_usd: e["estimate_usd"], estimate_low_usd: e["low_usd"], estimate_high_usd: e["high_usd"], estimate_version: e["model_version"])
  end

  private

  def vin_not_in_live_auction
    errors.add(:vin, "is already in a live auction") if Auction.live.joins(:vehicle).exists?(vehicles: { vin: })
  end

  def photo_is_an_image
    return unless photo.attached?
    errors.add(:photo, "must be a JPEG, PNG or WebP") unless photo.content_type.in?(%w[image/jpeg image/png image/webp])
    errors.add(:photo, "must be under 8 MB") if photo.blob.byte_size > 8.megabytes
  end
end
