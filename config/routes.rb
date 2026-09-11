Rails.application.routes.draw do
  root "pages#home"

  get "category/:slug", to: "pages#category", as: :category
  get "search", to: "pages#search", as: :search
  get "article/:id", to: "pages#article", as: :article
  get "business-idea", to: "pages#business_idea", as: :business_idea
end