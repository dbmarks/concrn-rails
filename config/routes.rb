Streetmom::Application.routes.draw do

  resources :agencies

  devise_for :users, path_prefix: 'my'

  resources :reports, except: %w(edit) do
    collection do
      get 'active'
      get 'history'
    end

    member do
      post 'upload' => 'reports#update'
      get 'download' => 'reports#download', :as => :download
    end
  end

  resources :users, except: %w(destroy) do
    collection do
      get 'deactivated'
    end
    member do
      post 'start', to: 'shifts#start', :as => :start_shift
      post  'end',  to: 'shifts#end',   :as => :end_shift
    end
  end


  namespace :api do
    resources :users, except: %w(create update destroy edit new show index) do
      collection do
        get 'is_user_responder'
        get 'has_responder_shift_started'
        get 'start_responder_shift'
        get 'end_responder_shift'
      end
    end
    resources :phone_numbers, only: [:new, :create]
    post 'phone_numbers/verify' => "phone_numbers#verify"
  end


  resources :dispatches, only: %w(create update)
  resources :logs,       only: %w(create update)
  resources :reporters,  only: %w(show create new)
  resources :sms,        only: %w(create)

  resources :uploads,    only: %w(destroy)

  root 'pages#home'
end
