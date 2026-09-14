# frozen_string_literal: true

require 'shared_specs/sanitize_attrs'

RSpec.describe CamaleonCms::PostType, type: :model do
  init_site

  it_behaves_like 'sanitize attrs', model: described_class, attrs_to_sanitize: %i[description]

  describe 'the options a post type is created with' do
    def stored_options(post_type)
      JSON.parse(post_type.metas.find_by!(key: '_default').value)
    end

    it 'fills the defaults under the options given to the creation' do
      post_type = create(:post_type, data_options: { has_category: true })

      options = stored_options(post_type)
      expect(options).to include('has_category' => true, 'has_seo' => true, 'default_layout' => '')
      expect(options.keys).to match_array(described_class::DEFAULT_OPTIONS.keys.map(&:to_s))
    end

    it 'keeps an option set on the record before its first save' do
      post_type = build(:post_type, data_options: { has_category: true })
      post_type.set_option('has_picture', false)

      post_type.save!

      expect(stored_options(post_type)).to include('has_picture' => false, 'has_category' => true)
      expect(post_type.metas.where(key: '_default').count).to eq(1)
      expect(described_class.find(post_type.id).get_option(:has_picture)).to be(false)
    end

    it 'stores request parameters once, over their defaults' do
      params = ActionController::Parameters.new('has_category' => 'true', 'has_picture' => 'false', 'default_layout' => 'x')
      post_type = create(:post_type, data_options: params)

      options = stored_options(post_type)
      expect(options).to include('has_category' => true, 'has_picture' => false, 'default_layout' => 'x')
      expect(options.keys).to match_array(described_class::DEFAULT_OPTIONS.keys.map(&:to_s))
    end
  end
end
