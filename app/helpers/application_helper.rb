module ApplicationHelper
  # 已知單位白名單（數字與單位之間補空格用）。只在數字緊接這些字時才拆，
  # 避免誤切網址 (lab19coffee)、電話 (8792) 等非單位的英數字串。
  UNITS = %w[g kg mg m cm mm km ml l oz].freeze
  UNIT_PATTERN = /(\d)(#{UNITS.join('|')})\b/i

  # 盤古之白：在中英文／中文數字／數字單位之間補上空格，方便閱讀。
  # 純計算、不改資料本身；顯示時才套用。
  #   1. 中英文之間              我喝coffee → 我喝 coffee
  #   2. 中文與數字之間          瑞光路76巷 → 瑞光路 76 巷
  #   3. 數字與單位之間          200g → 200 g、100%阿拉比卡 → 100% 阿拉比卡
  def pangu(text)
    return text if text.blank?

    text.to_s
        .gsub(/(\p{Han})([0-9A-Za-z%])/, '\1 \2')   # 中文 → 英數/%
        .gsub(/([0-9A-Za-z%])(\p{Han})/, '\1 \2')   # 英數/% → 中文
        .gsub(UNIT_PATTERN, '\1 \2')                # 數字 → 單位
  end
end
