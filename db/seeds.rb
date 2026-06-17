# 匯入 coffee_ocr 試算表的 4 筆原始 OCR 辨識文字。
# 依「全部各自匯入、之後在畫面手動合併」的流程：每筆 scan 先各自成一支豆。
# 來源：https://docs.google.com/spreadsheets/d/1PjeAehn5nPYXDwbPfhXJDVubveOeqann4XUZ4sRclVc
require "time"

ROWS = [
  {
    recognized_at: "2026-06-15T16:18:02Z",
    text: "品名：咖啡豆保存方式：   成份：100%阿拉比卡咖啡豆請置於乾燥陰涼處，避免陽光直射   咖啡豆產國：玻利维亞開封後請密封保存並儘早飲用   烘焙程度：浅焙 净重：200g+1% 製造商：時久企業有限公司 地址：114台北市内湖區瑞光路76巷20號5楼 電話：(02)-8792-7668 官網：https://lab19coffee.com/製造日期：2026/06/08（西元年/月/日）   裂造地：臺灣保存期限：2026/12/08（西元年/月/日）",
  },
  {
    recognized_at: "2026-06-15T16:24:41Z",
    text: "Bolivia Brenda Palli Washed Light Roasts Country Bolivia Process Washed Varietal Caturra Region Caranavi Altitude1500-1680m   Plum, Pluot, Orange, Cashew",
  },
  {
    recognized_at: "2026-06-15T16:26:00Z",
    text: "成份：100%阿拉比卡咖啡豆品名：咖啡豆請置於乾燥陰涼處，避免陽光直射保存方式   咖啡豆產國：衣索比亞開封後請密封保存並儘早飲用  烘焙程度：浅焙 净重：200g+1% 製造商：時久企業有限公司 地址：114台北市内湖區瑞光路76巷20號5楼 電话：（02）-8792-7668官網：https://lab19coffee.com/製造日期：2026/06/08（西元年/月/日   裂造地：臺灣保存期限：2026/12/08（西元年/月/日",
  },
  {
    recognized_at: "2026-06-15T16:26:45Z",
    text: "LAB 19 RORSTNO200g Ethiopia Mewa Premium Washed Light Roasts Country Ethiopia Process Washed VarietalHelena Forest Heirl Region West Arsi Altitude2220m Orange, Peach, Red Plum, Mik Tea",
  },
]

ActiveRecord::Base.transaction do
  ROWS.each do |row|
    scan = Scan.find_or_create_by!(recognized_at: Time.parse(row[:recognized_at])) do |s|
      s.text = row[:text]
      s.category = "coffee"
    end
    CoffeeProfile.create_for(scan) if scan.coffee_profile.nil?
  end
end

puts "Seeded #{Scan.count} scans / #{CoffeeProfile.count} coffee_profiles."
