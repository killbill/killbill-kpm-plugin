require 'nexus_cli'

module KPM
  class Listener < Killbill::Plugin::Notification

    def start_plugin
      super

      ::KPM::PluginsInstaller.instance.initialize!(@root, @conf_dir, @kb_apis, @logger)
    end

    def on_event(event)
      return unless [:BROADCAST_SERVICE].include?(event.event_type)

      unless ::KPM::PluginsInstaller.instance.initialized?
        @logger.warn "KPM plugin wasn't started properly - check logs"
        return
      end

      broadcast_metadata = event.meta_data.nil? ? {} : JSON.parse(event.meta_data)
      command = broadcast_metadata['commandType']
      return if command != 'INSTALL_PLUGIN' && command != 'UNINSTALL_PLUGIN'

      service = broadcast_metadata['service']
      event_json = broadcast_metadata['eventJson'].nil? ? {} : JSON.parse(broadcast_metadata['eventJson'])

      properties = properties_to_hash(event_json['properties'])

      @logger.info "Received #{event.event_type} event: service=#{service} command=#{command} event=#{event_json}"

      # pluginKey is the only mandatory property
      if event_json['pluginKey'].nil?
        @logger.info("Cannot run #{command}: missing pluginKey property")
        return false
      end

      handle_event(command,
                   event_json['pluginKey'],
                   properties['pluginArtifactId'],
                   event_json['pluginVersion'],
                   properties['pluginGroupId'],
                   properties['pluginPackaging'],
                   properties['pluginClassifier'],
                   properties['pluginType'],
                   properties['forceDownload'] == 'true')
    end

    private

    def handle_event(command, plugin_key, artifact_id, version=nil, group_id=nil, packaging=nil, classifier=nil, type=nil, force_download=false)
      @logger.info "handle_event command=#{command}, plugin_key=#{plugin_key}, artifact_id=#{artifact_id}, version=#{version}, group_id=#{group_id}, packaging=#{packaging}, classifier=#{classifier}, type=#{type}, force_download=#{force_download}"

      if command == 'INSTALL_PLUGIN'
        ::KPM::PluginsInstaller.instance.install(plugin_key, artifact_id, version, group_id, packaging, classifier, type, force_download)
      elsif command == 'UNINSTALL_PLUGIN'
        ::KPM::PluginsInstaller.instance.uninstall(plugin_key, version)
      else
        @logger.warn("Ignoring unsupported command #{command}")
      end
    rescue NexusCli::ArtifactNotFoundException
      @logger.warn("Unable to #{command} for plugin_key=#{plugin_key}: artifact was not found in Nexus")
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
