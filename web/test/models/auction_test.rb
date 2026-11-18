require "test_helper"

class AuctionTest < ActiveSupport::TestCase
  setup { @auction = auctions(:camry) }

  test "first bid must meet the starting bid, then the increment" do
    assert_raises(Auction::BidError) { @auction.place_bid!(users(:alice), 9_900) }
    @auction.place_bid!(users(:alice), 10_000)
    assert_equal 10_250, @auction.minimum_bid
    assert_raises(Auction::BidError) { @auction.place_bid!(users(:bob), 10_100) }
    @auction.place_bid!(users(:bob), 10_250)
    assert_equal 2, @auction.reload.bids_count
  end

  test "seller and current leader cannot bid" do
    assert_raises(Auction::BidError) { @auction.place_bid!(users(:seller), 10_000) }
    @auction.place_bid!(users(:alice), 10_000)
    assert_raises(Auction::BidError) { @auction.place_bid!(users(:alice), 11_000) }
  end

  test "rejects bids far above the estimate" do
    assert_raises(Auction::BidError) { @auction.place_bid!(users(:alice), 70_000) }
  end

  test "late bids extend the auction" do
    @auction.update!(ends_at: 30.seconds.from_now)
    @auction.place_bid!(users(:alice), 10_000)
    assert_in_delta Auction::SNIPE_WINDOW.from_now, @auction.reload.ends_at, 2.seconds
  end

  test "closing picks the winner only when the reserve is met" do
    @auction.place_bid!(users(:alice), 11_000)
    @auction.update_columns(starts_at: 1.minute.ago, ends_at: 1.second.ago)
    @auction.close!
    assert_equal "ended", @auction.status
    assert_nil @auction.winner

    @auction.restart!(duration: 1.hour)
    @auction.place_bid!(users(:bob), 12_500)
    @auction.update_columns(starts_at: 1.minute.ago, ends_at: 1.second.ago)
    @auction.close!
    assert_equal users(:bob), @auction.reload.winner
  end

  test "ended auctions refuse bids" do
    @auction.update_columns(ends_at: 1.minute.ago)
    assert_raises(Auction::BidError) { @auction.place_bid!(users(:alice), 10_000) }
  end
end
