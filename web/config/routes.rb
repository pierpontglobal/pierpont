Rails.application.routes.draw do
  root "auctions#index"

  resources :auctions, only: %i[index show] do
    resources :bids, only: :create
  end
  resources :listings, only: %i[new create]
  resource :session, only: %i[new create destroy]
  resource :registration, only: %i[new create]
  resource :demo_session, only: :create

  scope :assist, controller: :assist, as: :assist do
    post :vin
    post :photo
    post :estimate
  end

  get "model" => "pages#model", as: :model_card
  get "up" => "rails/health#show", as: :rails_health_check
end
