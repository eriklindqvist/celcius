source 'https://rubygems.org'

gem 'sinatra'
gem 'mongoid'
gem 'json'
gem 'erubis'
gem 'bigdecimal'

group :migration do
  gem 'activerecord'
  gem 'mysql'
end

group :development do
  gem 'shotgun'
  gem 'thin'
end

group :production do
  gem 'raindrops', '< 0.14'
  gem 'unicorn'
end
