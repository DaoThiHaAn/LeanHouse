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
  get "/login", to: "authentication#log_in", as: :login
  post "/login", to: "authentication#handle_log_in", as: :login_handle
  get "/logout", to: "authentication#log_out", as: :logout
  get "/forgot-password", to: "authentication#forgot_pw", as: :forgot_pw
  get "/reset-password", to: "authentication#reset_pw", as: :reset_pw

  post "/request_otp", to: "otp#create"
  get  "/verify_otp",  to: "otp#verify"
  post "/verify_otp",  to: "otp#confirm"
  get "/otp", to: "otp#new"


  resources :posts, only: [ :index, :show ]
  resources :users

  namespace :landlord do
    # Use path: "" to remove the extra "/landlord" segment from the URL
    # but keep the "Landlord::" module and folder structure
    resources :landlords, path: "", shallow: true do
      resources :reports
    end
  end
end
