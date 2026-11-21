# frozen_string_literal: true

# The create of a site installs the default plugins and then the theme of the site. The plugin
# installs fired their hooks before the site had its theme, so the default theme got them. The
# create also ran an on_inactive hook, although a new site has no theme to uninstall.
RSpec.describe 'The theme hooks of a site create', type: :request do
  include_context 'with theme hook probes'

  let(:default_plugins) { PluginRoutes.system_info['default_plugins'] }
  let(:hooks) do
    %w[default new].index_with do |slug|
      { 'plugin_after_install' => ["probe_#{slug}_plugin_after_install"],
        'on_inactive' => ["probe_#{slug}_on_inactive"], 'on_active' => ["probe_#{slug}_on_active"] }
    end
  end

  # Each theme records its hooks. Its plugin_after_install handler stores an option on the theme
  # record. The on_inactive handler of "new" destroys that record, as the handler of the bundled
  # theme does.
  def probe_helper
    log = hook_log
    Module.new do
      %w[default new].each do |slug|
        define_method(:"probe_#{slug}_plugin_after_install") do |args|
          current_theme.set_option('probe_stored', 'by a plugin hook')
          log << [:plugin_after_install, slug, args[:plugin].slug]
        end
        define_method(:"probe_#{slug}_on_inactive") do |theme|
          theme.destroy if slug == 'new'
          log << [:on_inactive, slug]
        end
        define_method(:"probe_#{slug}_on_active") do |theme|
          log << [:on_active, slug, theme.get_option('probe_stored')]
        end
      end
    end
  end

  before { probe_theme_hooks(probe_helper, hooks) }

  describe 'the installer with a theme that is not the default theme' do
    let(:site) { CamaleonCms::Site.last }

    before do
      # The installer is open only while no site exists.
      [CamaleonCms::Site, CamaleonCms::User].each(&:delete_all)
      post save_cama_admin_installers_path, params: { site: { name: 'First site', slug: 'first-site' }, theme: 'new' }
    end

    it 'sends the hooks of the default plugins to the theme of the site' do
      expect(response).to redirect_to(welcome_cama_admin_installers_path)
      expect(hook_log).to include(*default_plugins.map { |plugin| [:plugin_after_install, 'new', plugin] })
      expect(hook_log.map { |entry| entry[1] }.uniq).to eq(['new'])
    end

    it 'makes one theme record, with the name of the theme config' do
      expect(site.themes.pluck(:slug, :name)).to eq([['new', PluginRoutes.theme_info('new')['name']]])
    end

    it 'runs on_active with the value that a plugin hook stored, and no on_inactive' do
      expect(hook_log.map(&:first)).not_to include(:on_inactive)
      expect(hook_log.last).to eq([:on_active, 'new', 'by a plugin hook'])
      expect(hook_log.count { |entry| entry.first == :on_active }).to eq(1)
    end
  end

  describe 'with a site that exists' do
    init_site

    let(:admin_user) do
      create(
        :user, username: 'admin', password: 'admin123', password_confirmation: 'admin123', role: 'admin', site: @site
      )
    end
    let(:lifecycle) { hook_log.map(&:first) - [:plugin_after_install] }

    before { sign_in_as(admin_user, site: @site) }

    it 'runs on_active only for a site create in the admin panel' do
      post cama_admin_settings_sites_path, params: { site: { name: 'Second site', slug: 'second-site' } }

      expect(response).to redirect_to(cama_admin_settings_sites_path)
      expect(lifecycle).to eq([:on_active])
      new_site = CamaleonCms::Site.find_by!(slug: 'second-site')
      expect(new_site.themes.pluck(:slug, :name)).to eq([['default', PluginRoutes.theme_info('default')['name']]])
    end

    it 'runs on_inactive and then on_active for an install of the current theme' do
      get cama_admin_appearances_themes_path, params: { set: 'default' }

      expect(lifecycle).to eq(%i[on_inactive on_active])
    end
  end
end
