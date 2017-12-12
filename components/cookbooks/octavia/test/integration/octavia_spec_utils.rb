
CIRCUIT_PATH="/opt/oneops/inductor/circuit-oneops-1"
COOKBOOKS_PATH="#{CIRCUIT_PATH}/components/cookbooks"
OCTAVIA_PATH="#{COOKBOOKS_PATH}/octavia"

require File.expand_path("#{OCTAVIA_PATH}/libraries/data_access/lbaas/loadbalancer_dao", __FILE__)
require File.expand_path("#{OCTAVIA_PATH}/libraries/data_access/lbaas/listener_dao", __FILE__)
require File.expand_path("#{OCTAVIA_PATH}/libraries/data_access/lbaas/pool_dao", __FILE__)
require File.expand_path("#{OCTAVIA_PATH}/libraries/data_access/lbaas/member_dao", __FILE__)
require File.expand_path("#{OCTAVIA_PATH}/libraries/data_access/lbaas/health_monitor_dao", __FILE__)
require File.expand_path("#{OCTAVIA_PATH}/libraries/requests/lbaas/loadbalancer_request", __FILE__)
require File.expand_path("#{OCTAVIA_PATH}/libraries/requests/lbaas/listener_request", __FILE__)
require File.expand_path("#{OCTAVIA_PATH}/libraries/requests/lbaas/pool_request", __FILE__)
require File.expand_path("#{OCTAVIA_PATH}/libraries/requests/lbaas/member_request", __FILE__)
require File.expand_path("#{OCTAVIA_PATH}/libraries/requests/lbaas/health_monitor_request", __FILE__)
require File.expand_path("#{OCTAVIA_PATH}/libraries/models/tenant_model", __FILE__)
require File.expand_path("#{OCTAVIA_PATH}/libraries/loadbalancer_manager", __FILE__)

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

  def build_listener_from_wo()
    env_name = @node.workorder.payLoad.Environment[0]["ciName"]
    asmb_name = @node.workorder.payLoad.Assembly[0]["ciName"]
    org_name = @node.workorder.payLoad.Organization[0]["ciName"]

    cloud_name = @node['workorder']['cloud']['ciName']
    lb_service_type = @node.lb.lb_service_type

    cloud_service = @node.workorder.services["#{lb_service_type}"][cloud_name]
    cloud_dns_id = cloud_service[:ciAttributes][:cloud_dns_id]
    dns_service = nil
    if !@node['workorder']['services']['slb'].nil? &&
        !@node['workorder']['services']['slb'][cloud_name].nil?
      dns_service = @node['workorder']['services']['dns'][cloud_name]
    end
    dns_zone = dns_service[:ciAttributes][:zone]

    platform_name = @node.workorder.box.ciName

    ci = {}
    if @node.workorder.has_key?("rfcCi")
      ci = @node.workorder.rfcCi
    else
      ci = @node.workorder.ci
    end

    # map for iport to node port
    override_iport_map = {}
    @node.workorder.payLoad.DependsOn.each do |dep|
      if dep['ciClassName'] =~ /Container/
        JSON.parse(dep['ciAttributes']['node_ports']).each_pair do |internal_port,external_port|
          override_iport_map[internal_port] = external_port
        end
        puts "override_iport_map: #{override_iport_map.inspect}"
      end
    end

    listeners_list = []
    listeners = JSON.parse(ci[:ciAttributes][:listeners])
    puts "listeners:"
    puts listeners.inspect
    i=0
    listeners.each do |l|

      acl = ''
      puts l.inspect
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

      if override_iport_map.has_key?(iport)
        Chef::Log.info("using container PAT: #{iport} to #{override_iport_map[iport]}")
        iport = override_iport_map[iport]
      end

      # Get the service types
      iprotocol = get_ns_service_type(cloud_service[:ciClassName],iproto)
      vprotocol = get_ns_service_type(cloud_service[:ciClassName],vproto)

      # primary lb - neteng convention
      if cloud_dns_id.nil?
        lb_name = [env_name, platform_name, dns_zone].join(".") + '-'+vprotocol+"_"+vport+"tcp" +'-' + ci[:ciId].to_s + "-lb"
      else
        lb_name = [env_name, platform_name, cloud_dns_id, dns_zone].join(".") + '-'+vprotocol+"_"+vport+"tcp" +'-' + ci[:ciId].to_s + "-lb"
      end


      # elb 32char limit
      if cloud_service[:ciClassName] =~ /Elb/
        lb_name = [env_name,platform_name,ci[:ciId].to_s].join(".")
        if lb_name.size > 32
          lb_name = [platform_name,ci[:ciId].to_s].join(".")
        end
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
      listeners_list.push(lb)

    end

    @node.set["loadbalancers"]=listeners_list
    listeners_list2 = get_listeners_from_wo()

    listeners_list2

  end

  def initialize_members(subnet_id, protocol_port)
    members = Array.new
    computes = @node[:workorder][:payLoad][:DependsOn].select { |d| d[:ciClassName] =~ /Compute/ }
    computes.each do |compute|
      ip_address = compute["ciAttributes"]["private_ip"]
      if compute["ciAttributes"].has_key?("private_ipv6") && !compute["ciAttributes"]["private_ipv6"].nil? && !compute["ciAttributes"]["private_ipv6"].empty?
        ip_address = compute["ciAttributes"]["private_ipv6"]
        Chef::Log.info("ipv6 address: #{ip_address}")
      end

      member = MemberModel.new(ip_address, protocol_port, subnet_id)
      members.push(member)
    end
    return members
  end

  def get_ns_service_type(cloud_service_type, service_type)
    case cloud_service_type
      when "cloud.service.Netscaler" , "cloud.service.F5-bigip"

        case service_type.upcase
          when "HTTPS"
            service_type = "SSL"
        end

    end
    return service_type.upcase
  end


  def get_service_metadata()
    cloud_name = get_cloud_name()
    service_lb_attributes = @node[:workorder][:services][:slb][cloud_name][:ciAttributes]
    service_lb_attributes
  end

  def get_current_lb_service_type()
    service_type = @node[:workorder][:rfcCi][:ciAttributes][:lb_service_type]
    service_type
  end

  def get_old_lb_service_type()
    service_type = @node[:workorder][:rfcCi][:ciBaseAttributes][:lb_service_type]
    service_type
  end

  def get_loadbalancer_details()

    service_lb_attributes = get_service_metadata()
    tenant = TenantModel.new(service_lb_attributes[:endpoint],service_lb_attributes[:tenant],
                             service_lb_attributes[:username],service_lb_attributes[:password])

    loadbalancer_request = LoadbalancerRequest.new(tenant)
    @loadbalancer_dao = LoadbalancerDao.new(loadbalancer_request)
    lb_name = build_n_return_lb_name()
    lb_id = @loadbalancer_dao.get_loadbalancer_id(lb_name)
    lb_manager = LoadbalancerManager.new(tenant)
    loadbalancer=lb_manager.get_loadbalancer(lb_id)
    loadbalancer
  end

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

  def check_for_lbvserver(conn,lbvserver_name)
    resp_obj = JSON.parse(conn.request(
        :method => :get,
        :path => "/nitro/v1/config/lbvserver/#{lbvserver_name}").body)
    Chef::Log.info("get lbvserver response: #{resp_obj.inspect}")
    if resp_obj["message"] =~ /No such resource/
      return false
    end
    return true
  end

  def get_ns_loadbalancer_details()
    cloud_name = get_cloud_name()
    cloud_service = @node[:workorder][:services][:lb][cloud_name][:ciAttributes]
    az_map = JSON.parse(cloud_service[:availability_zones])
    found = false
    vnames = get_dc_lb_names()
    puts "VNAMES : #{vnames}"
    az_map.keys.each do |check_az|
      host = az_map[check_az]
      conn = gen_conn(cloud_service,host)
      vnames.keys.each do |vname|
        if check_for_lbvserver(conn,vname)
          puts "found netscaler LB"
          found = true
          break
        end
      end
      break if found
    end

    if found
      return true
    else
      return false
    end
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
    listeners = build_listener_from_wo()
    # listeners = get_listeners_from_wo()
    listeners.each do |listener|
      frontend_port = listener[:vport]

      service_type = listener[:vprotocol]
      if service_type == "HTTPS"
        service_type = "SSL"
      end
      dc_lb_name = [platform_name, environment_name, assembly_name, org_name, dc_dns_zone].join(".") +
          '-'+service_type+"_"+frontend_port+"tcp-" + platform_ciId + "-lb"

      vnames[dc_lb_name] = dc_lb_name
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

