# frozen_string_literal: true

# data_options and data_metas are written to a record's options and metas when it is saved, but they stayed
# assigned: every later save of the same instance wrote them again, over any value set since. A post type
# also skipped its data_metas when it was created and wrote them on its first update instead.
RSpec.describe CamaleonCms::Metas do
  let(:shared_post_type) { installed_post_type }

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

  # With no data_options, the `_default` meta is the plain Hash set_metas passed to set_meta when the
  # defaults are filled in, which must find its String-keyed options by their Symbol key.
  it 'fills the defaults in under a _default meta given alone in data_metas' do
    post_type = create(:post_type, data_metas: { '_default' => { 'has_tags' => true } })

    expect(post_type.manage_tags?).to be(true)
    expect(post_type.metas.where(key: '_default').count).to eq(1)
    stored = CamaleonCms::PostType.find(post_type.id)
    expect(stored.get_option(:has_tags)).to be(true)
    expect(stored.get_option(:has_seo)).to be(true)
  end

  # set_metas yields the queued `_default` meta as request parameters when data_metas are; the defaults are
  # then filled in under them on the same instance.
  it 'fills the defaults in under a _default meta given as request parameters' do
    queued = ActionController::Parameters.new('_default' => { 'has_category' => true })
    post_type = create(:post_type, data_metas: queued)

    expect(post_type.manage_categories?).to be(true)
    expect(post_type.categories.where(slug: 'uncategorized')).to exist
    expect(post_type.metas.where(key: '_default').count).to eq(1)
    stored = CamaleonCms::PostType.find(post_type.id)
    expect(stored.get_option(:has_category)).to be(true)
    expect(stored.get_option(:has_seo)).to be(true)
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
    # Ruby's dup copies every instance variable, so a copy saved inside the transaction of the
    # original's write inherited the record of that write and, when the transaction was rolled back,
    # queued the original's values on itself.
    it 'does not queue the values on a copy saved inside the rolled-back transaction' do
      copy = nil
      ActiveRecord::Base.transaction(requires_new: true) do
        post = create(:post, post_type: shared_post_type, data_options: { has_comments: true })
        copy = post.dup
        copy.slug = "#{post.slug}-copy"
        copy.save!
        raise ActiveRecord::Rollback
      end

      expect(copy.data_options).to be_blank
      expect(copy.data_metas).to be_blank
    end

    it 'gives a copy queues of its own' do
      post = build(:post, post_type: shared_post_type, data_options: { has_comments: true })
      copy = post.dup
      copy.data_options[:has_layout] = true

      expect(post.data_options).to eq(has_comments: true)
    end

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

    # A creation rolled back leaves the record new again, under the id it had before the save, so what it
    # memoized before or while being created is dropped, and its metas, queued or not, are built again: it
    # reads what its next save stores, where it read the value memoized before the save and a meta written
    # twice in the transaction was left claiming a row that no longer exists, which the next save skipped.
    it 'reads, once its creation is rolled back, the metas its next save stores' do
      post_type = build(:post_type)
      post_type.set_meta('probe', 'before the save')
      ActiveRecord::Base.transaction(requires_new: true) do
        post_type.save!
        post_type.set_meta('probe', 'after the save')
        raise ActiveRecord::Rollback
      end
      read = post_type.get_meta('probe')

      post_type.save!

      expect(read).to eq('before the save').or eq('after the save')
      expect([post_type.get_meta('probe'), CamaleonCms::PostType.find(post_type.id).get_meta('probe')])
        .to eq([read, read])
    end

    # previously_new_record? still holds during the first update after a create, so a write that took it to
    # tell whether it created the record built a rolled-back first update's metas again as new ones, and the
    # next save stored a second row beside each.
    it 'stores a meta once when the first update after the creation is rolled back' do
      post = create(:post, post_type: shared_post_type, data_metas: { subtitle: 'first' })
      ActiveRecord::Base.transaction(requires_new: true) do
        post.update!(data_metas: { subtitle: 'second' })
        raise ActiveRecord::Rollback
      end

      post.save!

      expect(post.metas.where(key: 'subtitle').count).to eq(1)
      expect(CamaleonCms::Post.find(post.id).get_meta('subtitle')).to eq('second')
    end

    # ActiveRecord runs the record's rollback callbacks before it makes new again the metas its save stored, so
    # the callback that dropped the metas of a rolled-back update, to read the stored ones again, dropped a meta
    # built and not saved yet with them, and no later save stored it.
    it 'stores, once an update that wrote them is rolled back, a meta built before it' do
      post = create(:post, post_type: shared_post_type)
      post.metas.build(key: 'pending', value: 'built')
      ActiveRecord::Base.transaction(requires_new: true) do
        post.update!(data_options: { has_comments: true })
        raise ActiveRecord::Rollback
      end

      post.save!

      stored = CamaleonCms::Post.find(post.id)
      expect([post.get_meta('pending'), stored.get_meta('pending')]).to eq(%w[built built])
      expect(stored.get_option(:has_comments)).to be(true)
      expect(stored.metas.where(key: %w[pending _default]).group(:key).count).to eq('_default' => 1, 'pending' => 1)
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

  # A meta or an option written directly, not through a save of the record, takes no part of the record in the
  # transaction, so its rollback runs no callback of the record, which read the rolled-back value from its memo
  # and its metas in memory, and stored a meta created there again with its next save.
  describe 'a direct write rolled back with its transaction' do
    it 'reads the value stored before it, into the options it handed out too' do
      post = create(:post, post_type: shared_post_type)
      post.set_meta('probe', 'before')
      post.set_option(:size, 'xl')
      held = post.options
      ActiveRecord::Base.transaction(requires_new: true) do
        post.set_meta('probe', 'rolled back')
        post.set_option(:color, 'red')
        raise ActiveRecord::Rollback
      end

      expect(post.get_meta('probe')).to eq('before')
      expect(held).to equal(post.options)
      expect(held).to eq('size' => 'xl')
    end

    it 'reads a meta it deleted from eager-loaded metas' do
      post = create(:post, post_type: shared_post_type)
      post.set_meta('probe', 'stored')
      loaded = CamaleonCms::Post.includes(:metas).find(post.id)
      ActiveRecord::Base.transaction(requires_new: true) do
        loaded.delete_meta('probe')
        raise ActiveRecord::Rollback
      end

      expect(loaded.get_meta('probe')).to eq('stored')
    end

    it 'is not stored by the next save of the record' do
      post = CamaleonCms::Post.includes(:metas).find(create(:post, post_type: shared_post_type).id)
      ActiveRecord::Base.transaction(requires_new: true) do
        post.set_meta('probe', 'rolled back')
        raise ActiveRecord::Rollback
      end

      post.update!(title: 'Renamed')

      expect(CamaleonCms::Post.find(post.id).get_meta('probe')).to be_nil
    end

    # A savepoint's state is committed when it is released, and never fully committed, so a write in it was kept
    # for the instance's life and rescanned before every later read, write and save.
    it 'is forgotten once committed in a savepoint and no transaction is open' do
      post = create(:post, post_type: shared_post_type)
      ActiveRecord::Base.transaction(requires_new: true) { post.set_meta('probe', 'committed') }
      post.get_meta('probe')
      expect(post.instance_variable_get(:@meta_write_states)).to be_present

      allow(post.class.connection).to receive(:transaction_open?).and_return(false)
      post.get_meta('probe')
      allow(post.class.connection).to receive(:transaction_open?).and_call_original

      expect(post.instance_variable_get(:@meta_write_states)).to be_nil
    end

    it 'reads a write committed in a savepoint again when the transaction around it is rolled back' do
      post = create(:post, post_type: shared_post_type)
      post.set_meta('probe', 'before')
      ActiveRecord::Base.transaction(requires_new: true) do
        ActiveRecord::Base.transaction(requires_new: true) { post.set_meta('probe', 'inner') }
        expect(post.get_meta('probe')).to eq('inner')
        raise ActiveRecord::Rollback
      end

      expect(post.get_meta('probe')).to eq('before')
    end

    # The metas dropped to undo the write were read again from the database on demand, so a meta built and not
    # saved yet, which the loaded metas read, read as absent, and every other key cost a query of its own.
    it 'keeps the metas it loaded, and a meta built on them, for the other keys' do
      post = create(:post, post_type: shared_post_type)
      post.set_meta('stored', 'kept')
      loaded = CamaleonCms::Post.includes(:metas).find(post.id)
      loaded.metas.build(key: 'pending', value: 'built')
      ActiveRecord::Base.transaction(requires_new: true) do
        loaded.set_meta('probe', 'rolled back')
        raise ActiveRecord::Rollback
      end

      expect(loaded.get_meta('pending')).to eq('built')
      expect(metas_selects { expect(loaded.get_meta('stored')).to eq('kept') }).to be_empty
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

  # previously_new_record? still holds during the first update after a create, and the update took it to
  # read and write the record's rows among its metas in memory, as its creation does: a meta or options row
  # another instance stored since was missed, and a second row written beside it, which no read takes.
  it 'writes the first update after the creation to the rows another instance stored since' do
    post = create(:post, post_type: shared_post_type)
    other = CamaleonCms::Post.find(post.id)
    other.set_meta('subtitle', 'other')
    other.set_option(:has_layout, true)

    post.update!(data_metas: { subtitle: 'mine' }, data_options: { has_comments: true })

    expect(post.metas.where(key: %w[subtitle _default]).group(:key).count).to eq('subtitle' => 1, '_default' => 1)
    stored = CamaleonCms::Post.find(post.id)
    expect(stored.get_meta('subtitle')).to eq('mine')
    expect(stored.options).to include('has_layout' => true, 'has_comments' => true)
  end
end
