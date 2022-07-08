GrapeAPI.config do |config|
  config.base_api_class = "Api::base"
  config.pagination.configure do |pagination|
    pagination.paginator = :kaminari
    pagination.per_page = "Per-Page"
    pagination.per_page_count = 25
    pagination.include_total = true
    pagination.page = "Page"
  end
end