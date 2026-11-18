class PricingClient < MlClient
  def estimate(make:, model:, year:, mileage:)
    req = Net::HTTP::Post.new(uri("/v1/price"), "Content-Type" => "application/json")
    req.body = { make:, model:, year:, mileage: }.to_json
    request(req)
  end

  def model_card
    Rails.cache.fetch("ml/model_card", expires_in: 5.minutes) { request(Net::HTTP::Get.new(uri("/v1/models"))) }
  end

  def catalog
    Rails.cache.fetch("ml/catalog", expires_in: 1.hour) { request(Net::HTTP::Get.new(uri("/v1/catalog"))) } || {}
  end
end
