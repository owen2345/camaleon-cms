# frozen_string_literal: true

require 'rails_helper'

describe 'the Custom Fields', :js do
  init_site

  it 'Custom fields list' do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/settings/custom_fields"
    # click the Add Field Group link (don't scope to a specific container to be resilient)
    click_link 'Add Field Group'

    # new custom field
    within '#cama_custom_field_form' do
      fill_in 'custom_field_group_name', with: 'Test name'
      fill_in 'custom_field_group_description', with: 'Test name description'
      post_type_id = @site.post_types.where(slug: :post).pick(:id)
      script_string = "$(\"#select_assign_group\").val(\"PostType_Post,#{post_type_id}\")"
      page.execute_script(script_string)

      wait 2
      all('#content-items-default a').each(&:click)
      wait_for_ajax
      first('button[type="submit"]').click
    end
    expect(page).to have_css('.alert-success')

    # update
    within '#edit_custom_field_group' do
      fill_in 'custom_field_group_name', with: 'Test updated'
      first('button[type="submit"]').click
    end
    within '#sortable-fields' do
      expect(page).to have_content('Untitled Text Box')
    end
    expect(page).to have_css('.alert-success')
    expect(page).to have_content('Test updated')
  end

  it 'delete custom field' do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/settings/custom_fields"
    within '#admin_content' do
      all('table .btn-danger').last.click
    end
    confirm_dialog
    expect(page).to have_css('.alert-success')
  end

  it 'prevents non-permitted users from managing Custom Fields' do
    # create a limited role and a user with that role
    role = @site.user_roles.create!(name: 'Limited', slug: 'limited_role')
    role.set_meta("_manager_#{@site.id}", {})
    user = create(:user, role: role.slug, site: @site)

    # sign in as that user
    admin_sign_in(user.username, '12345678')

    visit "#{cama_root_relative_path}/admin/settings/custom_fields"
    if page.has_link?('Add Field Group')
      click_link 'Add Field Group'

      within '#cama_custom_field_form' do
        fill_in 'custom_field_group_name', with: 'Blocked Group'
        fill_in 'custom_field_group_description', with: 'Blocked description'
        post_type_id = @site.post_types.where(slug: :post).pick(:id)
        script_string = "$(\"#select_assign_group\").val(\"PostType_Post,#{post_type_id}\")"
        page.execute_script(script_string)

        wait 2
        all('#content-items-default a').each(&:click)
        wait_for_ajax
        first('button[type="submit"]').click
      end

      # should not succeed
      expect(page).to have_no_css('.alert-success')
      expect(page).to satisfy do |_|
        page.has_css?('.alert-danger') || page.has_content?('You are not authorized')
      end
    else
      # the UI may hide the 'Add Field Group' action for non-permitted roles
      expect(page).to have_no_link('Add Field Group')
    end
  end

  it 'allows users with the Custom Fields manager permission to manage Custom Fields' do
    role = @site.user_roles.create!(name: 'CF Manager', slug: 'cf_manager')
    role.set_meta("_manager_#{@site.id}", { 'custom_fields' => 1 })
    user = create(:user, role: role.slug, site: @site)

    admin_sign_in(user.username, '12345678')
    visit "#{cama_root_relative_path}/admin/settings/custom_fields"
    click_link 'Add Field Group'

    within '#cama_custom_field_form' do
      fill_in 'custom_field_group_name', with: 'Allowed Group'
      fill_in 'custom_field_group_description', with: 'Allowed description'
      post_type_id = @site.post_types.where(slug: :post).pick(:id)
      script_string = "$(\"#select_assign_group\").val(\"PostType_Post,#{post_type_id}\")"
      page.execute_script(script_string)

      wait 2
      all('#content-items-default a').each(&:click)
      wait_for_ajax
      first('button[type="submit"]').click
    end

    expect(page).to have_css('.alert-success')
    # also assert the group was persisted in the database (avoids flaky UI assertions)
    group = @site.custom_field_groups.find_by(name: 'Allowed Group')
    expect(group).to be_present
  end
end
