class RecycleDemoAuctionsJob < ApplicationJob
  queue_as :default

  def perform
    Auction.where(demo: true, status: "ended").where("ends_at < ?", 20.minutes.ago).find_each do |auction|
      auction.restart!(duration: rand(25..180).minutes)
    end
  end
end
