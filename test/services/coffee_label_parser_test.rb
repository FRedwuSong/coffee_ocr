require "test_helper"

# 測試資料取自 coffee_ocr 試算表的 4 筆真實 OCR 辨識文字。
class CoffeeLabelParserTest < ActiveSupport::TestCase
  ZH_BOLIVIA = <<~TEXT.freeze
    品名：咖啡豆
    保存方式：
    成份：100%阿拉比卡咖啡豆
    請置於乾燥陰涼處，避免陽光直射
    咖啡豆產國：玻利维亞
    開封後請密封保存並儘早飲用
    烘焙程度：浅焙
    净重：200g+1%
    製造商：時久企業有限公司
    地址：114台北市内湖區瑞光路76巷20號5楼
    電話：(02)-8792-7668
    官網：https://lab19coffee.com/
    製造日期：2026/06/08（西元年/月/日）
    裂造地：臺灣
    保存期限：2026/12/08（西元年/月/日）
  TEXT

  EN_BOLIVIA = <<~TEXT.freeze
    Bolivia Brenda Palli
    Washed
    Light Roasts Country Bolivia
    Process Washed
    Varietal Caturra
    Region Caranavi
    Altitude 1500-1680m
    Plum, Pluot, Orange, Cashew
  TEXT

  EN_ETHIOPIA = <<~TEXT.freeze
    LAB 19 RORSTNO 200g
    Ethiopia Mewa Premium
    Washed
    Light Roasts Country Ethiopia
    Process Washed
    Varietal Helena Forest Heirl
    Region West Arsi
    Altitude 2220m
    Orange, Peach, Red Plum, Milk Tea
  TEXT

  test "解析中文背標的主要欄位" do
    a = CoffeeLabelParser.parse(ZH_BOLIVIA)

    assert_equal "zh", a[:language]
    assert_equal "咖啡豆", a[:product_name]
    assert_equal "玻利维亞", a[:origin_country]
    assert_equal "light", a[:roast_level]
    assert_equal "200g+1%", a[:net_weight]
    assert_equal 200, a[:net_weight_g]
    assert_equal "時久企業有限公司", a[:manufacturer]
    assert_equal "https://lab19coffee.com/", a[:website]
    assert_equal "臺灣", a[:origin]
    assert_equal Date.new(2026, 6, 8), a[:manufactured_on]
    assert_equal Date.new(2026, 12, 8), a[:expires_on]
  end

  test "中文成份不會吃進下一段文字" do
    a = CoffeeLabelParser.parse(ZH_BOLIVIA)
    assert_equal "100%阿拉比卡咖啡豆", a[:ingredients]
  end

  test "解析英文規格表的杯測欄位" do
    a = CoffeeLabelParser.parse(EN_BOLIVIA)

    assert_equal "en", a[:language]
    assert_equal "Bolivia Brenda Palli", a[:product_name]
    assert_equal "Bolivia", a[:origin_country]
    assert_equal "Washed", a[:process]
    assert_equal "Caturra", a[:varietal]
    assert_equal "Caranavi", a[:region]
    assert_equal "1500-1680m", a[:altitude]
    assert_equal 1500, a[:altitude_min_m]
    assert_equal 1680, a[:altitude_max_m]
    assert_equal "light", a[:roast_level]
    assert_equal %w[Plum Pluot Orange Cashew], a[:flavor_notes]
  end

  test "單一海拔值的 min/max 相同，並解析淨重" do
    a = CoffeeLabelParser.parse(EN_ETHIOPIA)

    assert_equal "Ethiopia", a[:origin_country]
    assert_equal "West Arsi", a[:region]
    assert_equal 2220, a[:altitude_min_m]
    assert_equal 2220, a[:altitude_max_m]
    assert_equal 200, a[:net_weight_g]
    assert_equal ["Orange", "Peach", "Red Plum", "Milk Tea"], a[:flavor_notes]
  end

  # 帶冒號標籤的英文格式（Region: / Roasted On: / Varietal: / process: / Note:），
  # 末端還黏著日式地址與電話。
  EN_PANAMA = "SWAMP Panama Nirvana Region: volcan Roasted On: 20260409 " \
              "Varietal: Geisha process: Natural Anaerobic " \
              "Note:plum, gold rum, American cherry, ripe, pineapple " \
              "Tokyo Shinjuku Nishishinjuku 7-21-12 Renge-So105 0366832584".freeze

  test "解析帶冒號標籤的英文格式（Region/Roasted On/Varietal/Note）" do
    a = CoffeeLabelParser.parse(EN_PANAMA)

    assert_equal "en", a[:language]
    assert_equal "Panama", a[:origin_country]   # 沒有 Country 標籤，從內文辨識
    assert_equal "Panama Nirvana", a[:product_name] # 商店名 SWAMP 切掉、保留產國
    assert_equal "SWAMP", a[:manufacturer]      # 產國之前的商店名切成製造商
    assert_equal "volcan", a[:region]           # 不會吃進 "Roasted On"
    assert_equal "Geisha", a[:varietal]
    assert_equal "Natural Anaerobic", a[:process] # 不會吃進 "Note"
    assert_equal Date.new(2026, 4, 9), a[:manufactured_on]
    assert_equal "20260409", a[:manufactured_on_raw]
    assert_equal "0366832584", a[:phone]
    assert_equal "Tokyo Shinjuku Nishishinjuku 7-21-12 Renge-So105", a[:manufacturer_address]
    # 地址、電話都切掉後，風味乾淨
    assert_equal ["plum", "gold rum", "American cherry", "ripe", "pineapple"], a[:flavor_notes]
  end

  test "parse_date 支援 YYYYMMDD 連寫" do
    a = CoffeeLabelParser.parse("Colombia Roasted On: 20251231 Note: cocoa")
    assert_equal Date.new(2025, 12, 31), a[:manufactured_on]
  end

  test "空字串安全回傳預設值" do
    a = CoffeeLabelParser.parse("")
    assert_equal [], a[:flavor_notes]
    assert_nil a[:product_name]
  end
end
