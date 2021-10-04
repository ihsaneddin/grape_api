# GrapeAPI
Short description and motivation.

## Usage
How to use my plugin.

## Installation
Add this line to your application's Gemfile:

```ruby
gem 'grape_api, path: "modules/grape_api"'
```

And then execute:
```bash
$ bundle
```

## Setup
install gem `pagy` or `will_paginate` or `kaminari`
pagination will be included on the header, we can customized the config like below :
```ruby
GrapeAPI.configure do |configuration|
  config.pagination.config do |config|
    # If you have more than one gem included, you can choose a paginator.
    config.paginator = :kaminari # or :will_paginate

    # By default, this is set to 'Total'
    config.total_header = 'X-Total'

    # By default, this is set to 'Per-Page'
    config.per_page_header = 'X-Per-Page'

    # Optional: set this to add a header with the current page number.
    config.page_header = 'X-Page'

    # Optional: set this to add other response format. Useful with tools that define :jsonapi format
    config.response_formats = [:json, :xml, :jsonapi]

    # Optional: what parameter should be used to set the page option
    config.page_param = :page
    # or
    # config.page_param do |params|
    #   params[:page][:number] if params[:page].is_a?(ActionController::Parameters)
    # end

    # Optional: what parameter should be used to set the per page option
    config.per_page_param = :per_page
    # or
    # config.per_page_param do |params|
    #   params[:page][:size] if params[:page].is_a?(ActionController::Parameters)
    # end

    # Optional: Include the total and last_page link header
    # By default, this is set to true
    # Note: When using kaminari, this prevents the count call to the database
    config.include_total = false
  end
end
```


## Contributing
Contribution directions go here.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
