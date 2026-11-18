require "test_helper"

class VinDecoderTest < ActiveSupport::TestCase
  test "maps NHTSA fields and body classes" do
    row = { "ModelYear" => "2019", "Make" => "RAM", "Model" => "1500", "Trim" => "", "BodyClass" => "Pickup" }
    assert_equal({ year: 2019, make: "Ram", model: "1500", trim: nil, body_style: "pickup truck" }, VinDecoder.parse(row))
    assert_equal "SUV", VinDecoder.parse(row.merge("BodyClass" => "Sport Utility Vehicle (SUV)/Multi-Purpose Vehicle (MPV)"))[:body_style]
    assert_nil VinDecoder.parse(row.merge("Make" => ""))
  end
end
