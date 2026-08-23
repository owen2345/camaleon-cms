# frozen_string_literal: true

RSpec.describe PluginRoutes do
  describe '.add_after_reload_routes' do
    after do
      # Clean up the instance variable to avoid polluting other tests
      described_class.instance_variable_set(:@after_reload_callbacks, [])
    end

    it 'accepts a Proc' do
      callable = proc { 'hello' }
      expect { described_class.add_after_reload_routes(callable) }.not_to raise_error
    end

    it 'accepts a Lambda' do
      callable = -> { 'hello' }
      expect { described_class.add_after_reload_routes(callable) }.not_to raise_error
    end

    it 'raises ArgumentError for a String' do
      expect { described_class.add_after_reload_routes('puts "hello"') }
        .to raise_error(ArgumentError, /callable/)
    end
  end

  describe '.reload' do
    it 'calls each registered callable' do
      callback = instance_double(Proc)
      described_class.instance_variable_set(:@after_reload_callbacks, [callback])

      allow(Rails.application).to receive(:reload_routes!)

      expect(callback).to receive(:call)

      described_class.reload

      # Clean up
      described_class.instance_variable_set(:@after_reload_callbacks, [])
    end

    it 'clears the cache before reloading routes' do
      # Set a cache value
      described_class.cache_variable('test_key', 'test_value')
      expect(described_class.cache_variable('test_key')).to eq('test_value')

      # Mock reload_routes! to not actually reload
      allow(Rails.application).to receive(:reload_routes!)

      described_class.reload

      # Cache should be cleared
      expect(described_class.cache_variable('test_key')).to be_nil
    end
  end

  describe '.cache_variable' do
    before do
      # Clear cache before each test
      described_class.instance_variable_set(:@cache, {})
    end

    it 'stores and retrieves values' do
      described_class.cache_variable('my_key', 'my_value')
      expect(described_class.cache_variable('my_key')).to eq('my_value')
    end

    it 'returns nil for nonexistent keys' do
      expect(described_class.cache_variable('nonexistent')).to be_nil
    end

    it 'overwrites existing values' do
      described_class.cache_variable('key', 'value1')
      described_class.cache_variable('key', 'value2')
      expect(described_class.cache_variable('key')).to eq('value2')
    end
  end

  describe '.plugin_info' do
    it 'returns plugin info by key' do
      # Stub all_plugins to return a known plugin
      plugin = { 'key' => 'test_plugin', 'name' => 'Test Plugin' }
      allow(described_class).to receive(:all_plugins).and_return([plugin])

      expect(described_class.plugin_info('test_plugin')).to eq(plugin)
    end

    it 'returns nil for nonexistent plugin' do
      allow(described_class).to receive(:all_plugins).and_return([])

      expect(described_class.plugin_info('nonexistent')).to be_nil
    end

    it 'finds plugin by path basename' do
      plugin = { 'key' => 'my_plugin', 'path' => '/some/path/my_plugin' }
      allow(described_class).to receive(:all_plugins).and_return([plugin])

      expect(described_class.plugin_info('my_plugin')).to eq(plugin)
    end
  end

  describe '.theme_info' do
    it 'returns theme info by key' do
      theme = { 'key' => 'test_theme', 'name' => 'Test Theme' }
      allow(described_class).to receive(:all_themes).and_return([theme])

      expect(described_class.theme_info('test_theme')).to eq(theme)
    end

    it 'returns nil for nonexistent theme' do
      allow(described_class).to receive(:all_themes).and_return([])

      expect(described_class.theme_info('nonexistent')).to be_nil
    end
  end

  describe 'class instance variables' do
    it 'uses class instance variables instead of class variables' do
      # Verify that we're using class instance variables (no @@)
      expect(described_class.instance_variable_defined?(:@cache)).to be true
      expect(described_class.instance_variable_defined?(:@reload_monitor)).to be true
      expect(described_class.instance_variable_defined?(:@after_reload_callbacks)).to be true
    end

    it 'does not have class variables' do
      # Ensure we're not using class variables anymore
      expect { described_class.class_variable_get(:@@cache) }.to raise_error(NameError)
    end
  end

  describe '.all_helpers' do
    after { described_class.send(:cache).delete('plugins_helper') }

    it 'omits apps that declare no helpers' do
      described_class.send(:cache).delete('plugins_helper')
      apps = [
        { 'key' => 'no_helpers_key' },
        { 'key' => 'empty_helpers', 'helpers' => [] },
        { 'key' => 'with_helpers', 'helpers' => ['CamaleonCms::CamaleonHelper'] }
      ]
      allow(described_class).to receive(:all_apps).and_return(apps)

      expect(described_class.all_helpers).to eq(['CamaleonCms::CamaleonHelper'])
    end

    # filter_map + flatten has to keep behaving like the flat_map + compact it replaced, for a
    # scalar as well as a list, since an app config may declare either shape.
    it 'accepts a single helper declared as a scalar' do
      described_class.send(:cache).delete('plugins_helper')
      apps = [{ 'key' => 'scalar_helper', 'helpers' => 'CamaleonCms::CamaleonHelper' }]
      allow(described_class).to receive(:all_apps).and_return(apps)

      expect(described_class.all_helpers).to eq(['CamaleonCms::CamaleonHelper'])
    end
  end

  describe '.site_plugin_helpers' do
    after { described_class.send(:cache).delete('site_plugin_helpers') }

    it 'omits enabled apps that declare no helpers' do
      described_class.send(:cache).delete('site_plugin_helpers')
      apps = [
        { 'key' => 'no_helpers_key' },
        { 'key' => 'with_helpers', 'helpers' => ['CamaleonCms::CamaleonHelper'] }
      ]
      site = instance_double(CamaleonCms::Site)
      allow(described_class).to receive(:enabled_apps).with(site).and_return(apps)

      expect(described_class.site_plugin_helpers(site)).to eq(['CamaleonCms::CamaleonHelper'])
    end
  end

  # ---- cold-boot route-draw performance + eager draw (fix/cold-boot-route-draw) ----
  # sql_queries(matching:) is provided by spec/support/sql_queries.rb

  describe '.get_sites' do
    before { described_class.instance_variable_set(:@all_sites, nil) }
    after  { described_class.instance_variable_set(:@all_sites, nil) }

    # The per-site option/language/theme reads route drawing performs are an N+1 unless metas
    # are eager-loaded here; on a multi-site install that N+1 is the bulk of cold-boot draw time.
    it 'eager-loads the metas association for every site' do
      create(:site)

      sites = described_class.get_sites

      expect(sites).to be_present
      sites.each { |site| expect(site.association(:metas)).to be_loaded }
    end

    # Frontend route drawing loops PluginRoutes.get_sites and reads each site's post_types; without
    # eager-loading them here that is one query per site at draw time.
    it 'eager-loads the post_types association for every site' do
      create(:site)

      sites = described_class.get_sites

      expect(sites).to be_present
      sites.each { |site| expect(site.association(:post_types)).to be_loaded }
    end
  end

  describe '.all_enabled_plugins' do
    # Reset the memoized site list and the cached result. Creating a site can trigger a route
    # reload that re-populates both with pre-stub data, so each example resets again just before
    # exercising the method.
    def reset_enabled_plugins_cache!
      described_class.instance_variable_set(:@all_sites, nil)
      described_class.send(:cache).delete('all_enabled_plugins')
    end

    # No `before` reset: each example creates its sites (which triggers a route reload that
    # re-populates the cache with pre-stub data) and then resets again just before exercising the
    # method, so a leading reset would be immediately overwritten. The `after` keeps the isolation.
    after { reset_enabled_plugins_cache! }

    it 'returns the config of a plugin active on any site' do
      site = create(:site)
      site.plugins.where(slug: 'cb_active_plugin').first_or_create!.update!(term_group: 1)
      config = { 'key' => 'cb_active_plugin', 'name' => 'Active Plugin' }
      allow(described_class).to receive(:all_plugins).and_return([config])
      reset_enabled_plugins_cache!

      expect(described_class.all_enabled_plugins).to include(config)
    end

    it 'resolves enabled plugin slugs in a single query, not one per site' do
      allow(described_class).to receive(:all_plugins).and_return([])
      create_list(:site, 2) # more than one site: a per-site lookup would issue several queries
      reset_enabled_plugins_cache!

      plugin_queries = sql_queries(matching: /term_taxonomy/i) { described_class.all_enabled_plugins }
      # Every site's enabled-plugin slugs come back in one `parent_id IN (...)` query -- the whole
      # point of the fix -- rather than one lookup per site. get_sites also batches its post_types
      # preload with a `parent_id IN`, so match the plugin lookup specifically: it is the one that
      # selects `slug` (the preload selects `*`).
      batched_lookups = plugin_queries.count { |q| q.match?(/parent_id.*\bIN\b/i) && q.include?('slug') }

      expect(batched_lookups).to(eq(1), plugin_queries.join("\n----\n"))
    end

    # A draw that runs before the DB is ready caches []; that empty result must not stick (it is
    # truthy), or plugin routes stay undrawn until an explicit reload even after sites exist.
    it 'recomputes instead of serving a cached empty result as a hit' do
      site = create(:site)
      site.plugins.where(slug: 'cb_active_plugin').first_or_create!.update!(term_group: 1)
      config = { 'key' => 'cb_active_plugin', 'name' => 'Active Plugin' }
      allow(described_class).to receive(:all_plugins).and_return([config])
      reset_enabled_plugins_cache!

      # Seed a stale empty result, as if an earlier draw ran before the DB was ready.
      described_class.send(:cache)['all_enabled_plugins'] = []

      # The stuck [] is ignored and the plugin active on the site is resolved.
      expect(described_class.all_enabled_plugins).to include(config)
    end
  end

  describe '.draw_routes_eagerly' do
    # eager_load is off in development/test, where routes would otherwise be drawn lazily on the
    # first request; the guarded draw is a no-op when eager_load is on (production draws at boot).
    before { allow(Rails.application.config).to receive(:eager_load).and_return(false) }

    # The boot draw calls Rails.application.reload_routes! (version-agnostic, the same redraw
    # PluginRoutes.reload performs); these examples assert the guards decide whether that call runs.
    it 'draws the routes when the DB is installed and routes are lazy' do
      allow(described_class).to receive(:db_installed?).and_return(true)

      expect(Rails.application).to receive(:reload_routes!)

      described_class.draw_routes_eagerly
    end

    it 'does nothing when the database is not installed' do
      allow(described_class).to receive(:db_installed?).and_return(false)

      expect(Rails.application).not_to receive(:reload_routes!)

      described_class.draw_routes_eagerly
    end

    it 'does nothing when routes are already eager-loaded at boot (production)' do
      allow(Rails.application.config).to receive(:eager_load).and_return(true)
      allow(described_class).to receive(:db_installed?).and_return(true)

      expect(Rails.application).not_to receive(:reload_routes!)

      described_class.draw_routes_eagerly
    end

    it 'does nothing while a db: rake task is running (schema is mid-change)' do
      allow(described_class).to receive_messages(running_db_rake_task?: true, db_installed?: true)

      expect(Rails.application).not_to receive(:reload_routes!)

      described_class.draw_routes_eagerly
    end

    it 'never lets a database failure at boot abort startup' do
      allow(described_class).to receive(:db_installed?).and_return(true)
      allow(Rails.application).to receive(:reload_routes!)
        .and_raise(ActiveRecord::ConnectionNotEstablished)

      expect { described_class.draw_routes_eagerly }.not_to raise_error
    end

    it 'lets a non-database error (a real route bug) surface instead of swallowing it' do
      allow(described_class).to receive(:db_installed?).and_return(true)
      allow(Rails.application).to receive(:reload_routes!)
        .and_raise(NameError, 'uninitialized constant BrokenRoute')

      expect { described_class.draw_routes_eagerly }.to raise_error(NameError)
    end
  end

  describe '.running_db_rake_task?' do
    it 'is true when a db: task is the top-level Rake task' do
      stub_const('Rake', double(application: double(top_level_tasks: ['db:migrate'])))

      expect(described_class.send(:running_db_rake_task?)).to be(true)
    end

    it 'is true for an engine-prefixed db task (app:db:...)' do
      stub_const('Rake', double(application: double(top_level_tasks: ['app:db:test:prepare'])))

      expect(described_class.send(:running_db_rake_task?)).to be(true)
    end

    it 'is false when the top-level Rake task is not a db: task' do
      stub_const('Rake', double(application: double(top_level_tasks: ['assets:precompile'])))

      expect(described_class.send(:running_db_rake_task?)).to be(false)
    end

    it 'is false when no Rake application is running (web server, console, runner)' do
      hide_const('Rake')

      expect(described_class.send(:running_db_rake_task?)).to be(false)
    end
  end
end
