Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  get "tutorial", to: "tutorials#index", as: :tutorial
  get "tutorial/debug", to: "tutorials#debug", as: :tutorial_debug
  get "tutorial/profiles/:id", to: "tutorials#profiles", as: :tutorial_profile

  # --- ADD --- 2026/09/01 sou 仮割当ページへの画面遷移機能実装  --- start ---

  get "work_requests/draft", to: "work_requests#draft", as: :draft

    # --- ADD --- 2026/09/01 sou 仮割当ページへの画面遷移機能実装  --- end ---

    get "work_requests/shift", to: "work_requests#shift"
    # --- ADD --- 2026/09/02 sou シフト表のエクスポートを追加  --- end ---
    get "work_requests/export", to: "work_requests#export", as: :export_work_requests
    # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
    # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
    # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

    # Defines the root path route ("/")
    # root "posts#index"
    root "work_requests#index"

  resources :work_requests, only: %i[index show edit update]
  delete "work_requests/:work_request_id/assignments/:id",
    to: "work_requests#destroy_assignment",
    as: :work_request_assignment
  resources :staff_members, only: [ :index ]
  get "examples/local-data",
    to: "examples#local_data",
    as: :examples_local_data

    if Rails.env.development? &&
    ENV["ENABLE_CHANGE_EVENT_DEBUG"] == "true"
      namespace :debug do
        resources :change_events,
                  only: %i[index create destroy]
      end
    end
end
