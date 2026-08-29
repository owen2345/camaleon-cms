# frozen_string_literal: true

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
      # the available-fields box keeps its compact Bootstrap sizing class
      expect(page).to have_css('#content-items-default.form-group.input-group-sm')
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
      expect(page).to have_text('Untitled Text Box')
    end
    expect(page).to have_css('.alert-success')
    expect(page).to have_text('Test updated')
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

  it 'reports the reorder outcome of the drag that finished, not of the latest drag' do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/settings/custom_fields"

    # Direct-drive the reorder table's Sortable handlers with a stubbed $.post so a
    # second drag can begin before the first reorder request resolves. Each drag's
    # toast must be decided by that drag's own start/end positions.
    result = page.evaluate_script(<<~JS)
      (function() {
        var out = { alerts: [] };
        var tbody = document.querySelector('#table_custom_groups tbody');
        var instance = window.Sortable.get(tbody);
        $.fn.alert = function(o) { out.alerts.push(o.type || 'success'); };
        var pending = [];
        $.post = function(url, data, done) { pending.push(done); return { fail: function() { return this; } }; };

        if (instance.options.onStart) instance.options.onStart.call(instance, { oldIndex: 0, item: tbody.children[0] });
        instance.options.onEnd.call(instance, { oldIndex: 0, newIndex: 2, item: tbody.children[0] });
        // a second drag begins before the first response arrives, dropping back where it started
        if (instance.options.onStart) instance.options.onStart.call(instance, { oldIndex: 2, item: tbody.children[1] });
        pending[0]({});
        out.toastsAfterFirst = out.alerts.length;
        instance.options.onEnd.call(instance, { oldIndex: 2, newIndex: 2, item: tbody.children[1] });
        pending[1]({});
        out.toastsTotal = out.alerts.length;
        return out;
      })()
    JS

    # the completed move (0 -> 2) gets its success toast even though another drag
    # started meanwhile; the no-op drop (2 -> 2) stays silent
    expect(result['toastsAfterFirst']).to eq(1)
    expect(result['toastsTotal']).to eq(1)
    expect(result['alerts']).to eq(['success'])
  end
end
