class AssistController < ApplicationController
  rate_limit to: 30, within: 1.minute

  def vin
    decoded = VinDecoder.decode(params[:vin])
    decoded ? render(json: decoded) : head(:unprocessable_entity)
  end

  def photo
    file = params.require(:photo)
    return head(:payload_too_large) if file.size > 8.megabytes
    result = VisionClient.new.classify(file.tempfile, filename: file.original_filename, content_type: file.content_type)
    result ? render(json: result) : head(:service_unavailable)
  end

  def estimate
    p = params.permit(:make, :model, :year, :mileage)
    result = PricingClient.new.estimate(make: p[:make], model: p[:model], year: p[:year].to_i, mileage: p[:mileage].to_i)
    result ? render(json: result) : head(:service_unavailable)
  end
end
