source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.3.0'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails', branch: 'main'
gem 'rails', '~> 7.1', '>= 7.1.3.2'

# Use Puma as the app server
gem 'pg', '~> 1.5', '>= 1.5.6'
gem 'puma', '~> 6.4', '>= 6.4.2'
gem 'redis', '~> 5.2'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.4.4', require: false

group :development, :test do
  gem 'byebug', '~> 11.1', '>= 11.1.3'
  gem 'pry', '~> 0.14.1'

  gem 'database_cleaner-active_record', '~> 2.1'
  gem 'rspec-rails', '~> 6.1', '>= 6.1.3'
  gem 'rubocop', '~> 1.64', '>= 1.64.1'
  gem 'rubocop-performance', '~> 1.20', '>= 1.20.2'
  gem 'rubocop-rails', '~> 2.25'
  gem 'rubocop-rspec', '~> 2.22'
  gem 'shoulda-matchers', '~> 6.2'
end

group :development do
  # Listen is used by hot reload or other logic trigger by files modification
  gem 'listen', '~> 3.1', '>= 3.1.5'

  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
end
