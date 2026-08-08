# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::Admin::MenusHelper, type: :helper do
  include described_class

  before { CurrentRequest.reset }

  describe '#parse_datas (regression M22)' do
    it 'keeps a single-quoted value that contains double quotes' do
      datas = %(data-intro='<img style="max-width: 100%;" src="x.png" /> hi' data-position='right')
      result = helper.send(:parse_datas, datas)

      expect(result[:intro]).to eq('<img style="max-width: 100%;" src="x.png" /> hi')
      expect(result[:position]).to eq('right')
    end

    it 'keeps a double-quoted value that contains single quotes' do
      expect(helper.send(:parse_datas, %(data-note="it's here"))).to eq(note: "it's here")
    end
  end

  describe '#admin_menu_draw title sanitization (regression M22)' do
    before { allow(helper).to receive(:site_current_url).and_return('http://test.host/admin/dashboard') }

    it 'renders inline HTML in a plain-String menu title as markup, not escaped text' do
      # camaleon-ecommerce ships a title like "Orders <small class='label'>3</small>"
      admin_menu_add_menu('shop', { icon: 'cart', title: "Orders <small class='label'>3</small>", url: '#' })
      html = helper.admin_menu_draw

      expect(html).to include('<small')
      expect(html).to include('3')
      expect(html).not_to include('&lt;small')
    end

    it 'strips scripts and event handlers from a menu title' do
      admin_menu_add_menu('x', { icon: 'x', title: '<span onclick="e()">hi</span><script>evil()</script>', url: '#' })
      html = helper.admin_menu_draw

      expect(html).to include('hi')
      expect(html).not_to include('<script')
      expect(html).not_to include('onclick')
    end
  end

  describe 'admin menu store identity (regression M19)' do
    it 'lets a reference held before menu building (the @_admin_menus.delete idiom) still mutate the store' do
      admin_menu_add_menu('comments', { icon: 'c', title: 'Comments' })
      admin_menu_add_menu('media', { icon: 'm', title: 'Media' })
      aliased = CurrentRequest.admin_menu_items # what admin_init_actions aliases into @_admin_menus
      admin_menu_insert_menu_before('media', 'new', { icon: 'n', title: 'New' }) # identity-preserving op

      aliased.delete('comments')

      expect(CurrentRequest.admin_menu_items).not_to have_key('comments')
      expect(CurrentRequest.admin_menu_items).to equal(aliased)
    end

    it 'preserves store identity on insert_after' do
      admin_menu_add_menu('a', { icon: 'a', title: 'A' })
      store = CurrentRequest.admin_menu_items
      admin_menu_insert_menu_after('a', 'new', { icon: 'n', title: 'New' })

      expect(CurrentRequest.admin_menu_items).to equal(store)
    end
  end

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
