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
      params = ActionController::Parameters.new('has_category' => 'true', 'has_picture' => 'false',
                                                'default_layout' => 'x')
      post_type = create(:post_type, data_options: params)

      options = stored_options(post_type)
      expect(options).to include('has_category' => true, 'has_picture' => false, 'default_layout' => 'x')
      expect(options.keys).to match_array(described_class::DEFAULT_OPTIONS.keys.map(&:to_s))
    end
  end

  # set_settings wrote one option at a time, each an options write storing the whole options row again; a
  # post type's settings, and those add_post gives a post, are written at once.
  describe 'settings' do
    it 'stores the settings given to set_settings in one options write' do
      post_type = create(:post_type)
      expect(post_type).to receive(:set_meta).once.and_call_original

      post_type.set_settings(has_tags: true, has_summary: false, default_layout: 'probe')

      expect(described_class.find(post_type.id).options)
        .to include('has_tags' => true, 'has_summary' => false, 'default_layout' => 'probe')
    end

    it 'stores the settings add_post gives a post in one options write' do
      post = nil
      updates = sql_queries(matching: /\bUPDATE\s+["'`]?\w*metas\b/i) do
        post = installed_post_type.add_post(title: 'Settings probe', slug: 'settings-probe', content: 'body',
                                            settings: { has_content: false, default_template: 'probe' })
      end

      expect(updates).to be_empty
      expect(CamaleonCms::Post.find(post.id).options).to include('has_content' => false, 'default_template' => 'probe')
    end
  end
end
