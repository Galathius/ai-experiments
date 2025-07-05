Rails.application.routes.draw do
  resources :chats, only: [:index, :show, :destroy] do
    resources :messages, only: [:create]
  end
  
  # For creating messages without specifying a chat (creates new chat)
  resources :messages, only: [:create]
  
  resources :emails, only: [:index, :show] do
    collection do
      post :import
    end
  end
  
  resource :session
  resources :passwords, param: :token
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  get "/auth/:provider/callback" => "sessions/omni_auths#create", as: :omniauth_callback
  get "/auth/failure" => "sessions/omni_auths#failure", as: :omniauth_failure

  # Defines the root path route ("/")
  root "chats#index"
end
