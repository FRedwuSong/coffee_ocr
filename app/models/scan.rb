class Scan < ApplicationRecord
  # 一筆 OCR 掃描的原始辨識文字。解析後的結構化咖啡標籤資料見 CoffeeProfile。
  has_one :coffee_profile, dependent: :destroy

  validates :text, presence: true

  before_validation :set_recognized_at, on: :create

  scope :by_category, ->(c) { where(category: c) if c.present? }
  scope :search, ->(q) { where("text ILIKE ?", "%#{sanitize_sql_like(q)}%") if q.present? }
  scope :recent, -> { order(recognized_at: :desc, created_at: :desc) }

  def self.categories
    distinct.where.not(category: [nil, ""]).order(:category).pluck(:category)
  end

  private

  def set_recognized_at
    self.recognized_at ||= Time.current
  end
end
