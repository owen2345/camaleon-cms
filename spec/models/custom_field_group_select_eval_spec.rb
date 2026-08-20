# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::CustomFieldGroup, type: :model do
  init_site

  let(:site) { Cama::Site.first }
  let(:theme) { site.themes.first }

  it 'blocks creating select_eval via add_field when not authorized' do
    group = site.custom_field_groups.create!(name: 'G', slug: '_g', object_class: 'Theme', objectid: theme.id)

    expect do
      group.add_field(
        { name: 'X', slug: 'x' }, { field_key: 'select_eval', command: 'camaleon_first_list_select' }
      )
    end.to raise_error(CanCan::AccessDenied)
  end

  it 'allows creating select_eval when run as an authorized user' do
    role = site.user_roles.create!(name: 'CF Manager', slug: 'cf_manager2')
    # Grant both general custom_fields management and explicit select_eval permission
    role.set_meta("_manager_#{site.id}", { 'custom_fields' => 1, 'select_eval' => 1 })
    user = create(:user, role: role.slug, site: site)

    group = site.custom_field_groups.create!(name: 'G2', slug: '_g2', object_class: 'Theme', objectid: theme.id)
    set_current(user: user, site: site)
    field = group.add_field(
      { name: 'Recent items', slug: 'recent' }, { field_key: 'select_eval', command: 'camaleon_first_list_select' }
    )

    expect(field).to be_present
    expect(group.get_field('recent')).to be_present
  end

  it 'allows creating select_eval when role has explicit `select_eval` manager permission' do
    role = site.user_roles.create!(name: 'Select Eval Manager', slug: 'cf_select_eval')
    role.set_meta("_manager_#{site.id}", { select_eval: 1 })
    user = create(:user, role: role.slug, site: site)

    group = site.custom_field_groups.create!(name: 'G3', slug: '_g3', object_class: 'Theme', objectid: theme.id)
    set_current(user: user, site: site)
    field = group.add_field(
      { name: 'Explicit Recent', slug: 'explicit_recent' },
      { field_key: 'select_eval', command: 'camaleon_first_list_select' }
    )

    expect(field).to be_present
    expect(group.get_field('explicit_recent')).to be_present
  end

  it 'blocks updating an existing select_eval field when user lacks select_eval permission' do
    role = site.user_roles.create!(name: 'CF Manager Update', slug: 'cf_manager_update')
    # initially grant permission so user can create the select_eval field
    role.set_meta("_manager_#{site.id}", { 'custom_fields' => 1, 'select_eval' => 1 })
    user = create(:user, role: role.slug, site: site)

    group = site.custom_field_groups.create!(name: 'G4', slug: '_g4', object_class: 'Theme', objectid: theme.id)
    set_current(user: user, site: site)
    field = group
            .add_field({ name: 'Updatable',
                         slug: 'updatable' }, { field_key: 'select_eval', command: 'initial_command' })
    expect(field).to be_present

    # Remove explicit select_eval permission from the role (still has general custom_fields)
    role.set_meta("_manager_#{site.id}", { custom_fields: 1 })
    # Reset ability cache to reflect updated role meta
    group.reset_ability
    # ensure CurrentRequest reflects current user/site (ability will read role meta)
    set_current(user: user, site: site)

    items = { '0' => { 'id' => field.id, 'name' => 'Updatable', 'slug' => 'updatable' } }
    item_options = { '0' => { field_key: 'select_eval', command: 'malicious_command' } }

    errors_saved, _cache = group.add_fields(items, item_options)
    expect(errors_saved).not_to be_empty
    expect(errors_saved.first.errors.full_messages.join(' ')).to match(/Not authorized/i)
  end

  it 'raises error when no user context is present (background jobs/console)' do
    # Simulate background job or console usage where CurrentRequest is not set
    CurrentRequest.reset

    site = Cama::Site.first
    theme = site.themes.first
    group = site.custom_field_groups
                .create!(name: 'G_NoContext', slug: '_g_nocontext', object_class: 'Theme', objectid: theme.id)

    expect { group.add_field({ name: 'X', slug: 'x' }, { field_key: 'select_eval', command: 'dangerous' }) }
      .to raise_error(CanCan::AccessDenied)
  end

  it 'blocks direct field.set_options call for select_eval without permission' do
    role = site.user_roles.create!(name: 'CF Limited', slug: 'cf_limited')
    role.set_meta("_manager_#{site.id}", { custom_fields: 1 }) # No select_eval permission
    user = create(:user, role: role.slug, site: site)
    set_current(user: user, site: site)

    group = site.custom_field_groups.create!(name: 'G5', slug: '_g5', object_class: 'Theme', objectid: theme.id)
    # Create a safe field first
    field = group.add_field({ name: 'Safe', slug: 'safe' }, { field_key: 'text' })

    # Try to change it to select_eval via set_options
    field.set_options({ field_key: 'select_eval', command: 'malicious' })

    # Should not save due to authorization failure
    expect(field.save).to be false
    expect(field.errors[:base]).to include('Not authorized to create or modify select_eval fields')
  end

  it 'allows direct field.set_options call for select_eval with permission' do
    role = site.user_roles.create!(name: 'CF Admin', slug: 'cf_admin')
    role.set_meta("_manager_#{site.id}", { custom_fields: 1, select_eval: 1 })
    user = create(:user, role: role.slug, site: site)
    set_current(user: user, site: site)

    group = site.custom_field_groups.create!(name: 'G6', slug: '_g6', object_class: 'Theme', objectid: theme.id)
    field = group.add_field({ name: 'Changeable', slug: 'changeable' }, { field_key: 'text' })

    # Should be allowed to change to select_eval
    field.set_options({ field_key: 'select_eval', command: 'allowed_command' })

    expect(field.save).to be true
    expect(field.options[:field_key]).to eq('select_eval')
  end
end
