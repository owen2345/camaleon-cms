# frozen_string_literal: true

# The install of a theme runs the on_inactive hook of the old theme and the on_active hook of the new
# theme. hooks_run sends a hook to the current theme. A request read its current theme before the
# install, so a hook that the on_active handler fired went to the old theme.
RSpec.describe 'The current theme while a theme is installed', type: :request do
  include_context 'with theme hook probes'
  init_site

  let(:admin_user) do
    create(
      :user, username: 'admin', password: 'admin123', password_confirmation: 'admin123', role: 'admin', site: @site
    )
  end
  let(:calls_handler_directly) { false }
  let(:on_active_error) { nil }
  let(:installed_after_install_runs) { hook_log.count([:after_install, 'new']) }

  # The site has the theme "default". Each example installs the theme "new". Its on_active handler
  # installs a plugin, and both themes handle the after-install hook of that plugin.
  def probe_helper
    log = hook_log
    direct_call = calls_handler_directly
    error = on_active_error
    Module.new do
      define_method(:probe_old_on_inactive) { |theme| log << [:on_inactive, theme.slug, current_theme.slug] }
      define_method(:probe_old_after_install) { |_args| log << [:after_install, 'default'] }
      define_method(:probe_new_after_install) { |_args| log << [:after_install, 'new'] }
      define_method(:probe_new_on_active) do |theme|
        log << [:on_active, theme.slug, current_theme.slug, current_theme.object.equal?(theme)]
        raise error if error

        plugin = plugin_install('visibility_post')
        probe_new_after_install({ plugin: plugin }) if direct_call
      end
      define_method(:probe_preview_before_load) do
        begin
          site_install_theme('new')
        rescue RuntimeError => e
          log << [:install_error, e.message]
        end
        log << [:after_install_theme, current_theme.slug]
      end
    end
  end

  before do
    probe_theme_hooks(
      probe_helper,
      'default' => { 'on_inactive' => ['probe_old_on_inactive'],
                     'plugin_visibility_post_after_install' => ['probe_old_after_install'] },
      'new' => { 'on_active' => ['probe_new_on_active'],
                 'plugin_visibility_post_after_install' => ['probe_new_after_install'] },
      'camaleon_first' => { 'front_before_load' => ['probe_preview_before_load'] }
    )
    sign_in_as(admin_user, site: @site)
  end

  describe 'an install in the admin panel' do
    before { get cama_admin_appearances_themes_path, params: { set: 'new' } }

    it 'gives the on_active handler its own theme as the current theme' do
      expect(response).to redirect_to(cama_admin_appearances_themes_path)
      expect(hook_log).to include([:on_active, 'new', 'new', true])
    end

    it 'sends a hook that the on_active handler fires to the installed theme' do
      expect(installed_after_install_runs).to eq(1)
      expect(hook_log).not_to include([:after_install, 'default'])
    end

    it 'gives the on_inactive handler the old theme as the current theme' do
      expect(hook_log).to include([:on_inactive, 'default', 'default'])
    end

    context 'when the on_active handler also calls its handler directly' do
      let(:calls_handler_directly) { true }

      it 'runs that handler for the hook and for the direct call' do
        expect(installed_after_install_runs).to eq(2)
      end
    end
  end

  # A user who can manage themes sees the site with another theme when the URL has ccc_theme_preview.
  # No request of Camaleon installs a theme there, so a handler of the preview theme does it.
  describe 'an install in a request with a theme preview' do
    before { get '/', params: { ccc_theme_preview: 'camaleon_first' } }

    it 'gives each handler its own theme as the current theme' do
      expect(hook_log).to include([:on_inactive, 'default', 'default'], [:on_active, 'new', 'new', true])
      expect(installed_after_install_runs).to eq(1)
      expect(hook_log).not_to include([:after_install, 'default'])
    end

    it 'shows the preview theme after the install' do
      expect(hook_log).to include([:after_install_theme, 'camaleon_first'])
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('themes/camaleon_first/')
      expect(response.body).not_to include('themes/new/')
    end

    context 'when the on_active handler raises' do
      let(:on_active_error) { 'on_active failed' }

      it 'gives the error to the caller and keeps the preview theme' do
        expect(hook_log).to include([:install_error, 'on_active failed'], [:after_install_theme, 'camaleon_first'])
        expect(response.body).to include('themes/camaleon_first/')
      end
    end
  end
end
