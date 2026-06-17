# 把一段 OCR 辨識文字解析成 CoffeeProfile 的結構化欄位。
#
# 支援兩種標籤格式：
#   1. 中文背標（品名 / 成份 / 產國 / 烘焙程度 / 淨重 / 製造商 / 地址 / 電話 /
#      官網 / 製造日期 / 製造地 / 保存期限 / 保存方式）
#   2. 英文規格表（Country / Process / Varietal / Region / Altitude / Roast / 風味）
#
# 設計原則（針對真實 OCR 文字強化）：
#   - 真實資料常「整段空格黏死、無換行」，且欄位會黏在一起（例如 Altitude1500、
#     VarietalHelena）。因此英文解析以「已知標籤關鍵字」當切割界線，不依賴換行。
#   - 中文值常被無標籤的贅句污染（例如「開封後請密封保存並儘早飲用」），
#     解析後會在第一個 boilerplate 句子處截斷。
#   - 盡力解析（best-effort），解析不到回傳 nil（陣列回傳 []），不丟例外。
class CoffeeLabelParser
  # 中文欄位標記：key => 標籤的正則來源（含常見 OCR 錯字/異體字）
  ZH_LABELS = {
    product_name: "品名",
    ingredients: "成[份分]",
    origin_country: "(?:咖啡豆)?產國",
    roast_level: "烘焙程度",
    net_weight: "[淨净]重",
    manufacturer: "製造商",
    manufacturer_address: "地址",
    phone: "[電电][話话]",            # 電話 / 电话 / 電话 混用
    website: "官[網网]",
    manufactured_on: "製造日期",
    origin: "製造地|裂造地|產地",      # 裂造地 為常見 OCR 錯字
    expires_on: "保存期限",
    storage: "保存方式",
  }.freeze

  # 任一中文標籤（非貪婪擷取時的結束界線）
  ANY_ZH_LABEL = "(?:#{ZH_LABELS.values.join('|')})".freeze

  # 會黏進中文欄位值、但本身沒有標籤的贅句（保存/沖煮說明）
  ZH_BOILERPLATE = /開封後請密封保存並儘早飲用|請置於乾燥陰涼處[，,]?\s*避免陽光直射/

  # 英文結構標籤（切割界線用）
  EN_STRUCT = "Country|Process|Varietal|Region|Altitude".freeze
  # 英文品名的結束界線：結構標籤 + 處理法/烘焙度（品名在這些之前）
  EN_NAME_STOP = "#{EN_STRUCT}|Washed|Natural|Honey|Anaerobic|" \
                 "Light\\s*Roast|Medium\\s*Roast|Dark\\s*Roast".freeze

  class << self
    # 回傳可直接 assign 給 CoffeeProfile 的屬性 Hash。
    def parse(text)
      text = text.to_s
      attrs = { flavor_notes: [] }
      return attrs if text.strip.empty?

      lang = detect_language(text)
      attrs[:language] = lang
      lang == "zh" ? parse_zh(text, attrs) : parse_en(text, attrs)

      # 與語言無關的共用後處理
      attrs[:net_weight_g] = grams(attrs[:net_weight] || text)
      attrs[:roast_level] ||= roast_level(text)
      attrs[:website] ||= website(text)
      set_altitude_range(attrs)
      attrs
    end

    # 把多筆 parse 結果合併成一筆（互補；同欄位衝突時「英文優先」）。
    # 中文那半提供製造商/日期/淨重，英文那半提供處理法/品種/產區/風味，互相補齊。
    def merge(parsed_list)
      list = Array(parsed_list).reject(&:blank?)
      return { flavor_notes: [] } if list.empty?

      # 英文排前面 → 取「第一個非空值」時英文優先
      ordered = list.sort_by { |h| h[:language] == "en" ? 0 : 1 }
      keys = list.flat_map(&:keys).uniq

      keys.each_with_object({}) do |key, merged|
        merged[key] =
          case key
          when :language
            langs = list.filter_map { |h| h[:language] }.uniq
            langs.size > 1 ? "mixed" : langs.first
          when :flavor_notes
            ordered.map { |h| h[key] }.find { |v| v.present? } || []
          else
            ordered.map { |h| h[key] }.find { |v| v.present? }
          end
      end
    end

    private

    # 含中文標籤關鍵字 → zh；否則 en
    def detect_language(text)
      text.match?(/品名|成[份分]|產國|烘焙程度|製造商|保存/) ? "zh" : "en"
    end

    # ---- 中文背標 ----
    def parse_zh(text, attrs)
      ZH_LABELS.each_key { |key| attrs[key] = extract_zh(text, ZH_LABELS[key]) }

      attrs[:manufactured_on_raw] = attrs[:manufactured_on]   # 保留 OCR 原文
      attrs[:manufactured_on] = parse_date(attrs[:manufactured_on])
      attrs[:expires_on] = parse_date(attrs[:expires_on])
      attrs[:phone] = clean_phone(attrs[:phone])
      # 烘焙程度擷取出的是原文（例如「浅焙」），正規化為 light/medium/dark
      attrs[:roast_level] = roast_level(attrs[:roast_level].to_s)
      # 保存方式常被擠掉，若文中有保存說明則補回
      attrs[:storage] = attrs[:storage].presence ||
        (text.match?(/請置於乾燥陰涼處/) ? "請置於乾燥陰涼處，避免陽光直射" : nil)
      attrs
    end

    # 擷取「標籤：值」中的值：非貪婪擷取至下一個已知標籤、換行或字串結尾，
    # 再於第一個 boilerplate 贅句處截斷，並去掉尾註（例如「（西元年/月/日）」）。
    def extract_zh(text, label_source)
      re = /(?:#{label_source})\s*[：:]\s*(.*?)(?=(?:#{ANY_ZH_LABEL})\s*[：:]|[\r\n]|\z)/m
      m = text.match(re)
      return nil unless m

      value = m[1].split(ZH_BOILERPLATE).first.to_s.strip
      value = value.sub(/（西元年.*$/, "").strip
      value.presence
    end

    # ---- 英文規格表（不依賴換行）----
    def parse_en(text, attrs)
      attrs[:origin_country] = en_value(text, "Country")
      attrs[:process]        = en_value(text, "Process")
      attrs[:varietal]       = en_value(text, "Varietal")
      attrs[:region]         = en_value(text, "Region")

      # 海拔用數字樣式擷取（容忍 "Altitude1500-1680m" 無空格的情形）
      tail = text
      if (m = text.match(/Altitude\s*[:：]?\s*(\d[\d\s\-–—~]*m?)/i))
        attrs[:altitude] = m[1].strip
        tail = text[m.end(0)..].to_s   # 海拔之後通常就是風味描述
      end

      attrs[:flavor_notes] = comma_list(tail)
      attrs[:product_name] = en_product_name(text)
      attrs[:net_weight] = text[/(\d+\s*g)\b/i, 1]&.delete(" ")
      attrs
    end

    # 擷取英文「Label 值」，值非貪婪擷取至下一個結構標籤、換行或結尾。
    # 結構標籤以 lookahead 比對，可吃到無空格黏住的下一欄（例如 VarietalHelena）。
    def en_value(text, label)
      re = /#{label}\s*[:：]?\s*(.+?)(?=\s*(?:#{EN_STRUCT})|[\r\n]|\z)/i
      m = text.match(re)
      m && m[1].strip.presence
    end

    # 英文品名 = 第一個結構/處理法標籤之前的文字，並去掉開頭的烘焙廠代碼/重量等雜訊。
    def en_product_name(text)
      head = text[/\A\s*(.+?)\s*(?=#{EN_NAME_STOP})/i, 1] ||
             text.split(/[\r\n]/).first
      words = head.to_s.split(/\s+/).drop_while { |w| en_noise_word?(w) }
      words.join(" ").presence
    end

    # 開頭雜訊字：品牌字 LAB、或任何含數字的 token（烘焙代碼/重量/批號，如 RORSTNO200g）
    def en_noise_word?(word)
      word.match?(/\Alab\z/i) || word.match?(/\d/)
    end

    # ---- 共用解析 ----

    # "200g+1%" / "净重：200g" / "RORSTNO200g" → 200
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
      text[%r{https?://[^\s，（）)]+}i]
    end

    # 取出逗號分隔的風味清單（中英文逗號皆可），只看第一行避免吃到雜訊。
    def comma_list(segment)
      line = segment.to_s.strip.split(/[\r\n]/).first.to_s
      return [] unless line.match?(/[,，]/)

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
      nums = attrs[:altitude].to_s.scan(/\d+/).map(&:to_i)
      return if nums.empty?

      attrs[:altitude_min_m] = nums.min
      attrs[:altitude_max_m] = nums.max
    end
  end
end
