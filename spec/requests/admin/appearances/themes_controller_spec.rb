# frozen_string_literal: true

RSpec.describe 'Admin::Appearances::ThemesController', type: :request do
  init_site
  let(:admin_user) do
    create(
      :user, username: 'admin', password: 'admin123', password_confirmation: 'admin123', role: 'admin', site: @site
    )
  end

  before { sign_in_as(admin_user, site: @site) }

  describe 'GET /admin/appearances/themes' do
    it 'does not call PluginRoutes.reload when viewing themes list' do
      expect(PluginRoutes).not_to receive(:reload)
      get cama_admin_appearances_themes_path
    end

    it 'returns success when viewing themes list' do
      get cama_admin_appearances_themes_path
      expect(response).to have_http_status(:success)
    end

    it 'calls PluginRoutes.reload when installing a theme' do
      # site_install_theme calls PluginRoutes.reload
      expect(PluginRoutes).to receive(:reload)
      get cama_admin_appearances_themes_path, params: { set: 'default' }
    end

    # The draw of the app routes waits for the other requests. In the savepoint of the switch, a request
    # that waits for a row of the switch made that draw wait for 10 seconds.
    it 'draws the routes of the app after the savepoint of the switch' do
      depth = ActiveRecord::Base.connection.open_transactions
      depths = []
      allow(Rails.application).to receive(:reload_routes!).and_wrap_original do |original|
        depths << ActiveRecord::Base.connection.open_transactions
        original.call
      end

      get cama_admin_appearances_themes_path, params: { set: 'camaleon_first' }

      expect(CamaleonCms::Site.find(@site.id).get_theme_slug).to eq('camaleon_first')
      expect(depths).to eq([depth])
    end

    # The trial in the switch reads the rows as the transaction of the switch sees them. Another
    # connection can commit a row after that read. So the draw after the commit of the switch runs a
    # trial again. Here the example stores a name after the first trial, with no callback.
    it 'draws the routes of the switch from a trial that runs after its commit' do
      allow(PluginRoutes).to receive(:trial_routes).and_wrap_original do |original|
        # rubocop:disable Rails/SkipsModelValidations
        original.call.tap { CamaleonCms::Site.where(id: @site.id).update_all(name: 'Stored after the trial') }
        # rubocop:enable Rails/SkipsModelValidations
      end
      expect(PluginRoutes).to receive(:trial_draw).twice.and_call_original

      get cama_admin_appearances_themes_path, params: { set: 'camaleon_first' }

      expect(CamaleonCms::Site.find(@site.id).get_theme_slug).to eq('camaleon_first')
      expect(PluginRoutes.get_sites.find { |site| site.id == @site.id }.name).to eq('Stored after the trial')
    end

    it 'redirects after installing a theme' do
      get cama_admin_appearances_themes_path, params: { set: 'default' }
      expect(response).to redirect_to(cama_admin_appearances_themes_path)
    end

    # The index action wrote the notice to flash.now, which the redirect drops.
    it 'shows the notice of the install on the page after the redirect' do
      get cama_admin_appearances_themes_path, params: { set: 'default' }
      follow_redirect!

      expect(response.body).to include('Theme updated')
    end

    # The theme switch is a GET request, and AdminController raises the error of a failed draw again
    # for a GET request. The list of the themes has no draw, so the redirect leads to a page that works.
    it 'redirects to the list with the error of the route file when the routes cannot be drawn' do
      break_the_routes("raise ArgumentError, '<b>broken</b>'")

      get cama_admin_appearances_themes_path, params: { set: 'camaleon_first' }

      expect(response).to redirect_to(cama_admin_appearances_themes_path)
      expect(flash[:error]).to eq(I18n.t('camaleon_cms.admin.message.route_draw_failed_change_not_saved',
                                         error: 'ArgumentError: &lt;b&gt;broken&lt;/b&gt;'))
      expect(flash[:notice]).to be_nil
      expect(CamaleonCms::Site.find(@site.id).get_theme_slug).to eq('default')
      follow_redirect!
      expect(response).to have_http_status(:success)
    end

    # The draw after the commit of the switch runs a trial again. Here the route file breaks after the
    # trial in the switch, as a change outside the switch can do.
    it 'keeps the new theme and the routes when the trial after the savepoint fails' do
      allow(PluginRoutes).to receive(:trial_routes).and_wrap_original do |original|
        original.call.tap { break_the_routes }
      end

      get cama_admin_appearances_themes_path, params: { set: 'camaleon_first' }

      expect(response).to redirect_to(cama_admin_appearances_themes_path)
      expect(flash[:error]).to eq(I18n.t('camaleon_cms.admin.message.route_draw_failed_routes_kept',
                                         error: 'ArgumentError: broken plugin routes'))
      expect(CamaleonCms::Site.find(@site.id).get_theme_slug).to eq('camaleon_first')
    end

    # A second switch waits for the switch that holds the lock of the route reload. After its wait time,
    # the helper raises an error before its first write.
    it 'redirects to the list with an error when another theme switch still holds the lock' do
      allow_any_instance_of(CamaleonCms::Admin::Appearances::ThemesController).to receive(:site_install_theme)
        .and_raise(CamaleonCms::RouteReloadLock::WaitTimeout, 'the lock is held')

      get cama_admin_appearances_themes_path, params: { set: 'camaleon_first' }

      expect(response).to redirect_to(cama_admin_appearances_themes_path)
      expect(flash[:error]).to eq(I18n.t('camaleon_cms.admin.themes.message.another_switch_runs'))
      expect(flash[:notice]).to be_nil
    end

    it 'logs the error of the route file when the routes cannot be drawn' do
      break_the_routes
      allow(Rails.logger).to receive(:error)
      expect(Rails.logger).to receive(:error).with(/the routes cannot be drawn.*ArgumentError: broken plugin routes/m)

      get cama_admin_appearances_themes_path, params: { set: 'default' }
    end

    # A save of the on_active hook of the theme can draw the routes. A draw that fails rolls the whole
    # switch back.
    it 'keeps the old theme when a save of the on_active hook fails the draw' do
      break_the_routes
      site = @site
      allow_any_instance_of(CamaleonCms::Admin::Appearances::ThemesController).to receive(:hook_run) do |*args|
        site.post_types.create!(name: 'Books', slug: 'books') if args[-2] == 'on_active'
      end

      get cama_admin_appearances_themes_path, params: { set: 'camaleon_first' }

      expect(response).to redirect_to(cama_admin_appearances_themes_path)
      expect(flash[:error]).to eq(I18n.t('camaleon_cms.admin.message.route_draw_failed_change_not_saved',
                                         error: 'ArgumentError: broken plugin routes'))
      expect(CamaleonCms::Site.find(@site.id).get_theme_slug).to eq('default')
      expect(@site.post_types.where(slug: 'books')).to be_empty
    end
  end
end
