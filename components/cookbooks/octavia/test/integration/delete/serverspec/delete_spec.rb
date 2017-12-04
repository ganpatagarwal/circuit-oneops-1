CIRCUIT_PATH="/opt/oneops/inductor/circuit-oneops-1"
COOKBOOKS_PATH="#{CIRCUIT_PATH}/components/cookbooks"

require "#{CIRCUIT_PATH}/components/spec_helper.rb"
require "#{COOKBOOKS_PATH}/octavia/test/integration/octavia_spec_utils.rb"


#run the tests
tsts = File.expand_path("tests", File.dirname(__FILE__))
Dir.glob("#{tsts}/*.rb").each {|tst| require tst}