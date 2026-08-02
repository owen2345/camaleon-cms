# frozen_string_literal: true

# Installing a Camaleon site (default plugins, theme, sample content, admin
# user) costs ~0.6s and used to happen before nearly every example. Install one
# canonical site per suite run instead, committed outside the per-example
# transactions so every example can reuse it; example-level mutations still
# roll back with their transaction.
RSpec.configure do |config|
  config.before(:suite) do
    connection = ActiveRecord::Base.connection
    (connection.tables - %w[schema_migrations ar_internal_metadata]).each do |table|
      connection.execute("DELETE FROM #{connection.quote_table_name(table)}")
    end
    # Drop caches memoized during boot (they may hold sites the purge just
    # deleted); set_default_user_roles resolves Site.main_site while installing.
    CamaleonCms::Site.instance_variable_set(:@main_site, nil)
    PluginRoutes.instance_variable_set(:@all_sites, nil)
    PluginRoutes.instance_variable_get(:@cache)&.clear
    FactoryBot.create(:site)
  end

  config.before do
    # The shared site outlives examples, but these class-level caches must not:
    # an example that adds a site or toggles a plugin would poison later ones.
    CamaleonCms::Site.instance_variable_set(:@main_site, nil)
    PluginRoutes.instance_variable_set(:@all_sites, nil)
    PluginRoutes.instance_variable_get(:@cache)&.clear
  end
end
