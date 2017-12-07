COOKBOOKS_PATH ||= "/opt/oneops/inductor/circuit-oneops-1/components/cookbooks"


require File.expand_path('../../../../../../libraries/data_access/lbaas/loadbalancer_dao', __FILE__)
require File.expand_path('../../../../../../libraries/data_access/lbaas/listener_dao', __FILE__)
require File.expand_path('../../../../../../libraries/data_access/lbaas/pool_dao', __FILE__)
require File.expand_path('../../../../../../libraries/data_access/lbaas/member_dao', __FILE__)
require File.expand_path('../../../../../../libraries/data_access/lbaas/health_monitor_dao', __FILE__)
require File.expand_path('../../../../../../libraries/requests/lbaas/loadbalancer_request', __FILE__)
require File.expand_path('../../../../../../libraries/requests/lbaas/listener_request', __FILE__)
require File.expand_path('../../../../../../libraries/requests/lbaas/pool_request', __FILE__)
require File.expand_path('../../../../../../libraries/requests/lbaas/member_request', __FILE__)
require File.expand_path('../../../../../../libraries/requests/lbaas/health_monitor_request', __FILE__)
require File.expand_path('../../../../../../libraries/models/tenant_model', __FILE__)
require File.expand_path('../../../../../../libraries/loadbalancer_manager', __FILE__)
require File.expand_path('../../../../../../libraries/network_manager', __FILE__)

require File.expand_path('../../../../../../libraries/utils', __FILE__)


describe 'octavia SLB' do
  before(:each) do
    @spec_utils = Octavia_spec_utils.new($node)
  end

  it 'should exist' do

    service_lb_attributes = @spec_utils.get_service_metadata()
    tenant = TenantModel.new(service_lb_attributes[:endpoint],service_lb_attributes[:tenant],
                             service_lb_attributes[:username],service_lb_attributes[:password])

    loadbalancer_request = LoadbalancerRequest.new(tenant)
    @loadbalancer_dao = LoadbalancerDao.new(loadbalancer_request)
    lb_name = @spec_utils.build_n_return_lb_name
    lb_id = @loadbalancer_dao.get_loadbalancer_id(lb_name)
    #loadbalancer = @loadbalancer_dao.get_loadbalancer(lb_id)
    lb_manager = LoadbalancerManager.new(tenant)
    loadbalancer=lb_manager.get_loadbalancer(lb_id)
    expect(loadbalancer).not_to be_nil
    expect(loadbalancer.label.name).to eq(@spec_utils.build_n_return_lb_name)

  end

  it 'should have correct number of listeners' do

    listeners = @spec_utils.build_listener_from_wo()

    lb_details = @spec_utils.get_loadbalancer_details()

    puts lb_details.listeners.count
    puts listeners.count

    expect(lb_details.listeners.count).to eq(listeners.count)


  end


  it 'should have right frontend and backend ports on listeners' do

    listeners_users_input = @spec_utils.build_listener_from_wo()

    lb_details = @spec_utils.get_loadbalancer_details()

    puts lb_details.listeners.inspect
     flag= false
    lb_details.listeners.each do |listener|
      flag= false
      listeners_users_input.each do | l|
      if((listener.protocol_port.to_s) == (l.vport)) && ((listener.pool.members[0].protocol_port.to_s) == (l.iport))
        flag = true
        break
      end
      end
      expect(flag).to eq(true)

    end


  end

  it 'should have right frontend and backend protocols on listeners' do

    listeners = @spec_utils.build_listener_from_wo()

    lb_details = @spec_utils.get_loadbalancer_details()

    puts lb_details.listeners.inspect

    if listeners.count == 1
      if (listeners[0].vprotocol == "TERMINATED_HTTPS" || listeners[0].vprotocol == 'HTTPS') && listeners[0].vprotocol == "http"
       expect(lb_details.listeners[0].protocol).to eq("TERMINATED_HTTPS")
       expect(lb_details.listeners[0].pool.members[0].protocol).to eq(listeners[0].iprotocol)
      end

    end


  end

  it 'should have right number of members' do


    service_lb_attributes = @spec_utils.get_service_metadata()

    tenant = TenantModel.new(service_lb_attributes[:endpoint],service_lb_attributes[:tenant],
                             service_lb_attributes[:username],service_lb_attributes[:password])

    subnet_id = select_provider_network_to_use(tenant, service_lb_attributes[:enabled_networks])

    lb_details = @spec_utils.get_loadbalancer_details()

    members = @spec_utils.initialize_members(subnet_id, 8080)

    puts lb_details.listeners.inspect

    expect(lb_details.listeners[0].pool.members.count).to eq(members.count)


  end

  it 'should have barbican container ref if vprotocol is terminated https' do


    listeners_users_input = @spec_utils.build_listener_from_wo()

    lb_details = @spec_utils.get_loadbalancer_details()

    puts lb_details.listeners.inspect
    flag= false
    lb_details.listeners.each do |listener|
      flag= false
      listeners_users_input.each do | l|
        if((l.vprotocol) == listener.protocol) && (l.vprotocol == "TERMINATED_HTTPS")
          puts "here"
          expect(listener.default_tls_container_ref).not_to be_nil
        end
      end
    end
  end
end