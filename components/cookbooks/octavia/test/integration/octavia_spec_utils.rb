
class Octavia_spec_utils
  def initialize(node)
    @node=node
  end

  def get_cloud_name()
    cloud_name = @node['workorder']['cloud']['ciName']
    cloud_name

  end

  def get_stickiness()
    lb_attributes = @node[:workorder][:rfcCi][:ciAttributes]
    stickiness = lb_attributes[:stickiness]
    stickiness
  end

  def build_n_return_lb_name()
    node_1 = @node
    cloud_name = @node['workorder']['cloud']['ciName']
    dns_service = nil
    if !@node['workorder']['services']['slb'].nil? &&
        !@node['workorder']['services']['slb'][cloud_name].nil?
      dns_service = @node['workorder']['services']['dns'][cloud_name]
    end
    assembly_name = node_1.workorder.payLoad.Assembly[0]["ciName"]
    org_name = node_1.workorder.payLoad.Organization[0]["ciName"]
    platform_name = node_1.workorder.box.ciName
    env_name = node_1.workorder.payLoad.Environment[0]["ciName"]
    dns_zone = dns_service[:ciAttributes][:zone]
    gslb_site_dns_id = node_1.workorder.services["slb"][cloud_name][:ciAttributes][:gslb_site_dns_id]

    ci = {}
    if node_1.workorder.has_key?("rfcCi")
      ci = node_1.workorder.rfcCi
    else
      ci = node_1.workorder.ci
    end

    @node.set["lb_name"] = [platform_name, env_name, assembly_name, org_name, gslb_site_dns_id, dns_zone].join(".") +'-' + ci[:ciId].to_s + "-lb"

    puts @node.lb_name
    @node.lb_name
  end

  def get_service_metadata()
    cloud_name = get_cloud_name()
    service_lb_attributes = @node[:workorder][:services][:slb][cloud_name][:ciAttributes]
    service_lb_attributes
  end

def get_listeners_from_wo
  listeners = Array.new

  if @node["loadbalancers"]
    raw_data = @node['loadbalancers']
    raw_data.each do |listener|
      listeners.push(listener)
    end
  end

  return listeners
end



def get_dc_lb_names()
  platform_name = @node.workorder.box.ciName
  environment_name = @node.workorder.payLoad.Environment[0]["ciName"]
  assembly_name = @node.workorder.payLoad.Assembly[0]["ciName"]
  org_name = @node.workorder.payLoad.Organization[0]["ciName"]

  cloud_name = @node.workorder.cloud.ciName
  dc = @node.workorder.services["slb"][cloud_name][:ciAttributes][:gslb_site_dns_id]+"."
  dns_zone = @node.workorder.services["dns"][cloud_name][:ciAttributes][:zone]
  dc_dns_zone = dc + dns_zone
  platform_ciId = @node.workorder.box.ciId.to_s

  vnames = { }
  listeners = get_listeners_from_wo()
  listeners.each do |listener|
    frontend_port = listener[:vport]

    service_type = listener[:vprotocol]
    if service_type == "HTTPS"
      service_type = "SSL"
    end
    dc_lb_name = [platform_name, environment_name, assembly_name, org_name, dc_dns_zone].join(".") +
        '-'+service_type+"_"+frontend_port+"tcp-" + platform_ciId + "-lb"

    vnames[dc_lb_name] = nil
  end

  return vnames
end

def get_barbican_container_name()
  certs = @node.workorder.payLoad.DependsOn.select { |d| d["ciClassName"] =~ /Certificate/ }
  certs.each do |cert|
    cert_name =  cert[:ciId].to_s + "_tls_cert_container"
    Chef::Log.info("tls cert name : #{cert_name}")
    return cert_name
  end
end

end

