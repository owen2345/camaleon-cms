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

    it 'retrieves post_type from controller instance variable as fallback (backward compatibility)' do
      taxonomies = double(decorate: [category])
      allow(helper).to receive_messages(
        controller: double(instance_variable_get: post_type),
        link_to: '<a>link</a>',
        safe_join: '<a>link</a>',
        cama_admin_post_type_taxonomy_posts_path: '/path',
        content_tag: '<span>label</span>'
      )

      result = helper.post_type_list_taxonomy(taxonomies, 'primary')

      expect(result).not_to be_nil
    end

    it 'returns empty output if no post_type available from any source' do
      allow(helper).to receive(:controller).and_return(double(instance_variable_get: nil))

      expect(helper.post_type_list_taxonomy([])).to eq('')
    end
  end
end
