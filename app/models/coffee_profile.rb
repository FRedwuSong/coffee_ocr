# 一筆 Scan(原始 OCR 文字) 解析後的結構化咖啡標籤資料。
# 解析邏輯放在 CoffeeLabelParser，本 model 只負責結構、驗證與關聯。
class CoffeeProfile < ApplicationRecord
  belongs_to :scan

  ROAST_LEVELS = %w[light medium dark].freeze

  # 一筆 Scan 只會有一筆對應的結構化資料
  validates :scan_id, uniqueness: true
  validates :roast_level, inclusion: { in: ROAST_LEVELS }, allow_blank: true
  validates :language, inclusion: { in: %w[zh en] }, allow_blank: true

  scope :by_country, ->(c) { where(origin_country: c) if c.present? }
  scope :by_roast, ->(r) { where(roast_level: r) if r.present? }

  # 依 Scan 的 OCR 文字解析並建立/更新對應的 CoffeeProfile。
  # 既有資料會被覆寫，沒解析到的欄位保持 parser 回傳的值（通常為 nil/[]）。
  def self.parse_from_scan(scan)
    attrs = CoffeeLabelParser.parse(scan.text)
    profile = find_or_initialize_by(scan_id: scan.id)
    profile.assign_attributes(attrs)
    profile.save!
    profile
  end
end
