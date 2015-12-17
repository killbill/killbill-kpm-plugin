module KPM
  class PluginsInstaller
    include Singleton

    attr_reader :initialized
    alias_method :initialized?, :initialized

    def initialize!(root_dir, conf_dir, kb_apis, logger)
      @kb_apis = kb_apis
      @logger = logger

      configure!(Pathname.new(conf_dir).expand_path.join('kpm.yml'))

      @bundles_dir = Pathname.new(root_dir).join('..').join('..').join('..').join('..').expand_path
      plugins_dir = @bundles_dir.join('plugins')

      @installer = ::KPM::BaseInstaller.new(@logger, @glob_config[:kpm][:nexus], @glob_config[:kpm][:ssl_verify])
      @manager = ::KPM::PluginsManager.new(plugins_dir, @logger)

      @initialized = true
    end

    # If an earlier version of the plugin is installed, Kill Bill will only start the latest one (see org.killbill.billing.osgi.FileInstall)
    def install(plugin_key, specified_artifact_id, specified_version=nil, specified_group_id=nil, specified_packaging=nil, specified_classifier=nil, specified_type=nil, force_download=false)
      @logger.info("Instructed to install plugin_key=#{plugin_key} artifact_id=#{specified_artifact_id} version=#{specified_version} group_id=#{specified_group_id} packaging=#{specified_packaging} classifier=#{specified_classifier} type=#{specified_type} force_download=#{force_download}")
      info = @installer.install_plugin(plugin_key, specified_group_id, specified_artifact_id, specified_packaging, specified_classifier, specified_version, @bundles_dir, specified_type, force_download, @glob_config[:kpm][:verify_sha1])
      if info.nil?
        @logger.warn("Error during installation of plugin #{specified_artifact_id}")
      else
        path = info[:bundle_dir] || info[:dir_name]
        notify_fs_change(plugin_key, path, :NEW_VERSION)
      end
      info
    end

    def install_from_fs(plugin_key, file_path, version, type)
      @logger.info("Instructed to install file_path=#{file_path} plugin_key=#{plugin_key} version=#{version} type=#{type}")
      info = @installer.install_plugin_from_fs(plugin_key, file_path, plugin_key, version, @bundles_dir, type)
      if info.nil?
        @logger.warn("Error during installation of plugin #{plugin_key}")
      else
        path = info[:bundle_dir] || info[:dir_name]
        notify_fs_change(plugin_key, path, :NEW_VERSION)
      end
      info
    end

    def uninstall(plugin_key, version=nil)
      modified = @installer.uninstall_plugin(plugin_key, version || :all, @bundles_dir)
      modified.each do |path|
        notify_fs_change(plugin_key, path, :DISABLED)
      end
    end

    def restart(plugin_name, version=nil)
      @manager.restart(plugin_name, version || :all)
    end

    def lookup(artifact_id, latest=true)
      KPM::PluginsDirectory.lookup(artifact_id, latest)
    end

    def all(latest=true)
      KPM::PluginsDirectory.all(latest)
    end

    private

    def notify_fs_change(plugin_key, path, state)
      return if path.nil?

      # Plugin name should be the directory name (path is something like /var/tmp/bundles/plugins/ruby/killbill-stripe/2.0.0)
      fs_info = path.to_s.split('/')
      plugin_type = fs_info[-3].upcase

      unless %w(JAVA RUBY).include?(plugin_type)
        @logger.warn("Invalid plugin type #{plugin_type} (path #{path}): Kill Bill won't be notified of new state #{state}")
        return
      end

      if @kb_apis.nil?
        @logger.warn("APIs not configured: Kill Bill won't be notified of new state #{state}")
        return
      end

      plugin_name = fs_info[-2]
      plugin_version = fs_info[-1]
      @logger.info("Notifying Kill Bill: state=#{state} plugin_key=#{plugin_key} plugin_name=#{plugin_name} plugin_version=#{plugin_version} plugin_type=#{plugin_type}")
      @kb_apis.plugins_info_api.notify_of_state_changed(state, plugin_key, plugin_name, plugin_version, plugin_type)
    end

    def configure!(config_file)
      @glob_config = {}

      # Look for global config
      if !config_file.blank? && Pathname.new(config_file).file?
        @glob_config = ::Killbill::Plugin::ActiveMerchant::Properties.new(config_file)
        @glob_config.parse!
        @glob_config = @glob_config.to_hash
      end

      @glob_config[:kpm] ||= {}

      @glob_config[:kpm][:nexus] ||= {}
      @glob_config[:kpm][:nexus][:url] ||= 'https://oss.sonatype.org'
      @glob_config[:kpm][:nexus][:repository] ||= 'releases'

      @glob_config[:kpm][:ssl_verify] = true if @glob_config[:kpm][:ssl_verify].nil?
      @glob_config[:kpm][:verify_sha1] = true if @glob_config[:kpm][:verify_sha1].nil?

      @logger.level = Logger::DEBUG if (@glob_config[:logger] || {})[:debug]
    end
  end
end
