Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  get "tutorial", to: "tutorials#index", as: :tutorial
  get "tutorial/debug", to: "tutorials#debug", as: :tutorial_debug

    # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
    # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
    # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

    # Defines the root path route ("/")
    # root "posts#index"
    root "work_requests#index"

  resources :work_requests, only: [ :index, :show ]
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
