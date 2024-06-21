# Load Redis configuration from database.yml
redis_config = Rails.configuration.database_configuration[Rails.env]['redis']

redis_url = redis_config['url']

$redis = Redis.new(url: redis_url)

# Rails.application.config.cache_store = :redis_cache_store, { url: redis_url }

# Rails.application.config.action_cable.url = redis_url
