Rails.application.routes.draw do
  resources :users
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
  get "/reset-password", to: "authentication#reset_pw", as: :reset_pw

  post "/request_otp", to: "otp#create"
  get "/otp-verification", to: "otp#input", as: :otp_input
  post "/verify-otp",  to: "otp#verify", as: :verify_otp
  post "/resend-otp",  to: "otp#resend"
  # get "/otp", to: "otp#new"


  resources :posts, only: [ :index, :show ]
  resources :users

  scope module: "landlord_area" do
    resources :landlords, shallow: true do
      resources :dashboard, :posts
      resources :houses do
        resources :rooms, :invoices, :vehicles, :contracts
      end
      get "/houses-entry", to: "houses#entry"
    end
  end

  scope module: "tenant_area" do
    resources :tenants, shallow: true do
      resources :dashboard, :posts
    end
  end

  scope module: "admin_area" do
    resources :admin, shallow: true do
      resources :dashboard
      resources :houses
    end
  end
end
