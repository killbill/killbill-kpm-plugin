module KPM
  class PluginsInstaller
    include Singleton

    attr_reader :initialized
    alias_method :initialized?, :initialized

    def initialize!(root_dir, conf_dir, logger)
      @logger = logger

      configure!(Pathname.new(conf_dir).expand_path.join('kpm.yml'))

      @bundles_dir = Pathname.new(root_dir).join('..').join('..').join('..').join('..').expand_path
      plugins_dir = @bundles_dir.join('plugins')

      @installer = ::KPM::BaseInstaller.new(@logger, @glob_config[:kpm][:nexus], @glob_config[:kpm][:ssl_verify])
      @manager = ::KPM::PluginsManager.new(plugins_dir, @logger)

      @initialized = true
    end

    # If an earlier version of the plugin is installed, Kill Bill will only start the latest one (see org.killbill.billing.osgi.FileInstall)
    def install(specified_artifact_id, specified_version=nil, specified_group_id=nil, specified_packaging=nil, specified_classifier=nil, specified_type=nil, force_download=false)
      @installer.install_plugin(specified_group_id, specified_artifact_id, specified_packaging, specified_classifier, specified_version, @bundles_dir, specified_type, force_download, @glob_config[:kpm][:verify_sha1])
    end

    def uninstall(plugin_name, version=nil)
      @manager.uninstall(plugin_name, version || :all)
    end

    def restart(plugin_name, version=nil)
      @manager.restart(plugin_name, version || :all)
    end

    def lookup(artifact_id, latest=true)
      KPM::PluginsDirectory.lookup(artifact_id, latest)
    end

    private

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
