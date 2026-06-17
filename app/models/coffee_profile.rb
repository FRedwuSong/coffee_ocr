# 一支豆解析後的結構化資料。可由一筆或多筆 Scan(OCR 原文) 合併而成
# （例如背面中文標籤 + 正面英文規格）。解析邏輯在 CoffeeLabelParser。
class CoffeeProfile < ApplicationRecord
  has_many :scans, dependent: :nullify

  ROAST_LEVELS = %w[light medium dark].freeze
  LANGUAGES = %w[zh en mixed].freeze

  # 各製造商建議的「試飲期」天數，自製造日起算（純計算，不存 DB）。
  # 找不到對照的製造商時用 TASTING_DAYS_DEFAULT。數字可依實際建議調整。
  TASTING_DAYS = {
    "時久企業有限公司" => 30,
  }.freeze
  TASTING_DAYS_DEFAULT = 14

  validates :roast_level, inclusion: { in: ROAST_LEVELS }, allow_blank: true
  validates :language, inclusion: { in: LANGUAGES }, allow_blank: true

  scope :by_country, ->(c) { where(origin_country: c) if c.present? }
  scope :by_roast, ->(r) { where(roast_level: r) if r.present? }

  # 為一筆新 Scan 建立專屬的 CoffeeProfile（匯入時每筆 scan 先各自成一支）。
  def self.create_for(scan)
    profile = create!
    scan.update!(coffee_profile: profile)
    profile.rebuild!
    profile
  end

  # 把多筆 scan 合併到同一支豆：以第一筆的 profile 為目標，其餘 scan 改掛過來，
  # 清掉因此空掉的 profile，再重新解析合併。回傳合併後的 profile。
  def self.merge_scans(scan_ids)
    targets = Scan.where(id: scan_ids).order(:recognized_at, :id).to_a
    return nil if targets.empty?

    profile = targets.first.coffee_profile || create!
    targets.each { |s| s.update!(coffee_profile: profile) unless s.coffee_profile_id == profile.id }
    where.missing(:scans).where.not(id: profile.id).destroy_all
    profile.rebuild!
    profile
  end

  # 試飲期天數（依公司名稱對照；沒有公司名稱就無法判斷）。
  def tasting_days
    return nil if manufacturer.blank?
    TASTING_DAYS[manufacturer] || TASTING_DAYS_DEFAULT
  end

  # 試飲期截止日（製造日 + 試飲期天數）。需同時有製造日期與公司名稱。
  def tasting_until
    return nil if manufactured_on.blank? || tasting_days.nil?
    manufactured_on + tasting_days
  end

  # 依今天計算試飲期還剩幾天（正數=還剩、0=今天到期、負數=已過）。
  def tasting_days_left(today = Date.current)
    return nil if tasting_until.nil?
    (tasting_until - today).to_i
  end

  # 重新解析所有所屬 scan 的 OCR 文字並合併（衝突英文優先），寫回欄位。
  def rebuild!
    parsed = scans.order(:recognized_at, :id).map { |s| CoffeeLabelParser.parse(s.text) }
    assign_attributes(CoffeeLabelParser.merge(parsed))
    save!
    self
  end
end
