# frozen_string_literal: true

RSpec.describe 'Admin::InstallersController', type: :request do
  # The installer is open only while no site exists.
  before { [CamaleonCms::Site, CamaleonCms::User].each(&:delete_all) }

  # The theme select had no selected value. So a form that showed again selected the first theme, and
  # the next submit installed that theme.
  it 'keeps the theme that the operator selected when it shows the form again' do
    theme = PluginRoutes.all_themes.last['key']
    # A site with no name and no slug fails its validation.
    post save_cama_admin_installers_path, params: { site: { name: '', slug: '' }, theme: theme }

    expect(response).to have_http_status(:ok)
    selected = Nokogiri::HTML(response.body).at_css('select[name="theme"] option[selected]')
    expect(selected&.[]('value')).to eq(theme)
  end
end
