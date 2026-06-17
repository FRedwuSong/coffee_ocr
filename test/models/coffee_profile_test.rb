require "test_helper"

class CoffeeProfileTest < ActiveSupport::TestCase
  ZH_BOLIVIA = "品名：咖啡豆 咖啡豆產國：玻利维亞 烘焙程度：浅焙 净重：200g+1% 製造商：時久企業有限公司 製造日期：2026/06/08".freeze
  EN_BOLIVIA = "Bolivia Brenda Palli Washed Light Roasts Country Bolivia Process Washed Varietal Caturra Region Caranavi Altitude1500-1680m Plum, Orange".freeze

  test "roast_level 只接受 light/medium/dark 或空白" do
    assert CoffeeProfile.new(roast_level: "light").valid?
    assert CoffeeProfile.new(roast_level: nil).valid?
    assert_not CoffeeProfile.new(roast_level: "espresso").valid?
  end

  test "language 接受 zh/en/mixed 或空白" do
    assert CoffeeProfile.new(language: "mixed").valid?
    assert_not CoffeeProfile.new(language: "jp").valid?
  end

  test "create_for 為單筆 scan 建立專屬 profile 並解析" do
    scan = Scan.create!(text: EN_BOLIVIA)
    profile = CoffeeProfile.create_for(scan)

    assert_equal profile, scan.reload.coffee_profile
    assert_equal "Caturra", profile.varietal
    assert_equal "light", profile.roast_level
    assert_equal [scan], profile.scans.to_a
  end

  test "merge_scans 把中英文兩半合併為一支豆（英文優先、互補）" do
    zh = Scan.create!(text: ZH_BOLIVIA, recognized_at: Time.utc(2026, 6, 15, 16, 18))
    en = Scan.create!(text: EN_BOLIVIA, recognized_at: Time.utc(2026, 6, 15, 16, 24))
    CoffeeProfile.create_for(zh)
    CoffeeProfile.create_for(en)

    profile = CoffeeProfile.merge_scans([zh.id, en.id])

    # 兩筆 scan 都掛在同一支豆下，且只剩一筆 profile
    assert_equal 2, profile.scans.count
    assert_equal 1, CoffeeProfile.count

    # 衝突欄位英文優先
    assert_equal "Bolivia", profile.origin_country
    assert_equal "Bolivia Brenda Palli", profile.product_name
    # 互補：中文提供製造商/日期，英文提供品種/產區
    assert_equal "時久企業有限公司", profile.manufacturer
    assert_equal Date.new(2026, 6, 8), profile.manufactured_on
    assert_equal "Caturra", profile.varietal
    assert_equal "Caranavi", profile.region
    assert_equal "mixed", profile.language
  end

  test "merge_scans 後清掉空掉的 profile" do
    zh = Scan.create!(text: ZH_BOLIVIA)
    en = Scan.create!(text: EN_BOLIVIA)
    CoffeeProfile.create_for(zh)
    CoffeeProfile.create_for(en)
    assert_equal 2, CoffeeProfile.count

    CoffeeProfile.merge_scans([zh.id, en.id])
    assert_equal 1, CoffeeProfile.count
  end
end
