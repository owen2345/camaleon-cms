# frozen_string_literal: true

require 'rails_helper'

# A custom field group carries tenancy in `parent_id` (which site owns it) and placement in
# `object_class` + `objectid` (which record's admin page displays it). Placement reads are not
# scoped by site, so a group stamped with another site's placement ids renders on that site's admin
# pages -- while staying invisible in that site's own field-group list, which is tenancy-scoped.
#
# `assign_group` is split straight into the two placement columns with no ownership check, so a user
# who can manage custom fields on one site can inject a group into another site's admin panel.
RSpec.describe 'Cross-site custom field group injection', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:other_site) { CamaleonCms::Site.create!(name: 'Victim Site', slug: 'victim-site', taxonomy: 'site') }

  let(:attacker_role) { current_site.user_roles.create!(name: 'CF Manager', slug: 'cf_manager') }
  let(:attacker) { create(:user, role: attacker_role.slug, site: current_site) }

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:cama_authenticate)
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
    attacker_role.set_meta("_manager_#{current_site.id}", { 'custom_fields' => 1 })
    sign_in_as(attacker, site: current_site)
  end

  def inject(assign_group, name: 'Injected Group')
    post '/admin/settings/custom_fields', params: {
      custom_field_group: { name: name, assign_group: assign_group },
      fields: { '0' => { name: 'Injected Field', slug: 'injected-field' } },
      field_options: { '0' => { field_key: 'text_box' } }
    }
  end

  describe 'placements naming another site' do
    it "refuses a placement on the other site's theme" do
      victim_theme = other_site.get_theme

      expect { inject("Theme,#{victim_theme.id}") }
        .not_to(change(CamaleonCms::CustomFieldGroup, :count))

      expect(victim_theme.get_field_groups).to be_empty
    end

    it "refuses a placement on the other site's nav menu" do
      victim_menu = other_site.nav_menus.create!(name: 'Victim Menu', slug: 'victim-menu')

      expect { inject("NavMenu,#{victim_menu.id}") }
        .not_to(change(CamaleonCms::CustomFieldGroup, :count))

      expect(victim_menu.get_field_groups).to be_empty
    end

    it "refuses a placement on the other site's post type" do
      victim_post_type = other_site.post_types.create!(name: 'Victim PT', slug: 'victim-pt')

      expect { inject("PostType_Post,#{victim_post_type.id}") }
        .not_to(change(CamaleonCms::CustomFieldGroup, :count))

      expect(victim_post_type.get_field_groups('Post')).to be_empty
    end

    it "refuses a placement on the other site's plugin" do
      victim_plugin = other_site.get_plugin('victim_plugin')

      expect { inject("Plugin,#{victim_plugin.id}") }
        .not_to(change(CamaleonCms::CustomFieldGroup, :count))

      expect(victim_plugin.get_field_groups).to be_empty
    end

    # Site is the one class with a single legal target, so it is pinned rather than rejected -- the
    # coercion cannot misfile the group, and the behaviour predates this change (#1216).
    it 'pins a Site placement to the current site instead of refusing it' do
      inject("Site,#{other_site.id}", name: 'Pinned Group')

      group = current_site.custom_field_groups.find_by(name: 'Pinned Group')
      expect(group.objectid).to eq(current_site.id)
      expect(other_site.get_field_groups).to be_empty
    end

    it 'refuses to move an existing group onto another site' do
      victim_theme = other_site.get_theme
      group = current_site.custom_field_groups.create!(
        name: 'Own Group', slug: '_own-group', object_class: 'Site', objectid: current_site.id
      )

      patch "/admin/settings/custom_fields/#{group.id}", params: {
        id: group.id,
        custom_field_group: { name: 'Own Group', assign_group: "Theme,#{victim_theme.id}" }
      }

      expect(group.reload.object_class).to eql('Site')
      expect(group.objectid).to eq(current_site.id)
      expect(victim_theme.get_field_groups).to be_empty
    end
  end

  describe 'placements the current site owns' do
    it 'accepts a post type of the current site' do
      post_type = current_site.post_types.first

      inject("PostType_Post,#{post_type.id}", name: 'Own PT Group')

      group = current_site.custom_field_groups.find_by(name: 'Own PT Group')
      expect(post_type.get_field_groups('Post')).to include(group)
    end

    it 'accepts a theme of the current site' do
      theme = current_site.get_theme

      inject("Theme,#{theme.id}", name: 'Own Theme Group')

      group = current_site.custom_field_groups.find_by(name: 'Own Theme Group')
      expect(theme.get_field_groups).to include(group)
    end

    it 'accepts a nav menu of the current site' do
      menu = current_site.nav_menus.create!(name: 'Own Menu', slug: 'own-menu')

      inject("NavMenu,#{menu.id}", name: 'Own Menu Group')

      group = current_site.custom_field_groups.find_by(name: 'Own Menu Group')
      expect(menu.get_field_groups).to include(group)
    end

    it 'accepts the configured user model with the current site id' do
      user_class = PluginRoutes.static_system_info['user_model'].presence || 'User'

      inject("#{user_class},#{current_site.id}", name: 'Own User Group')

      group = current_site.custom_field_groups.find_by(name: 'Own User Group')
      expect(group).to be_present
      expect(group.object_class).to eql(user_class)
    end

    # Models contributed through the custom_field_custom_models hook are emitted by the form as
    # "<Class>,<current_site.id>". The default arm keys on the id, so it admits them without the
    # controller needing an allow-list every downstream plugin would have to extend.
    it 'accepts a hook-registered model with the current site id' do
      inject("MyPluginModel,#{current_site.id}", name: 'Hook Model Group')

      group = current_site.custom_field_groups.find_by(name: 'Hook Model Group')
      expect(group).to be_present
      expect(group.object_class).to eql('MyPluginModel')
    end

    it 'lets an administrator re-save a group whose stored placement is not in the select' do
      group = current_site.custom_field_groups.create!(
        name: 'Widget Group', slug: '_widget-group', object_class: 'Widget::Main', objectid: current_site.id
      )
      theme = current_site.get_theme

      patch "/admin/settings/custom_fields/#{group.id}", params: {
        id: group.id,
        custom_field_group: { name: 'Widget Group', assign_group: "Theme,#{theme.id}" }
      }

      expect(response).to have_http_status(:found)
      expect(group.reload.object_class).to eql('Theme')
      expect(group.objectid).to eq(theme.id)
    end
  end

  describe 'malformed placements' do
    it 'refuses an empty assign_group' do
      expect { inject('') }.not_to(change(CamaleonCms::CustomFieldGroup, :count))
    end

    it 'refuses an assign_group with no id component' do
      expect { inject('Theme') }.not_to(change(CamaleonCms::CustomFieldGroup, :count))
    end

    it 'refuses an assign_group naming an id that does not exist' do
      expect { inject('Theme,999999') }.not_to(change(CamaleonCms::CustomFieldGroup, :count))
    end

    it 'refuses an assign_group with a non-numeric id' do
      expect { inject('Theme,abc') }.not_to(change(CamaleonCms::CustomFieldGroup, :count))
    end
  end
end
