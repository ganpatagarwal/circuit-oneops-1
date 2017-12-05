#
# Cookbook Name:: kafka
# Recipe:: jmxtrans.rb
#
# Copyright 2014, @WalmartLabs
#
# All rights reserved - Do Not Redistribute

# jmxtrans config file
template "/etc/sysconfig/jmxtrans" do
  source "jmxtrans.erb"
  owner  'root'
  group  'root'
  mode   '0644'
  notifies :restart, "service[jmxtrans]"
end

monitoring_system = node.workorder.rfcCi.ciAttributes.monitoring_system

case monitoring_system
when "Graphite"
  graphite_host = get_graphite_host
  # write the conf file for Graphite reporter
  land_graphite_jmx_conf(graphite_host)
else
  Chef::Log.error(monitoring_system + " is not recognized")
  exit 1
end

# jmxtrans service
service "jmxtrans" do
  action [:restart, :enable]
  supports :status => true, :restart => true, :reload => true
end
