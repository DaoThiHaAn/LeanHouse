Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  root "public_pages#main_home"

  get "/about", to: "public_pages#about"
  get "/contact", to: "public_pages#contact"
  get "/features", to: "public_pages#features"
  get "/privacy", to: "public_pages#privacy"
  get "/terms-of-use", to: "public_pages#terms"
  get "/report-issues", to: "public_pages#report_issues"


  get "/signup", to: "authentication#sign_up", as: :signup
  get "/login", to: "authentication#login_form", as: :login
  post "/login", to: "authentication#handle_log_in", as: :handle_login
  get "/logout", to: "authentication#log_out", as: :logout
  get "/forgot-password", to: "authentication#forgot_pw", as: :forgot_pw
  post "/forgot-password", to: "authentication#handle_forgot_pw", as: :handle_forgot_pw
  get "/reset-password", to: "authentication#reset_pw", as: :reset_pw

  post "/request_otp", to: "otp#create"
  get "/otp-verification", to: "otp#input", as: :otp_input
  post "/verify-otp",  to: "otp#verify", as: :verify_otp
  post "/resend-otp",  to: "otp#resend"
  # get "/otp", to: "otp#new"


  resources :posts, only: [ :index, :show ]
  resources :users

  namespace :landlord, module: :landlord_portal do
    resource :dashboard, only: [ :show ]

    resources :posts

    resources :houses do
      member do # act on 1 single record
        get "/other-houses", to: "houses#other_houses", as: :other_houses
        patch :change_mode
        get :check_delete
      end

      resources :services

      resources :rooms do
        collection do # act on the collection of records
          get :filtered_table
        end
      end

      resources :floors, only: [ :update, :destroy, :new, :create ] do
        member do
          get :check_delete
        end

        collection do
          patch :sort
        end
      end

      get "/tenants/create_new", to: "tenants#create_new", as: :create_new_tenant
      get "/tenants/available", to: "tenants#available", as: :tenant_available

      # resources :rental_unit, only: [] do
      #   resources :tenants, only: [ :create ]
      # end
      resources :tenants, only: [ :index, :show, :new, :create ] do
        member do
          get :link
        end
      end

      resources :beds do
        collection do # act on the collection of records
          get :filtered_table
        end
      end

      resources :invoices, :vehicles, :contracts
    end
  end

  namespace :tenant, module: :tenant_portal do
    get "/dashboard", to: "dashboard#show", as: :dashboard
    get "/room", to: "room#show", as: :room
    get "/contract", to: "contract#show", as: :contract
    get "/services", to: "services#show", as: :services

    resources :posts
    resources :invoices, only: [ :show, :index ]
    resources :requests
  end

  namespace :admin, module: :admin_area do
    resources :dashboard, :houses
  end
end
