class CreateScans < ActiveRecord::Migration[8.0]
  def change
    create_table :scans do |t|
      t.text :text          # OCR 辨識後的原始文字
      t.string :category    # 分類 / 歸戶
      t.datetime :recognized_at

      t.timestamps
    end
    add_index :scans, :category
  end
end
