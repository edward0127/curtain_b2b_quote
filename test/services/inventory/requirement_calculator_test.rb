require "test_helper"

class Inventory::RequirementCalculatorTest < ActiveSupport::TestCase
  test "calculates single open requirements with zero track metres for active flow" do
    result = Inventory::RequirementCalculator.new(
      width_mm: 3830,
      opening_type: :single_open,
      ceiling_drop_mm: 2410,
      finished_floor_mode: :just_off_floor
    ).calculate

    assert_equal 0, result.track_metres_required
    assert_equal 7, result.brackets_total
    assert_equal 72, result.hooks_total
    assert_equal "72", result.hooks_display
    assert_equal 2370, result.factory_drop_mm
  end

  test "calculates double open hooks split and puddled factory drop with zero track metres" do
    result = Inventory::RequirementCalculator.new(
      width_mm: 3030,
      opening_type: :double_open,
      ceiling_drop_mm: 2415,
      finished_floor_mode: :puddled
    ).calculate

    assert_equal 0, result.track_metres_required
    assert_equal 6, result.brackets_total
    assert_equal 60, result.hooks_total
    assert_equal "30 and 30", result.hooks_display
    assert_equal 2415, result.factory_drop_mm
  end
end
