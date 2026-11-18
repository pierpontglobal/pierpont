class CloseAuctionJob < ApplicationJob
  queue_as :default

  def perform(auction)
    auction.reload
    return if auction.status == "ended"
    auction.ends_at.future? ? self.class.set(wait_until: auction.ends_at + 1.second).perform_later(auction) : auction.close!
  end
end
