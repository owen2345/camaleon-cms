# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::Admin::MenusHelper, type: :helper do
  include CamaleonCms::Admin::MenusHelper

  before do
    CurrentRequest.reset
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

RSpec.describe CamaleonCms::Admin::PostTypeHelper, type: :helper do
  include CamaleonCms::Admin::PostTypeHelper

  describe 'hierarchy post list building with local accumulator' do
    it 'builds hierarchical post list from flat array using local accumulator' do
      post1 = instance_double('Post', post_parent: nil, id: 1)
      post2 = instance_double('Post', post_parent: 1, id: 2)
      post3 = instance_double('Post', post_parent: 2, id: 3)
      posts = [post1, post2, post3]

      result = cama_hierarchy_post_list(posts)

      expect(result.map(&:id)).to eq([1, 2, 3])
    end

    it 'handles posts without parents using local accumulator' do
      post1 = instance_double('Post', post_parent: nil, id: 1)
      post2 = instance_double('Post', post_parent: nil, id: 2, show_title_with_parent: nil)

      allow(post2).to receive(:show_title_with_parent=)

      posts = [post1, post2]
      result = cama_hierarchy_post_list(posts)

      expect(result.map(&:id)).to eq([1, 2])
    end

    it 'accepts explicit no_parent_accumulator parameter' do
      post1 = instance_double('Post', post_parent: nil, id: 1)
      post2 = instance_double('Post', post_parent: 1, id: 2)
      posts = [post1, post2]

      accumulator = []
      result = cama_hierarchy_post_list(posts, nil, false, accumulator)

      expect(result).to be_an(Array)
    end
  end

  describe 'post_type_list_taxonomy with explicit parameter' do
    let(:post_type) { instance_double('PostType', id: 1) }

    it 'requires post_type parameter instead of using instance variable' do
      expect { helper.post_type_list_taxonomy([]) }.to raise_error(ArgumentError, /required/)
    end
  end
end

RSpec.describe CamaleonCms::Admin::CustomFieldsHelper, type: :helper do
  include CamaleonCms::Admin::CustomFieldsHelper

  before do
    CurrentRequest.reset
    allow(helper).to receive(:hooks_run)
  end

  describe 'custom field model registry with CurrentRequest' do
    it 'adds models to CurrentRequest.extra_models_for_fields' do
      CurrentRequest.extra_models_for_fields = []
      cf_add_model('Product')
      expect(CurrentRequest.extra_models_for_fields).to include('Product')
    end

    it 'initializes extra_models_for_fields in CurrentRequest if not present' do
      CurrentRequest.extra_models_for_fields = nil
      cf_add_model('Product')
      expect(CurrentRequest.extra_models_for_fields).not_to be_nil
      expect(CurrentRequest.extra_models_for_fields).to include('Product')
    end

    it 'persists registry across multiple adds' do
      CurrentRequest.extra_models_for_fields = []
      cf_add_model('Product')
      cf_add_model('Service')
      expect(CurrentRequest.extra_models_for_fields).to include('Product', 'Service')
    end
  end
end

