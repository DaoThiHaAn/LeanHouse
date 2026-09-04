Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  root "public_pages#main_home"

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
  get  "/resend-otp",  to: redirect("/otp-verification")
  # get "/otp", to: "otp#new"


  resources :posts, only: [ :index, :show ]
  resources :users, only: %i[create update]

  resources :notifications, only: [ :index ] do
    member do
      patch :mark_as_read
    end
    collection do
      patch :mark_all_as_read
    end
  end

  # LANDLORD
  namespace :landlord, module: :landlord_portal do
    resource :profile, only: [ :show, :edit, :update ] do
      patch :update_avatar
      get :new_tel
      post :change_tel
      get :change_password
    end

    resource :dashboard, only: [ :show ]

    resources :bank_accounts, only: %i[index new create destroy] do
      member do
        patch :set_default
      end
    end

    resources :posts

    resources :requests, only: %i[index show] do
      collection do
        get :filtered
      end
      member do
        patch :handle
      end
    end

    resources :houses do
      member do # act on 1 single record
        get "/other-houses", to: "houses#other_houses", as: :other_houses
        patch :change_mode
        get :check_deletion
      end

      resources :services do
        resources :service_variants, only: %i[new create edit update destroy] do
          member do
            get :edit_application
            patch :update_application
          end
        end
      end

      resources :rooms do
        collection do # act on the collection of records
          get :filtered
        end
        resources :service_usage_logs, only: %i[index] do
          collection do
            patch :confirm_all
          end
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

      resources :tenants, only: [ :index, :show, :new, :create, :destroy ] do
        member do
          get :move
          post :move, to: "tenants#execute_move"
        end
        collection do
          get :filtered
        end

        resource :contract, only: %i[new create]
      end

      resources :beds do
        collection do # act on the collection of records
          get :filtered
        end
      end

      resources :assets, except: [ :show ] do
        collection do
          get :filtered
        end

        resources :maintenance_logs do
          collection do
            get :filtered
          end
        end
      end

      resources :contracts, except: %i[new create] do
        collection do
          get :filtered
        end
        member do
          get :extend
          post :extend, to: "contracts#execute_extend"
          patch :extend, to: "contracts#execute_extend"
          get :close
          get :sign_new
          post :sign_new, to: "contracts#execute_sign_new"
        end
      end

      resources :service_usage_logs do
        collection do
          get :filtered
          patch :confirm_all
        end
        member do
          patch :confirm
        end
      end

      resources :invoices do
        collection do
          get :filtered
          get :preview
        end
        member do
          patch :mark_paid
          patch :undo_paid
          patch :cancel
        end
      end

      resources :vehicles, only: %i[index destroy] do
        collection do
          get :filtered
        end
      end
    end
  end

  # TENANT
  namespace :tenant, module: :tenant_portal do
    get "/dashboard", to: "dashboard#show", as: :dashboard

    resource :profile, only: [ :show, :edit, :update ] do
      patch :update_avatar
      get :new_tel
      post :change_tel
      get :change_password
    end

    resources :invoices, only: [ :show, :index ] do
      member do
        patch :mark_paid
      end
    end
    resources :service_usage_logs, only: %i[index edit update create]
    resource :contract, only: [ :show ]
    get "/old-contracts", to: "contracts#old_index"
    resource :room, only: [ :show ]
    resources :services, only: [ :index ]


    resources :requests, only: %i[index show] do
      collection do
        get :filtered
      end
    end
    resources :vehicle_requests, only: %i[new create]
    resources :repair_requests, only: %i[new create]
    resources :leave_house_requests, only: %i[create]
    resources :vehicles, only: %i[index destroy]
  end

  # ADMIN
  namespace :admin, module: :admin_portal do
    get "/login", to: "sessions#new", as: :login
    post "/login", to: "sessions#create", as: :handle_login
    delete "/logout", to: "sessions#destroy", as: :logout
    get "/logout", to: "sessions#destroy"

    root to: "dashboard#show"
    resource :dashboard, only: [ :show ], controller: "dashboard"
    resources :users, only: [ :index, :show ] do
      member do
        patch :toggle_active
        patch :recycle_phone
        get :contracts
        get :invoices
      end
    end
    resources :admins, only: [ :index, :new, :create, :edit, :update ] do
      member do
        patch :toggle_active
      end
    end
    resources :houses, only: [ :index, :show ] do
      resources :services, only: [ :index ]
      resources :assets, only: [ :index ]
      resources :contracts, only: [ :index ]
      resources :invoices, only: [ :index ]
    end
    resources :contracts, only: [ :show ]
    resources :invoices, only: [ :show ]
  end
end
