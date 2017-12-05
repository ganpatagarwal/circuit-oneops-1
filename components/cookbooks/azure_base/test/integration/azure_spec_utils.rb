require '/opt/oneops/inductor/circuit-oneops-1/components/cookbooks/azure_base/test/integration/spec_utils'

class AzureSpecUtils < SpecUtils
  def initialize(node)
    @node = node
  end

  def get_azure_creds
    cloud_name = get_cloud_name
    app_type = get_app_type
    svc = get_service

    credentials = {
        tenant_id: svc['tenant_id'],
        client_secret: svc['client_secret'],
        client_id: svc['client_id'],
        subscription_id: svc['subscription']
    }

    credentials
  end
  def get_resource_group_name
    nsPathParts = get_ns_path_parts
    org = nsPathParts[1]
    assembly = nsPathParts[2]
    environment = nsPathParts[3]

    svc = get_service
    location = svc['location']

    resource_group_name = org[0..15] + '-' + assembly[0..15] + '-' + @node['workorder']['box']['ciId'].to_s + '-' + environment[0..15] + '-' + Utils.abbreviate_location(location)
    resource_group_name
  end
  def set_attributes_on_node_required_for_vm_manager
    @node.set['image_id'] = get_image_id
    @node.set['platform-resource-group'] = get_resource_group_name
  end
  def is_express_route_enabled
    svc = get_service

    express_route_enabled = true
    if svc[:express_route_enabled].nil?
      # We cannot assume express route is enabled if it is not set
      express_route_enabled = false
    elsif svc[:express_route_enabled] == 'false'
      express_route_enabled = false
    end

    express_route_enabled
  end
  def get_azure_rule_definition(resource_group_name, network_security_group_name, rules, node)
    sec_rules = []
    priority = 100
    reg_ex = /(\d+|\*|\d+-\d+)\s(\d+|\*|\d+-\d+)\s([A-Za-z]+|\*)\s\S+/
    rules.each do |item|
      raise "#{item} is not a valid security rule" unless reg_ex.match(item)
      item2 = item.split(' ')
      security_rule_access = Fog::ARM::Network::Models::SecurityRuleAccess::Allow
      security_rule_description = node['secgroup']['description']
      security_rule_source_addres_prefix = item2[3]
      security_rule_destination_port_range = item2[1].to_s
      security_rule_direction = Fog::ARM::Network::Models::SecurityRuleDirection::Inbound
      security_rule_priority = priority
      security_rule_protocol = case item2[2].downcase
        when 'tcp'
          Fog::ARM::Network::Models::SecurityRuleProtocol::Tcp
        when 'udp'
          Fog::ARM::Network::Models::SecurityRuleProtocol::Udp
        else
          Fog::ARM::Network::Models::SecurityRuleProtocol::Asterisk
        end
      security_rule_provisioning_state = nil
      security_rule_destination_addres_prefix = '*'
      security_rule_source_port_range = '*'
      security_rule_name = network_security_group_name + '-' + priority.to_s
      sec_rules << { name: security_rule_name, resource_group: resource_group_name, protocol: security_rule_protocol, network_security_group_name: network_security_group_name, source_port_range: security_rule_source_port_range, destination_port_range: security_rule_destination_port_range, source_address_prefix: security_rule_source_addres_prefix, destination_address_prefix: security_rule_destination_addres_prefix, access: security_rule_access, priority: security_rule_priority, direction: security_rule_direction }
      priority += 100
      end
    sec_rules
  end
end