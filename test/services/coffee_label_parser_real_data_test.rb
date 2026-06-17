require "test_helper"

# 以 coffee_ocr 試算表「實際儲存」的 OCR 原文做迴歸測試。
# 重點：真實資料是「整段空格黏死、無換行」，且欄位會黏在一起
# （Altitude1500、VarietalHelena），並夾雜錯字與無標籤贅句。
class CoffeeLabelParserRealDataTest < ActiveSupport::TestCase
  # 第1筆：玻利維亞 中文背標
  ROW1 = "品名：咖啡豆保存方式：   成份：100%阿拉比卡咖啡豆請置於乾燥陰涼處，避免陽光直射   咖啡豆產國：玻利维亞開封後請密封保存並儘早飲用   烘焙程度：浅焙 净重：200g+1% 製造商：時久企業有限公司 地址：114台北市内湖區瑞光路76巷20號5楼 電話：(02)-8792-7668 官網：https://lab19coffee.com/製造日期：2026/06/08（西元年/月/日）   裂造地：臺灣保存期限：2026/12/08（西元年/月/日）".freeze

  # 第2筆：Bolivia 英文規格表（單行、空格黏字）
  ROW2 = "Bolivia Brenda Palli Washed Light Roasts Country Bolivia Process Washed Varietal Caturra Region Caranavi Altitude1500-1680m   Plum, Pluot, Orange, Cashew".freeze

  # 第3筆：衣索比亞 中文背標（欄位順序錯亂、電话異體字）
  ROW3 = "成份：100%阿拉比卡咖啡豆品名：咖啡豆請置於乾燥陰涼處，避免陽光直射保存方式   咖啡豆產國：衣索比亞開封後請密封保存並儘早飲用  烘焙程度：浅焙 净重：200g+1% 製造商：時久企業有限公司 地址：114台北市内湖區瑞光路76巷20號5楼 電话：（02）-8792-7668官網：https://lab19coffee.com/製造日期：2026/06/08（西元年/月/日   裂造地：臺灣保存期限：2026/12/08（西元年/月/日".freeze

  # 第4筆：Ethiopia 英文規格表（含烘焙廠雜訊 LAB 19 RORSTNO200g）
  ROW4 = "LAB 19 RORSTNO200g Ethiopia Mewa Premium Washed Light Roasts Country Ethiopia Process Washed VarietalHelena Forest Heirl Region West Arsi Altitude2220m Orange, Peach, Red Plum, Mik Tea".freeze

  test "第1筆 中文背標：欄位乾淨、無贅句污染" do
    a = CoffeeLabelParser.parse(ROW1)

    assert_equal "zh", a[:language]
    assert_equal "咖啡豆", a[:product_name]
    assert_equal "100%阿拉比卡咖啡豆", a[:ingredients]   # 不含「請置於…」贅句
    assert_equal "玻利维亞", a[:origin_country]          # 不含「開封後…」贅句
    assert_equal "light", a[:roast_level]
    assert_equal "200g+1%", a[:net_weight]
    assert_equal 200, a[:net_weight_g]
    assert_equal "時久企業有限公司", a[:manufacturer]
    assert_equal "114台北市内湖區瑞光路76巷20號5楼", a[:manufacturer_address]
    assert_equal "(02)-8792-7668", a[:phone]
    assert_equal "https://lab19coffee.com/", a[:website]
    assert_equal "臺灣", a[:origin]
    assert_equal "2026/06/08", a[:manufactured_on_raw]   # 保留 OCR 原文
    assert_equal Date.new(2026, 6, 8), a[:manufactured_on]
    assert_equal Date.new(2026, 12, 8), a[:expires_on]
    assert_equal "請置於乾燥陰涼處，避免陽光直射", a[:storage]
  end

  test "第2筆 英文規格表：單行黏字仍能切出各欄" do
    a = CoffeeLabelParser.parse(ROW2)

    assert_equal "en", a[:language]
    assert_equal "Bolivia Brenda Palli", a[:product_name]
    assert_equal "Bolivia", a[:origin_country]
    assert_equal "Washed", a[:process]
    assert_equal "Caturra", a[:varietal]
    assert_equal "Caranavi", a[:region]                  # 不會連到 Altitude/風味
    assert_equal "1500-1680m", a[:altitude]              # 容忍 Altitude1500 無空格
    assert_equal 1500, a[:altitude_min_m]
    assert_equal 1680, a[:altitude_max_m]
    assert_equal "light", a[:roast_level]
    assert_equal %w[Plum Pluot Orange Cashew], a[:flavor_notes]
  end

  test "第3筆 中文背標：順序錯亂與電话異體字仍正確" do
    a = CoffeeLabelParser.parse(ROW3)

    assert_equal "zh", a[:language]
    assert_equal "咖啡豆", a[:product_name]
    assert_equal "衣索比亞", a[:origin_country]
    assert_equal "(02)-8792-7668", a[:phone]             # 電话(異體字) 也能解析
    assert_equal "114台北市内湖區瑞光路76巷20號5楼", a[:manufacturer_address]  # 地址不含電話
    assert_equal Date.new(2026, 6, 8), a[:manufactured_on]
    assert_equal Date.new(2026, 12, 8), a[:expires_on]
    assert_equal "臺灣", a[:origin]
  end

  test "第4筆 英文規格表：去除烘焙廠雜訊、解析黏住的品種" do
    a = CoffeeLabelParser.parse(ROW4)

    assert_equal "en", a[:language]
    assert_equal "Ethiopia Mewa Premium", a[:product_name]   # 去掉 LAB 19 RORSTNO200g
    assert_equal "Ethiopia", a[:origin_country]
    assert_equal "Washed", a[:process]
    assert_equal "Helena Forest Heirl", a[:varietal]         # VarietalHelena 黏字
    assert_equal "West Arsi", a[:region]
    assert_equal "2220m", a[:altitude]
    assert_equal 2220, a[:altitude_min_m]
    assert_equal 2220, a[:altitude_max_m]
    assert_equal 200, a[:net_weight_g]
    assert_equal ["Orange", "Peach", "Red Plum", "Mik Tea"], a[:flavor_notes]
  end
end
