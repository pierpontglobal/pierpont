require "test_helper"

class AuctionsFlowTest < ActionDispatch::IntegrationTest
  test "anyone can browse, guests can bid" do
    get root_path
    assert_response :success
    assert_select "a.card", 1

    get auction_path(auctions(:camry))
    assert_response :success
    assert_select "button", text: "Bid as a guest"

    post demo_session_path(return_to: auction_path(auctions(:camry)))
    assert_redirected_to auction_path(auctions(:camry))

    post auction_bids_path(auctions(:camry)), params: { amount_usd: 10_000 }, as: :turbo_stream
    assert_response :success
    assert_equal 10_000, auctions(:camry).reload.current_bid_usd
  end

  test "demo redirect ignores off-site targets" do
    post demo_session_path(return_to: "//evil.example")
    assert_redirected_to root_path
  end

  test "selling requires an account" do
    get new_listing_path
    assert_redirected_to new_session_path
  end
end
