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


describe 'loadbalancer migration' do
  before(:each) do
    @spec_utils = Octavia_spec_utils.new($node)
  end

  it 'loadbalancer with new service type should exist' do
    new_lb_service_type = @spec_utils.get_current_lb_service_type()
    puts "New LB Service Type : #{new_lb_service_type}"
    if new_lb_service_type == "slb"
      lb_details = @spec_utils.get_loadbalancer_details()
      expect(lb_details).not_to be_nil
      expect(lb_details.label.name).to eq(@spec_utils.build_n_return_lb_name)
    elsif new_lb_service_type == "lb"
      lb_details = @spec_utils.get_ns_loadbalancer_details()
      expect(lb_details).to be true
    end

  end

  it 'loadbalancer with old service type should not exist' do
    old_lb_service_type = @spec_utils.get_old_lb_service_type()
    puts "Old LB Service Type : #{old_lb_service_type}"
    if old_lb_service_type == "slb"
      service_lb_attributes = @spec_utils.get_service_metadata()
      tenant = TenantModel.new(service_lb_attributes[:endpoint],service_lb_attributes[:tenant],
                               service_lb_attributes[:username],service_lb_attributes[:password])

      loadbalancer_request = LoadbalancerRequest.new(tenant)

      @loadbalancer_dao = LoadbalancerDao.new(loadbalancer_request)
      lb_name = @spec_utils.build_n_return_lb_name
      lb_id = @loadbalancer_dao.get_loadbalancer_id(lb_name)

      expect(lb_id).to be false
    elsif old_lb_service_type == "lb"
      lb_details = @spec_utils.get_ns_loadbalancer_details()
      expect(lb_details).to be false
    end
  end
end