class ListingsController < ApplicationController
  DURATIONS = { "30 minutes" => 30, "2 hours" => 120, "1 day" => 1440, "3 days" => 4320 }.freeze

  def new
    @vehicle = Vehicle.new
  end

  def create
    @vehicle = current_user.vehicles.new(vehicle_params)
    minutes = DURATIONS.values.include?(params[:duration_minutes].to_i) ? params[:duration_minutes].to_i : 120
    return render(:new, status: :unprocessable_entity) unless photo_looks_like_a_vehicle?

    Vehicle.transaction do
      @vehicle.save!
      @vehicle.refresh_estimate!
      @auction = @vehicle.create_auction!(
        starts_at: Time.current, ends_at: minutes.minutes.from_now,
        starting_bid_usd: params[:starting_bid_usd].to_i.clamp(100, 1_000_000),
        reserve_usd: params[:reserve_usd].presence&.to_i
      )
    end
    redirect_to @auction, notice: "Your auction is live."
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  private

  def photo_looks_like_a_vehicle?
    file = params.dig(:vehicle, :photo)
    return true if file.blank?
    result = VisionClient.new.classify(file.tempfile, filename: file.original_filename, content_type: file.content_type)
    file.tempfile.rewind
    return true if result.nil? || result["is_vehicle"]

    @vehicle.errors.add(:photo, "doesn't look like a vehicle")
    false
  end

  def vehicle_params
    params.require(:vehicle).permit(:vin, :year, :make, :model, :trim, :mileage, :body_style, :color, :description, :photo)
  end
end
