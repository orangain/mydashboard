#
# Cookbook Name:: ruby
# Recipe:: default
#
# Copyright 2013, orangain
#
# All rights reserved - Do Not Redistribute
#

package "ruby1.9.3" do
  action :install
end

gem_package "bundler" do
  action :install
end
