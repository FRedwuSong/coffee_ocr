class CreateCoffeeProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :coffee_profiles do |t|
      # 一筆 Scan(原始 OCR 文字) 對應一筆解析後的結構化資料
      t.references :scan, null: false, foreign_key: true, index: { unique: true }

      # 商品基本資料（多來自中文背標）
      t.string :product_name            # 品名
      t.text   :ingredients             # 成份
      t.string :net_weight              # 淨重原文，例如 "200g+1%"
      t.integer :net_weight_g           # 解析後的公克數，例如 200

      # 產地 / 杯測資料（中文背標 + 英文規格表）
      t.string :origin_country          # 咖啡豆產國 / Country
      t.string :process                 # 處理法 / Process，例如 Washed
      t.string :varietal                # 品種 / Varietal，例如 Caturra
      t.string :region                  # 產區 / Region，例如 Caranavi
      t.string :altitude                # 海拔原文，例如 "1500-1680m"
      t.integer :altitude_min_m         # 解析後海拔下限（公尺）
      t.integer :altitude_max_m         # 解析後海拔上限（公尺）
      t.string :roast_level             # 烘焙程度 / Roast，正規化為 light/medium/dark
      t.string :flavor_notes, array: true, default: [] # 風味，例如 ["Plum", "Orange"]

      # 製造商資訊（中文背標）
      t.string :manufacturer            # 製造商
      t.string :manufacturer_address    # 地址
      t.string :phone                   # 電話
      t.string :website                 # 官網
      t.string :origin                  # 製造地 / 產地，例如 臺灣
      t.text   :storage                 # 保存方式

      # 日期
      t.date :manufactured_on           # 製造日期
      t.date :expires_on                # 保存期限

      t.string :language                # 偵測到的標籤語言：zh / en

      t.timestamps
    end

    add_index :coffee_profiles, :origin_country
    add_index :coffee_profiles, :roast_level
  end
end
