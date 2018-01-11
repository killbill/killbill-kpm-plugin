module KPM
  class Listener < Killbill::Plugin::Notification


    def start_plugin
      super
      ::KPM::PluginsInstaller.instance.initialize!(@root, @conf_dir, @kb_apis, @logger)
      # We don't know yet
      @kb_version = nil
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

    def get_kb_version
      return @kb_version if @kb_version

      nodes_info = @kb_apis.killbill_nodes_api.get_nodes_info
      if nodes_info.nil? || nodes_info.empty?
        @logger.warn("Unable to retrieve node info")
        return nil
      end

      # This is incorrect, we need to find the entry for our node, but we don't seem to know who we are -:(
      # (The will break in rolling upgrade scenario)
      @kb_version = nodes_info[0].killbill_version

      @logger.info("KPM plugin extracted killbill version #{@kb_version}")

      @kb_version
    end

    def handle_event(command, plugin_key, artifact_id, version=nil, group_id=nil, packaging=nil, classifier=nil, type=nil, force_download=false)
      @logger.info "handle_event command=#{command}, plugin_key=#{plugin_key}, artifact_id=#{artifact_id}, version=#{version}, group_id=#{group_id}, packaging=#{packaging}, classifier=#{classifier}, type=#{type}, force_download=#{force_download}"

      if command == 'INSTALL_PLUGIN'
        ::KPM::PluginsInstaller.instance.install(plugin_key, get_kb_version, artifact_id, version, group_id, packaging, classifier, type, force_download)
      elsif command == 'UNINSTALL_PLUGIN'
        ::KPM::PluginsInstaller.instance.uninstall(plugin_key, version)
      else
        @logger.warn("Ignoring unsupported command #{command}")
      end
    rescue StandardError => e
      @logger.warn("Unable to #{command} for plugin_key=#{plugin_key}: #{e.message}")
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
