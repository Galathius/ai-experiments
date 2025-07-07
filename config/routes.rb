Rails.application.routes.draw do
  resources :chats, only: [ :show ] do
    resources :messages, only: [ :create ]
  end

  # For creating messages without specifying a chat (creates new chat)
  resources :messages, only: [ :create ]

  delete "/hubspot/disconnect" => "hubspot#disconnect", as: :disconnect_hubspot
  post "/hubspot/import_contacts" => "hubspot#import_contacts", as: :import_hubspot_contacts
  post "/hubspot/import_notes" => "hubspot#import_notes", as: :import_hubspot_notes

  delete "/google/disconnect" => "google#disconnect", as: :disconnect_google
  post "/google/import_emails" => "google#import_emails", as: :import_google_emails
  post "/google/import_calendar" => "google#import_calendar", as: :import_google_calendar

  resource :session, only: [:new, :destroy]
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  get "/auth/:provider/callback" => "sessions/omni_auths#create", as: :omniauth_callback
  get "/auth/failure" => "sessions/omni_auths#failure", as: :omniauth_failure

  # Dashboard and chat interface routes
  get "/chat_interface" => "chats#interface"
  post "/pull_data" => "dashboard#pull_data"
  
  # Defines the root path route ("/")
  root "dashboard#index"
end
