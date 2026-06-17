# 即時顯示 Google 試算表的原始 OCR 資料（與去重後的豆列表並存的另一個入口）。
class SpreadsheetController < ApplicationController
  def index
    rows = GoogleSheet.rows
    @header = rows.first || []
    @rows = rows.drop(1)
  rescue GoogleSheet::FetchError => e
    @fetch_error = e.message
  end
end
