set :default_stage, "production"
require 'capistrano/ext/multistage'

require "bundler/capistrano"

set :application, "mydashboard"
set :repository,  "https://github.com/orangain/mydashboard"

set :scm, :git # You can set :scm explicitly or Capistrano will make an intelligent guess based on known version control directory names
# Or: `accurev`, `bzr`, `cvs`, `darcs`, `git`, `mercurial`, `perforce`, `subversion` or `none`
set :deploy_via, :remote_cache

# setting true causes failure in git checkout
# See: https://github.com/capistrano/capistrano/issues/276
set :use_sudo, false

# if you want to clean up old releases on each deploy uncomment this:
# after "deploy:restart", "deploy:cleanup"

# if you're still using the script/reaper helper you will need
# these http://github.com/rails/irs_process_scripts

# If you are using Passenger mod_rails uncomment this:
namespace :deploy do
  task :copy_config, :roles => :app do
    name = "config.secret.ru"
    # Using top.upload instread of upload
    # See: https://gist.github.com/mrchrisadams/3084229
    top.upload(name, "#{latest_release}/#{name}")
  end

  task :start, :roles => :app, :except => { :no_release => true } do
    run "#{sudo} restart #{application} || #{sudo} start #{application}"
  end

  task :stop, :roles => :app, :except => { :no_release => true } do
    run "#{sudo} stop #{application}"
  end

  task :restart, :roles => :app, :except => { :no_release => true } do
    start
  end

  task :write_upstart_script, :roles => :app do
    upstart_script = <<-UPSTART_SCRIPT
description "#{application} upstart script"
start on (local-filesystem and net-device-up)
stop on shutdown
respawn
respawn limit 5 60
setuid #{user}
script
  chdir #{current_path}
  exec bundle exec dashing start
end script
UPSTART_SCRIPT

    put upstart_script, "/tmp/#{application}.conf"
    run "#{sudo} mv /tmp/#{application}.conf /etc/init"
  end
end

after 'deploy:update_code', 'deploy:copy_config'
after 'deploy:update', 'deploy:write_upstart_script'
