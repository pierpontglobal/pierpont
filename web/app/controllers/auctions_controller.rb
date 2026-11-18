class AuctionsController < ApplicationController
  allow_unauthenticated_access

  def index
    scope = Auction.live.includes(vehicle: { photo_attachment: :blob })
    scope = scope.joins(:vehicle).where(vehicles: { body_style: params[:body] }) if params[:body].in?(Vehicle::BODY_STYLES)
    scope = scope.joins(:vehicle).where("vehicles.make ILIKE ?", Auction.sanitize_sql_like(params[:make].to_s) + "%") if params[:make].present?
    @auctions = scope.ending_soonest.limit(60)
    @mape = PricingClient.new.model_card&.dig("price", "metrics", "mape")&.*(100)&.round
    @recently_sold = Auction.ended.includes(:vehicle).order(ends_at: :desc).limit(4)
  end

  def show
    @auction = Auction.includes(:vehicle, bids: :bidder).find(params[:id])
    @bids = @auction.bids.limit(15)
  end
end
