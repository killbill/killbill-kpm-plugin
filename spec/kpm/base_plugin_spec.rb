require 'spec_helper'

describe ::KPM::Listener do

  include ::Killbill::Plugin::ActiveMerchant::RSpec

  before(:each) do
    Dir.mktmpdir do |dir|
      file = File.new(File.join(dir, 'kpm.yml'), 'w+')
      file.write(<<-eos)
:kpm:
      eos
      file.close

      @plugin = build_plugin(::KPM::Listener, 'kpm', File.dirname(file))

      # Start the plugin here - since the config file will be deleted
      @plugin.start_plugin
    end
  end

  it 'should start and stop correctly' do
    @plugin.stop_plugin
  end
end
