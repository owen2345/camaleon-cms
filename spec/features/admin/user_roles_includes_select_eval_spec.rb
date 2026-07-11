require 'rails_helper'

describe 'User Roles UI includes select_eval permission', :js do
  init_site

  def open_new_role_form
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/user_roles"
    within '#admin_content' do
      click_link 'Add User Role'
    end
    expect(page).to have_css('#new_user_role')
  end

  # BS4 modal CSS transitions can stall in headless Chrome, preventing
  # modal("hide") from completing. This helper forces the modal DOM to hide
  # and removes BS4's internal data so modal("show") re-initializes cleanly.
  def force_close_modal
    page.execute_script(<<~JS)
      var m = document.getElementById('select-eval-danger-modal');
      if (m && window.jQuery) {
        var $m = $(m);
        $m.trigger('hidden.bs.modal');
        $m.removeData('bs.modal');
        m.classList.remove('show');
        m.style.display = 'none';
        document.querySelectorAll('.modal-backdrop').forEach(function(e){ e.remove(); });
        document.body.classList.remove('modal-open');
        document.body.style.paddingRight = '';
      }
    JS
  end

  it 'shows a select_eval checkbox in the manager permissions when creating a role' do
    open_new_role_form

    within '#new_user_role' do
      expect(page).to have_unchecked_field('Select Eval')
    end
  end

  it 'warns every time select_eval is enabled from unchecked state' do
    open_new_role_form

    within '#new_user_role' do
      check 'Select Eval'
    end
    expect(page).to have_css('#select-eval-danger-modal', visible: :visible)
    click_button 'Accept'
    force_close_modal
    expect(page).to have_no_css('#select-eval-danger-modal', visible: :visible)
    expect(page).to have_checked_field('Select Eval')

    within '#new_user_role' do
      uncheck 'Select Eval'
      check 'Select Eval'
    end
    expect(page).to have_css('#select-eval-danger-modal', visible: :visible)
    find('body').send_keys(:escape)
    force_close_modal
    expect(page).to have_no_css('#select-eval-danger-modal', visible: :visible)
    expect(page).to have_unchecked_field('Select Eval')
  end

  it 'shows warning once when Select All enables select_eval' do
    open_new_role_form

    within '#checked-actions' do
      click_link 'Select All'
    end

    expect(page).to have_css('#select-eval-danger-modal', visible: :visible)
    click_button 'Cancel'
    force_close_modal
    expect(page).to have_no_css('#select-eval-danger-modal', visible: :visible)
    expect(page).to have_unchecked_field('Select Eval')
  end

  it 'does not warn on load when select_eval is already checked, but warns after off-on toggle' do
    role = @site.user_roles.create!(name: 'Select Eval Role', slug: 'select-eval-role')
    role.set_meta("_manager_#{@site.id}", { select_eval: 1 })

    admin_sign_in
    visit "#{cama_root_relative_path}/admin/user_roles/#{role.id}/edit"

    expect(page).to have_checked_field('Select Eval')
    expect(page).to have_no_css('#select-eval-danger-modal', visible: :visible)

    uncheck 'Select Eval'
    check 'Select Eval'

    expect(page).to have_css('#select-eval-danger-modal', visible: :visible)
  end
end
