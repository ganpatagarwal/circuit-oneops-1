require 'azure_mgmt_network'
require '/opt/oneops/inductor/circuit-oneops-1/components/cookbooks/azure_base/test/integration/azure_spec_utils'

class AzureLBSpecUtils < AzureSpecUtils
  def get_lb_name
    platform_name = @node['workorder']['box']['ciName']
    plat_name = platform_name.gsub(/-/, '').downcase
    lb_name = "lb-#{plat_name}"

    lb_name
  end
  def get_probes
    probes = []
    ecvs = AzureNetwork::LoadBalancer.get_probes_from_wo(@node)

    ecvs.each do |ecv|
      probe = AzureNetwork::LoadBalancer.create_probe(ecv[:probe_name], ecv[:protocol], ecv[:port], ecv[:interval_secs], ecv[:num_probes], ecv[:request_path])
      probes.push(probe)
    end
    probes
  end
  def get_loadbalancer_rules(subscription_id, resource_group_name, lb_name, env_name, platform_name, probes, frontend_ipconfig_id, backend_address_pool_id)
    lb_rules = []

    ci = {}
    ci = @node.workorder.key?('rfcCi') ? @node.workorder.rfcCi : @node.workorder.ci

    listeners = AzureNetwork::LoadBalancer.get_listeners(@node)

    listeners.each do |listener|
      lb_rule_name = "#{env_name}.#{platform_name}-#{listener[:vport]}_#{listener[:iport]}tcp-#{ci[:ciId]}-lbrule"
      frontend_port = listener[:vport]
      backend_port = listener[:iport]
      protocol = 'Tcp'
      load_distribution = 'Default'

      ### Select the right probe for the lb rule
      the_probe = AzureNetwork::LoadBalancer.get_probe_for_listener(listener, probes)
      if(the_probe.nil?)
        OOLog.fatal("No valid ecv specified for listener: #{listener[:vprotocol]} #{listener[:vport]} #{listener[:iprotocol]} #{listener[:iport]}")
      end

      probe_id = "/subscriptions/#{subscription_id}/resourceGroups/#{resource_group_name}/providers/Microsoft.Network/loadBalancers/#{lb_name}/probes/#{the_probe[:name]}"
      lb_rule = AzureNetwork::LoadBalancer.create_lb_rule(lb_rule_name, load_distribution, protocol, frontend_port, backend_port, probe_id, frontend_ipconfig_id, backend_address_pool_id)
      lb_rules.push(lb_rule)
    end

    lb_rules
  end
  def get_compute_nat_rules(frontend_ipconfig_id, nat_rules, compute_natrules)
    compute_nodes = get_compute_nodes_from_wo
    if compute_nodes.count > 0
      port_increment = 10
      port_counter = 1
      front_port = 0
      compute_nodes.each do |compute_node|
        idle_min = 5
        nat_rule_name = "NatRule-#{compute_node[:ciId]}-#{compute_node[:allow_port]}tcp"
        front_port = (compute_node[:allow_port].to_i * port_increment) + port_counter
        frontend_port = front_port
        backend_port = compute_node[:allow_port].to_i
        protocol = 'Tcp'

        nat_rule = AzureNetwork::LoadBalancer.create_inbound_nat_rule(nat_rule_name, protocol, frontend_ipconfig_id, frontend_port, backend_port)
        nat_rules.push(nat_rule)

        compute_natrules.push(
            instance_id: compute_node[:instance_id],
            instance_name: compute_node[:instance_name],
            nat_rule: nat_rule
        )
        port_counter += 1
      end
    end

    nat_rules
  end
  def get_compute_nodes_from_wo
    compute_nodes = []
    computes = @node.workorder.payLoad.DependsOn.select { |d| d[:ciClassName] =~ /Compute/ }
    if computes
      # Build computes nodes to load balance
      computes.each do |compute|
        compute_nodes.push(
            ciId: compute[:ciId],
            ipaddress: compute[:ciAttributes][:private_ip],
            hostname: compute[:ciAttributes][:hostname],
            instance_id: compute[:ciAttributes][:instance_id],
            instance_name: compute[:ciAttributes][:instance_name],
            allow_port: get_allow_rule_port(compute[:ciAttributes][:allow_rules])
        )
      end
    end

    compute_nodes
  end
  def get_allow_rule_port(allow_rules)
    port = 22 # Default port
    unless allow_rules.nil?
      rulesParts = allow_rules.split(' ')
      rulesParts.each do |item|
        port = item.gsub!(/\D/, '') if item =~ /\d/
      end
    end

    port
  end

  # Returns backend ip configurations of a load balancer
  # == Parameters:
  # resource_group_name::
  #   Name of the resource group the load balancer belongs to
  # lb_name::
  #   Name of the load balancer
  # backend_address_pool_id::
  #   A load balancer can have more than one backend address pool
  #   If this is `nil`,`backend_ipconfigurations` of first `backend_address_pool` is returned
  #   If it is not `nil`, `backend_ipconfigurations` of the specified `backend_address_pool` is returned
  #   When it is not nil, provide backend address pool id in format - `/subscriptions/{subscription id}/resourceGroups/{resource group name}/providers/Microsoft.Network/loadBalancers/{load balancer name}/backendAddressPools/{backend address pool name}`
  #
  # == Returns:
  # Array of objects. Each object has an `id` property which specifies the `id` of network interface ip configuration
  # This `id` is in the format `/subscriptions/{subscription id}/resourceGroups/{resource group name}/providers/Microsoft.Network/networkInterfaces/{nic name}/ipConfigurations/{nic ip config name}`
  def get_backend_ip_configurations(resource_group_name, lb_name, backend_address_pool_id = nil)

    creds = get_azure_creds
    token_provider                  = MsRestAzure::ApplicationTokenProvider.new(creds[:tenant_id], creds[:client_id], creds[:client_secret])
    credentials                     = MsRest::TokenCredentials.new(token_provider)
    network_client                  = Azure::ARM::Network::NetworkManagementClient.new(credentials)
    network_client.subscription_id  = creds[:subscription_id]


    lb = network_client.load_balancers.get(resource_group_name, lb_name, nil, nil)
    backend_ip_configurations = nil

    if backend_address_pool_id.nil?
      backend_ip_configurations = lb.backend_address_pools[0].backend_ipconfigurations
    else
      backend_address_pool = lb.backend_address_pools.detect {|p| p.id == backend_address_pool_id}
      backend_ip_configurations = backend_address_pool.backend_ipconfigurations unless backend_address_pool.nil?
    end

    return backend_ip_configurations
  end
end