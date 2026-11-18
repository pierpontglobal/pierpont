require "json"

module SeedVin
  VALUES = ("A".."Z").zip([ 1, 2, 3, 4, 5, 6, 7, 8, 0, 1, 2, 3, 4, 5, 0, 7, 0, 9, 2, 3, 4, 5, 6, 7, 8, 9 ]).to_h.merge(("0".."9").to_h { |d| [ d, d.to_i ] })
  WEIGHTS = [ 8, 7, 6, 5, 4, 3, 2, 10, 0, 9, 8, 7, 6, 5, 4, 3, 2 ].freeze
  CHARS = (("A".."Z").to_a - %w[I O Q]) + ("0".."9").to_a

  def self.generate(rng)
    vin = Array.new(17) { CHARS.sample(random: rng) }
    vin[9] = "ABCDEFGHJKLMNPRSTVWXY123456789".chars.sample(random: rng)
    sum = vin.each_with_index.sum { |c, i| VALUES.fetch(c) * WEIGHTS[i] }
    vin[8] = (sum % 11 == 10 ? "X" : (sum % 11).to_s)
    vin.join
  end
end

rng = Random.new(42)
dir = Rails.root.join("db/seeds")

seller = User.find_or_create_by!(email_address: "motors@demo.pierpont.invalid") do |u|
  u.name = "Pierpont Demo Motors"
  u.password = SecureRandom.base58(24)
  u.demo = true
  u.bot = true
end

%w[Harbor\ Auto\ Group Northside\ Imports Lakeview\ Motors Summit\ Trucks Coastline\ Cars Redline\ Dealers].each do |name|
  User.find_or_create_by!(email_address: "#{name.parameterize}@bots.pierpont.invalid") do |u|
    u.name = name
    u.password = SecureRandom.base58(24)
    u.demo = true
    u.bot = true
  end
end

pricing = PricingClient.new(timeout: 10)
vision = VisionClient.new
JSON.parse(dir.join("vehicles.json").read).each_with_index do |row, i|
  next if Vehicle.exists?(make: row["make"], model: row["model"], year: row["year"], seller:)

  age = [ Date.current.year - row["year"], 1 ].max
  vehicle = seller.vehicles.new(
    vin: SeedVin.generate(rng), year: row["year"], make: row["make"], model: row["model"],
    mileage: (age * rng.rand(7_500..13_500)).clamp(4_000, 230_000).round(-2),
    body_style: row["body_style"], photo_credit: row["credit"], photo_source_url: row["source"],
    description: "Demo listing with simulated bidders."
  )
  photo = dir.join("photos", row["file"])
  insight = photo.open { |f| vision.classify(f, filename: row["file"], content_type: "image/jpeg") }
  vehicle.color = insight&.dig("color", 0, "label")
  vehicle.photo.attach(io: photo.open, filename: row["file"], content_type: "image/jpeg")
  vehicle.save!
  vehicle.refresh_estimate!(pricing)

  base = vehicle.estimate_usd || 15_000
  vehicle.create_auction!(
    starts_at: Time.current, ends_at: Time.current + (20 + i * 13).minutes,
    starting_bid_usd: (base * 0.55).round(-2), reserve_usd: i.even? ? (base * 0.8).round(-2) : nil, demo: true
  )
end

puts "#{Vehicle.count} vehicles, #{Auction.live.count} live auctions"
