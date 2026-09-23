# frozen_string_literal: true

# The cama_post_decorator_class option is loaded as code by Post#decorator_class, so a post type
# stores it only when it names a CamaleonCms::PostDecorator subclass, whoever writes it and through
# whichever option writer. A stored value that predates the check is ignored at read and reported,
# never rewritten. OpenSpec: post-decorator-class-integrity.
RSpec.describe CamaleonCms::PostType, type: :model do
  let(:post_type) { create(:post_type, data_options: { has_category: false }) }
  let(:option) { 'cama_post_decorator_class' }

  before { stub_const('ProbePostDecorator', Class.new(CamaleonCms::PostDecorator)) }

  # A fresh record: the one in `post_type` memoizes its options.
  def stored_post_type
    described_class.find(post_type.id)
  end

  # A value stored without passing the save-time check: written before the check existed, or naming
  # the decorator of a plugin since removed.
  def store_decorator_option(value)
    meta = post_type.metas.find_by!(key: '_default')
    meta.update!(value: JSON.parse(meta.value).merge(option => value).to_json)
  end

  describe 'storing the option' do
    it 'accepts a post decorator subclass and decorates the posts with it' do
      post_type.set_option(option, 'ProbePostDecorator')

      expect(stored_post_type.get_option(option)).to eq('ProbePostDecorator')
      expect(stored_post_type.post_decorator_class).to eq(ProbePostDecorator)
      post = create(:post, post_type: post_type)
      expect(CamaleonCms::Post.find(post.id).decorator_class).to eq(ProbePostDecorator)
    end

    it 'refuses a class outside the decorator hierarchy and leaves the stored options as they were' do
      post_type.set_option('has_tags', true)

      expect { post_type.set_option(option, 'Object') }
        .to raise_error(ActiveRecord::RecordInvalid, /cama_post_decorator_class.*'Object'/)

      expect(post_type.errors[:base].first).to include(option).and include('Object')
      # The option writer puts back the options it changed, so the instance reads them without a query.
      keys = nil
      expect(metas_selects { keys = post_type.options.keys.map(&:to_s) }).to be_empty
      expect(keys).not_to include(option)
      expect(stored_post_type.get_option(option)).to be_nil
      expect(stored_post_type.get_option('has_tags')).to be(true)
    end

    it 'refuses an unknown class name' do
      expect { post_type.set_option(option, 'Plugins::Missing::Decorator') }
        .to raise_error(ActiveRecord::RecordInvalid, /Plugins::Missing::Decorator/)

      expect(stored_post_type.get_option(option)).to be_nil
    end

    it 'refuses a name that cannot be loaded the same way, leaving the options it holds as they were' do
      expect { post_type.set_option(option, 'ENV::X') }
        .to raise_error(ActiveRecord::RecordInvalid, /cama_post_decorator_class.*'ENV::X'/)

      expect(post_type.options.keys.map(&:to_s)).not_to include(option)
      expect(stored_post_type.get_option(option)).to be_nil
    end

    it 'refuses it through set_options and set_multiple_options' do
      expect { post_type.set_options(option.to_sym => 'Object') }.to raise_error(ActiveRecord::RecordInvalid)
      expect { post_type.set_multiple_options(option => 'Object', 'has_tags' => true) }
        .to raise_error(ActiveRecord::RecordInvalid)

      expect(stored_post_type.get_option(option)).to be_nil
      expect(stored_post_type.get_option('has_tags')).to be(false)
    end

    it 'refuses it through set_meta however the options are passed' do
      params = ActionController::Parameters.new(option => 'Object', 'has_tags' => true)

      expect { post_type.set_meta('_default', params) }.to raise_error(ActiveRecord::RecordInvalid)
      expect { post_type.set_meta('_default', { option => 'Object' }.to_json) }
        .to raise_error(ActiveRecord::RecordInvalid)
      # With both key forms the one written last is stored, so that is the one checked.
      expect { post_type.set_meta('_default', { option => '', option.to_sym => 'Object' }) }
        .to raise_error(ActiveRecord::RecordInvalid)

      expect(stored_post_type.get_option(option)).to be_nil
      expect(stored_post_type.get_option('has_tags')).to be(false)
    end

    it 'accepts the key form written last when both are passed' do
      options = post_type.options.to_h.merge(option.to_sym => 'Object', option => 'ProbePostDecorator')
      post_type.set_meta('_default', options)

      expect(stored_post_type.get_option(option)).to eq('ProbePostDecorator')
    end

    # An option write changes a copy of the options, so the options the post type holds do not show a write
    # before it is stored, not while its check runs either.
    it 'does not show a write in the options it holds while checking it' do
      held = post_type.options
      seen = nil
      allow(post_type).to receive(:check_meta_write).and_wrap_original do |check, *args|
        seen = held.key?(option)
        check.call(*args)
      end

      expect { post_type.set_option(option, 'Object') }.to raise_error(ActiveRecord::RecordInvalid)
      expect(seen).to be(false)
      expect(held).to equal(post_type.options)
    end

    # The options a post type handed out, changed in place and written back with set_meta, read what is stored
    # again when the write is refused, so the refused value is not read and later option writes succeed.
    it 'reads what is stored again into options it handed out whose write is refused' do
      held = post_type.options
      held[option] = 'Object'

      expect { post_type.set_meta('_default', held) }.to raise_error(ActiveRecord::RecordInvalid)

      expect(held).to equal(post_type.options)
      expect(post_type.get_option(option)).to be_nil
      post_type.set_option('has_tags', true)
      expect(stored_post_type.get_option('has_tags')).to be(true)
    end

    # With the options row deleted by another instance meanwhile, the options handed out hold nothing, as the
    # post type reads no options, rather than the refused value.
    it 'empties options it handed out whose write is refused once their row is gone' do
      held = post_type.options
      held[option] = 'Object'
      described_class.find(post_type.id).delete_meta('_default')

      expect { post_type.set_meta('_default', held) }.to raise_error(ActiveRecord::RecordInvalid)

      expect(held).to be_empty
      expect(post_type.options).to eq({})
    end

    it 'reads what is stored again when options it handed out are frozen, written back and refused' do
      held = post_type.options
      held[option] = 'Object'
      held.freeze

      expect { post_type.set_meta('_default', held) }.to raise_error(ActiveRecord::RecordInvalid)

      expect(post_type.get_option(option)).to be_nil
      expect(held).not_to equal(post_type.options)
    end

    it 'keeps earlier writes when a later one is refused on a record with its metas loaded' do
      record = described_class.includes(:metas).find(post_type.id)
      record.set_option('has_tags', true)
      expect { record.set_option(option, 'Object') }.to raise_error(ActiveRecord::RecordInvalid)

      record.set_option('has_seo', false)

      expect(stored_post_type.get_option('has_tags')).to be(true)
      expect(stored_post_type.get_option('has_seo')).to be(false)
    end

    # The check reads the decorator option from the form set_meta is about to store, so an options write
    # parses the options it stores once.
    it 'parses the options once for an options write' do
      post_type.options
      expect(JSON).to receive(:parse).once.and_call_original

      post_type.set_option('has_tags', true)
    end

    # The stored value a refusal compares with is read from the database, from the row a write updates, even
    # when the metas are loaded: they may be older than the row. It is read only for a value the check refuses.
    it 'reads the stored value from the database, with the metas loaded too' do
      record = described_class.includes(:metas).find(post_type.id)
      record.options

      refused = metas_selects do
        expect { record.set_option(option, 'Object') }.to raise_error(ActiveRecord::RecordInvalid)
      end
      accepted = metas_selects { record.set_option(option, 'ProbePostDecorator') }

      expect(refused.size).to eq(1)
      expect(accepted).to be_empty
    end

    it 'refuses a value loaded metas still hold after the stored one was corrected' do
      store_decorator_option('Object')
      stale = described_class.includes(:metas).find(post_type.id)
      stale.options
      store_decorator_option('ProbePostDecorator')

      expect { stale.set_option('has_tags', true) }
        .to raise_error(ActiveRecord::RecordInvalid, /cama_post_decorator_class.*'Object'/)
      expect(stored_post_type.get_option(option)).to eq('ProbePostDecorator')
    end

    # A refused write changes no row, so the metas in memory stay: on an unsaved record they are the
    # metas built for its first save.
    it 'keeps the metas built on an unsaved record when a write is refused' do
      record = build(:post_type)
      record.set_meta('probe', 'built')
      expect { record.set_option(option, 'Object') }.to raise_error(ActiveRecord::RecordInvalid)

      record.save!

      expect(record.get_meta('probe')).to eq('built')
      expect(described_class.find(record.id).get_meta('probe')).to eq('built')
    end

    it 'accepts a blank value, which clears it' do
      post_type.set_option(option, 'ProbePostDecorator')
      post_type.set_option(option, '')

      expect(stored_post_type.post_decorator_class).to eq(CamaleonCms::PostDecorator)
    end

    it 'stores the other options as before' do
      post_type.set_options('has_tags' => true, 'has_seo' => false)

      expect(stored_post_type.get_option('has_tags')).to be(true)
      expect(stored_post_type.get_option('has_seo')).to be(false)
    end
  end

  describe 'a stored value the check would refuse' do
    before { store_decorator_option('Object') }

    it 'does not block writing or deleting other options, and stays stored' do
      stored_post_type.set_option('has_tags', true)
      stored_post_type.delete_option('has_seo')

      expect(stored_post_type.get_option('has_tags')).to be(true)
      expect(stored_post_type.options).not_to have_key('has_seo')
      expect(stored_post_type.get_option(option)).to eq('Object')
    end

    it 'does not block saving the post type with data_options' do
      expect(stored_post_type.update(name: 'Renamed probe', data_options: { has_tags: true })).to be(true)

      expect(stored_post_type.name).to eq('Renamed probe')
      expect(stored_post_type.get_option('has_tags')).to be(true)
    end

    it 'still refuses changing it to another value the check refuses' do
      expect { stored_post_type.set_option(option, 'String') }
        .to raise_error(ActiveRecord::RecordInvalid, /'String'/)

      expect(stored_post_type.get_option(option)).to eq('Object')
    end

    it 'accepts replacing it with a post decorator or clearing it' do
      stored_post_type.set_option(option, 'ProbePostDecorator')
      expect(stored_post_type.get_option(option)).to eq('ProbePostDecorator')

      stored_post_type.set_option(option, '')
      expect(stored_post_type.post_decorator_class).to eq(CamaleonCms::PostDecorator)
    end
  end

  describe 'a decorator option passed to a save' do
    it 'fails the update before anything is written' do
      record = stored_post_type

      expect(record.update(name: 'Renamed probe', data_options: { option => 'Object' })).to be(false)
      expect(record.errors[:base].first).to include(option).and include('Object')
      expect(stored_post_type.name).not_to eq('Renamed probe')
      expect(stored_post_type.get_option(option)).to be_nil
    end

    it 'raises from update! as any invalid record does' do
      expect { stored_post_type.update!(data_options: { option => 'Object' }) }
        .to raise_error(ActiveRecord::RecordInvalid, /cama_post_decorator_class/)
    end

    it 'creates no post type, even inside an enclosing transaction' do
      site = post_type.site
      created = nil
      ActiveRecord::Base.transaction do
        created = site.post_types.create(name: 'Probe decorator', slug: 'probe-decorator-type',
                                         data_options: { option => 'Object' })
      end

      expect(created).not_to be_persisted
      expect(created.errors[:base].first).to include(option)
      expect(site.post_types.where(slug: 'probe-decorator-type')).not_to exist
    end

    it 'refuses the option passed as the _default meta the same way' do
      site = post_type.site
      created = nil
      ActiveRecord::Base.transaction do
        created = site.post_types.create(name: 'Probe decorator meta', slug: 'probe-decorator-meta',
                                         data_metas: { '_default' => { option => 'Object' } })
      end

      expect(created).not_to be_persisted
      expect(created.errors[:base].first).to include(option).and include('Object')
      expect(site.post_types.where(slug: 'probe-decorator-meta')).not_to exist

      record = stored_post_type
      expect(record.update(name: 'Renamed probe', data_metas: { _default: { option => 'Object' } })).to be(false)
      expect(record.errors[:base].first).to include(option)
      expect(stored_post_type.get_option(option)).to be_nil
    end

    # The check reads one option, by its String key, from the text set_meta will store, parsed as a read parses
    # it: the hashes in the options it parses are not read by either key type, as a read of them all is.
    it 'reads the option from the options passed without reading every hash in them by either key type' do
      record = stored_post_type
      record.data_options = { option => 'ProbePostDecorator', 'sizes' => [{ 'top' => 'xl' }] }
      expect(CamaleonCms::Metas).to receive(:indifferent_json_value).once.and_call_original

      expect(record).to be_valid
    end

    it 'looks the stored value up once for a refused value in both queues' do
      record = stored_post_type
      lookups = 0
      count_lookup = lambda do |*, payload|
        lookups += 1 if payload[:sql].start_with?('SELECT') && payload[:type_casted_binds].to_a.include?('_default')
      end

      saved = ActiveSupport::Notifications.subscribed(count_lookup, 'sql.active_record') do
        record.update(data_options: { option => 'Object' }, data_metas: { '_default' => { option => 'String' } })
      end

      expect(saved).to be(false)
      expect(record.errors[:base].size).to eq(2)
      expect(lookups).to eq(1)
    end

    it 'accepts a post decorator' do
      expect(stored_post_type.update(data_options: { option => 'ProbePostDecorator' })).to be(true)

      expect(stored_post_type.get_option(option)).to eq('ProbePostDecorator')
    end
  end

  describe '#post_decorator_class' do
    it 'ignores a stored value that is not a post decorator, warns, and leaves it stored' do
      store_decorator_option('Object')
      allow(Rails.logger).to receive(:warn)
      expect(Rails.logger).to receive(:warn).with(/cama_post_decorator_class "Object"/)

      expect(stored_post_type.post_decorator_class).to eq(CamaleonCms::PostDecorator)
      expect(stored_post_type.get_option(option)).to eq('Object')
    end

    it 'ignores a stored name that cannot be loaded, and warns' do
      store_decorator_option('ENV::X')
      allow(Rails.logger).to receive(:warn)
      expect(Rails.logger).to receive(:warn).with(/cama_post_decorator_class "ENV::X"/)

      expect(stored_post_type.post_decorator_class).to eq(CamaleonCms::PostDecorator)
    end

    it 'warns once per request for a post type and value, not once per decorated post' do
      store_decorator_option("Object\nforged line")
      warnings = []
      allow(Rails.logger).to receive(:warn) { |message| warnings << message }
      posts = Array.new(3) { create(:post, post_type: post_type) }

      CamaleonCms::Post.where(id: posts.map(&:id)).includes(:post_type).find_each(&:decorate)
      CamaleonCms::Post.find(posts.first.id).decorate
      expect(warnings.grep(/cama_post_decorator_class/)).to contain_exactly(include('"Object\nforged line"'))

      CurrentRequest.reset
      CamaleonCms::Post.find(posts.first.id).decorate
      expect(warnings.grep(/cama_post_decorator_class/).size).to eq(2)
    end

    it 'is the default for a post without a post type' do
      expect(CamaleonCms::Post.new.decorator_class).to eq(CamaleonCms::PostDecorator)
    end

    # An options row that is not a JSON object reads as no options (meta-storage-integrity), so the
    # lookup no longer fails on it; the scan task lists the row.
    it 'is the default for a post whose post type options row is not an object, without a lookup failure' do
      post = create(:post, post_type: post_type)
      post_type.metas.find_by!(key: '_default').update!(value: '[]')
      warnings = []
      allow(Rails.logger).to receive(:warn) { |message| warnings << message }

      expect(CamaleonCms::Post.find(post.id).decorator_class).to eq(CamaleonCms::PostDecorator)
      expect(warnings.grep(/decorator lookup failed/)).to be_empty
    end
  end

  describe '.decorator_class_for' do
    it 'is the default decorator for a blank value, for the check, the read and the scan alike' do
      ['', ' ', nil, false].each do |blank|
        expect(described_class.decorator_class_for(blank)).to eq(CamaleonCms::PostDecorator)
      end
    end

    it 'is nil for a name through a constant that is not a class or module' do
      expect(described_class.decorator_class_for('ENV::X')).to be_nil
      expect(described_class.decorator_class_for('RUBY_VERSION::X')).to be_nil
    end

    it 'is nil for a decorator whose file fails to load' do
      # Loading the decorator raises for another constant, which safe_constantize re-raises.
      namespace = Module.new do
        def self.const_missing(_name)
          raise NameError.new('uninitialized constant MissingProbeConstant', :MissingProbeConstant)
        end
      end
      stub_const('ProbeDecorators', namespace)

      expect(described_class.decorator_class_for('ProbeDecorators::BrokenDecorator')).to be_nil
    end
  end
end
