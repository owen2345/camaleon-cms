# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Sidebar menu expand', :js do
  init_site

  it 'renders expandable menu items with data-key attributes' do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/"

    # Check that sidebar menu items exist with data-key attribute
    within '.sidebar' do
      # Check that has-treeview items have data-key attribute directly on them
      treeview_items = find_all('.nav-item.has-treeview[data-key]')
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
      # Find has-treeview items that have nav-treeview children
      expandable_items = find_all('.nav-item.has-treeview[data-key]')
      expect(expandable_items.length).to be > 0

      # Use the first treeview item to check structure
      first_item = expandable_items.first

      # The 'a' tag should exist
      expect(first_item).to have_css('a')

      # Check that submenu exists using visible: false to include hidden elements
      expect(first_item).to have_css('ul.nav-treeview', visible: false)
    end
  end

  it 'has correct data-key attribute for menu items' do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/"

    within '.sidebar' do
      all('.nav-item.has-treeview[data-key]').each do |item|
        data_key = item['data-key'].to_s
        expect(data_key).not_to be_empty
      end
    end
  end
end
