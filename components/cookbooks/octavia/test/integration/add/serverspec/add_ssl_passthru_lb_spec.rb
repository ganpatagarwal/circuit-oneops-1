CIRCUIT_PATH="/opt/oneops/inductor/circuit-oneops-1"
COOKBOOKS_PATH="#{CIRCUIT_PATH}/components/cookbooks"

require "#{CIRCUIT_PATH}/components/spec_helper.rb"
require "#{COOKBOOKS_PATH}/octavia/test/integration/octavia_spec_utils.rb"

require "#{COOKBOOKS_PATH}/octavia/test/integration/add/serverspec/tests/add_basic_lb.rb"
require "#{COOKBOOKS_PATH}/octavia/test/integration/add/serverspec/tests/add_ssl_passthru_lb.rb"

#run the tests
#tsts = File.expand_path("tests", File.dirname(__FILE__))
#Dir.glob("#{tsts}/add_ssl_passthru-lb.rb").each {|tst| require tst}
