class Auction < ApplicationRecord
  SNIPE_WINDOW = 2.minutes

  class BidError < StandardError; end

  belongs_to :vehicle
  belongs_to :winner, class_name: "User", optional: true
  has_many :bids, -> { order(amount_usd: :desc) }, dependent: :destroy

  validates :starting_bid_usd, numericality: { only_integer: true, greater_than: 0 }
  validates :ends_at, comparison: { greater_than: :starts_at }
  validates :status, inclusion: { in: %w[live ended] }

  scope :live, -> { where(status: "live").where("ends_at > ?", Time.current) }
  scope :ended, -> { where(status: "ended") }
  scope :ending_soonest, -> { order(:ends_at) }

  after_create_commit :schedule_close

  def self.increment_for(amount)
    case amount
    when ...5_000 then 100
    when ...20_000 then 250
    else 500
    end
  end

  def live? = status == "live" && ends_at.future?
  def minimum_bid = current_bid_usd ? current_bid_usd + self.class.increment_for(current_bid_usd) : starting_bid_usd
  def reserve_met? = reserve_usd.nil? || current_bid_usd.to_i >= reserve_usd
  def leading_bid = bids.first

  def place_bid!(bidder, amount)
    bid = nil
    extended = false
    with_lock do
      raise BidError, "This auction has ended." unless live?
      raise BidError, "You can't bid on your own listing." if bidder.id == vehicle.seller_id
      raise BidError, "You're already the highest bidder." if leading_bid&.bidder_id == bidder.id
      raise BidError, "Bid at least #{ActiveSupport::NumberHelper.number_to_currency(minimum_bid, precision: 0)}." if amount.to_i < minimum_bid
      raise BidError, "That bid is more than 3× the market estimate. Check the amount." if vehicle.estimate_usd && amount.to_i > vehicle.estimate_usd * 3

      bid = bids.create!(bidder:, amount_usd: amount.to_i)
      extended = ends_at - Time.current < SNIPE_WINDOW
      update!(current_bid_usd: bid.amount_usd, bids_count: bids_count + 1, ends_at: extended ? Time.current + SNIPE_WINDOW : ends_at)
    end
    schedule_close if extended
    broadcast_bid(bid)
    bid
  end

  def close!
    with_lock do
      return if status == "ended" || ends_at.future?
      update!(status: "ended", winner: reserve_met? ? leading_bid&.bidder : nil)
    end
    broadcast_replace_to self, target: "auction_#{id}_panel", partial: "auctions/panel", locals: { auction: self }
  end

  def restart!(duration:)
    transaction do
      bids.delete_all
      update!(status: "live", winner: nil, current_bid_usd: nil, bids_count: 0, starts_at: Time.current, ends_at: Time.current + duration)
    end
    schedule_close
  end

  private

  def schedule_close
    CloseAuctionJob.set(wait_until: ends_at + 1.second).perform_later(self)
  end

  def broadcast_bid(bid)
    broadcast_replace_to self, target: "auction_#{id}_panel", partial: "auctions/panel", locals: { auction: self }
    broadcast_prepend_to self, target: "auction_#{id}_bids", partial: "bids/bid", locals: { bid: }
    broadcast_replace_to "auctions", target: "auction_#{id}_price", partial: "auctions/price", locals: { auction: self }
  end
end
