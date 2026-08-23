# frozen_string_literal: true

RSpec.describe 'Admin custom fields form: users placement option', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:admin) { create(:user, role: 'admin', site: current_site) }

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:cama_authenticate)
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
    sign_in_as(admin, site: current_site)
  end

  # The users option's value is the placement every user field group is stored under. Emitting
  # the raw user_model config here is how namespaced-host installs ended up with groups the
  # demodulized save filter cannot see (audit N5).
  it 'emits the demodulized name for a namespaced host user model' do
    allow(PluginRoutes).to receive(:static_system_info).and_return(
      PluginRoutes.static_system_info.merge('user_model' => 'Admin::User')
    )

    get '/admin/settings/custom_fields/new'

    expect(response.body).to include("value=\"User,#{current_site.id}\"")
    expect(response.body).not_to include('Admin::User')
  end

  it 'emits User for the engine-default user model' do
    get '/admin/settings/custom_fields/new'

    expect(response.body).to include("value=\"User,#{current_site.id}\"")
  end
end
