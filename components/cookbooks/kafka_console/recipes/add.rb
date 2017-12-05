# Cookbook Name:: kafka_console
# Recipe:: add
#
# Copyright 2014, @WalmartLabs
#
# All rights reserved - Do Not Redistribute

# install rpms

include_recipe "kafka_console::pkg_install"

include_recipe "kafka_console::set_domain_name"

#monitoring_system = node.workorder.rfcCi.ciAttributes.monitoring_system
#if monitoring_system.eql? "Ganglia"
  # gmetad setup
#  include_recipe "kafka_console::gmetad"

  # gmond setup
#  include_recipe "kafka_console::gmond"

  # httpd setup
#  include_recipe "kafka_console::httpd"
#end

# nginx setup
include_recipe "kafka_console::nginx"

# kafka-manager setup
include_recipe "kafka_console::kafka-manager"

# execute add_init_cluster.sh
bash "add cluster to kafka-manager" do
  user "root"
  code <<-EOF
    /etc/kafka-manager/add_init_cluster.sh
  EOF
end

Chef::Log.info('Installing burrow...')
include_recipe "kafka_console::burrow_install"
