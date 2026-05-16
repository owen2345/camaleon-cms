# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::Admin::MenusHelper, type: :helper do
  include described_class

  before { CurrentRequest.reset }

  describe 'admin menu management with CurrentRequest' do
    it 'stores menu items in CurrentRequest instead of instance variables' do
      expect(CurrentRequest).to receive(:admin_menu_items=).and_call_original

      admin_menu_add_menu('test', { icon: 'test', title: 'Test' })

      expect(CurrentRequest.admin_menu_items).to include('test' => hash_including(icon: 'test', title: 'Test'))
    end

    it 'appends menu items using CurrentRequest' do
      admin_menu_add_menu('main', { icon: 'main', title: 'Main', items: [] })
      admin_menu_append_menu_item('main', { icon: 'sub', title: 'Sub' })

      expect(CurrentRequest.admin_menu_items['main'][:items].count).to eq(1)
      expect(CurrentRequest.admin_menu_items['main'][:items][0][:title]).to eq('Sub')
    end

    it 'prepends menu items using CurrentRequest' do
      admin_menu_add_menu('main', { icon: 'main', title: 'Main', items: [{ icon: 'sub', title: 'Sub' }] })
      admin_menu_prepend_menu_item('main', { icon: 'first', title: 'First' })

      expect(CurrentRequest.admin_menu_items['main'][:items][0][:title]).to eq('First')
      expect(CurrentRequest.admin_menu_items['main'][:items][1][:title]).to eq('Sub')
    end

    it 'inserts menu before target using CurrentRequest' do
      admin_menu_add_menu('a', { icon: 'a', title: 'A' })
      admin_menu_add_menu('b', { icon: 'b', title: 'B' })
      admin_menu_insert_menu_before('b', 'new', { icon: 'new', title: 'New' })
      keys = CurrentRequest.admin_menu_items.keys

      expect(keys).to eq(%w[a new b])
    end

    it 'inserts menu after target using CurrentRequest' do
      admin_menu_add_menu('a', { icon: 'a', title: 'A' })
      admin_menu_add_menu('b', { icon: 'b', title: 'B' })
      admin_menu_insert_menu_after('a', 'new', { icon: 'new', title: 'New' })
      keys = CurrentRequest.admin_menu_items.keys

      expect(keys).to eq(%w[a new b])
    end
  end
end
