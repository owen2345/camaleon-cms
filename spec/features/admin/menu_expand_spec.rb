# frozen_string_literal: true

RSpec.describe 'Sidebar menu expand', :js do
  init_site

  it 'renders expandable menu items with data-key attributes' do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/"

    # Check that sidebar menu items exist with data-key attribute
    within '.sidebar' do
      # Check that treeview items have data-key attribute directly on them
      treeview_items = find_all('.treeview[data-key]')
      expect(treeview_items.length).to be > 0

      # Check that all treeview items have non-empty data-key
      treeview_items.each do |item|
        data_key = item['data-key'].to_s
        expect(data_key).not_to be_empty
      end
    end
  end

  it 'has expandable menu items with submenus in DOM' do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/"

    within '.sidebar' do
      # Find treeview items that have treeview-menu children
      expandable_items = find_all('.treeview[data-key]')
      expect(expandable_items.length).to be > 0

      # Use the first treeview item to check structure
      first_item = expandable_items.first

      # The 'a' tag should exist
      expect(first_item).to have_css('a')

      # Check that submenu exists using visible: false to include hidden elements
      expect(first_item).to have_css('ul.treeview-menu', visible: :hidden)
    end
  end

  it 'has correct data-key attribute for menu items' do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/"

    within '.sidebar' do
      all('.treeview[data-key]').each do |item|
        data_key = item['data-key'].to_s
        expect(data_key).not_to be_empty
      end
    end
  end

  # Regression (PR #1169 review, APPJS-VENDOR/LTE-CSS-VENDOR): nested menu parents
  # (post types inside Contents) carried the dead class xn-openable instead of the
  # canonical AdminLTE treeview. The vendored app.js had to deviate (length guard) to
  # not break, nested submenus could not toggle, and the init-time marking of active
  # nested branches (Tree: .treeview.active -> menu-open) never fired.
  it 'expands nested submenus and pre-opens the active branch' do
    post_type_id = @site.post_types.where(slug: :post).pick(:id)
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/post_type/#{post_type_id}/posts"
    wait(2)

    within '.sidebar' do
      nested = all('.treeview-menu li.treeview')
      expect(nested.size).to be > 0
      expect(nested.map { |item| item[:class] }.join(' ')).not_to include('xn-openable')

      # the visited page's ancestor post-type item is marked menu-open on init
      active_nested = find('.treeview-menu li.treeview.active')
      expect(active_nested[:class]).to include('menu-open')

      # clicking its header (the first link, before its expanded submenu) collapses it
      active_nested.first('a').click
      wait(1)
      expect(active_nested[:class]).not_to include('menu-open')
    end
  end

  # Regression (PR #1169 review, TREE-ON-LOAD): AdminLTE 2.4 binds the sidebar tree only on
  # window.load, while expandable parents are pure toggles. If those anchors carry href="" a click
  # before the tree binds reloads the current page (discarding in-progress edits); they must be
  # href="#" (a no-op fragment), and the tree must be bound eagerly so the toggle works at once.
  it 'renders expandable parents as non-navigating toggles and binds the tree eagerly' do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/"

    raw_hrefs = page.evaluate_script(
      "Array.prototype.map.call(document.querySelectorAll('.sidebar .treeview[data-key] > a')," \
      " function(a){ return a.getAttribute('href'); })"
    )
    expect(raw_hrefs).not_to be_empty
    expect(raw_hrefs).to all(eq('#'))

    tree_bound = page.evaluate_script("!!(window.jQuery && jQuery('[data-widget=\"tree\"]').data('lte.tree'))")
    expect(tree_bound).to be(true)
  end
end
