# frozen_string_literal: true

require 'rails_helper'
require 'camaleon_cms/assets_precompile'
require 'tmpdir'

# Guards the Sprockets precompile declaration for plugin/theme assets.
#
# Regression context: on Sprockets >= 4 with `unknown_asset_fallback = false`, a
# plugin asset such as `plugins/visibility_post/assets/js/form.js` (rendered by the
# admin post form via `javascript_include_tag`) raises `AssetNotPrecompiledError`
# unless its exact logical path is declared as precompiled. `match?` decides which
# assets qualify; `logical_paths` enumerates the concrete files to declare.
RSpec.describe CamaleonCms::AssetsPrecompile do
  describe '.match?' do
    it 'matches plugin and theme assets with asset extensions' do
      expect(described_class.match?('plugins/visibility_post/assets/js/form.js')).to be true
      expect(described_class.match?('themes/my_theme/assets/css/app.css')).to be true
      expect(described_class.match?('themes/my_theme/assets/img/logo.png')).to be true
      expect(described_class.match?('plugins/foo/assets/fonts/icons.woff2')).to be true
    end

    it 'matches gem_mode plugin assets that have no assets/ path segment' do
      # e.g. cama_contact_form ships app/assets/javascripts/plugins/cama_contact_form/admin_editor.js
      expect(described_class.match?('plugins/cama_contact_form/admin_editor.js')).to be true
      expect(described_class.match?('themes/gem_theme/app.css')).to be true
    end

    it 'rejects assets outside plugins/ and themes/' do
      expect(described_class.match?('camaleon_cms/admin/app.js')).to be false
      expect(described_class.match?('application.js')).to be false
    end

    it 'rejects partials, view templates and non-asset files' do
      expect(described_class.match?('plugins/foo/assets/js/_partial.js')).to be false
      expect(described_class.match?('plugins/foo/views/index.html.erb')).to be false
      expect(described_class.match?('plugins/foo/foo_helper.rb')).to be false
      expect(described_class.match?('plugins/foo/config/config.json')).to be false
    end
  end

  describe '.logical_paths' do
    it 'enumerates only matching plugin/theme asset files under the base dirs' do
      Dir.mktmpdir do |base|
        FileUtils.mkdir_p(File.join(base, 'plugins/sample/assets/js'))
        FileUtils.mkdir_p(File.join(base, 'plugins/sample/views'))
        FileUtils.mkdir_p(File.join(base, 'themes/sample/assets/css'))
        File.write(File.join(base, 'plugins/sample/assets/js/form.js'), '// js')
        File.write(File.join(base, 'plugins/sample/assets/js/_partial.js'), '// partial')
        File.write(File.join(base, 'plugins/sample/views/index.html.erb'), 'erb')
        File.write(File.join(base, 'plugins/sample/sample_helper.rb'), 'ruby')
        File.write(File.join(base, 'themes/sample/assets/css/app.css'), 'css')

        result = described_class.logical_paths([base])

        expect(result).to contain_exactly(
          'plugins/sample/assets/js/form.js',
          'themes/sample/assets/css/app.css'
        )
      end
    end

    it 'returns [] for base dirs that do not exist' do
      expect(described_class.logical_paths(['/no/such/dir'])).to eq([])
    end

    it 'enumerates gem_mode plugin assets that live directly under a plugins/ asset root' do
      # gem_mode plugins (separate gems) expose their assets under an asset load path like
      # <gem>/app/assets/javascripts, so the logical path has no `assets/` segment.
      Dir.mktmpdir do |root|
        FileUtils.mkdir_p(File.join(root, 'plugins/gem_plugin'))
        FileUtils.mkdir_p(File.join(root, 'themes/gem_theme'))
        File.write(File.join(root, 'plugins/gem_plugin/admin_editor.js'), '// js')
        File.write(File.join(root, 'themes/gem_theme/app.css'), 'css')

        result = described_class.logical_paths([root])

        expect(result).to contain_exactly(
          'plugins/gem_plugin/admin_editor.js',
          'themes/gem_theme/app.css'
        )
      end
    end

    it 'enumerates the gem-bundled visibility_post form.js asset' do
      gem_apps = File.join($camaleon_engine_dir, 'app', 'apps') # rubocop:disable Style/GlobalVars

      expect(described_class.logical_paths([gem_apps]))
        .to include('plugins/visibility_post/assets/js/form.js')
    end

    it 'covers host/gem-bundled and separately gem-packaged (gem_mode) assets via default roots' do
      # Organic, end-to-end: with no argument it scans the configured Sprockets load paths,
      # so both an app/apps-layout plugin (visibility_post, bundled in the gem) and a
      # gem_mode-layout plugin (cama_contact_form, a separate gem) must be declared.
      result = described_class.logical_paths

      expect(result).to include('plugins/visibility_post/assets/js/form.js')
      expect(result).to include('plugins/cama_contact_form/admin_editor.js')
    end
  end

  describe '.default_asset_roots' do
    it 'includes the configured Sprockets asset load paths' do
      roots = described_class.default_asset_roots
      expect(roots).to include(*Array(Rails.application.config.assets.paths).map(&:to_s))
    end
  end
end
