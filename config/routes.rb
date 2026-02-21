Rails.application.routes.draw do
  devise_for :users, skip: [ :registrations ]

  namespace :admin do
    resources :b2b_customers, except: [ :show ] do
      post :impersonate, on: :member
    end
    resource :settings, only: [ :edit, :update ]
    resources :products do
      resources :pricing_rules, except: [ :index, :show ]
    end
    resources :quote_templates, except: [ :show ]
    resources :quote_requests, only: [ :index, :show, :update ] do
      member do
        patch :update_status
        post :convert_to_job
        get :document
      end
    end
    resources :jobs, only: [ :index, :show, :update ]
  end

  resource :impersonation, only: [ :destroy ]
  get "terms", to: "legal#terms"
  get "privacy", to: "legal#privacy"

  get "dashboard", to: "dashboard#show", as: :dashboard
  resources :quote_requests, only: [ :index, :new, :create, :show ] do
    member do
      get :document
    end
  end

  root "dashboard#show"

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
end
