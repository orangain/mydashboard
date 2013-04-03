template "reverse_proxy_site.conf" do
  path "/etc/nginx/sites-available/reverse_proxy"
  source "reverse_proxy_site.conf.erb"
  owner "root"
  group "root"
  mode "0644"
  notifies :reload, 'service[nginx]'
end

# Disable default site
link "/etc/nginx/sites-enabled/default" do
  action :delete
  only_if "test -L /etc/nginx/sites-enabled/default"
  notifies :reload, 'service[nginx]'
end

# Enable reverse proxy
link "/etc/nginx/sites-enabled/reverse_proxy" do
  action :create
  to "/etc/nginx/sites-available/reverse_proxy"
  owner "root"
  notifies :reload, 'service[nginx]'
end
