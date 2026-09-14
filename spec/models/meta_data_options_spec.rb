# frozen_string_literal: true

# data_options and data_metas are written to a record's options and metas when it is saved, but they stayed
# assigned: every later save of the same instance wrote them again, over any value set since. A post type
# also skipped its data_metas when it was created and wrote them on its first update instead.
RSpec.describe CamaleonCms::Metas do
  # the shared site's installed post type: a post created for it skips a post type's creation and route reload
  let(:shared_post_type) { CamaleonCms::Site.first.post_types.find_by!(slug: 'post') }

  it 'keeps a later option write when a post type created with data_options is updated' do
    post_type = create(:post_type, data_options: { has_category: true })
    post_type.set_option(:has_category, false)

    post_type.update!(name: 'Products')

    expect(CamaleonCms::PostType.find(post_type.id).get_option(:has_category)).to be(false)
    expect(post_type.get_option(:has_category)).to be(false)
  end

  it 'stores the data_metas a post type is created with' do
    post_type = create(:post_type, data_metas: { icon_color: 'red' })

    expect(CamaleonCms::PostType.find(post_type.id).get_meta('icon_color')).to eq('red')
  end

  it 'merges the options given with a _default meta into it' do
    post_type = create(:post_type, data_options: { has_category: true },
                                   data_metas: { '_default' => { 'has_tags' => true } })

    expect(post_type.manage_categories?).to be(true)
    expect(post_type.categories.where(slug: 'uncategorized')).to exist
    expect(post_type.metas.where(key: '_default').count).to eq(1)
    stored = CamaleonCms::PostType.find(post_type.id)
    expect(stored.get_option(:has_tags)).to be(true)
    expect(stored.get_option(:has_category)).to be(true)
    expect(stored.get_option(:has_seo)).to be(true)

    post = create(:post, post_type: shared_post_type, data_options: { has_comments: true },
                         data_metas: { '_default' => { 'has_summary' => false } })

    expect(CamaleonCms::Post.find(post.id).options).to include('has_comments' => true, 'has_summary' => false)
  end

  it 'writes the queues of a created record without looking its metas up' do
    lookups = []
    subscription = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
      next unless payload[:sql].start_with?('SELECT') && payload[:sql].include?('"metas"')

      binds = payload[:type_casted_binds].to_a
      lookups << payload[:sql] if binds.include?('Post') && (binds & %w[_default subtitle icon]).any?
    end

    post = create(:post, post_type: shared_post_type, data_options: { has_comments: true },
                         data_metas: { subtitle: 'first', icon: 'star' })

    ActiveSupport::Notifications.unsubscribe(subscription)
    expect(lookups).to be_empty
    stored = CamaleonCms::Post.find(post.id)
    expect(stored.get_option(:has_comments)).to be(true)
    expect(stored.metas.where(key: %w[subtitle icon _default]).count).to eq(3)
  end

  it 'writes the data_metas of a post type into the meta built before its first save' do
    post_type = build(:post_type, data_metas: { icon_color: 'red' })
    post_type.set_meta('icon_color', 'blue')

    post_type.save!

    expect(post_type.metas.find { |m| m.key == 'icon_color' }.value).to eq('red')
    expect(post_type.metas.where(key: 'icon_color').pluck(:value)).to eq(['red'])
  end

  it 'keeps later writes when a post created with data_options and data_metas is updated' do
    post = create(:post, post_type: shared_post_type, data_options: { has_comments: true },
                         data_metas: { subtitle: 'first' })
    post.set_option(:has_comments, false)
    post.set_meta('subtitle', 'second')

    post.update!(title: 'Renamed')

    stored = CamaleonCms::Post.find(post.id)
    expect(stored.get_option(:has_comments)).to be(false)
    expect(stored.get_meta('subtitle')).to eq('second')
  end

  it 'refuses a data_options or data_metas container that is not a set of fields before the row is written' do
    post_type = build(:post_type, data_options: '{"has_category": true}')
    post = build(:post, post_type: shared_post_type, data_metas: [%w[subtitle x]])

    ActiveRecord::Base.transaction do
      expect { post_type.save }.to raise_error(CamaleonCms::Metas::InvalidContainer, /String/)
      expect { post.save }.to raise_error(CamaleonCms::Metas::InvalidContainer, /Array/)
    end

    expect(post_type).not_to be_persisted
    expect(post).not_to be_persisted
    expect(CamaleonCms::PostType.where(slug: post_type.slug)).not_to exist
    expect(CamaleonCms::Post.where(slug: post.slug)).not_to exist
  end

  it 'ignores a blank data_options container' do
    post_type = create(:post_type, data_options: [])

    expect(CamaleonCms::PostType.find(post_type.id).get_option(:has_seo)).to be(true)
  end

  describe 'a save rolled back after it wrote them' do
    it 'queues them again for the next save of the instance, with the metas set before it' do
      post_type = build(:post_type, data_options: { has_category: true }, data_metas: { icon_color: 'red' })
      post_type.set_meta('note', 'kept')
      allow(PluginRoutes).to receive(:reload).and_raise('routes failed') # a later after_create
      expect { post_type.save! }.to raise_error('routes failed')
      allow(PluginRoutes).to receive(:reload).and_call_original

      post_type.save!

      stored = CamaleonCms::PostType.find(post_type.id)
      expect(stored.get_option(:has_category)).to be(true)
      expect(stored.get_meta('icon_color')).to eq('red')
      expect(stored.get_meta('note')).to eq('kept')
      expect(stored.metas.group(:key).count).to eq('_default' => 1, 'icon_color' => 1, 'note' => 1)
    end

    it 'queues the values given to an update whose transaction is rolled back' do
      post = create(:post, post_type: shared_post_type)
      ActiveRecord::Base.transaction(requires_new: true) do
        post.update!(data_options: { has_comments: true }, data_metas: { subtitle: 'first' })
        raise ActiveRecord::Rollback
      end
      expect(CamaleonCms::Post.find(post.id).get_meta('subtitle')).to be_nil

      post.save!

      stored = CamaleonCms::Post.find(post.id)
      expect(stored.get_option(:has_comments)).to be(true)
      expect(stored.get_meta('subtitle')).to eq('first')
    end

    it 'leaves them written when a later save of the instance is rolled back' do
      post = create(:post, post_type: shared_post_type, data_options: { has_comments: true })
      post.set_option(:has_comments, false)
      ActiveRecord::Base.transaction(requires_new: true) do
        post.update!(title: 'Renamed')
        raise ActiveRecord::Rollback
      end

      post.update!(title: 'Renamed again')

      expect(CamaleonCms::Post.find(post.id).get_option(:has_comments)).to be(false)
    end
  end

  it 'writes data_options and data_metas given to an update once' do
    post = create(:post, post_type: shared_post_type)
    post.update!(data_options: { has_comments: true }, data_metas: { subtitle: 'first' })
    stored = CamaleonCms::Post.find(post.id)
    expect(stored.get_option(:has_comments)).to be(true)
    expect(stored.get_meta('subtitle')).to eq('first')
    post.set_option(:has_comments, false)
    post.set_meta('subtitle', 'second')

    post.update!(title: 'Renamed')

    stored = CamaleonCms::Post.find(post.id)
    expect(stored.get_option(:has_comments)).to be(false)
    expect(stored.get_meta('subtitle')).to eq('second')
    expect(post.get_option(:has_comments)).to be(false)
    expect(post.get_meta('subtitle')).to eq('second')
  end

  it 'writes data_options given to a post type update once' do
    post_type = create(:post_type)
    post_type.update!(data_options: { has_tags: true })
    expect(CamaleonCms::PostType.find(post_type.id).get_option(:has_tags)).to be(true)
    post_type.set_option(:has_tags, false)

    post_type.update!(name: 'Renamed')

    expect(CamaleonCms::PostType.find(post_type.id).get_option(:has_tags)).to be(false)
    expect(post_type.get_option(:has_tags)).to be(false)
  end
end
