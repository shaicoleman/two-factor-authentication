require 'sidekiq/web'

Rails.application.routes.draw do
  # Devise
  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks",
                                    sessions: "users/sessions" }

  devise_scope :user do
    scope controller: 'users/otp_sessions' do
      get   '/users/sign_in/otp', action: :new, as: :new_user_otp_session
      post  '/users/sign_in/otp', action: :create, as: :user_otp_session
    end
    scope controller: 'users/two_factors' do
      get   '/users/two_factors/new', action: :new, as: :new_user_two_factors
      post  '/users/two_factors/new', action: :create, as: :user_two_factors
      get   '/users/two_factors/edit', action: :edit, as: :edit_user_two_factors
    end
    scope controller: 'users/backup_codes' do
      get   '/users/backup_codes', action: :index, as: :user_backup_codes
      post  '/users/backup_codes', action: :create
    end
  end

  resource :two_factor

  # Admin
  authenticate :user, lambda { |u| u.admin? } do
    mount Sidekiq::Web => '/sidekiq'
  end

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
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
