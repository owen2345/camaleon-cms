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
      rolled_back_transaction do
        post = create(:post, post_type: shared_post_type, data_options: { has_comments: true })
        copy = post.dup
        copy.slug = "#{post.slug}-copy"
        copy.save!
      end

      expect(copy.data_options).to be_blank
      expect(copy.data_metas).to be_blank
    end

    # A host's user_model gets this concern through CamaleonCms::UserMethods on a base class of its own
    # (config/initializers/model_alias.rb), without CamaleonRecord's memo, so the callback that drops what a
    # rolled-back creation memoized raised NameError: over the error that rolled the creation back, and in place
    # of the ActiveRecord::Rollback that ends a transaction quietly.
    it 'rolls back the creation of a record that is not a CamaleonRecord as it would without the metas' do
      # the dummy app has no ApplicationRecord: a host model subclasses its own base class
      stub_const('SpecHostUser', Class.new(ActiveRecord::Base)) # rubocop:disable Rails/ApplicationRecord
      SpecHostUser.class_eval do
        self.table_name = CamaleonCms::User.table_name
        include CamaleonCms::UserMethods
      end
      create_user = -> { SpecHostUser.create!(username: 'host-user', email: 'host-user@example.com') }

      expect { rolled_back_transaction { create_user.call } }.not_to raise_error
      expect do
        ActiveRecord::Base.transaction(requires_new: true) do
          create_user.call
          raise ArgumentError, 'a later step'
        end
      end.to raise_error(ArgumentError, 'a later step')
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
      rolled_back_transaction do
        post_type.save!
        post_type.set_meta('probe', 'after the save')
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
      rolled_back_transaction { post.update!(data_metas: { subtitle: 'second' }) }

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
      rolled_back_transaction { post.update!(data_options: { has_comments: true }) }

      post.save!

      stored = CamaleonCms::Post.find(post.id)
      expect([post.get_meta('pending'), stored.get_meta('pending')]).to eq(%w[built built])
      expect(stored.get_option(:has_comments)).to be(true)
      expect(stored.metas.where(key: %w[pending _default]).group(:key).count).to eq('_default' => 1, 'pending' => 1)
    end

    # The rollback callback dropped every value the instance had memoized, so the options it had handed out, which
    # the update's option write changed in place, kept the rolled-back option and read no later write, and so did a
    # list it had handed out for a key the update never wrote.
    it 'reads what is stored, in the options and a list it handed out, once an update that wrote them is rolled back' do
      post = create(:post, post_type: shared_post_type)
      post.set_option(:size, 'xl')
      post.set_meta('list', [1, 2])
      held = post.options
      list = post.get_meta('list')
      rolled_back_transaction { post.update!(data_options: { color: 'red' }) }

      expect([post.options, post.get_meta('list')]).to match([equal(held), equal(list)])
      expect(held).to eq('size' => 'xl')
      post.set_option(:weight, 3)
      expect(held).to eq('size' => 'xl', 'weight' => 3)
    end

    it 'queues the values given to an update whose transaction is rolled back' do
      post = create(:post, post_type: shared_post_type)
      rolled_back_transaction { post.update!(data_options: { has_comments: true }, data_metas: { subtitle: 'first' }) }
      expect(CamaleonCms::Post.find(post.id).get_meta('subtitle')).to be_nil

      post.save!

      stored = CamaleonCms::Post.find(post.id)
      expect(stored.get_option(:has_comments)).to be(true)
      expect(stored.get_meta('subtitle')).to eq('first')
    end

    it 'leaves them written when a later save of the instance is rolled back' do
      post = create(:post, post_type: shared_post_type, data_options: { has_comments: true })
      post.set_option(:has_comments, false)
      rolled_back_transaction { post.update!(title: 'Renamed') }

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
      rolled_back_transaction do
        post.set_meta('probe', 'rolled back')
        post.set_option(:color, 'red')
      end

      expect(post.get_meta('probe')).to eq('before')
      expect(held).to equal(post.options)
      expect(held).to eq('size' => 'xl')
    end

    it 'reads a meta it deleted from eager-loaded metas' do
      post = create(:post, post_type: shared_post_type)
      post.set_meta('probe', 'stored')
      loaded = CamaleonCms::Post.includes(:metas).find(post.id)
      rolled_back_transaction { loaded.delete_meta('probe') }

      expect(loaded.get_meta('probe')).to eq('stored')
    end

    it 'is not stored by the next save of the record' do
      post = CamaleonCms::Post.includes(:metas).find(create(:post, post_type: shared_post_type).id)
      rolled_back_transaction { post.set_meta('probe', 'rolled back') }

      post.update!(title: 'Renamed')

      expect(CamaleonCms::Post.find(post.id).get_meta('probe')).to be_nil
    end

    # A savepoint's state is committed when it is released, and never fully committed, so a write in it was kept
    # for the instance's life and rescanned before every later read, write and save.
    it 'is forgotten once committed in a savepoint and no transaction is open' do
      post = create(:post, post_type: shared_post_type)
      ActiveRecord::Base.transaction(requires_new: true) { post.set_meta('probe', 'committed') }
      expect(post.instance_variable_get(:@meta_write_states)).to be_present

      allow(post.class.connection_pool).to receive(:active_connection?).and_return(nil)
      post.get_meta('probe')
      allow(post.class.connection_pool).to receive(:active_connection?).and_call_original

      expect(post.instance_variable_get(:@meta_write_states)).to be_nil
    end

    it 'reads the writes committed in the savepoints of a transaction again when it is rolled back' do
      post = create(:post, post_type: shared_post_type)
      rolled_back_transaction do
        3.times { |i| ActiveRecord::Base.transaction(requires_new: true) { post.set_meta("probe#{i}", i) } }
        post.get_meta('probe0')
      end

      expect([post.get_meta('probe0'), post.get_meta('probe2')]).to eq([nil, nil])
    end

    # A write committed in a savepoint was kept under the transaction open at the next read, write or save, which
    # can be a later savepoint beside it or a transaction begun after its own, and whose rollback was then taken
    # for the write's: its value was read again, and the metas built for its key dropped, so no save stored them.
    it 'reads a write committed in a savepoint from its memo once a later savepoint beside it is rolled back' do
      post = create(:post, post_type: shared_post_type)
      ActiveRecord::Base.transaction(requires_new: true) do
        ActiveRecord::Base.transaction(requires_new: true) { post.set_meta('probe', 'committed') }
        rolled_back_transaction { post.get_meta('probe') }

        expect(metas_selects { expect(post.get_meta('probe')).to eq('committed') }).to be_empty
      end
    end

    it 'stores a meta built for the key of a write committed in a savepoint once a later one is rolled back' do
      post = create(:post, post_type: shared_post_type)
      post.set_meta('probe', 'stored')
      ActiveRecord::Base.transaction(requires_new: true) do
        ActiveRecord::Base.transaction(requires_new: true) { post.delete_meta('probe') }
        post.metas.build(key: 'probe', value: 'built')
        rolled_back_transaction { post.get_meta('other') }
        post.save!

        expect(CamaleonCms::Post.find(post.id).get_meta('probe')).to eq('built')
      end
    end

    it 'reads a write committed in a savepoint again when the transaction around it is rolled back' do
      post = create(:post, post_type: shared_post_type)
      post.set_meta('probe', 'before')
      rolled_back_transaction do
        ActiveRecord::Base.transaction(requires_new: true) { post.set_meta('probe', 'inner') }
        expect(post.get_meta('probe')).to eq('inner')
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
      rolled_back_transaction { loaded.set_meta('probe', 'rolled back') }

      expect(loaded.get_meta('pending')).to eq('built')
      expect(metas_selects { expect(loaded.get_meta('stored')).to eq('kept') }).to be_empty
    end

    # Undoing the write forgot the keys it wrote before reading them again, so when that read failed, as every query
    # does in a PostgreSQL transaction a failed statement aborted, the instance read the rolled-back value for good.
    it 'reads the value stored before it once an undoing that failed is tried again' do
      post = create(:post, post_type: shared_post_type)
      post.set_meta('probe', 'stored')
      loaded = CamaleonCms::Post.includes(:metas).find(post.id)
      rolled_back_transaction { loaded.set_meta('probe', 'rolled back') }
      failed = false
      allow(loaded.metas).to receive(:where).and_wrap_original do |where, *args|
        next where.call(*args) if failed

        failed = true
        raise ActiveRecord::StatementInvalid, 'current transaction is aborted'
      end

      expect { loaded.get_meta('probe') }.to raise_error(ActiveRecord::StatementInvalid)
      expect(loaded.get_meta('probe')).to eq('stored')
    end

    # Undoing the write took the metas of the keys it wrote out of the list the metas hold and appended their rows,
    # in place, so a loop over the metas whose first read undid it skipped the meta after it and met another twice.
    it 'lets a loop over the metas read each of them once' do
      post = create(:post, post_type: shared_post_type)
      %w[a b c].each_with_index { |key, i| post.set_meta(key, i) }

      [CamaleonCms::Post.includes(:metas).find(post.id), CamaleonCms::Post.find(post.id)].each do |record|
        rolled_back_transaction { record.set_meta('a', 'rolled back') }
        read = record.metas.map { |meta| [meta.key, record.get_meta(meta.key)] }

        expect(read.map(&:first).tally.values).to all(eq(1))
        expect(read.to_h.slice('a', 'b', 'c')).to eq('a' => 0, 'b' => 1, 'c' => 2)
      end
    end

    # Undoing the write loaded every meta row of the record again, to read the rows of the keys it wrote.
    it 'loads again only the rows of the keys it wrote' do
      post = create(:post, post_type: shared_post_type)
      post.set_meta('stored', 'kept')
      post.set_meta('probe', 'before')
      loaded = CamaleonCms::Post.includes(:metas).find(post.id)
      kept = loaded.metas.find { |meta| meta.key == 'stored' }
      rolled_back_transaction { loaded.set_meta('probe', 'rolled back') }

      selects = metas_selects { expect(loaded.get_meta('probe')).to eq('before') }

      expect(selects).to contain_exactly(a_string_matching(/"metas"\."key" (=|IN)/))
      expect(loaded.metas.find { |meta| meta.key == 'stored' }).to equal(kept)
    end

    # Telling the transaction a write belongs to asked the model for its connection, which leases one to the thread
    # for good, so a meta written, deleted or created with a record raised where a host refuses such a lease.
    context 'when a host refuses a permanent connection lease' do
      before { skip 'Rails 7.2+ refuses it' unless ActiveRecord.respond_to?(:permanent_connection_checkout) }

      # A thread of its own holds no connection until a query leases one for its length
      def in_a_thread_refusing_a_lease
        checkout = ActiveRecord.permanent_connection_checkout
        Thread.new do
          ActiveRecord.permanent_connection_checkout = :disallowed
          yield
        ensure
          ActiveRecord.permanent_connection_checkout = checkout
        end.join
      end

      it 'writes, deletes and creates metas, in a transaction too' do
        post = create(:post, post_type: shared_post_type)
        created = nil

        in_a_thread_refusing_a_lease do
          post.set_option(:color, 'red')
          post.set_meta('probe', 'written')
          post.delete_meta('probe')
          ActiveRecord::Base.transaction(requires_new: true) { post.set_meta('inside', 'a transaction') }
          post.get_meta('inside')
          created = create(:post, post_type: shared_post_type, data_metas: { subtitle: 'created' })
        end

        stored = CamaleonCms::Post.find(post.id)
        expect([stored.get_option(:color), stored.get_meta('probe'), stored.get_meta('inside')])
          .to eq(['red', nil, 'a transaction'])
        expect(CamaleonCms::Post.find(created.id).get_meta('subtitle')).to eq('created')
      end
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
