Rails.application.routes.draw do
  devise_for :users

  root "essays#index"

  resources :essays do
    resource  :position,  only: [:update], controller: "positions"
    resources :highlights, only: %i[create destroy]
  end

  resource :preferences, only: [:update]

  get "up", to: "rails/health#show", as: :rails_health_check

  # PWA
  get "manifest", to: "pwa#manifest", as: :pwa_manifest, defaults: { format: :json }
  get "service-worker", to: "pwa#service_worker"
end
