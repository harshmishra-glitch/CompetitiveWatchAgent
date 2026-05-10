Rails.application.routes.draw do
  get "/health", to: "health#show"

  namespace :api do
    # ----- Onboarding -----
    get "restaurants/search", to: "restaurants#search"

    resources :pilot_restaurants, only: %i[index create show] do
      collection do
        get :current
      end
      member do
        get :suggested_competitors
        get :threat_assessments
        get :daily_digest
        get :daily_digests
        get :suggested_questions
      end
    end

    resources :competitor_sets, only: %i[index show create] do
      member do
        get :leaderboard
        get "leaderboard/history", action: :leaderboard_history
      end
      resources :members, only: %i[create destroy], controller: "competitor_set_members"
    end

    # ----- Restaurant drill-down -----
    resources :restaurants, only: %i[show] do
      member do
        get :menu
        get :menu_changes
        get :rating_trend
        get :pricing_analysis
        get :activity_feed
        get :social_signals
        get :serp_presence
        get :google_reviews
      end
    end

    # ----- Chatbot -----
    resources :chat_sessions, only: %i[index show create] do
      resources :messages, only: %i[index create], controller: "chat_messages"
    end
  end
end
