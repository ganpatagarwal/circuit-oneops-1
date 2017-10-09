require 'excon'

def gen_conn(cloud_service,host)
  encoded = Base64.encode64("#{cloud_service[:username]}:#{cloud_service[:password]}").gsub("\n","")
  conn = Excon.new(
      'https://'+host,
      :headers => {
          'Authorization' => "Basic #{encoded}",
          'Content-Type' => 'application/x-www-form-urlencoded'
      },
      :ssl_verify_peer => false)
  return conn
end

Chef::Log.info("Migrating loadbalancer")

# Check if GSLB site id matches for new lb and old lb
cloud_name = node.workorder.cloud.ciName
new_lb_service_type = node.lb.lb_service_type

exit_with_error "#{new_lb_service_type} service not found. either add it or change service type" if !node.workorder.services.has_key?("#{new_lb_service_type}")

new_cloud_service = nil
if !node.workorder.services["#{new_lb_service_type}"].nil? &&
    !node.workorder.services["#{new_lb_service_type}"][cloud_name].nil?

  new_cloud_service = node.workorder.services["#{new_lb_service_type}"][cloud_name]
end

exit_with_error "Not able to find cloud service with servicetype: #{new_lb_service_type}" if new_cloud_service.nil?

# Fetching old configuration
old_lb_service_type = node[:workorder][:rfcCi][:ciBaseAttributes][:lb_service_type]
old_cloud_service = nil
if !node.workorder.services["#{old_lb_service_type}"].nil? &&
    !node.workorder.services["#{old_lb_service_type}"][cloud_name].nil?

  old_cloud_service = node.workorder.services["#{old_lb_service_type}"][cloud_name]
end

exit_with_error "Not able to find cloud service with servicetype: #{old_lb_service_type}" if old_cloud_service.nil?

if new_cloud_service[:ciAttributes][:gslb_site_dns_id] != old_cloud_service[:ciAttributes][:gslb_site_dns_id]
  Chef::Log.error("gslb_site_dns_id does not match for old lb service type : #{old_lb_service_type} \
    and new lb service type : #{new_lb_service_type} .Please check your cloud configuration")
  raise Exception, "gslb_site_dns_id does not match for old lb service type : #{old_lb_service_type} \
    and new lb service type : #{new_lb_service_type} .Please check your cloud configuration"
end

include_recipe "lb::build_load_balancers"

if new_lb_service_type == 'lb'
  az_map = JSON.parse(new_cloud_service[:ciAttributes][:availability_zones])
  if node.workorder.has_key?("rfcCi") &&
      node.workorder.rfcCi.ciAttributes.has_key?("availability_zone")

    host_old = az_map[node.workorder.rfcCi.ciAttributes.availability_zone]
    Chef::Log.info("previous netscaler: #{host_old}")
    node.set["ns_conn_prev"] = gen_conn(new_cloud_service[:ciAttributes],host_old)
  end
end

# Creating new loadbalancer
Chef::Log.info("Creating New loadbalancer")
node.set["rfcAction"] = "delete"
include_recipe "lb::delete"
node.set["rfcAction"] = "replace"
include_recipe "lb::add"

# If creation is success , delete old loadbalancer
Chef::Log.info("Deleting existing loadbalancer with servicetype: #{old_lb_service_type}")

# Deleting old loadbalancer

case old_cloud_service[:ciClassName].split(".").last.downcase
  when /azure_lb/
    include_recipe "azure_lb::delete"

  when /netscaler/
    # node.set["ns_conn"] = nil
    n = netscaler_connection "conn" do
      action :nothing
    end
    n.run_action(:create)

    include_recipe "netscaler::delete_lbvserver"
    include_recipe "netscaler::delete_servicegroup"
    include_recipe "netscaler::delete_server"
    include_recipe "netscaler::logout"

  when /octavia/
    include_recipe "octavia::delete_lb"
end
