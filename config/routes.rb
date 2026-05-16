Rails.application.routes.draw do
  devise_for :users

  root "essays#index"

  resources :essays do
    resource  :position,  only: [:update], controller: "positions"
    resources :highlights, only: %i[create destroy]
    resources :recommendations, only: [:create]
  end
  resources :recommendations, only: [:show]

  resources :highlights, only: [] do
    resources :highlight_tags, only: %i[create destroy], path: :tags
  end

  resources :tags,    only: %i[index show], param: :name
  resources :authors, only: [:show]

  resource :preferences, only: [:update]

  get "up", to: "rails/health#show", as: :rails_health_check

  # PWA
  get "manifest", to: "pwa#manifest", as: :pwa_manifest, defaults: { format: :json }
  get "service-worker", to: "pwa#service_worker"
end
