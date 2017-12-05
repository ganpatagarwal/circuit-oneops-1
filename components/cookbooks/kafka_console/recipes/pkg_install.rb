# Cookbook Name:: kafka_console
# Recipe:: pkg_install.rb
#
# Copyright 2015, @WalmartLabs
#
# All rights reserved - Do Not Redistribute

# install kafka binary
payLoad = node.workorder.payLoad[:kafka].select { |cm| cm['ciClassName'].split('.').last == 'Kafka'}.first

Chef::Log.info("payload: #{payLoad.inspect.gsub("\n"," ")}" )

if payLoad.nil?
    Chef::Log.error("kafka_metadata is missing.")
    exit 1
end

Chef::Log.info("ciAttributes content: "+payLoad["ciAttributes"].inspect.gsub("\n"," "))
kafka_version = payLoad["ciAttributes"]["version"]

kafka_rpm = "kafka-#{kafka_version}.noarch.rpm"

cloud = node.workorder.cloud.ciName
mirror_url_key = "lola"
Chef::Log.info("Getting mirror service for #{mirror_url_key}, cloud: #{cloud}")

mirror_svc = node[:workorder][:services][:mirror]
mirror = JSON.parse(mirror_svc[cloud][:ciAttributes][:mirrors]) if !mirror_svc.nil?
base_url = ''
# Search for Kafka mirror
base_url = mirror[mirror_url_key] if !mirror.nil? && mirror.has_key?(mirror_url_key)

if base_url.empty?
  Chef::Log.error("#{mirror_url_key} mirror is empty for #{cloud}.")
end

kafka_download = base_url + "#{kafka_rpm}"

execute "remove kafka" do
  user "root"
  exists = <<-EOF
  rpm -qa | grep 'kafka'
  EOF
  command "rpm -e $(rpm -qa '*kafka*')"
  only_if exists, :user => "root"
end

# download kafka
remote_file ::File.join(Chef::Config[:file_cache_path], "#{kafka_rpm}") do
  owner "root"
  mode "0644"
  source kafka_download
  action :create
end

# install kafka
execute 'install kafka' do
  user "root"
  cwd Chef::Config[:file_cache_path]
  command "rpm -i #{kafka_rpm}"
end

kafka_manager_rpm = node['kafka_console']['console']['filename']

kafka_manager_download = base_url + "#{kafka_manager_rpm}"

# remove kafka-manager, if it has been installed
execute "remove kafka-manager" do
  user "root"
  exists = <<-EOF
  rpm -qa | grep 'kafka-manager'
  EOF
  command "rpm -e $(rpm -qa 'kafka-manager*')"
  only_if exists, :user => "root"
end

# download kafka-manager
remote_file ::File.join(Chef::Config[:file_cache_path], "#{kafka_manager_rpm}") do
  owner "root"
  mode "0644"
  source kafka_manager_download
  action :create
end

# install kafka-manager
execute 'install kafka-manager' do
  user "root"
  cwd Chef::Config[:file_cache_path]
  command "rpm -i #{kafka_manager_rpm}"
end

# remove php-gd.x86_64
execute "remove php-gd.x86_64" do
  user "root"
  exists = <<-EOF
  rpm -qa | grep 'php-gd.x86_64'
  EOF
  command "rpm -e $(rpm -qa 'php-gd*')"
  only_if exists, :user => "root"
end

# remove php-ZendFramework
execute "remove php-ZendFramework" do
  user "root"
  exists = <<-EOF
  rpm -qa | grep 'php-ZendFramework'
  EOF
  command "rpm -e $(rpm -qa 'php-ZendFramework*')"
  only_if exists, :user => "root"
end

# remove libconfuse
execute "remove libconfuse" do
  user "root"
  exists = <<-EOF
  rpm -qa | grep 'libconfuse'
  EOF
  command "rpm -e $(rpm -qa 'libconfuse')"
  only_if exists, :user => "root"
end

nginx_rpm = node['kafka_console']['nginx']['filename']
nginx_download = base_url + "#{nginx_rpm}"

# remove nginx, if it has been installed
execute "remove nginx" do
  user "root"
  exists = <<-EOF
  rpm -qa | grep 'nginx'
  EOF
  command "rpm -e $(rpm -qa 'nginx*')"
  only_if exists, :user => "root"
end

# download nginx
remote_file ::File.join(Chef::Config[:file_cache_path], "#{nginx_rpm}") do
  owner "root"
  mode "0644"
  source nginx_download
  action :create
end

# install nginx
execute 'install nginx' do
  user "root"
  cwd Chef::Config[:file_cache_path]
  command "rpm -i #{nginx_rpm}"
end


# httpd should has been installed with every OneOps VM.

gweb_rpm = node['kafka_console']['gweb']['filename']
gweb_download = base_url + "#{gweb_rpm}"

remote_file ::File.join(Chef::Config[:file_cache_path], "#{gweb_rpm}") do
  owner "root"
  mode "0644"
  source gweb_download
  action :create
end

# install gweb
execute 'install gweb' do
  user "root"
  cwd Chef::Config[:file_cache_path]
  command "rpm -i #{gweb_rpm}"
end

bash "move-and-chown" do
  user "root"
  code <<-EOF
  (ln -s /usr/share/ganglia/ /var/www/html/gweb)
  (chown -R apache:apache /var/www/html/gweb/)
  EOF
end
