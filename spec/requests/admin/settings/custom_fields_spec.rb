# frozen_string_literal: true

RSpec.describe 'CustomFields create/update permissions', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }

  before do
    # bypass login redirect and ensure controller sees our current_site
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:cama_authenticate)
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
  end

  context 'when updating an existing group' do
    let!(:group) do
      current_site.custom_field_groups.create!(
        name: 'Existing Group', slug: '_existing-group', object_class: 'Site', objectid: current_site.id
      )
    end

    it 'allows updating custom fields to select_eval for roles with permissions' do
      role = current_site.user_roles.create!(name: 'CF Manager 2', slug: 'cf_manager_2')
      # grant both custom_fields manager and explicit select_eval permission
      role.set_meta("_manager_#{current_site.id}", { 'custom_fields' => 1, 'select_eval' => 1 })
      user = create(:user, role: role.slug, site: current_site)
      sign_in_as(user, site: current_site)

      patch "/admin/settings/custom_fields/#{group.id}", params: {
        id: group.id,
        custom_field_group: { name: 'Existing Group Updated', assign_group: "Site,#{current_site.id}" },
        fields: { '0' => { name: 'EvalUpdate', slug: 'eval_update' } },
        field_options: { '0' => { field_key: 'select_eval' } }
      }

      expect(response).to have_http_status(:found)
      expect(group.reload.fields.where(slug: 'eval_update')).to be_present
    end

    it 'blocks updating custom fields for roles without permission and sets flash error' do
      role = current_site.user_roles.create!(name: 'Limited 2', slug: 'limited_2')
      role.set_meta("_manager_#{current_site.id}", {})
      user = create(:user, role: role.slug, site: current_site)
      sign_in_as(user, site: current_site)

      patch "/admin/settings/custom_fields/#{group.id}", params: {
        id: group.id,
        custom_field_group: { name: 'Existing Group Updated 2', assign_group: "Site,#{current_site.id}" },
        fields: { '0' => { name: 'EvalBlocked', slug: 'eval_blocked' } },
        field_options: { '0' => { field_key: 'select_eval' } }
      }

      expect(response).to have_http_status(:found)
      expect(group.reload.fields.where(slug: 'eval_blocked')).to be_empty
      expected_custom = I18n.t(
        'camaleon_cms.admin.custom_field.message.select_eval_admin_only',
        default: 'The "Select Eval" field type is restricted to administrators.'
      )
      expect(flash[:error]).to satisfy do |msg|
        msg = msg.to_s
        msg.include?(expected_custom) || msg.include?('You are not authorized')
      end
    end
  end

  context 'when user has the custom_fields and select_eval permission' do
    it 'allows creating a custom field group, including select_eval fields' do
      role = current_site.user_roles.create!(name: 'CF Manager', slug: 'cf_manager')
      # grant both custom_fields manager and explicit select_eval permission
      role.set_meta("_manager_#{current_site.id}", { 'custom_fields' => 1, 'select_eval' => 1 })

      user = create(:user, role: role.slug, site: current_site)
      sign_in_as(user, site: current_site)

      expect do
        post '/admin/settings/custom_fields', params: {
          custom_field_group: { name: 'Allowed Group', assign_group: "Site,#{current_site.id}" },
          # field attributes go into fields; field_key (type) is provided in field_options
          fields: { '0' => { name: 'Eval', slug: 'eval' } },
          field_options: { '0' => { field_key: 'select_eval' } }
        }
      end.to change { current_site.custom_field_groups.count }.by(1)
    end
  end

  context 'when user does NOT have the custom_fields manager permission' do
    it 'does not allow creating a custom field group containing select_eval' do
      role = current_site.user_roles.create!(name: 'Limited', slug: 'limited')
      role.set_meta("_manager_#{current_site.id}", {})

      user = create(:user, role: role.slug, site: current_site)
      sign_in_as(user, site: current_site)

      expect do
        post '/admin/settings/custom_fields', params: {
          custom_field_group: { name: 'Blocked Group', assign_group: "Site,#{current_site.id}" },
          fields: { '0' => { name: 'Eval', slug: 'eval' } },
          field_options: { '0' => { field_key: 'select_eval' } }
        }
      end.not_to(change { current_site.custom_field_groups.count })

      # should redirect (either by authorization or permission check)
      expect(response).to have_http_status(:found)

      # and set an error message about select_eval restriction (either the custom message or the standard CanCan denial)
      expected_custom = I18n.t(
        'camaleon_cms.admin.custom_field.message.select_eval_admin_only',
        default: 'The "Select Eval" field type is restricted to administrators.'
      )
      expect(flash[:error]).to satisfy do |msg|
        msg = msg.to_s
        msg.include?(expected_custom) || msg.include?('You are not authorized')
      end
    end
  end

  describe 'Site placement' do
    # Site#get_field_groups matches object_class and objectid, so a Site group carrying another
    # site's id would be stranded: unreachable from both sites' settings pages. The form only ever
    # offers "Site,<current_site.id>", so the id is pinned rather than trusted.
    it 'pins objectid to the current site when the placement class is Site' do
      user = create(:user, role: 'admin', site: current_site)
      sign_in_as(user, site: current_site)
      other_site = create(:site, slug: 'other-placement-site', name: 'Other Placement Site')

      post '/admin/settings/custom_fields', params: {
        custom_field_group: { name: 'Pinned Group', assign_group: "Site,#{other_site.id}" },
        fields: { '0' => { name: 'Pinned Field', slug: 'pinned-field' } },
        field_options: { '0' => { field_key: 'text_box' } }
      }

      group = current_site.custom_field_groups.find_by(name: 'Pinned Group')
      expect(group.objectid).to eq(current_site.id)
      expect(current_site.get_field_groups).to include(group)
      expect(other_site.get_field_groups).not_to include(group)
    end
  end

  describe '/admin/settings/custom_fields/list' do
    let(:post_type) { current_site.post_types.create!(name: 'Test PT', slug: 'test-pt') }
    let(:my_post) { post_type.posts.create!(title: 'Test Post', slug: 'test-post') }
    let(:category) { post_type.categories.create!(name: 'Test Cat', slug: 'test-cat') }

    it 'renders the list of custom fields successfully' do
      user = create(:user, role: 'admin', site: current_site)
      sign_in_as(user, site: current_site)

      get '/admin/settings/custom_fields/list', params: { post_type: post_type.id, post_id: my_post.id }
      expect(response).to have_http_status(:ok)
    end

    it 'respects categories parameter for field groups and updates post categories' do
      user = create(:user, role: 'admin', site: current_site)
      sign_in_as(user, site: current_site)

      group = current_site.custom_field_groups.create!(
        name: 'Cat Group', slug: 'cat-group', object_class: 'Category_Post', objectid: category.id
      )
      group.add_field({ name: 'Cat Field', slug: 'cat-field' }, { field_key: 'text' })
      expect(group.fields.count).to eq(1)

      my_post.update_categories([])
      # The category write is state-changing, so it is exercised through POST (a GET renders only).
      post '/admin/settings/custom_fields/list',
           params: { post_type: post_type.id, post_id: my_post.id, categories: [category.id] }

      expect(response.body).to include('Cat Group')
      expect(my_post.categories.reload).to include(category)
    end

    it 'does not union the request categories into an existing post GET render' do
      user = create(:user, role: 'admin', site: current_site)
      sign_in_as(user, site: current_site)

      cat_b = post_type.categories.create!(name: 'Cat B', slug: 'test-cat-b')
      group_a = current_site.custom_field_groups.create!(
        name: 'Group A', slug: 'cf-group-a', object_class: 'Category_Post', objectid: category.id
      )
      group_a.add_field({ name: 'A Field', slug: 'a-field' }, { field_key: 'text' })
      group_b = current_site.custom_field_groups.create!(
        name: 'Group B', slug: 'cf-group-b', object_class: 'Category_Post', objectid: cat_b.id
      )
      group_b.add_field({ name: 'B Field', slug: 'b-field' }, { field_key: 'text' })
      my_post.update_categories([category.id]) # the post is assigned to Cat A only

      # a read-only GET requesting Cat B must render only the post's own (Cat A) field groups
      get '/admin/settings/custom_fields/list',
          params: { post_type: post_type.id, post_id: my_post.id, categories: [cat_b.id] }

      expect(response.body).to include('Group A')
      expect(response.body).not_to include('Group B')
      expect(my_post.categories.reload.pluck(:id)).to contain_exactly(category.id)
    end

    it 'ignores categories parameter from another site' do
      user = create(:user, role: 'admin', site: current_site)
      sign_in_as(user, site: current_site)

      other_site = create(:site, slug: 'other-site', name: 'Other Site')
      other_post_type = other_site.post_types.create!(name: 'Other PT', slug: 'other-pt')
      other_category = other_post_type.categories.create!(name: 'Other Cat', slug: 'other-cat')
      other_group = other_site.custom_field_groups.create!(
        name: 'Other Group', slug: 'other-group', object_class: 'Category_Post', objectid: other_category.id
      )
      other_group.add_field({ name: 'Other Field', slug: 'other-field' }, { field_key: 'text' })

      my_post.update_categories([])
      post '/admin/settings/custom_fields/list',
           params: { post_type: post_type.id, post_id: my_post.id, categories: [other_category.id] }

      expect(response.body).not_to include('Other Group')
      expect(my_post.categories.reload).to be_empty
    end

    # #list carries no before_action, so it is reachable by any signed-in user; the action authorizes
    # against the resolved record itself (audit finding M6).
    context 'when authorizing the caller against the record' do
      let(:limited_user) do
        role = current_site.user_roles.create!(name: 'No Posts', slug: 'no_posts')
        role.set_meta("_manager_#{current_site.id}", {})
        create(:user, role: role.slug, site: current_site)
      end

      it 'denies the POST category write for a user who cannot update the post, leaving categories intact' do
        my_post.update_categories([category.id])
        sign_in_as(limited_user, site: current_site)

        post '/admin/settings/custom_fields/list',
             params: { post_type: post_type.id, post_id: my_post.id, categories: [] }

        expect(response).to redirect_to(cama_admin_dashboard_path)
        expect(my_post.categories.reload.pluck(:id)).to eq([category.id])
      end

      it 'denies the GET render of a post the user cannot update' do
        sign_in_as(limited_user, site: current_site)

        get '/admin/settings/custom_fields/list', params: { post_type: post_type.id, post_id: my_post.id }

        expect(response).to redirect_to(cama_admin_dashboard_path)
      end

      it 'denies the new-post render for a user who cannot create posts of that type' do
        sign_in_as(limited_user, site: current_site)

        get '/admin/settings/custom_fields/list', params: { post_type: post_type.id }

        expect(response).to redirect_to(cama_admin_dashboard_path)
      end

      it 'still renders the new-post field groups for an authorized user' do
        user = create(:user, role: 'admin', site: current_site)
        sign_in_as(user, site: current_site)

        get '/admin/settings/custom_fields/list', params: { post_type: post_type.id }

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
