# frozen_string_literal: true

# All threads share the site that main_site keeps. In a request, the query cache holds the rows that
# the request read, and a write of another thread does not clear it. A request that read the main site
# before a new slug of another request filled the memo with the old row. The draw of the app routes
# reads the main site for the default host, so the routes then got the old host.
# A write of another thread clears the cache only when the two threads use one database connection, as
# in the transaction of a test. So the examples run outside that transaction, and they put the slug
# back.
RSpec.describe CamaleonCms::Site do
  self.use_transactional_tests = false
  init_site

  # The read of main_site, as a request makes it. The query cache keeps its row.
  let!(:main) { described_class.reorder(id: :asc).first }
  let(:new_slug) { 'renamed-by-another-request.test' }

  around { |example| ActiveRecord::Base.cache { example.run } }

  after do
    store_slug(main.slug)
    described_class.forget_main_site
    PluginRoutes.reload
  end

  # Stores the slug with no callback, so the write itself reloads no routes and clears no memo.
  def store_slug(slug)
    described_class.where(id: main.id).update_all(slug: slug) # rubocop:disable Rails/SkipsModelValidations
  end

  def rename_in_another_request
    Thread.new { ActiveRecord::Base.connection_pool.with_connection { store_slug(new_slug) } }.join
  end

  describe '.main_site' do
    it 'gives each thread the stored main site after a new slug of another request' do
      rename_in_another_request
      # The commit of the other request does this.
      described_class.forget_main_site

      expect(described_class.main_site.slug).to eq(new_slug)
      expect(Thread.new { described_class.main_site.slug }.value).to eq(new_slug)
    end

    it 'gives the routes the stored slug as their default host' do
      rename_in_another_request

      PluginRoutes.reload

      expect(PluginRoutes.drawn_default_host).to eq(new_slug)
    end
  end
end
