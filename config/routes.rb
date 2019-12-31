Rails.application.routes.draw do
  # Devise
  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks",
                                    sessions: "users/sessions",
                                    passwords: "users/passwords" }

  namespace :auth do
    resource :two_factors, only: [:new, :create, :edit, :destroy]
    resources :otp_sessions, only: [:new, :create]
    resources :backup_code_sessions, only: [:new, :create]
    resources :backup_codes, only: [:index, :create]
    get '/backup_codes/print', to: 'backup_codes#print'
    get '/backup_codes/download', to: 'backup_codes#download'
    get '/two_factors', to: redirect('/auth/two_factors/new')
    get '/otp_sessions', to: redirect('/auth/otp_sessions/new')
    get '/backup_code_sessions', to: redirect('/auth/backup_code_sessions/new')
  end

  # Admin
  namespace :admin do
    resources :users
    resources :announcements
    resources :notifications

    root to: "users#index"
  end

  # Main app routes
  resources :notifications, only: [:index]
  resources :announcements, only: [:index]

  get '/privacy', to: 'home#privacy'
  get '/terms', to: 'home#terms'

  root to: 'home#index'
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end
