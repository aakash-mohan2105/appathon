Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  resources :export, only: [:show, :create, :update] do
    member do
      get :file
    end
  end
end
