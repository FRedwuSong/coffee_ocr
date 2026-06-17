class AddManufacturedOnRawToCoffeeProfiles < ActiveRecord::Migration[8.0]
  # 製造日期的 OCR 原文（例如 "2026/06/08"），與解析後的 manufactured_on(Date) 並存。
  # 比照 net_weight(原文)+net_weight_g、altitude+altitude_min_m 的「原文+解析」慣例。
  def change
    add_column :coffee_profiles, :manufactured_on_raw, :string
  end
end
