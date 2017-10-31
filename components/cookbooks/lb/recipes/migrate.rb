Chef::Log.info("Migrating loadbalancer")

# Adding more checks to decide migration
config_items_changed= node[:workorder][:rfcCi][:ciBaseAttributes]
if !config_items_changed.empty? && config_items_changed.length > 1 && config_items_changed.has_key?("lb_service_type")
  Chef::Log.error("Detected changes in loadbalancer configuration alongwith request for migration. Migration can not be performed")
  raise("Detected changes in loadbalancer configuration alongwith request for migration. Migration can not be performed")
end

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

# Creating new loadbalancer
Chef::Log.info("Creating New loadbalancer")
node.set["workorder"]["rfcCi"]["ciAttributes"]["dns_record"] = nil
node.set["rfcAction"] = "add"
include_recipe "lb::add"

# If creation is success , delete old loadbalancer
Chef::Log.info("Deleting existing loadbalancer with servicetype: #{old_lb_service_type}")
node.set["rfcAction"] = "delete"

# Deleting old loadbalancer
# Generating load balancer details --start
dns_service = node.workorder.services["dns"][cloud_name]
cloud_dns_id = old_cloud_service[:ciAttributes][:cloud_dns_id]
env_name = node.workorder.payLoad.Environment[0]["ciName"]
asmb_name = node.workorder.payLoad.Assembly[0]["ciName"]
org_name = node.workorder.payLoad.Organization[0]["ciName"]
dns_zone = dns_service[:ciAttributes][:zone]

dc_dns_zone = ""
if old_cloud_service[:ciAttributes].has_key?("gslb_site_dns_id")
  dc_dns_zone = old_cloud_service[:ciAttributes][:gslb_site_dns_id]+"."
end
dc_dns_zone += dns_service[:ciAttributes][:zone]

ci = {}
if node.workorder.has_key?("rfcCi")
  ci = node.workorder.rfcCi
else
  ci = node.workorder.ci
end


def get_ns_service_type(service_type)
  case service_type.upcase
    when "HTTPS"
      service_type = "SSL"
  end

  return service_type.upcase
end

platform = node.workorder.box
platform_name = node.workorder.box.ciName

dcloadbalancers = Array.new
loadbalancers = Array.new

# build load-balancers from listeners
listeners = JSON.parse(ci[:ciAttributes][:listeners])

listeners.each do |l|

  acl = ''
  lb_attrs = l.split(" ")
  vproto = lb_attrs[0]
  vport = lb_attrs[1]
  if vport.include?(':')
    vport_parts = vport.split(':')
    vport = vport_parts[0]
    acl = vport_parts[1]
  end
  iproto = lb_attrs[2]
  iport = lb_attrs[3]

  # Get the service types
  iprotocol = get_ns_service_type(iproto)
  vprotocol = get_ns_service_type(vproto)

  # primary lb - neteng convention
  if cloud_dns_id.nil?
    lb_name = [env_name, platform_name, dns_zone].join(".") + '-'+vprotocol+"_"+vport+"tcp" +'-' + ci[:ciId].to_s + "-lb"
  else
    lb_name = [env_name, platform_name, cloud_dns_id, dns_zone].join(".") + '-'+vprotocol+"_"+vport+"tcp" +'-' + ci[:ciId].to_s + "-lb"
  end

  sg_name = [env_name, platform_name, cloud_name, iport, ci["ciId"].to_s, "svcgrp"].join("-")
  lb = {
      :name => lb_name,
      :iport => iport,
      :vport => vport,
      :acl => acl,
      :sg_name => sg_name,
      :vprotocol => vprotocol,
      :iprotocol => iprotocol
  }
  loadbalancers.push(lb)

  dc_lb_name = [platform_name, env_name, asmb_name, org_name, dc_dns_zone].join(".") +
      '-'+vprotocol+"_"+vport+"tcp-" + platform[:ciId].to_s + "-lb"
  dc_lb = {
      :name => dc_lb_name,
      :iport => iport,
      :vport => vport,
      :acl => acl,
      :sg_name => sg_name,
      :vprotocol => vprotocol,
      :iprotocol => iprotocol
  }
  dcloadbalancers.push(dc_lb)
end
node.set["loadbalancers"] = loadbalancers
node.set["dcloadbalancers"] = dcloadbalancers
# Generating load balancer details --end

case old_cloud_service[:ciClassName].split(".").last.downcase
  when /azure_lb/

    include_recipe "azure_lb::delete"

  when /netscaler/

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
