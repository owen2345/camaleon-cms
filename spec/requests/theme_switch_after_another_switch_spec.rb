# frozen_string_literal: true

# Two theme switches can run at the same time, and the second switch waits for the lock of the first
# switch. Its request read the site before that wait. The site object holds the options of that time,
# and in a request the query cache holds the theme row of that time. With those reads, the second
# switch ran the on_inactive hook of the theme before the first switch a second time. It never ran
# that hook for the theme of the first switch, and it dropped an option that the first switch stored.
# With no query cache, it raised ActiveRecord::RecordInvalid.
RSpec.describe 'A theme switch after a switch of another request' do
  include_context 'with theme hook probes'
  init_site

  let(:helper_object) do
    Class.new do
      include CamaleonCms::PluginsHelper
      include CamaleonCms::HooksHelper
    end.new
  end
  let(:stored_site) { CamaleonCms::Site.find(@site.id) }

  # Each handler notes its hook and its theme. The on_active handler of the theme new stores an option.
  def probe_helper
    log = hook_log
    Module.new do
      define_method(:probe_on_active) do |theme|
        log << [:on_active, theme.slug]
        current_site.set_option('probe_option', 'of the first switch') if theme.slug == 'new'
      end
      define_method(:probe_on_inactive) { |theme| log << [:on_inactive, theme.slug] }
    end
  end

  # The site as a request reads it before its action: the options and the row of the current theme.
  def site_that_the_request_read
    CamaleonCms::Site.find(@site.id).decorate.tap(&:get_theme)
  end

  # Runs a whole switch in a thread of its own, with a site object of its own.
  def switch_in_another_request(key)
    site = CamaleonCms::Site.find(@site.id).decorate
    helper = helper_object
    Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        CurrentRequest.site = site
        helper.site_install_theme(key)
      end
    ensure
      CurrentRequest.reset
    end.join
  end

  before do
    hooks = { 'on_active' => ['probe_on_active'], 'on_inactive' => ['probe_on_inactive'] }
    probe_theme_hooks(probe_helper, %w[default new camaleon_first].index_with { hooks })
  end

  after { CurrentRequest.reset }

  shared_examples 'a switch from the theme of the other switch' do
    it 'runs the on_inactive hook of that theme, and keeps the option that the other switch stored' do
      CurrentRequest.site = site_that_the_request_read
      switch_in_another_request('new')

      helper_object.site_install_theme('camaleon_first')

      expect(hook_log).to eq([[:on_inactive, 'default'], [:on_active, 'new'],
                              [:on_inactive, 'new'], [:on_active, 'camaleon_first']])
      expect(stored_site.get_theme_slug).to eq('camaleon_first')
      expect(stored_site.get_option('probe_option')).to eq('of the first switch')
    end
  end

  context 'with no query cache' do
    it_behaves_like 'a switch from the theme of the other switch'
  end

  # A write of another thread clears the query cache of a request only when the two threads use one
  # database connection. The transaction of a test gives the two threads one connection. So the example
  # runs outside that transaction, and it puts the rows of the site back.
  context 'with the query cache of a request' do
    self.use_transactional_tests = false

    let(:themes_before) { stored_site.themes.pluck(:id, :status).to_h }
    let(:options_before) { stored_site.metas.where(key: '_default').pluck(:id, :value).to_h }

    around { |example| ActiveRecord::Base.cache { example.run } }

    before do
      themes_before
      options_before
    end

    after do
      CamaleonCms::Theme.where(id: stored_site.themes.ids - themes_before.keys).delete_all
      # The rows get their old values back as they were stored, so no validation and no callback runs.
      # rubocop:disable Rails/SkipsModelValidations
      themes_before.each { |id, status| CamaleonCms::Theme.where(id: id).update_all(status: status) }
      options_before.each { |id, value| CamaleonCms::Meta.where(id: id).update_all(value: value) }
      # rubocop:enable Rails/SkipsModelValidations
      PluginRoutes.reload
    end

    it_behaves_like 'a switch from the theme of the other switch'
  end

  # A site can hold its metas in memory, for example a site of PluginRoutes.get_sites. Its reads come
  # from those rows, so the switch loads them again after it takes the lock.
  context 'with the metas of the site loaded' do
    let(:loaded_site) { CamaleonCms::Site.includes(:metas).find(@site.id).decorate.tap(&:get_theme) }

    before { CurrentRequest.site = loaded_site }

    it 'runs the on_inactive hook of the theme of the other switch, and keeps its option' do
      expect(loaded_site.metas).to be_loaded
      switch_in_another_request('new')

      helper_object.site_install_theme('camaleon_first')

      expect(hook_log).to eq([[:on_inactive, 'default'], [:on_active, 'new'],
                              [:on_inactive, 'new'], [:on_active, 'camaleon_first']])
      expect(stored_site.get_theme_slug).to eq('camaleon_first')
      expect(stored_site.get_option('probe_option')).to eq('of the first switch')
    end

    # A load of the metas drops a meta or a change that the caller did not save. So the switch loads
    # no metas then (intended).
    it 'keeps a meta that the site holds and did not save' do
      built = loaded_site.metas.build(key: 'probe_unsaved', value: '1')

      helper_object.send(:cama_forget_site_reads)

      expect(loaded_site.metas.target).to include(built)
    end

    it 'keeps a change of a meta that the site did not save' do
      meta = loaded_site.metas.target.first
      meta.value = 'changed and not saved'

      helper_object.send(:cama_forget_site_reads)

      expect(loaded_site.metas.target.first).to equal(meta)
    end
  end
end
