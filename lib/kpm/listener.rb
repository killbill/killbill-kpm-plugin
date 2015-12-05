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
      command = broadcast_metadata['commandType']
      return if command != 'INSTALL_PLUGIN' && command != 'UNINSTALL_PLUGIN'

      service = broadcast_metadata['service']
      event_json = broadcast_metadata['eventJson'].nil? ? {} : JSON.parse(broadcast_metadata['eventJson'])

      properties = properties_to_hash(event_json['properties'])

      @logger.info "Received #{event.event_type} event: service=#{service} command=#{command} event=#{event_json}"

      return if !validate_inputs(command, properties, Proc.new { |command, properties, property_name|
                                          if properties[property_name].nil?
                                            @logger.info("Cannot run #{command}: missing property #{property_name}")
                                            return false
                                          end
                                        })

      handle_event(command,
                   properties['pluginKey'] || properties['pluginArtifactId'],
                   properties['pluginVersion'],
                   properties['pluginGroupId'],
                   properties['pluginPackaging'],
                   properties['pluginClassifier'],
                   properties['pluginType'],
                   properties['forceDownload'] == 'true')
    end

    private

    # Check for mandatory properties
    def validate_inputs(command, properties, proc_validation)
      if properties['pluginKey'].nil?
        proc_validation.call(command, properties, 'pluginGroupId')
        proc_validation.call(command, properties, 'pluginArtifactId')
        proc_validation.call(command, properties, 'pluginVersion')
        proc_validation.call(command, properties, 'pluginType')
      end
      return true
    end

    def handle_event(command, artifact_id, version=nil, group_id=nil, packaging=nil, classifier=nil, type=nil, force_download=false)

      @logger.info "handle_event command=#{command}, artifact_id=#{artifact_id}, version=#{version}, group_id=#{group_id}, packaging=#{packaging}, classifier=#{classifier}, type=#{type}, force_download=#{force_download}"

      if command == 'INSTALL_PLUGIN'
        info = ::KPM::PluginsInstaller.instance.install(artifact_id, version, group_id, packaging, classifier, type, force_download)
        if info.nil?
          @logger.warn("Error during installation of plugin #{artifact_id}")
        else
          notify_fs_change(info[:bundle_dir], :NEW_VERSION)
        end
      elsif command == 'UNINSTALL_PLUGIN'
        modified = ::KPM::PluginsInstaller.instance.uninstall(artifact_id, version)
        modified.each do |path|
          notify_fs_change(path, :DISABLED)
        end
      else
        @logger.warn("Ignoring unsupported command #{command}")
      end
    rescue NexusCli::ArtifactNotFoundException
      @logger.warn("Unable to #{command} #{plugin_name}: artifact was not found in Nexus")
    end

    def notify_fs_change(path, state)
      return if path.nil?

      # Plugin name should be the directory name (path is something like /var/tmp/bundles/plugins/ruby/killbill-stripe/2.0.0)
      fs_info = path.to_s.split('/')
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
