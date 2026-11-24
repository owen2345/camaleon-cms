# frozen_string_literal: true

# The rollback of a theme switch leaves the records that the switch created in the themes and the plugins
# of the site of the request. With no transaction around the switch, they are new records again, and a
# later save of that site stored them.
# The example runs outside the transaction of the test. After the rollback of a savepoint, only a record
# that the switch saved one time is a new record again. The switch saves its theme and its plugin more
# than one time. The switch rolls back, so the example leaves no row.
RSpec.describe 'A save of the site after a theme switch that rolled back' do
  include_context 'with theme hook probes'
  self.use_transactional_tests = false
  init_site

  let(:helper_object) do
    Class.new do
      include CamaleonCms::PluginsHelper
      include CamaleonCms::HooksHelper
    end.new
  end
  let(:stored_site) { CamaleonCms::Site.find(@site.id) }
  let(:rows_before) { { themes: stored_site.themes.ids, plugins: stored_site.plugins.ids } }

  # The on_active handler of the new theme installs a plugin, and then it raises.
  def probe_helper
    Module.new do
      define_method(:probe_new_on_active) do |_theme|
        plugin_install('visibility_post')
        raise ArgumentError, 'the hook raised'
      end
    end
  end

  before do
    rows_before
    probe_theme_hooks(probe_helper, 'default' => {}, 'new' => { 'on_active' => ['probe_new_on_active'] })
    CurrentRequest.site = @site
  end

  # A failed example leaves the rows that the save stored. The other examples need the site as it was.
  after do
    CamaleonCms::Theme.where(id: stored_site.themes.ids - rows_before[:themes]).delete_all
    CamaleonCms::Plugin.where(id: stored_site.plugins.ids - rows_before[:plugins]).delete_all
    CurrentRequest.reset
  end

  it 'stores no theme and no plugin of the switch' do
    expect { helper_object.site_install_theme('new') }.to raise_error(ArgumentError, 'the hook raised')

    @site.save!

    expect(stored_site.themes.ids).to eq(rows_before[:themes])
    expect(stored_site.plugins.ids).to eq(rows_before[:plugins])
  end
end
