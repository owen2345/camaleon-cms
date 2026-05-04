# frozen_string_literal: false

require 'json'
require 'monitor'
require 'fileutils'

# rubocop:disable Metrics/ClassLength
class PluginRoutes
  class << self
    # return plugin information
    def plugin_info(plugin_key)
      all_plugins.find { |p| p['key'] == plugin_key || p['path'].split('/').last == plugin_key }
    end

    # return theme information
    # if theme_name is nil, the use current site theme
    def theme_info(theme_name)
      all_themes.find { |p| p['key'] == theme_name }
    end

    # return system static settings (config.json values)
    def static_system_info
      r = cache_variable('statis_system_info')
      return r if r

      settings = {}

      gem_settings = File.join($camaleon_engine_dir, 'config', 'system.json')
      app_settings = Rails.root.join('config', 'system.json')

      settings.merge!(JSON.parse(File.read(gem_settings))) if File.exist?(gem_settings)
      settings.merge!(JSON.parse(File.read(app_settings))) if File.exist?(app_settings)

      # custom settings
      settings['key'] = 'system'
      settings['path'] = ''
      settings['kind'] = 'system'
      settings['hooks']['on_notification'] ||= []
      cache_variable('statis_system_info', settings)
    end
    alias system_info static_system_info

    # convert action parameter into hash
    def fixActionParameter(h)
      return h unless h.is_a?(ActionController::Parameters)

      begin
        h.permit!.to_h
      rescue StandardError
        h.to_hash
      end
    end

    # add a new anonymous hook
    # sample: PluginRoutes.add_anonymous_hook('before_admin', lambda{|params| puts params })
    # @param hook_key [String], key of hook
    # @param hook_id [String], identifier for the anonymous hook
    # @param callback [Lambda], anonymous function to be called when the hook was called
    # @return nil
    def add_anonymous_hook(hook_key, callback, hook_id = '')
      (anonymous_hooks[hook_key] ||= []) << { id: hook_id, callback: callback }
    end

    # return all registered anonymous hooks for hook_key
    # @param hook_key [String] name of the hook
    # @return [Array] array of hooks for hook_key
    def get_anonymous_hooks(hook_key)
      (anonymous_hooks[hook_key.to_s] || []).map { |item| item[:callback] }
    end

    # return all registered anonymous hooks for hook_key
    # @param hook_key [String] name of the hook
    # @param hook_id [String] identifier of the anonymous hooks
    # @return [Array] array of hooks for hook_key
    def remove_anonymous_hook(hook_key, hook_id)
      (anonymous_hooks[hook_key.to_s] || []).delete_if { |item| item[:id] == hook_id }
    end

    # return the class name for user model
    def get_user_class_name
      static_system_info['user_model'].presence || 'CamaleonCms::User'
    end

    # load plugin routes if it is enabled
    def load(env = 'admin')
      plugins = all_enabled_plugins
      res = ''
      case env
      when 'front'
        res << "namespace :plugins do \n"
        plugins.each do |plugin|
          res << "namespace '#{plugin['key']}' do \n"
          begin
            res << "#{File.open(File.join(plugin['path'], 'config', "routes_#{env}.txt")).read}\n"
          rescue StandardError
            ''
          end
          res << "end\n"
        end
        res << "end\n"

      when 'admin' # admin
        res << "scope 'admin', as: 'admin' do \n"
        res << "namespace :plugins do \n"
        plugins.each do |plugin|
          res << "namespace '#{plugin['key']}' do \n"
          begin
            res << "#{File.open(File.join(plugin['path'], 'config', "routes_#{env}.txt")).read}\n"
          rescue StandardError
            ''
          end
          res << "end\n"
        end
        res << "end\n"
        res << "end\n"
      else # main
        plugins.each do |plugin|
          res << "#{File.open(File.join(plugin['path'], 'config', "routes_#{env}.txt")).read}\n"
        rescue StandardError
          ''
        end
      end
      res + load_themes(env)
    end

    def load_themes(env = 'admin')
      plugins = all_enabled_themes
      res = ''
      case env
      when 'front'
        res << "namespace :themes do \n"
        plugins.each do |plugin|
          res << "namespace '#{plugin['key']}' do \n"
          begin
            res << "#{File.open(File.join(plugin['path'], 'config', "routes_#{env}.txt")).read}\n"
          rescue StandardError
            ''
          end
          res << "end\n"
        end
        res << "end\n"

      when 'admin' # admin
        res << "scope 'admin', as: 'admin' do \n"
        res << "namespace :themes do \n"
        plugins.each do |plugin|
          res << "namespace '#{plugin['key']}' do \n"
          begin
            res << "#{File.open(File.join(plugin['path'], 'config', "routes_#{env}.txt")).read}\n"
          rescue StandardError
            ''
          end
          res << "end\n"
        end
        res << "end\n"
        res << "end\n"
      else # main
        plugins.each do |plugin|
          res << "#{File.open(File.join(plugin['path'], 'config', "routes_#{env}.txt")).read}\n"
        rescue StandardError
          ''
        end
      end
      res
    end

    # reload routes (thread-safe) and trigger server restart in multi-process mode.
    # Uses a reloading guard to prevent nested calls (e.g. reload triggers
    # route loading which fires model callbacks that call reload again).
    # When will_restart? is true, defers the server restart until after all
    # transactions commit (Rails 7.2+ ActiveRecord.after_all_transactions_commit).
    # A Mutex ensures only one restart is scheduled; subsequent calls during
    # the pending window fall back to reload_local.
    def reload
      return if @reloading

      @reloading = true
      begin
        if will_restart?
          schedule_restart_after_commit
        else
          reload_local
        end
      ensure
        @reloading = false
      end
    end

    # reload routes locally without server restart (for use in view helpers, model callbacks, etc.)
    def reload_local
      reload_monitor.synchronize do
        @all_sites = nil
        cache.clear
        Rails.application.reload_routes!
        after_reload_callbacks.uniq.each(&:call)
      end
    end

    # Check if calling reload will trigger a server restart (multi-process mode)
    def will_restart?
      return false if Rails.env.test?

      RUBY_ENGINE == 'ruby' && clustered_mode?
    end

    # Add a callable (Proc/Lambda) to run after routes reload; strings are not supported.
    def add_after_reload_routes(command)
      after_reload_callbacks << (command.is_a?(String) ? raise(ArgumentError, 'Expected a callable (Proc/Lambda), not a String') : command)
    end

    # return all enabled plugins []
    def enabled_plugins(site)
      r = cache_variable("enable_plugins_site_#{site.id}")
      return r if r

      enabled_ps = site.plugins.active.pluck(:slug)
      res = all_plugins.each_with_object([]) do |plugin, ary|
        ary << plugin if enabled_ps.include?(plugin['key'])
      end
      res = res.sort_by { |e| e['position'] || 10 }
      cache_variable("enable_plugins_site_#{site.id}", res)
    end

    # return all enabled apps for site (themes + system + plugins) []
    # theme_slug: current theme slug
    def enabled_apps(site, theme_slug = nil)
      theme_slug ||= site.get_theme_slug
      r = cache_variable("enabled_apps_#{site.id}_#{theme_slug}")
      return r if r

      res = [system_info] + enabled_plugins(site) + [theme_info(theme_slug)]
      cache_variable("enabled_apps_#{site.id}_#{theme_slug}", res)
    end

    # return all enabled apps as []: system, themes, plugins
    def all_enabled_apps
      [system_info] + all_enabled_themes + all_enabled_plugins
    end

    # return all enabled themes (a theme is enabled if at least one site is assigned)
    def all_enabled_themes
      r = cache_variable('all_enabled_themes')
      return r if r

      res = get_sites.each_with_object([]) do |site, ary|
        i = theme_info(site.get_theme_slug)
        ary << i if i.present?
      end
      cache_variable('all_enabled_themes', res)
    end

    # return all enabled plugins (a theme is enabled if at least one site has installed)
    def all_enabled_plugins
      r = cache_variable('all_enabled_plugins')
      return r if r

      enabled_ps = get_sites.flat_map { |site| site.plugins.active.pluck(:slug) }
      res = all_plugins.each_with_object([]) do |plugin, ary|
        ary << plugin if enabled_ps.include?(plugin['key'])
      end
      cache_variable('all_enabled_plugins', res)
    end

    # all helpers of enabled plugins for site
    def site_plugin_helpers(site)
      r = cache_variable('site_plugin_helpers')
      return r if r

      res = enabled_apps(site).flat_map do |settings|
        settings['helpers'] if settings['helpers'].present?
      end
      cache_variable('site_plugin_helpers', res)
    end

    # all helpers of enabled plugins
    def all_helpers
      r = cache_variable('plugins_helper')
      return r if r

      res = all_apps.flat_map do |settings|
        settings['helpers'] if settings['helpers'].present?
      end
      cache_variable('plugins_helper', res.uniq)
    end

    # destroy plugin
    def destroy_plugin(plugin_key)
      begin
        FileUtils.rm_r(Rails.root.join('app', 'apps', 'plugins', plugin_key))
      rescue StandardError
        nil
      end
      PluginRoutes.reload
    end

    def cache_variable(var_name, value = nil)
      reload_monitor.synchronize do
        if value.nil?
          cache[var_name]
        else
          cache[var_name] = value
        end
      end
    end

    # return all sites registered for Plugin routes
    def get_sites
      @all_sites ||= CamaleonCms::Site.order(id: :asc).all.to_a
    rescue StandardError
      []
    end

    # check if db migrate already done
    def db_installed?
      @db_installed ||= ActiveRecord::Base.connection.table_exists?(CamaleonCms::Site.table_name)
    end

    # return all locales for all sites joined by |
    def all_locales
      r = cache_variable('site_all_locales')
      return r if r

      res = get_sites.flat_map(&:get_languages)
      cache_variable('site_all_locales', res.uniq.join('|'))
    end

    # return all translations for all languages, sample: ['Sample', 'Ejemplo', '....']
    def all_translations(key, *args)
      args = args.extract_options!
      all_locales.split('|').map { |_l| I18n.t(key, **args.merge({ locale: _l })) }.uniq
    end

    # return all locales for translated routes
    def all_locales_for_routes
      r = cache_variable('all_locales_for_routes')
      return r if r

      res = all_locales.split('|').each_with_object({}) do |locale, hsh|
        hsh[locale] = "_#{locale}"
      end
      res[false] = ''
      cache_variable('all_locales_for_routes', res)
    end

    # return app's directory path
    def apps_dir
      @apps_dir ||= Rails.root.join('app', 'apps').to_s
    end

    # return all plugins located in cms and in this project
    def all_plugins
      camaleon_gem = get_gem('camaleon_cms')
      return [] unless camaleon_gem

      r = cache_variable('all_plugins')
      return r if r.present?

      res = get_gem_plugins
      entries = %w[. ..]
      res.each { |plugin| entries << plugin['key'] }
      (Dir["#{apps_dir}/plugins/*"] + Dir["#{camaleon_gem.gem_dir}/app/apps/plugins/*"]).each do |path|
        entry = path.split('/').last
        config = File.join(path, 'config', 'config.json')
        next if entries.include?(entry) || !File.directory?(path) || !File.exist?(config)

        p = JSON.parse(File.read(config))
        p = begin
          p.with_indifferent_access
        rescue StandardError
          p
        end
        p['key'] = entry
        p['path'] = path
        p['kind'] = 'plugin'
        res << p
        entries << entry
      end
      cache_variable('all_plugins', res)
    end

    # return an array of all themes installed for all sites
    def all_themes
      camaleon_gem = get_gem('camaleon_cms')
      return [] unless camaleon_gem

      r = cache_variable('all_themes')
      return r if r.present?

      res = get_gem_themes
      entries = %w[. ..]
      res.each { |theme| entries << theme['key'] }
      Dir["#{apps_dir}/themes/*"].each do |path|
        entry = path.split('/').last
        config = File.join(path, 'config', 'config.json')
        next if entries.include?(entry) || !File.directory?(path) || !File.exist?(config)

        p = JSON.parse(File.read(config))
        p = begin
          p.with_indifferent_access
        rescue StandardError
          p
        end
        p['key'] = entry
        p['path'] = path
        p['kind'] = 'theme'
        p['title'] = p['name']
        res << p
        entries << entry
      end
      cache_variable('all_themes', res)
    end

    # return all apps loaded
    def all_apps
      all_plugins + all_themes
    end

    # return all plugins registered as gems
    def get_gem_plugins
      Gem::Specification.each_with_object([]) do |gem, ary|
        path = gem.gem_dir
        config = File.join(path, 'config', 'camaleon_plugin.json')
        next unless File.exist?(config)

        p = JSON.parse(File.read(config))
        p = begin
          p.with_indifferent_access
        rescue StandardError
          p
        end
        p['key'] = gem.name if p['key'].nil? # TODO: REVIEW ERROR FOR conflict plugin keys
        p['version'] = gem.version.to_s
        p['path'] = path
        p['kind'] = 'plugin'
        p['descr'] = gem.description unless p['descr'].present?
        p['gem_mode'] = true
        ary << p
      end
    end

    # return all themes registered as gems
    def get_gem_themes
      Gem::Specification.each_with_object([]) do |gem, ary|
        path = gem.gem_dir
        config = File.join(path, 'config', 'camaleon_theme.json')
        next unless File.exist?(config)

        p = JSON.parse(File.read(config))
        p = begin
          p.with_indifferent_access
        rescue StandardError
          p
        end
        p['key'] = gem.name if p['key'].nil? # TODO: REVIEW ERROR FOR conflict plugin keys
        p['path'] = path
        p['kind'] = 'theme'
        p['gem_mode'] = true
        ary << p
      end
    end

    # check if a gem is available or not
    # Arguemnts:
    # name: name of the gem
    # return (Boolean) true/false
    def get_gem(name)
      Gem::Specification.find_by_name(name)
    rescue Gem::LoadError
      false
    rescue StandardError
      Gem.available?(name)
    end

    # return the default url options for Camaleon CMS
    def default_url_options
      options = { host: begin
        CamaleonCms::Site.main_site.slug
      rescue StandardError
        ''
      end }
      options.merge!({ protocol: 'https' }) if Rails.application.config.force_ssl
      options
    end

    def migration_class
      ActiveRecord::Migration[4.2]
    end

    private

    def anonymous_hooks
      @anonymous_hooks ||= {}
    end

    def after_reload_callbacks
      @after_reload_callbacks ||= []
    end

    def reload_monitor
      @reload_monitor ||= Monitor.new
    end

    def cache
      @cache ||= {}
    end

    def schedule_restart_after_commit
      restart_monitor.synchronize do
        if @restart_pending
          # Restart already scheduled; just refresh routes locally
          reload_local
        else
          @restart_pending = true
          ActiveRecord.after_all_transactions_commit do
            restart_monitor.synchronize do
              @restart_pending = false
            end
            trigger_server_restart_if_clustered
          end
        end
      end
    end

    def restart_monitor
      @restart_monitor ||= Monitor.new
    end

    def trigger_server_restart_if_clustered
      return unless RUBY_ENGINE == 'ruby'
      return unless clustered_mode?

      master_pid = find_master_pid
      if defined?(Puma)
        is_preloaded = Puma.respond_to?(:cli_config) && Puma.cli_config&.options&.fetch(:preload_app, false)
        signal = is_preloaded ? 'SIGUSR2' : 'SIGUSR1'
        Process.kill(signal, master_pid)
      elsif defined?(Unicorn) || defined?(Pitchfork)
        Process.kill('HUP', master_pid)
      elsif defined?(PhusionPassenger)
        FileUtils.touch(Rails.root.join('tmp', 'restart.txt'))
      elsif defined?(Falcon)
        Process.kill('HUP', master_pid)
      end
    rescue StandardError => e
      Rails.logger.error "Could not trigger server restart: #{e.message}"
    end

    def clustered_mode?
      return @clustered_mode if defined?(@clustered_mode)

      @clustered_mode = if defined?(Puma)
                          stats = begin
                            JSON.parse(Puma.stats)
                          rescue StandardError
                            {}
                          end
                          stats.key?('workers') || stats.fetch('worker_status', []).present?
                        elsif defined?(Unicorn) || defined?(Pitchfork)
                          Process.ppid != 1 && Process.ppid != Process.pid
                        elsif defined?(PhusionPassenger)
                          true
                        else
                          Process.ppid > 1
                        end
    end

    def find_master_pid
      ['tmp/pids/server.pid', 'tmp/pids/puma.pid', 'tmp/pids/unicorn.pid'].each do |path|
        full_path = Rails.root.join(path)
        return File.read(full_path).to_i if File.exist?(full_path)
      end
      Process.ppid
    end
  end
end
# rubocop:enable Metrics/ClassLength
CamaManager = PluginRoutes
