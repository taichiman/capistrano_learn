require "rvm/capistrano"
require 'bundler/capistrano'
require 'capistrano/ext/multistage'

set :stages, %w(production staging)
set :default_stage, "staging"

set :application, "cap learn 2"
set :user, "admin"

set :scm, :git
set :repository,  "git@github.com:taichiman/capistrano_learn.git"
set :deploy_via, :remote_cache
# set :branch, "master"

#role :web, "your web-server here"                          # Your HTTP server, Apache/etc
#role :app, "your app-server here"                          # This may be the same as your `Web` server
#role :db,  "your primary db-server here", :primary => true # This is where Rails migrations will run
#role :db,  "your slave db-server here"

default_run_options[:pty] = true # needed for git password prompts
set :use_sudo, false
set :keep_releases, 5

# if you want to clean up old releases on each deploy uncomment this:
# after "deploy:restart", "deploy:cleanup"

# if you're still using the script/reaper helper you will need
# these http://github.com/rails/irs_process_scripts

namespace :deploy do
  task :start, :roles => :app, :except => { :no_release => true } do
    run "cd #{deploy_to}/current && bundle exec #{unicorn_binary} -c #{unicorn_conf} -E #{rails_env} -D"
  end

  task :stop, :roles => :app, :except => { :no_release => true } do
    run "if [ -f #{unicorn_pid} ] && [ -e /proc/$(cat #{unicorn_pid}) ]; then kill `cat #{unicorn_pid}`; fi"
  end

  task :gstop, :roles => :app, :except => { :no_release => true } do
    run "if [ -f #{unicorn_pid} ] && [ -e /proc/$(cat #{unicorn_pid}) ]; then kill -s QUIT `cat #{unicorn_pid}`; fi"
  end

  task :restart, :roles => :app, :except => { :no_release => true } do
    stop
    start
  end

  task :reload, :roles => :app, :except => { :no_release => true } do
    run "if [ -f #{unicorn_pid} ] && [ -e /proc/$(cat #{unicorn_pid}) ]; then kill -s USR2 `cat #{unicorn_pid}`; fi"
  end

  namespace :db do
    desc "Seed the database on already deployed code"
    task :seed, :only => {:primary => true}, :except => { :no_release => true } do
      run "cd #{current_path}; RAILS_ENV=#{rails_env} bundle exec rake db:seed"
    end

    desc "Setup application schema"
    task :setup do
      run "cd #{current_path}; RAILS_ENV=#{rails_env} bundle exec rake db:create"
    end

    desc "Wipe tables then rerun all migrations and seed database"
    task :remigrate, :only => {:primary => true}, :except => { :no_release => true } do
      run "cd #{current_path}; RAILS_ENV=#{rails_env} bundle exec rake db:remigrate"
    end
  end

  desc "Symlink shared configs and folders on each release."
  task :symlink_shared do
    run "ln -nfs #{shared_path}/config/database.yml #{release_path}/config/database.yml"
  end

end

task :uname do
  run "uname -a"
end

after 'deploy:update_code', 'deploy:symlink_shared'
after "deploy:update", "deploy:cleanup"

# server '27.50.89.108', :app, :web, :db, :primary => true

set :deploy_to, "/home/www/#{application}"
set :rails_env, 'production'

#set :rvm_ruby_string, '1.9.3'

#set :rvm_ruby_string, ENV['GEM_HOME'].gsub(/.*\//,"")
set :rvm_ruby_string, :local
set :rvm_install_ruby_params, '--1.9'      # for jruby/rbx default to 1.9 mode
set :rvm_install_pkgs, %w[libyaml openssl] # package list from https://rvm.io/packages
set :rvm_install_ruby_params, '--with-opt-dir=/usr/local/rvm/usr' # package support

set :unicorn_binary, "unicorn"
set :unicorn_conf, "#{deploy_to}/current/config/unicorn/#{rails_env}.rb"
set :unicorn_pid, "#{deploy_to}/shared/pids/unicorn.pid"
set :unicorn_pid_old, "#{unicorn_pid}.old"

before 'deploy:setup', 'rvm:install_rvm'   # install RVM
before 'deploy:setup', 'rvm:install_pkgs'  # install RVM packages before Ruby
before 'deploy:setup', 'rvm:install_ruby'  # install Ruby and create gemset, or:
before 'deploy:setup', 'rvm:create_gemset' # only create gemset
before 'deploy:setup', 'rvm:import_gemset' # import gemset from file


task :r do |params|
  require 'pry'
  binding.pry
end

namespace :logs do
  desc "Tail unicorn error logs"
  task :unicorn_err, :roles => :app do
    trap("INT") { puts 'Interupted'; exit 0; }
    run "tail -f #{shared_path}/log/unicorn_error.log" do |channel, stream, data|
      puts  # for an extra line break before the host name
      puts "#{channel[:host]}: #{data}"
      break if stream == :err
    end
  end
end