require "net/http"

# NHTSA vPIC, public domain: https://vpic.nhtsa.dot.gov/api/
class VinDecoder
  ENDPOINT = "https://vpic.nhtsa.dot.gov/api/vehicles/DecodeVinValues/%s?format=json"
  BODY_CLASSES = {
    /pickup/i => "pickup truck", /sport utility|crossover/i => "SUV", /minivan/i => "minivan",
    /convertible|cabriolet/i => "convertible", /coupe/i => "coupe", /hatchback/i => "hatchback",
    /wagon/i => "station wagon", /van/i => "cargo van", /sedan|saloon/i => "sedan"
  }.freeze

  def self.decode(vin)
    vin = vin.to_s.upcase.delete("^A-Z0-9")
    return nil unless vin.length == 17

    Rails.cache.fetch("vin/#{vin}", expires_in: 30.days) do
      uri = URI(format(ENDPOINT, vin))
      res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 2, read_timeout: 4) { |http| http.get(uri.request_uri) }
      row = JSON.parse(res.body).dig("Results", 0) if res.is_a?(Net::HTTPSuccess)
      parse(row) if row
    end
  rescue Net::OpenTimeout, Net::ReadTimeout, SystemCallError, SocketError, JSON::ParserError
    nil
  end

  def self.parse(row)
    return nil if row["Make"].blank? || row["ModelYear"].blank?
    body = BODY_CLASSES.find { |re, _| row["BodyClass"].to_s.match?(re) }&.last
    { year: row["ModelYear"].to_i, make: row["Make"].titleize, model: row["Model"], trim: row["Trim"].presence, body_style: body }
  end
end
