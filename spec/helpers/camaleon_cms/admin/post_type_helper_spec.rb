# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::Admin::PostTypeHelper, type: :helper do
  include described_class

  describe 'hierarchy post list building with local accumulator' do
    it 'builds hierarchical post list from flat array using local accumulator' do
      post1 = instance_double(CamaleonCms::Post, post_parent: nil, id: 1)
      post2 = instance_double(CamaleonCms::Post, post_parent: 1, id: 2)
      post3 = instance_double(CamaleonCms::Post, post_parent: 2, id: 3)
      posts = [post1, post2, post3]

      result = cama_hierarchy_post_list(posts)

      expect(result.map(&:id)).to eq([1, 2, 3])
    end

    it 'handles posts without parents using local accumulator' do
      post1 = instance_double(CamaleonCms::Post, post_parent: nil, id: 1)
      post2 = instance_double(CamaleonCms::Post, post_parent: nil, id: 2, show_title_with_parent: nil)

      allow(post2).to receive(:show_title_with_parent=)

      posts = [post1, post2]
      result = cama_hierarchy_post_list(posts)

      expect(result.map(&:id)).to eq([1, 2])
    end

    it 'accepts explicit no_parent_accumulator parameter' do
      post1 = instance_double(CamaleonCms::Post, post_parent: nil, id: 1)
      post2 = instance_double(CamaleonCms::Post, post_parent: 1, id: 2)
      posts = [post1, post2]

      accumulator = []
      result = cama_hierarchy_post_list(posts, nil, false, accumulator)

      expect(result).to be_an(Array)
    end
  end

  describe 'post_type_list_taxonomy backward compatibility' do
    let(:post_type) { instance_double(CamaleonCms::PostType, id: 1) }
    let(:category) { double(id: 1, the_title: 'Test Category', taxonomy: 'category') }

    it 'accepts post_type parameter explicitly' do
      taxonomies = double(decorate: [category])
      allow(helper).to receive_messages(
        link_to: '<a>link</a>',
        safe_join: '<a>link</a>',
        cama_admin_post_type_taxonomy_posts_path: '/path',
        content_tag: '<span>label</span>'
      )

      result = helper.post_type_list_taxonomy(taxonomies, 'primary', post_type)

      expect(result).not_to be_nil
    end

    it 'falls back to the controller @post_type for the legacy 2-arg call (regression M23)' do
      # #1178 kept this fallback; #1183 (Phase 6C) removed it, so overridden admin posts-index views
      # calling the 2-arg form rendered nothing. camaleon-ecommerce is a live 2-arg caller.
      taxonomies = double(decorate: [category])
      controller.instance_variable_set(:@post_type, post_type)
      allow(helper).to receive(:cama_admin_post_type_taxonomy_posts_path).and_return('/path')

      result = helper.post_type_list_taxonomy(taxonomies, 'primary')

      expect(result).to include('Test Category')
    end

    it 'returns empty output if no post_type available from any source' do
      expect(helper.post_type_list_taxonomy([])).to eq('')
    end
  end

  describe 'empty-taxonomy message (regression L15)' do
    # The empty branch computed the translated taxonomy label and then discarded it, interpolating
    # the raw 'post_tags' slug instead. Drive the private builder with an empty relation so the
    # result does not depend on fixture state.
    it 'interpolates the translated taxonomy label, not the raw slug' do
      html = helper.send(:post_type_taxonomy_html_, CamaleonCms::PostTag.none, 'post_tags')

      expect(html).to include('Tags')
      expect(html).not_to include('post_tags')
    end
  end
end
