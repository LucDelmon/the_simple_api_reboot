# config valid for current version and patch releases of Capistrano
lock '~> 3.19.1'

set :application, 'simple-api'
set :repo_url, 'https://github.com/LucDelmon/the_simple_api_reboot.git'

set :branch, ENV.fetch('BRANCH', nil)

# Deploy to the user's home directory
set :deploy_to, "/home/ubuntu/#{fetch(:application)}"

# RVM settings
set :rvm_type, :system # Defaults to: :auto
set :rvm_ruby_version, '3.3.0' # Defaults to: 'default'

# Linked files and directories (shared between releases)
set :linked_dirs, %w[log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system]

# Keep the last 5 releases to rollback if needed
set :keep_releases, 5

set :default_env, {
  DB_USERNAME: 'rails',
  DB_HOST: ENV.fetch('DB_HOST', nil),
  'http_proxy' => 'http://10.0.1.252:3128',
  'https_proxy' => 'http://10.0.1.252:3128',
}

# SSH Options
set :ssh_options, {
  forward_agent: true,
  auth_methods: %w[publickey],
  keys: %w[~/.ssh/id_rsa],
  user: 'ubuntu',
}

namespace :deploy do
  desc 'Write RAILS_MASTER_KEY to config/master.key before migrating'
  task :write_master_key_before_migrate do
    on roles(:app, :db) do
      within release_path do
        # Capture the RAILS_MASTER_KEY from the environment
        rails_master_key = capture('source /etc/profile.d/rails_env.sh && echo $RAILS_MASTER_KEY').strip

        # Ensure the config directory exists in the current release
        execute :mkdir, '-p', 'config'

        # Write the RAILS_MASTER_KEY to config/master.key
        execute :echo, "\"#{rails_master_key}\" > config/master.key"
      end
    end
  end

  desc 'Delete config/master.key at end'
  task :delete_master_key_at_end do
    on roles(:app, :db) do
      within release_path do
        # Remove the master.key after the migration is finished
        execute :rm, '-f', 'config/master.key'
      end
    end
  end

  # Ensure Puma is restarted after deployment
  after :finishing, 'deploy:cleanup'
end

namespace :puma do
  desc 'Restart Puma service'
  task :restart do
    on roles(:app) do
      # If using systemd, restart the Puma service
      execute :sudo, :systemctl, :restart, 'puma'
    end
  end
end

# Ensure master.key is written before migrations are run
before 'deploy:migrating', 'deploy:write_master_key_before_migrate'

# Ensure master.key is deleted after the migration is complete
after 'deploy:finished', 'deploy:delete_master_key_at_end'
after 'deploy:finished', 'puma:restart'
