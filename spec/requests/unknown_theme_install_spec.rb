# frozen_string_literal: true

# An install of a theme that PluginRoutes does not know stored the slug as the theme of the site and
# made each theme record inactive. Then it raised NoMethodError, and the site had a theme with no
# config. The installer saved the site before that error, so the operator did not see the admin
# password.
RSpec.describe 'An install of a theme that is not installed', type: :request do
  let(:missing_theme) { 'missing_theme' }

  describe 'the theme page of the admin panel' do
    init_site

    let(:admin_user) do
      create(
        :user, username: 'admin', password: 'admin123', password_confirmation: 'admin123', role: 'admin', site: @site
      )
    end
    let(:theme_state) do
      site = CamaleonCms::Site.find(@site.id)
      [site.get_theme_slug, site.themes.order(:id).pluck(:slug, :status)]
    end

    before { sign_in_as(admin_user, site: @site) }

    it 'refuses the theme and keeps the theme of the site as it was' do
      state_before = theme_state
      get cama_admin_appearances_themes_path, params: { set: missing_theme }

      expect(response).to redirect_to(cama_admin_appearances_themes_path)
      expect(flash[:error]).to eq('The theme is not installed.')
      expect(theme_state).to eq(state_before)
    end
  end

  describe 'the installer' do
    # The installer is open only while no site exists.
    before { [CamaleonCms::Site, CamaleonCms::User].each(&:delete_all) }

    it 'refuses the theme before it creates the site' do
      expect do
        post save_cama_admin_installers_path,
             params: { site: { name: 'First site', slug: 'first-site' }, theme: missing_theme }
      end.not_to change(CamaleonCms::Site, :count).from(0)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('The selected theme is not installed.')
    end
  end

  describe 'the install helpers' do
    init_site

    subject(:helper_object) do
      Class.new do
        include CamaleonCms::PluginsHelper
        include CamaleonCms::HooksHelper
      end.new
    end

    let(:new_site) { CamaleonCms::Site.create!(name: 'Second site', slug: 'second-site') }

    before do
      CurrentRequest.reset
      CurrentRequest.site = @site.decorate
    end

    after { CurrentRequest.reset }

    it 'gives site_install_theme an ArgumentError before its first write' do
      expect { helper_object.site_install_theme(missing_theme) }
        .to raise_error(ArgumentError, /missing_theme/)
      expect(CamaleonCms::Site.find(@site.id).get_theme_slug).to eq('default')
    end

    it 'gives site_after_install an ArgumentError before its first write' do
      expect { helper_object.site_after_install(new_site, missing_theme) }
        .to raise_error(ArgumentError, /missing_theme/)
      expect(CamaleonCms::Site.find(new_site.id).options[:_theme]).to be_nil
      expect(new_site.themes).to be_empty
    end
  end
end
