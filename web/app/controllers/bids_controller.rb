class BidsController < ApplicationController
  rate_limit to: 20, within: 1.minute, only: :create

  def create
    @auction = Auction.find(params[:auction_id])
    @auction.place_bid!(current_user, params.require(:amount_usd))
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("bid_form", partial: "bids/form", locals: { auction: @auction.reload, notice: "Bid placed." }) }
      format.html { redirect_to @auction, notice: "Bid placed." }
    end
  rescue Auction::BidError => e
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("bid_form", partial: "bids/form", locals: { auction: @auction.reload, alert: e.message }), status: :unprocessable_entity }
      format.html { redirect_to @auction, alert: e.message }
    end
  end
end
