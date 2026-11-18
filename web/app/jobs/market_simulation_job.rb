# Demo bidders keep the public demo moving: each bot values a car around the ML estimate
# and bids while the price is below its private valuation.
class MarketSimulationJob < ApplicationJob
  queue_as :default

  def perform(rng: Random.new)
    bots = User.bots.to_a
    return if bots.empty?

    Auction.live.where(demo: true).includes(:vehicle).find_each do |auction|
      next unless rng.rand < 0.35
      bot = bots.sample(random: rng)
      valuation = (auction.vehicle.estimate_usd || auction.starting_bid_usd * 1.4) * rng.rand(0.82..1.04)
      next if auction.minimum_bid > valuation

      auction.place_bid!(bot, auction.minimum_bid)
    rescue Auction::BidError
      next
    end
  end
end
