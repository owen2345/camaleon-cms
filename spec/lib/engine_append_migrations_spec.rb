# frozen_string_literal: true

# With `auto_include_migrations` on, the engine puts its own db/migrate on the host app's migration
# path, except for an app that lives inside the engine's tree (the engine's spec/dummy app). That
# exception is a path containment test: a host that only shares the engine root as a string prefix,
# such as a plugin checked out beside the core as `camaleon-cms-seo` with the core sourced as a path
# gem, is a regular host and gets the migrations.
RSpec.describe CamaleonCms::Engine do
  describe '#append_engine_migrations' do
    let(:engine) { described_class.instance }
    # Read off the engine's config, which an example stubbing `engine.root` leaves alone.
    let(:engine_migrations) { engine.config.root.join('db/migrate').to_s }

    def host_app(root_path)
      paths = Rails::Paths::Root.new(root_path.to_s)
      # Its own entry points elsewhere, so a host at the engine root does not list the engine's
      # migrations before the append.
      paths.add 'db/migrate', with: 'db/host_migrate'
      config = instance_double(Rails::Application::Configuration, paths: paths)
      instance_double(Rails::Application, root: Pathname.new(root_path.to_s), config: config)
    end

    def migration_paths_after_append(root_path)
      app = host_app(root_path)
      engine.append_engine_migrations(app)
      app.config.paths['db/migrate'].to_a
    end

    before do
      allow(PluginRoutes).to receive(:static_system_info).and_return('auto_include_migrations' => true)
    end

    it "skips the engine's own dummy app, which lives inside the engine root" do
      expect(migration_paths_after_append(engine.root.join('spec/dummy'))).not_to include(engine_migrations)
    end

    it 'skips a host rooted at the engine root itself' do
      expect(migration_paths_after_append(engine.root)).not_to include(engine_migrations)
    end

    it 'appends for a sibling checkout whose path starts with the engine root string' do
      expect(migration_paths_after_append("#{engine.root}-seo/spec/dummy")).to include(engine_migrations)
    end

    it 'appends for a host whose path contains the engine root further along' do
      expect(migration_paths_after_append("/mnt/backup#{engine.root}/spec/dummy")).to include(engine_migrations)
    end

    it 'appends for a host at an unrelated path' do
      expect(migration_paths_after_append('/srv/apps/blog')).to include(engine_migrations)
    end

    it 'reads regexp metacharacters in the engine root literally' do
      allow(engine).to receive(:root).and_return(Pathname.new('/srv/camaleon+cms (v2)'))

      expect(migration_paths_after_append('/srv/camaleon+cms (v2)/spec/dummy')).not_to include(engine_migrations)
    end

    it 'appends nothing when auto_include_migrations is off' do
      allow(PluginRoutes).to receive(:static_system_info).and_return('auto_include_migrations' => false)

      expect(migration_paths_after_append('/srv/apps/blog')).not_to include(engine_migrations)
    end
  end
end
