Rails.application.routes.draw do
  root "pages#home"

  get "category/:slug", to: "pages#category", as: :category
  get "search", to: "pages#search", as: :search
  get "article/:id", to: "pages#article", as: :article
  get "business-idea", to: "pages#business_idea", as: :business_idea

  post "business-ideas/:business_idea_id/vote", to: "votes#create", as: :business_idea_vote

  post "newsletter", to: "newsletter#create", as: :newsletter
  get "newsletter/confirm", to: "newsletter#confirm"
  get "newsletter/unsubscribe", to: "newsletter#unsubscribe"
end