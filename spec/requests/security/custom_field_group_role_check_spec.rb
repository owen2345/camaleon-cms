# frozen_string_literal: true

# The custom fields controller named three actions for its role check: create, update and destroy.
# That line replaced the role check of the settings controller, which covered each action. So a
# signed-in user with no custom_fields permission could change the order of the field groups, and
# could read each group in the list and in the form. Each action must check the role, except the
# list action, which checks the right of the user on its post.
RSpec.describe 'the role check of the custom field group pages', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:paths) { '/admin/settings/custom_fields' }
  let!(:first_group) do
    current_site.custom_field_groups.create!(name: 'First', slug: '_role-check-first', object_class: 'Site',
                                             objectid: current_site.id, field_order: 0)
  end
  let!(:second_group) do
    current_site.custom_field_groups.create!(name: 'Second', slug: '_role-check-second', object_class: 'Site',
                                             objectid: current_site.id, field_order: 1)
  end

  def group_order
    [first_group, second_group].map { |group| group.reload.field_order }
  end

  context 'with a role that has no custom_fields permission' do
    before { sign_in_as(create(:user, role: 'contributor', site: current_site), site: current_site) }

    it 'refuses a new order of the field groups' do
      post "#{paths}/reorder", params: { values: [second_group.id, first_group.id] }

      expect(response).to redirect_to('/admin/dashboard')
      expect(group_order).to eq([0, 1])
    end

    {
      'the list of the field groups' => ->(_group) { get paths },
      'the form of a new field group' => ->(_group) { get "#{paths}/new" },
      'the form of a field group' => ->(group) { get "#{paths}/#{group.id}/edit" },
      'the page of a field group' => ->(group) { get "#{paths}/#{group.id}" },
      'the settings of a field kind' => ->(_group) { post "#{paths}/get_items/text_box" }
    }.each do |page, request|
      it "refuses #{page}" do
        instance_exec(first_group, &request)

        expect(response).to redirect_to('/admin/dashboard')
      end
    end
  end

  context 'with a role that has the custom_fields permission' do
    before do
      role = current_site.user_roles.create!(name: 'Field manager', slug: 'field-manager')
      role.set_meta("_manager_#{current_site.id}", { 'custom_fields' => 1 })
      sign_in_as(create(:user, role: role.slug, site: current_site), site: current_site)
    end

    it 'stores a new order of the field groups' do
      post "#{paths}/reorder", params: { values: [second_group.id, first_group.id] }

      expect(response).to have_http_status(:ok)
      expect(group_order).to eq([1, 0])
    end

    it 'shows the form of a field group' do
      get "#{paths}/#{first_group.id}/edit"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('_role-check-first').or include('First')
    end
  end

  # The Settings menu gave its Custom Fields item to each role with the settings permission. The pages
  # of the item now need the custom_fields permission, so the item must need it too.
  describe 'the Custom Fields item of the Settings menu' do
    def sign_in_with(permissions)
      role = current_site.user_roles.create!(name: 'Site manager', slug: 'site-manager')
      role.set_meta("_manager_#{current_site.id}", permissions)
      sign_in_as(create(:user, role: role.slug, site: current_site), site: current_site)
    end

    def menu_link(path)
      %(<a href="#{path}">)
    end

    it 'does not show for a role with the settings permission and no custom_fields permission' do
      sign_in_with('settings' => 1)
      get cama_admin_dashboard_path

      expect(response.body).to include(menu_link(cama_admin_settings_post_types_path))
      expect(response.body).not_to include(menu_link(cama_admin_settings_custom_fields_path))
    end

    it 'shows for a role with the settings permission and the custom_fields permission' do
      sign_in_with('settings' => 1, 'custom_fields' => 1)
      get cama_admin_dashboard_path

      expect(response.body).to include(menu_link(cama_admin_settings_custom_fields_path))
    end
  end
end
