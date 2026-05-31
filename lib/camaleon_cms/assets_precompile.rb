module CamaleonCms
  # Helper used by config/initializers/assets.rb to declare plugin/theme assets as
  # precompiled.
  #
  # Plugin and theme assets can live in three different layouts:
  #   * host app:               <app>/app/apps/{plugins,themes}/<key>/assets/...
  #   * the camaleon_cms gem:   <gem>/app/apps/{plugins,themes}/<key>/assets/...
  #   * separate "gem_mode" gems: <gem>/app/assets/<type>/{plugins,themes}/<key>/...
  #     (e.g. cama_contact_form ships app/assets/javascripts/plugins/cama_contact_form/...)
  #
  # Rails' default Sprockets precompile rules only cover the app/assets top level, so none
  # of these are declared as precompiled. On modern Sprockets (>= 4) with
  # `config.assets.unknown_asset_fallback = false`, requesting such an asset (e.g. via
  # `javascript_include_tag "plugins/visibility_post/assets/js/form.js"`) raises
  # `Sprockets::Rails::Helper::AssetNotPrecompiledError` unless it is declared.
  #
  # We enumerate the concrete asset files from the *real* Sprockets load paths and declare
  # their exact logical paths as strings. Strings are the canonical, Sprockets-version
  # agnostic form (work on both 3.x and 4.x). Scanning `config.assets.paths` (instead of a
  # couple of hardcoded directories) ensures host, gem-bundled and separately gem-packaged
  # (gem_mode) plugins/themes are all covered, matching the reach of the old precompile
  # `proc` this replaced. Because the declaration is computed from the on-disk files, every
  # installed plugin/theme is declared regardless of whether it is currently active, so
  # switching themes / enabling-disabling plugins (DB-only operations) never requires a
  # recompile.
  module AssetsPrecompile
    PRECOMPILE_EXTENSIONS = /\.(css|js|svg|ttf|woff|woff2|eot|otf|swf|pdf|png|jpe?g|gif|ico|mp3|mp4|webm|ogg|webp)\z/i
    PRECOMPILE_CONTENT_TYPES = %r{(javascript|image/|audio|video|font)}

    module_function

    # path: logical asset path relative to an asset load path, e.g.
    #   "plugins/visibility_post/assets/js/form.js", "themes/my_theme/assets/css/app.css"
    #   or "plugins/cama_contact_form/admin_editor.js" (gem_mode layout).
    # Returns true when the asset must be precompiled.
    def match?(path)
      dirname = File.dirname(path)
      return false unless dirname.start_with?('plugins/', 'themes/')

      name = File.basename(path)
      return false if name.start_with?('_') || path.include?('/views/')

      PRECOMPILE_EXTENSIONS.match?(path) || content_type_for(name).scan(PRECOMPILE_CONTENT_TYPES).any?
    end

    def content_type_for(name)
      MIME::Types.type_for(name).first.content_type
    rescue StandardError
      ''
    end

    # Enumerate the logical paths of every plugin/theme asset found under the given asset
    # roots. For each root, only the `plugins/` and `themes/` subtrees are scanned, and each
    # file is converted to its logical path (relative to the root) and filtered by `match?`.
    def logical_paths(asset_roots = default_asset_roots)
      asset_roots.flat_map do |root|
        root = root.to_s
        next [] if root.empty? || !Dir.exist?(root)

        prefix = "#{root.chomp('/')}/"
        Dir.glob(File.join(root, '{plugins,themes}', '**', '*')).filter_map do |file|
          next unless File.file?(file)

          logical = file.delete_prefix(prefix)
          logical if match?(logical)
        end
      end.uniq
    end

    # Asset roots to scan: the configured Sprockets load paths (which cover host,
    # gem-bundled and gem_mode plugin/theme assets), plus the host and camaleon_cms gem
    # `app/apps` folders as a fallback in case the asset paths are not yet populated when
    # this is called during initialization.
    def default_asset_roots
      roots = []
      if defined?(Rails) && Rails.respond_to?(:application) && Rails.application
        roots.concat(Array(Rails.application.config.assets.paths).map(&:to_s))
      end
      roots << Rails.root.join('app/apps').to_s if defined?(Rails) && Rails.respond_to?(:root) && Rails.root
      # rubocop:disable Style/GlobalVars
      roots << File.join($camaleon_engine_dir, 'app', 'apps') if defined?($camaleon_engine_dir) && $camaleon_engine_dir
      # rubocop:enable Style/GlobalVars
      roots.uniq
    end
  end
end
