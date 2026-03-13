Rails.application.routes.draw do
  devise_for :users, skip: [ :registrations ]

  get "edit", to: "partners_editor#home", as: :edit_pages
  get "edit/partners", to: "partners_editor#partners", as: :edit_partners_page
  get "edit/builders", to: "partners_editor#builders", as: :edit_builders_page
  patch "edit/:page", to: "partners_editor#update", as: :update_page_editor

  get "partners/edit", to: redirect("/edit/partners")
  patch "partners/edit", to: "partners_editor#update", defaults: { page: "partners" }, as: :update_partners_page

  get "partners", to: "public_pages#partners"
  get "builders", to: "public_pages#builders"
  get "builders-developers", to: "public_pages#builders"
  post "get-in-touch", to: "public_pages#create_contact", as: :public_contact

  namespace :admin do
    resources :b2b_customers, except: [ :show ] do
      post :impersonate, on: :member
    end
    resource :settings, only: [ :edit, :update ]
    resources :products do
      member do
        get :preview_price
        post :preview_price
      end
      resources :pricing_rules, except: [ :index, :show ]
    end
    resources :inventory_items do
      patch :adjust_stock, on: :member
    end
    resources :pricebook_imports, only: [ :index, :new, :create ]
    resources :quote_requests, only: [ :index, :new, :create, :show, :update ] do
      member do
        patch :update_status
        get :document
        get :invoice
        get :to_chinese_factory
      end
    end
  end

  resource :impersonation, only: [ :destroy ]
  get "terms", to: "legal#terms"
  get "privacy", to: "legal#privacy"

  get "dashboard", to: "dashboard#show", as: :dashboard
  namespace :b2b do
    get "shop", to: "shop#index"
    get "shop/:id", to: "shop#show", as: :shop_product
    resource :cart, only: [ :show ], controller: "carts" do
      post :add_line
      patch "lines/:line_id", action: :update_line, as: :update_line
      delete "lines/:line_id", action: :remove_line, as: :remove_line
      post :checkout
    end
  end
  resources :quote_requests, only: [ :index, :new, :create, :show ] do
    member do
      get :document
    end
  end

  root "public_pages#home"

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
end
