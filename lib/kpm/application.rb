configure do
  # Usage: bundle exec rackup -Ilib -E test
  if development? or test?
    require 'logger'
    ::KPM::PluginsInstaller.instance.initialize!('/var/tmp/bundles/plugins/ruby/kpm/0.0.1',
                                                 File.expand_path(File.dirname(__FILE__) + '../../../'),
                                                 Logger.new(STDOUT))
  end
end

# Lookup a plugin
get '/plugins/killbill-kpm/plugins', :provides => 'json' do
  group_id, artifact_id, packaging, classifier, version, type = ::KPM::PluginsInstaller.instance.lookup params[:artifact_id] || params[:name],
                                                                                                        params[:latest]

  if artifact_id.nil?
    status 404
  else
    {
        :group_id => group_id,
        :artifact_id => artifact_id,
        :packaging => packaging,
        :classifier => classifier,
        :version => version,
        :type => type
    }.to_json
  end
end

# Install a plugin
post '/plugins/killbill-kpm/plugins', :provides => 'json' do
  info = ::KPM::PluginsInstaller.instance.install params[:artifact_id] || params[:name],
                                                  params[:version],
                                                  params[:group_id],
                                                  params[:packaging],
                                                  params[:classifier],
                                                  params[:type],
                                                  params[:force_download]

  if info.nil?
    status 400
  else
    info.to_json
  end
end

# Uninstall a plugin
delete '/plugins/killbill-kpm/plugins', :provides => 'json' do
  modified = ::KPM::PluginsInstaller.instance.uninstall params[:name],
                                                        params[:version]

  if modified.empty?
    status 404
  else
    modified.to_json
  end
end

# Restart a plugin
put '/plugins/killbill-kpm/plugins', :provides => 'json' do
  modified = ::KPM::PluginsInstaller.instance.restart params[:name],
                                                      params[:version]

  if modified.empty?
    status 404
  else
    modified.to_json
  end
end
