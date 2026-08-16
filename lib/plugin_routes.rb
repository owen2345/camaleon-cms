# frozen_string_literal: false

require 'json'
require 'monitor'

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
      app_settings = Rails.root.join('config/system.json')

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

    # reload routes (thread-safe)
    def reload
      reload_monitor.synchronize do
        @all_sites = nil
        cache.clear
        Rails.application.reload_routes!
        after_reload_callbacks.uniq.each(&:call)
      end
    end

    # Draw the route table at boot so the first request is never served against a half-built set
    # of routes. Production already eager-loads routes; this closes the development window where
    # the first request after a restart races the (multi-site) draw. Guarded by db_installed? and
    # rescued so boot never aborts when the DB is unavailable (migrations, asset precompile, or a
    # fresh install before db:create).
    def draw_routes_eagerly
      return if Rails.application.config.eager_load # production draws routes at boot already
      return unless db_installed?

      # Draw once and leave the table marked loaded, so the first request does not redraw it.
      # reload_routes! would draw and then reset loaded=false (its contract is to force a *reload*),
      # which -- now that the engine runs this after :set_routes_reloader_hook, with the route set
      # fully assembled -- would only make the first request rebuild the identical table. The hook's
      # own execute_unless_loaded is skipped for a development LazyRouteSet, so this is the one draw.
      Rails.application.routes_reloader.execute_unless_loaded
    rescue StandardError => e
      Rails.logger&.warn("Camaleon CMS: skipped eager route draw at boot (#{e.class}: #{e.message})")
      nil
    end

    # Add a callable (Proc/Lambda) to run after routes reload; strings are not supported.
    def add_after_reload_routes(command)
      raise(ArgumentError, 'Expected a callable (Proc/Lambda), not a String') if command.is_a?(String)

      after_reload_callbacks << command
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
      # Do not treat an empty result as a cache hit (an empty [] is truthy): if a draw runs before
      # the DB is ready, get_sites returns [] and this would otherwise cache [] permanently, matching
      # the self-healing all_plugins/all_themes below rather than the sticky-empty behavior.
      return r if r.present?

      res = get_sites.each_with_object([]) do |site, ary|
        i = theme_info(site.get_theme_slug)
        ary << i if i.present?
      end
      cache_variable('all_enabled_themes', res)
    end

    # return all enabled plugins (a theme is enabled if at least one site has installed)
    def all_enabled_plugins
      r = cache_variable('all_enabled_plugins')
      return r if r.present? # an empty [] must not stick as a cache hit -- see all_enabled_themes

      # Empty get_sites (the DB is not ready during early boot, or there simply are no sites) means
      # no DB work: gate the batched query on it here, as one explicit early return, so the query
      # never runs against a table that may not exist yet and aborts route loading. get_sites rescues
      # to [] on any DB error, so this single guard keeps the whole draw path safe -- and any batched
      # query added below inherits it, rather than each repeating a per-call emptiness check.
      return [] if get_sites.empty?

      # One query for every enabled plugin slug across all sites, rather than a
      # `site.plugins.active.pluck` per site (the N+1 that dominated multi-site route drawing). A
      # subquery over the site ids avoids marshaling every id into an IN(...) bind list, which can
      # exceed SQLite's SQLITE_MAX_VARIABLE_NUMBER on very large multi-site installs; Postgres and
      # MySQL handle either form.
      enabled_ps = CamaleonCms::Plugin.active.where(parent_id: CamaleonCms::Site.select(:id)).distinct.pluck(:slug)
      res = all_plugins.each_with_object([]) do |plugin, ary|
        ary << plugin if enabled_ps.include?(plugin['key'])
      end
      cache_variable('all_enabled_plugins', res)
    end

    # all helpers of enabled plugins for site
    def site_plugin_helpers(site)
      r = cache_variable('site_plugin_helpers')
      return r if r

      res = enabled_apps(site).filter_map { |settings| settings['helpers'].presence }.flatten
      cache_variable('site_plugin_helpers', res)
    end

    # all helpers of enabled plugins
    def all_helpers
      r = cache_variable('plugins_helper')
      return r if r

      res = all_apps.filter_map { |settings| settings['helpers'].presence }.flatten
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
      # Eager-load metas and post_types so the per-site reads route drawing performs come from the
      # loaded associations instead of one query per site: metas back the option/language/theme
      # lookups (get_meta checks metas.loaded?), and post_types back the frontend post-type route
      # loop. On large multi-site installs those N+1s are the bulk of cold-boot route-draw time --
      # the window where the first request races a half-built table.
      #
      # The whole metas set is loaded on purpose, not a scoped subset: get_meta's loaded branch reads
      # a key absent from the loaded records as unset, so preloading only _default/languages_site
      # would make every other site meta read silently return its default. Site-level metas are few
      # rows per site, so this bounded over-fetch is the safe trade against that correctness hazard.
      @all_sites ||= CamaleonCms::Site.includes(:metas, :post_types).order(id: :asc).to_a
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
      # A blank '' must not stick as a hit: an empty all_locales makes the frontend
      # `locale: /#{all_locales}/` constraint an empty regex `//` that matches anything.
      return r if r.present?

      res = get_sites.flat_map(&:get_languages)
      cache_variable('site_all_locales', res.uniq.join('|'))
    end

    # return all translations for all languages, sample: ['Sample', 'Ejemplo', '....']
    def all_translations(key, *args)
      args = args.extract_options!
      all_locales.split('|').map { |_l| I18n.t(key, **args.merge({ locale: _l })) }.uniq
    end

    # return app's directory path
    def apps_dir
      @apps_dir ||= Rails.root.join('app/apps').to_s
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
        p['descr'] = gem.description if p['descr'].blank?
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
      options[:protocol] = 'https' if Rails.application.config.force_ssl
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
  end
end
CamaManager = PluginRoutes
