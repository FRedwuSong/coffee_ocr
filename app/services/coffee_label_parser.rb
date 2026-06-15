# 把一段 OCR 辨識文字解析成 CoffeeProfile 的結構化欄位。
#
# 支援兩種標籤格式：
#   1. 中文背標（品名 / 成份 / 產國 / 烘焙程度 / 淨重 / 製造商 / 地址 / 電話 /
#      官網 / 製造日期 / 製造地 / 保存期限 / 保存方式）
#   2. 英文規格表（Country / Process / Varietal / Region / Altitude / Roast / 風味）
#
# 設計原則：
#   - 盡力解析（best-effort）。OCR 文字常有錯字、缺空格、欄位順序錯亂，
#     解析不到的欄位回傳 nil（陣列欄位回傳 []），不丟例外。
#   - 使用 class methods，無狀態。
class CoffeeLabelParser
  # 中文欄位標記：key => 標籤的正則來源（含常見 OCR 錯字）
  ZH_LABELS = {
    product_name: "品名",
    ingredients: "成[份分]",
    origin_country: "(?:咖啡豆)?產國",
    roast_level: "烘焙程度",
    net_weight: "[淨净]重",
    manufacturer: "製造商",
    manufacturer_address: "地址",
    phone: "電話|电话",
    website: "官[網网]",
    manufactured_on: "製造日期",
    origin: "製造地|裂造地|產地",      # 裂造地 為常見 OCR 錯字
    expires_on: "保存期限",
    storage: "保存方式",
  }.freeze

  # 英文欄位標記
  EN_LABELS = {
    origin_country: "Country",
    process: "Process",
    varietal: "Varietal",
    region: "Region",
    altitude: "Altitude",
  }.freeze

  # 任一中文標籤（用於非貪婪擷取時的結束界線）
  ANY_ZH_LABEL = "(?:#{ZH_LABELS.values.join('|')})".freeze
  # 任一英文標籤
  ANY_EN_LABEL = "(?:#{EN_LABELS.keys.map(&:to_s).map(&:capitalize).join('|')}|Roast)".freeze

  class << self
    # 回傳可直接 assign 給 CoffeeProfile 的屬性 Hash。
    def parse(text)
      text = text.to_s
      attrs = base_attributes
      return attrs if text.strip.empty?

      lang = detect_language(text)
      attrs[:language] = lang

      if lang == "zh"
        parse_zh(text, attrs)
      else
        parse_en(text, attrs)
      end

      # 與語言無關的共用後處理
      attrs[:net_weight_g] = grams(attrs[:net_weight] || text)
      attrs[:roast_level] ||= roast_level(text)
      attrs[:website] ||= website(text)
      set_altitude_range(attrs)
      attrs
    end

    private

    def base_attributes
      { flavor_notes: [] }
    end

    # 含中文標籤關鍵字 → zh；否則 en
    def detect_language(text)
      text.match?(/品名|成[份分]|產國|烘焙程度|製造商|保存/) ? "zh" : "en"
    end

    # ---- 中文背標 ----
    def parse_zh(text, attrs)
      ZH_LABELS.each_key do |key|
        attrs[key] = extract_zh(text, ZH_LABELS[key])
      end

      attrs[:manufactured_on] = parse_date(attrs[:manufactured_on])
      attrs[:expires_on] = parse_date(attrs[:expires_on])
      attrs[:phone] = clean_phone(attrs[:phone])
      # 烘焙程度擷取出的是原文（例如「浅焙」），正規化為 light/medium/dark
      attrs[:roast_level] = roast_level(attrs[:roast_level].to_s)
      attrs[:flavor_notes] = flavor_notes(text)
      attrs
    end

    # 擷取「標籤：值」中的值，非貪婪擷取至下一個已知標籤、換行或字串結尾。
    # 以換行為界可避免在「一行一欄位」的 OCR 文字中吃進下一段內容。
    def extract_zh(text, label_source)
      re = /(?:#{label_source})\s*[：:]\s*(.+?)(?=(?:#{ANY_ZH_LABEL})\s*[：:]|[\r\n]|\z)/m
      m = text.match(re)
      return nil unless m

      value = m[1].strip
      # 去掉常見的尾註，例如「（西元年/月/日）」
      value = value.sub(/（西元年.*$/, "").strip
      value.presence
    end

    # ---- 英文規格表 ----
    def parse_en(text, attrs)
      lines = text.split(/[\r\n]+/).map(&:strip).reject(&:empty?)

      EN_LABELS.each do |key, label|
        attrs[key] = extract_en(text, label)
      end

      # 第一行通常是品名，例如 "Bolivia Brenda Palli"
      attrs[:product_name] = lines.first
      attrs[:net_weight] = text[/\b(\d+\s*g)\b/i, 1]&.delete(" ")
      attrs[:flavor_notes] = flavor_notes(text)
      attrs
    end

    # 擷取「Label 值」中的值（英文標籤後不一定有冒號），至下一個標籤或行尾
    def extract_en(text, label)
      re = /\b#{label}\b\s*[:：]?\s*(.+?)(?=\s+#{ANY_EN_LABEL}\b|[\r\n]|\z)/i
      m = text.match(re)
      m && m[1].strip.presence
    end

    # ---- 共用解析 ----

    # "200g+1%" / "净重：200g" → 200
    def grams(value)
      value.to_s[/(\d+)\s*g\b/i, 1]&.to_i
    end

    # 浅焙/淺焙→light、中焙/中度→medium、深焙→dark、Light/Medium/Dark Roast→同上
    def roast_level(text)
      case text
      when /[浅淺]焙|Light\s*Roast/i then "light"
      when /中(?:度)?焙|Medium\s*Roast/i then "medium"
      when /深焙|Dark\s*Roast/i then "dark"
      end
    end

    def website(text)
      text[%r{https?://[^\s）)]+}i]
    end

    # 取出風味描述（逗號分隔的那一段），中英文逗號皆可
    def flavor_notes(text)
      line = text.split(/[\r\n]+/).map(&:strip).find do |l|
        l.count(",，") >= 1 && !l.match?(/地址|電話|电话|製造|官[網网]/)
      end
      return [] unless line

      line.split(/[,，]/).map(&:strip).reject(&:empty?)
    end

    # "(02)-8792-7668" / "（02）-8792-7668" → 全形轉半形並去除多餘空白
    def clean_phone(value)
      return nil if value.blank?

      value.tr("（）", "()").strip.presence
    end

    # "2026/06/08" / "2026/6/8" → Date；解析失敗回傳 nil
    def parse_date(value)
      m = value.to_s.match(%r{(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})})
      return nil unless m

      Date.new(m[1].to_i, m[2].to_i, m[3].to_i)
    rescue ArgumentError
      nil
    end

    # "1500-1680m" → min 1500 / max 1680；"2220m" → min/max 同值
    def set_altitude_range(attrs)
      raw = attrs[:altitude].to_s
      nums = raw.scan(/\d+/).map(&:to_i)
      return if nums.empty?

      attrs[:altitude_min_m] = nums.min
      attrs[:altitude_max_m] = nums.max
    end
  end
end
