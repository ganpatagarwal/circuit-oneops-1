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
    loadbalancer = @loadbalancer_dao.get_loadbalancer(lb_id)

    expect(loadbalancer).not_to be_nil
    expect(loadbalancer.label.name).to eq(@spec_utils.build_n_return_lb_name)

  end

end