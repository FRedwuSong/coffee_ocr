require "test_helper"

class ScansControllerTest < ActionDispatch::IntegrationTest
  EN_LABEL = "Bolivia Brenda Palli Process Washed Varietal Caturra Altitude1500-1680m Light Roasts Plum, Orange".freeze
  ZH_LABEL = "品名：咖啡豆 咖啡豆產國：玻利维亞 製造商：時久企業有限公司 製造日期：2026/06/08".freeze

  test "index 正常顯示" do
    get scans_path
    assert_response :success
  end

  test "new 正常顯示" do
    get new_scan_path
    assert_response :success
  end

  test "create 會建立 Scan 並各自成一支豆" do
    assert_difference ["Scan.count", "CoffeeProfile.count"], 1 do
      post scans_path, params: { scan: { text: EN_LABEL, category: "coffee" } }
    end
    scan = Scan.order(:created_at).last
    assert_redirected_to scan_path(scan)
    assert_equal "Caturra", scan.coffee_profile.varietal
  end

  test "create 文字空白時回 422 且不建立資料" do
    assert_no_difference "Scan.count" do
      post scans_path, params: { scan: { text: "" } }
    end
    assert_response :unprocessable_entity
  end

  test "merge 把勾選的多筆 scan 併為一支豆" do
    zh = Scan.create!(text: ZH_LABEL); CoffeeProfile.create_for(zh)
    en = Scan.create!(text: EN_LABEL); CoffeeProfile.create_for(en)

    assert_difference "CoffeeProfile.count", -1 do
      post merge_scans_path, params: { scan_ids: [zh.id, en.id] }
    end
    assert_response :redirect
    assert_equal en.reload.coffee_profile_id, zh.reload.coffee_profile_id
  end

  test "merge 勾選少於兩筆時提示且不變動" do
    en = Scan.create!(text: EN_LABEL); CoffeeProfile.create_for(en)
    assert_no_difference "CoffeeProfile.count" do
      post merge_scans_path, params: { scan_ids: [en.id] }
    end
    assert_redirected_to scans_path
  end

  test "unlink 把 scan 從原本的豆拆出" do
    zh = Scan.create!(text: ZH_LABEL)
    en = Scan.create!(text: EN_LABEL)
    CoffeeProfile.create_for(zh)
    CoffeeProfile.create_for(en)
    profile = CoffeeProfile.merge_scans([zh.id, en.id])
    assert_equal 1, CoffeeProfile.count

    assert_difference "CoffeeProfile.count", 1 do
      post unlink_scan_path(en)
    end
    assert_not_equal zh.reload.coffee_profile_id, en.reload.coffee_profile_id
  end

  test "show 顯示合併後欄位" do
    scan = Scan.create!(text: EN_LABEL)
    CoffeeProfile.create_for(scan)
    get scan_path(scan)
    assert_response :success
    assert_match "Caturra", response.body
  end

  test "destroy 刪掉 scan 後同步處理其豆" do
    scan = Scan.create!(text: EN_LABEL)
    CoffeeProfile.create_for(scan)
    assert_difference ["Scan.count", "CoffeeProfile.count"], -1 do
      delete scan_path(scan)
    end
    assert_redirected_to scans_path
  end
end
