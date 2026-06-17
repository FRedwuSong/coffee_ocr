Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  resources :scans, only: %i[index show new create destroy] do
    collection do
      post :merge    # 手動把多筆 scan 合併為同一支豆
    end
    member do
      post :reparse  # 重新依 OCR 文字解析
      post :unlink   # 從目前的豆拆出，獨立成一筆
    end
  end

  # 即時從 Google 試算表顯示原始 OCR 資料
  get "raw" => "spreadsheet#index", as: :raw_scans

  # Defines the root path route ("/")
  root "scans#index"
end
