# frozen_string_literal: true

# In a request, the query cache holds the rows that the request read, and a write of another thread
# does not clear it. A trial of the routes read the sites from that cache. So a reload drew old data
# over the newer draw of another thread.
# A write of another thread clears the cache only when the two threads use one database connection, as
# in the transaction of a test. So the examples run outside that transaction, and they put the name of
# the site back.
RSpec.describe PluginRoutes do
  self.use_transactional_tests = false
  init_site

  let(:name_before) { CamaleonCms::Site.where(id: @site.id).pick(:name) }
  let(:new_name) { 'The name of the other request' }

  around { |example| ActiveRecord::Base.cache { example.run } }

  before do
    name_before
    described_class.reload
    # The read of a trial, as a request makes it before its reload. The query cache keeps its rows.
    CamaleonCms::Site.includes(:metas, :post_types).order(id: :asc).load
  end

  after do
    store_name(@site.id, name_before)
    described_class.reload
  end

  # Stores the name with no callback, so the write itself reloads no routes.
  def store_name(id, name)
    CamaleonCms::Site.where(id: id).update_all(name: name) # rubocop:disable Rails/SkipsModelValidations
  end

  # Another request gives the site a new name. The block runs in the thread of that request.
  def rename_in_another_request
    id = @site.id
    Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        store_name(id, new_name)
        yield if block_given?
      end
    end.join
  end

  def drawn_name
    described_class.get_sites.find { |site| site.id == @site.id }.name
  end

  it 'reads the stored sites in the first trial of a reload' do
    rename_in_another_request

    described_class.reload

    expect(drawn_name).to eq(new_name)
  end

  it 'reads the stored sites in the trial that a reload runs again after a reload of another thread' do
    trial = described_class.trial_routes
    rename_in_another_request { described_class.reload }

    described_class.reload(trial: trial)

    expect(drawn_name).to eq(new_name)
  end

  # The site list and the plugin lists of PluginRoutes go to all threads. The commit of another request
  # can clear them, and a request then fills them again. That fill read the rows of the query cache.
  describe 'a fill of the data of all threads after a clear of another request' do
    let(:plugin) { @site.plugins.where(slug: 'authoring_post').first_or_create! }

    before do
      plugin
      described_class.reload
      # The reads of the site list and of the plugin lists, as a request makes them. The query cache
      # keeps their rows. The write of the plugin row above cleared that cache.
      CamaleonCms::Site.includes(:metas, :post_types).order(id: :asc).load
      @site.plugins.active.pluck(:slug)
      CamaleonCms::Plugin.active.where(parent_id: CamaleonCms::Site.select(:id)).distinct.pluck(:slug)
    end

    after { CamaleonCms::Plugin.where(id: plugin.id).delete_all }

    # Another request makes the plugin active, with no callback. Its commit clears the data of all threads.
    def enable_the_plugin_in_another_request
      id = plugin.id
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          CamaleonCms::Plugin.where(id: id).update_all(term_group: 1) # rubocop:disable Rails/SkipsModelValidations
          described_class.send(:clear_shared_route_data)
        end
      end.join
    end

    it 'reads the stored sites for the list of get_sites' do
      rename_in_another_request { described_class.send(:clear_shared_route_data) }

      expect(drawn_name).to eq(new_name)
    end

    it 'reads the stored plugins of a site for the list of enabled_plugins' do
      enable_the_plugin_in_another_request

      expect(described_class.enabled_plugins(@site).pluck('key')).to include('authoring_post')
    end

    it 'reads the stored plugins for the list of all_enabled_plugins' do
      enable_the_plugin_in_another_request

      expect(described_class.all_enabled_plugins.pluck('key')).to include('authoring_post')
    end
  end
end
