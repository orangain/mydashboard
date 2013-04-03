template "reverse_proxy_site.conf" do
  path "/etc/nginx/sites-available/reverse_proxy"
  source "reverse_proxy_site.conf.erb"
  owner "root"
  group "root"
  mode "0644"
  notifies :reload, 'service[nginx]'
end
