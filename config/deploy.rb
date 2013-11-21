set :stages, %w(production staging)
set :default_stage, "staging"
require 'capistrano/ext/multistage'

set :application, "capistrano_learn"
set :user, "admin"
set :group, "admin"

set :scm, :git
set :repository, "git@github.com:taichiman/capistrano_learn.git"
set :deploy_to, "/home/admin/www/#{application}"
set :deploy_via, :remote_cache
set :rails_env, 'production'

task :uname do
  run 'uname -a'
end