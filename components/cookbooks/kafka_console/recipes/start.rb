service "kafka-manager" do
  service_name 'kafka-manager'
  supports  :restart => true, :status => true, :stop => true, :start => true
  action :start
end

service 'burrow' do
  service_name 'burrow'
  supports  :restart => true, :status => true, :stop => true, :start => true
  action :start
end
