class ScansController < ApplicationController
  before_action :set_scan, only: %i[show edit update destroy reparse unlink]

  def index
    scans = Scan.recent
      .by_category(params[:category])
      .search(params[:q])
      .includes(:coffee_profile)

    # 一支豆只顯示一列（去重）：依 coffee_profile 分組，未掛豆的 scan 各自成組。
    # 每組以最新的 scan 為代表，整組按代表時間由新到舊排序。
    @beans = scans
      .group_by { |s| s.coffee_profile_id || "scan-#{s.id}" }
      .values
      .map { |group| group.sort_by { |s| [s.recognized_at || Time.at(0), s.id] }.reverse }
      .sort_by { |group| group.first.recognized_at || Time.at(0) }
      .reverse

    @categories = Scan.categories
  end

  def show
    @profile = @scan.coffee_profile
    @siblings = @profile ? @profile.scans.where.not(id: @scan.id) : Scan.none
  end

  def new
    @scan = Scan.new
  end

  def edit
  end

  # 修正 OCR 文字後重新解析所屬的豆（文字是解析來源）。
  def update
    if @scan.update(scan_params)
      @scan.coffee_profile&.rebuild!
      redirect_to @scan, notice: "已更新並重新解析。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # 建立 Scan 後，先各自成為一支豆（之後可在畫面手動合併）。
  def create
    @scan = Scan.new(scan_params)

    if @scan.save
      CoffeeProfile.create_for(@scan)
      redirect_to @scan, notice: "已建立並解析掃描結果。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  # 手動合併：把勾選的多筆 scan 併成同一支豆。
  def merge
    # 每個勾選代表「一支豆」，其 value 可能是逗號串接的多筆 scan id（同一支豆的全部掃描）。
    selections = Array(params[:scan_ids]).reject(&:blank?)
    if selections.size < 2
      redirect_to scans_path, alert: "請至少勾選兩支豆再合併。"
      return
    end

    ids = selections.flat_map { |v| v.to_s.split(",") }.reject(&:blank?)
    profile = CoffeeProfile.merge_scans(ids)
    redirect_to scan_path(profile.scans.first), notice: "已將 #{selections.size} 支豆合併為同一支。"
  end

  # 從目前的豆拆出，獨立成自己的一支豆。
  def unlink
    CoffeeProfile.create_for(@scan)
    redirect_to @scan, notice: "已從原本的豆拆出，獨立成一筆。"
  end

  def reparse
    @scan.coffee_profile&.rebuild!
    redirect_to @scan, notice: "已重新解析。"
  end

  def destroy
    profile = @scan.coffee_profile
    @scan.destroy
    profile&.reload
    profile&.scans&.any? ? profile.rebuild! : profile&.destroy
    redirect_to scans_path, notice: "已刪除掃描結果。", status: :see_other
  end

  private

  def set_scan
    @scan = Scan.find(params[:id])
  end

  def scan_params
    params.require(:scan).permit(:text, :category)
  end
end
