require 'nexus_cli'

module KPM
  class Listener < Killbill::Plugin::Notification

    def start_plugin
      super

      ::KPM::PluginsInstaller.instance.initialize!(@root, @conf_dir, @logger)
    end

    def on_event(event)
      return unless [:BROADCAST_SERVICE].include?(event.event_type)

      unless ::KPM::PluginsInstaller.instance.initialized?
        @logger.warn "KPM plugin wasn't started properly - check logs"
        return
      end

      broadcast_metadata = event.meta_data.nil? ? {} : JSON.parse(event.meta_data)
      service = broadcast_metadata['service']
      command = broadcast_metadata['commandType']
      event_json = broadcast_metadata['eventJson'].nil? ? {} : JSON.parse(broadcast_metadata['eventJson'])
      @logger.info "Received #{event.event_type} event: service=#{service} command=#{command} event=#{event_json}"

      properties = properties_to_hash(event_json['properties'])
      handle_event(command,
                   properties['pluginArtifactId'] || event_json['pluginName'],
                   event_json['pluginVersion'],
                   properties['pluginGroupId'],
                   properties['pluginPackaging'],
                   properties['pluginClassifier'],
                   properties['pluginType'],
                   properties['forceDownload'] == 'true')
    end

    private

    def handle_event(command, artifact_id, version=nil, group_id=nil, packaging=nil, classifier=nil, type=nil, force_download=false)
      if command == 'INSTALL_PLUGIN'
        info = ::KPM::PluginsInstaller.instance.install(artifact_id, version, group_id, packaging, classifier, type, force_download)
        if info.nil?
          @logger.warn("Error during installation of plugin #{artifact_id}")
        else
          notify_fs_change(info[:bundle_dir], :NEW_VERSION)
        end
      elsif command == 'UNINSTALL_PLUGIN'
        modified = ::KPM::PluginsInstaller.instance.uninstall(plugin_name, plugin_version)
        modified.each do |path|
          notify_fs_change(path, :DISABLED)
        end
      else
        @logger.info("Ignoring unsupported command #{command}")
      end
    rescue NexusCli::ArtifactNotFoundException
      @logger.warn("Unable to #{command} #{plugin_name}: artifact was not found in Nexus")
    end

    def notify_fs_change(path, state)
      return if path.nil?

      # Plugin name should be the directory name (path is something like /var/tmp/bundles/plugins/ruby/killbill-stripe/2.0.0)
      fs_info = path.split('/')
      plugin_type = fs_info[-3].upcase
      plugin_name = fs_info[-2]
      plugin_version = fs_info[-1]
      @kb_apis.plugins_info_api.notify_of_state_changed(state, plugin_name, plugin_version, plugin_type)
    end

    def properties_to_hash(properties)
      return {} if properties.nil?

      h = {}
      properties.each do |prop|
        h[prop['key']] = prop['value']
      end
      h
    end
  end
end
