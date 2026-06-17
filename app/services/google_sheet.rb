require "csv"
require "net/http"
require "uri"

# 即時從 Google 試算表讀取原始 OCR 列。
#
# 試算表需設為「知道連結的任何人可檢視」，這樣就能直接抓公開的 CSV 匯出，
# 不需要任何金鑰或 API 設定。
#
# 可用環境變數覆寫：
#   GOOGLE_SPREADSHEET_ID  試算表 ID（預設為 coffee_ocr 那張）
#   GOOGLE_SHEET_GID       指定工作表分頁的 gid（選填）
class GoogleSheet
  DEFAULT_SPREADSHEET_ID = "1PjeAehn5nPYXDwbPfhXJDVubveOeqann4XUZ4sRclVc".freeze
  MAX_REDIRECTS = 5

  # 抓取失敗（權限未開、ID 錯誤、回傳登入頁等）時丟這個，讓 controller 顯示指引。
  class FetchError < StandardError; end

  def self.rows(gid: nil)
    new.rows(gid: gid)
  end

  # 回傳二維陣列（含表頭列）；沒有資料時回 []。
  def rows(gid: nil)
    CSV.parse(fetch_csv(gid))
  end

  private

  def fetch_csv(gid)
    response = get_following_redirects(export_uri(gid))

    unless response.is_a?(Net::HTTPSuccess)
      raise FetchError, "讀取試算表失敗（HTTP #{response.code}）。請確認試算表已設為「知道連結的任何人可檢視」。"
    end

    body = response.body.to_s.force_encoding("UTF-8")
    if body.lstrip.start_with?("<!DOCTYPE", "<html", "<HTML")
      raise FetchError, "試算表回傳的是登入頁而非資料。請把「一般存取權」改成「知道連結的任何人」。"
    end

    body
  end

  def export_uri(gid)
    params = { format: "csv" }
    params[:gid] = gid if gid.present?
    URI("https://docs.google.com/spreadsheets/d/#{spreadsheet_id}/export?#{URI.encode_www_form(params)}")
  end

  # Google 的匯出網址會 302 轉址，Net::HTTP 不會自動跟，這裡手動跟幾次。
  def get_following_redirects(uri, limit = MAX_REDIRECTS)
    raise FetchError, "轉址次數過多" if limit.zero?

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 20) do |http|
      http.get(uri.request_uri)
    end

    if response.is_a?(Net::HTTPRedirection) && response["location"].present?
      get_following_redirects(URI.join(uri.to_s, response["location"]), limit - 1)
    else
      response
    end
  end

  def spreadsheet_id
    ENV["GOOGLE_SPREADSHEET_ID"].presence || DEFAULT_SPREADSHEET_ID
  end
end
