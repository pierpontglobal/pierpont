class PagesController < ApplicationController
  allow_unauthenticated_access

  def model
    @card = PricingClient.new.model_card
  end
end
