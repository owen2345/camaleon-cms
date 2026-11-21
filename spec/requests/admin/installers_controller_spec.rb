# frozen_string_literal: true

RSpec.describe 'Admin::InstallersController', type: :request do
  # The installer is open only while no site exists.
  before { [CamaleonCms::Site, CamaleonCms::User].each(&:delete_all) }

  # The form fills the domain field only when the field is empty. A form that shows again keeps the
  # domain that the operator typed.
  it 'shows the domain of the request in the domain field of a new form' do
    host! 'shop.example.org'
    get cama_admin_installers_path

    expect(response).to have_http_status(:ok)
    slug_field = Nokogiri::HTML(response.body).at_css('input[name="site[slug]"]')
    expect(slug_field&.[]('value')).to eq('shop.example.org')
  end

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
