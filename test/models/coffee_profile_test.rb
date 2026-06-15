require "test_helper"

class CoffeeProfileTest < ActiveSupport::TestCase
  test "需要關聯到一筆 Scan" do
    profile = CoffeeProfile.new
    assert_not profile.valid?
    assert_includes profile.errors.attribute_names, :scan
  end

  test "同一筆 Scan 只能有一筆 CoffeeProfile" do
    scan = scans(:one)
    CoffeeProfile.create!(scan: scan)
    dup = CoffeeProfile.new(scan: scan)
    assert_not dup.valid?
    assert_includes dup.errors.attribute_names, :scan_id
  end

  test "roast_level 只接受 light/medium/dark 或空白" do
    scan = scans(:one)
    assert CoffeeProfile.new(scan: scan, roast_level: "light").valid?
    assert CoffeeProfile.new(scan: scan, roast_level: nil).valid?
    assert_not CoffeeProfile.new(scan: scan, roast_level: "espresso").valid?
  end

  test "parse_from_scan 依 OCR 文字建立結構化資料" do
    scan = Scan.create!(text: <<~TEXT)
      Bolivia Brenda Palli
      Process Washed
      Varietal Caturra
      Altitude 1500-1680m
      Light Roasts
      Plum, Orange
    TEXT

    profile = CoffeeProfile.parse_from_scan(scan)

    assert profile.persisted?
    assert_equal scan.id, profile.scan_id
    assert_equal "Caturra", profile.varietal
    assert_equal "light", profile.roast_level
    assert_equal 1680, profile.altitude_max_m
  end

  test "parse_from_scan 重複呼叫會更新同一筆而非新增" do
    scan = scans(:one)
    p1 = CoffeeProfile.parse_from_scan(scan)
    p2 = CoffeeProfile.parse_from_scan(scan)

    assert_equal p1.id, p2.id
    assert_equal 1, CoffeeProfile.where(scan_id: scan.id).count
  end
end
