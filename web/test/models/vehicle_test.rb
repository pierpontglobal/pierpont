require "test_helper"

class VehicleTest < ActiveSupport::TestCase
  test "normalizes and validates the VIN" do
    v = Vehicle.new(seller: users(:seller), vin: " 1hgcm8-2633a004352 ", year: 2003, make: "Honda", model: "Accord", mileage: 1)
    assert v.valid?, v.errors.full_messages.to_sentence
    assert_equal "1HGCM82633A004352", v.vin
    v.vin = "1HGCM82633A00435O"
    assert_not v.valid?
  end

  test "a VIN can't be in two live auctions" do
    v = Vehicle.new(seller: users(:alice), vin: vehicles(:camry).vin, year: 2020, make: "Toyota", model: "Camry", mileage: 1)
    assert_not v.valid?
    assert_includes v.errors[:vin], "is already in a live auction"
  end
end
