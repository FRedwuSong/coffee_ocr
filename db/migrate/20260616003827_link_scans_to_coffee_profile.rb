class LinkScansToCoffeeProfile < ActiveRecord::Migration[8.0]
  # 一支豆可能由多筆 OCR scan 組成（例如正面英文規格 + 背面中文標籤）。
  # 把關聯從「coffee_profile 屬於一筆 scan」改成「scan 屬於一筆 coffee_profile」。
  def change
    remove_foreign_key :coffee_profiles, :scans
    remove_column :coffee_profiles, :scan_id, :bigint

    add_reference :scans, :coffee_profile, null: true, foreign_key: true
  end
end
