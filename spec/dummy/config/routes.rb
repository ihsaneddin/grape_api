Rails.application.routes.draw do
  mount GrapeAPI::Engine => "/grape_api"
end
