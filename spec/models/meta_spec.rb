# frozen_string_literal: true

RSpec.describe CamaleonCms::Meta, type: :model do
  describe 'value preservation' do
    it 'preserves angle brackets in Meta#value' do
      site = create(:site)
      meta = described_class.create!(objectid: site.id, object_class: 'Site', key: 'test_key', value: 'count < 10')
      expect(meta.reload.value).to eq('count < 10')
    end

    it 'preserves email addresses with angle brackets through set_option/get_option round-trip' do
      site = create(:site)
      site.set_option('email_from', 'My Name <myemail@domain.com>')
      fresh_site = CamaleonCms::Site.find(site.id)
      expect(fresh_site.get_option('email_from')).to eq('My Name <myemail@domain.com>')
    end

    it 'preserves angle brackets in JSON-serialized meta values' do
      site = create(:site)
      site.set_options(email_from: 'Admin <admin@test.com>', email_cc: 'Support <support@test.com>')
      fresh_site = CamaleonCms::Site.find(site.id)
      expect(fresh_site.get_option('email_from')).to eq('Admin <admin@test.com>')
      expect(fresh_site.get_option('email_cc')).to eq('Support <support@test.com>')
    end
  end

  describe '#get_meta with an eager-loaded metas association' do
    # PluginRoutes.get_sites eager-loads :metas, so route-draw reads take get_meta's in-memory
    # branch. That branch must normalize a Symbol key the same way the DB branch does, otherwise
    # 'a_key' == :a_key is always false and the stored value is silently replaced by the default.
    it 'resolves a Symbol key against the loaded metas instead of returning the default' do
      site = create(:site)
      site.set_meta('languages_site', %w[en es])

      loaded = CamaleonCms::Site.includes(:metas).find(site.id)
      expect(loaded.metas).to be_loaded

      expect(loaded.get_meta(:languages_site)).to eq(%w[en es])
    end

    # set_meta stores a key by its String form, so a read finds it by that form among the loaded metas as
    # the database lookup does, whatever object names the key.
    it 'resolves a key that is neither a String nor a Symbol by the String set_meta stores' do
      post = create(:post)
      post.set_meta(2024, 'probe')

      loaded = CamaleonCms::Post.includes(:metas).find(post.id)
      expect([loaded.get_meta(2024), CamaleonCms::Post.find(post.id).get_meta(2024)]).to eq(%w[probe probe])
    end
  end

  describe 'options and hash metas on the instance that wrote them' do
    # A post type's after_create writes its defaults with Symbol keys; a String-keyed set_option on
    # that instance must replace :has_category, not add "has_category" beside it (json 3 refuses to
    # generate the duplicate, json 2 stored both).
    it 'stores a String-keyed option once after Symbol-keyed defaults' do
      post_type = create(:post_type)
      post_type.set_option('has_category', true)

      stored = post_type.metas.find_by!(key: '_default').value
      expect(stored.scan('"has_category"').size).to eq(1)
      expect(post_type.get_option(:has_category)).to be(true)
      expect(CamaleonCms::PostType.find(post_type.id).get_option(:has_category)).to be(true)
    end

    it 'deletes an option whichever key type wrote it' do
      post = create(:post)
      post.set_meta('_default', { 'color' => 'red' }.merge(size: 'xl'))
      post.delete_option(:color)
      post.delete_option('size')

      expect(CamaleonCms::Post.find(post.id).options).to be_empty
    end

    it 'reads the first String-keyed option of a record back by Symbol' do
      post = create(:post)
      post.set_option('has_picture', false)

      expect(post.get_option(:has_picture)).to be(false)
    end

    it 'stores a hash meta with one entry per key however each key was written' do
      post_type = create(:post_type)
      post_type.set_meta('probe_settings', { sec: 20 }.merge('sec' => 30))
      post_type.set_meta('probe_rows', [{ sec: 20 }.merge('sec' => 30)])

      expect(post_type.metas.find_by!(key: 'probe_settings').value.scan('"sec"').size).to eq(1)
      expect(post_type.metas.find_by!(key: 'probe_rows').value.scan('"sec"').size).to eq(1)
      expect(CamaleonCms::PostType.find(post_type.id).get_meta('probe_settings')).to eq('sec' => 30)
    end

    # The memo is keyed by the record's id, so what a new record memoized before its first save is not
    # read after it: the saved record reads what it stored, which is what it read before the save.
    it 'reads the stored form once a new record is saved' do
      settings = { color: 'red' }
      post_type = build(:post_type)
      post_type.set_meta('probe_settings', settings)
      expect(post_type.get_meta('probe_settings')).to eq('color' => 'red')

      post_type.save!

      expect(post_type.get_meta('probe_settings')).to eq('color' => 'red')
    end

    # set_meta leaves a caller's plain Hash as passed, keys and all; options, get_option and get_meta read
    # it by either key type, as a reloaded record reads the options it parses.
    it 'reads options a caller passed to set_meta as a plain Hash by either key type' do
      passed = { 'color' => 'red', size: 'xl' }
      post_type = create(:post_type)
      post_type.set_meta('_default', passed)

      expect([post_type.options[:color], post_type.options['size']]).to eq(%w[red xl])
      expect([post_type.get_option(:color), post_type.get_option('size')]).to eq(%w[red xl])
      expect(post_type.get_meta('_default')).to eq('color' => 'red', 'size' => 'xl')
      expect(passed.keys).to eq(['color', :size])
      reloaded = CamaleonCms::PostType.find(post_type.id)
      expect([reloaded.options[:color], reloaded.get_option('size')]).to eq(%w[red xl])
    end

    # camaleon-ecommerce passes its params[:options] to set_meta('_default', ...) and reads them back with
    # get_option. The instance reads them as a freshly loaded record parses them, an indifferent hash whose
    # nested hashes are indifferent too, and an option written on it afterwards is stored beside them.
    it 'reads and writes options a caller passed to set_meta as request parameters' do
      post_type = create(:post_type)
      params = ActionController::Parameters.new('color' => 'red', 'sizes' => { 'top' => 'xl' })
      post_type.set_meta('_default', params)

      reads = [post_type.options[:color], post_type.options['color'], post_type.get_option(:color)]
      expect(reads).to eq(%w[red red red])
      expect(post_type.options).to be_a(ActiveSupport::HashWithIndifferentAccess)
      expect(post_type.options[:sizes].to_h).to eq('top' => 'xl')
      expect(params).not_to be_permitted
      post_type.set_option('size', 'xl')
      stored = JSON.parse(post_type.metas.find_by!(key: '_default').value)
      expect(stored).to eq('color' => 'red', 'sizes' => { 'top' => 'xl' }, 'size' => 'xl')
      expect(post_type.options).to eq(CamaleonCms::PostType.find(post_type.id).options)
    end

    # The first option writer stores and caches its own indifferent copy, which get_meta returns from then
    # on; the caller's hash is left as passed, where 2.9.4 wrote into it.
    it 'returns the writer\'s hash from get_meta once an option is written after set_meta' do
      passed = { 'color' => 'red' }
      post_type = create(:post_type)
      post_type.set_meta('_default', passed)

      post_type.set_option('size', 'xl')

      expect(post_type.get_meta('_default')).to eq('color' => 'red', 'size' => 'xl')
      expect(post_type.get_meta('_default')).not_to equal(passed)
      expect(passed).to eq('color' => 'red')
    end

    # The options hash a record hands out is the one its option writers update, so a hash read before the
    # writes keeps reading all of them on that instance, as it did in 2.9.4.
    it 'keeps a hash options returned reading the options written after it' do
      post_type = create(:post_type)
      held = post_type.options

      post_type.set_option('probe_a', 1)
      post_type.set_options(probe_b: 2)
      post_type.delete_option('has_tags')

      expect(held).to equal(post_type.options)
      expect([held[:probe_a], held[:probe_b], held.key?(:has_tags)]).to eq([1, 2, false])
    end

    # An option write changes in the hash `options` returned only what it writes, as 2.9.4's did: a nested
    # hash taken from it keeps reading the record across writes of other options, and a default set on it
    # stays, where the whole hash was replaced by the stored form on every write.
    it 'changes in a hash options returned only the options written' do
      post_type = create(:post_type, data_options: { sizes: { 'top' => 'xl' } })
      held = post_type.options
      sizes = held[:sizes]
      held.default = 'none'

      post_type.set_option(:unrelated, 'value')

      expect(held[:sizes]).to equal(sizes)
      expect([held[:unrelated], held[:missing]]).to eq(%w[value none])
      post_type.set_option(:sizes, { 'top' => 'm' })
      expect([held[:sizes][:top], sizes[:top]]).to eq(%w[m xl])
    end

    # eql? holds for 0.0 and -0.0, so a hash options returned kept the zero it held when a zero of the other sign
    # was written over it, and the writing instance read another sign than a reload.
    it 'reads in a hash options returned a zero written over a zero of the other sign' do
      post_type = create(:post_type)
      post_type.set_option(:offset, 0.0)
      held = post_type.options

      post_type.set_option(:offset, -0.0)

      expect(CamaleonCms::PostType.find(post_type.id).get_option(:offset).to_s).to eq('-0.0')
      expect([held[:offset], post_type.get_option(:offset)].map(&:to_s)).to eq(%w[-0.0 -0.0])
    end

    # An option write leaves the options it does not write in the form a reload reads, a value changed in place
    # without a writer included, which the write stores: the options handed out read what is stored.
    it 'reads what was changed in place without a writer as a reload reads it after an option write' do
      post = create(:post)
      post.set_option(:size, 'xl')
      held = post.options
      held[:shape] = :round
      held[:list] = [{ 'a' => 1 }]
      held[:list] << { 'b' => 2 }

      post.set_option(:other, 1)

      expect([held[:shape], held[:list].last.class]).to eq(['round', ActiveSupport::HashWithIndifferentAccess])
      expect(CamaleonCms::Post.find(post.id).options).to eq(held)
    end

    it 'keeps in a hash read from the record and written back the values it holds unchanged' do
      post = create(:post)
      post.set_meta('probe', { 'inner' => { 'size' => 'xl' }, 'count' => 1 })
      held = post.get_meta('probe')
      inner = held[:inner]
      held[:count] = 2

      post.set_meta('probe', held)

      expect(post.get_meta('probe')).to equal(held)
      expect(held[:inner]).to equal(inner)
      expect(CamaleonCms::Post.find(post.id).get_meta('probe')).to eq('inner' => { 'size' => 'xl' }, 'count' => 2)
    end

    # The options convert a list they are given in place, and a list in it, so an option writer gives them a copy
    # of those lists; a hash, and a list it holds, they convert into new ones. The caller's value is left as passed.
    it 'leaves a list of hashes passed to an option writer as it was' do
      post = create(:post)
      list = [{ 'key' => 'subtitle' }, [{ 'key' => 'nested' }], { 'group' => [{ 'key' => 'deep' }] }]

      post.set_option(:skip_fields, list)
      post.set_setting(:fields, list)

      expect([list[0], list[1].first, list[2], list[2]['group'].first]).to all(be_instance_of(Hash))
      expect(CamaleonCms::Post.find(post.id).get_option(:skip_fields)).to eq(list)
    end

    # A hash read from the record, changed and written back stays the one the record reads, so writing it
    # back again after another write stores that write too.
    it 'stores a hash read from the record and written back whole, however often' do
      post_type = create(:post_type)
      held = post_type.get_meta('_default')
      held[:probe_a] = 1
      post_type.set_meta('_default', held)
      post_type.set_option('probe_b', 2)
      post_type.set_meta('_default', held)

      expect(CamaleonCms::PostType.find(post_type.id).options.values_at(:probe_a, :probe_b)).to eq([1, 2])
    end

    it 'keeps a list read from the record and written back the one it reads' do
      post = create(:post)
      post.set_meta('probe_gallery', ['a.jpg'])
      gallery = post.get_meta('probe_gallery')
      gallery << 'b.jpg'
      post.set_meta('probe_gallery', gallery)

      expect(post.get_meta('probe_gallery')).to equal(gallery)
      expect(CamaleonCms::Post.find(post.id).get_meta('probe_gallery')).to eq(%w[a.jpg b.jpg])
    end

    # A frozen hash read from the record cannot take the stored form in place, so written back it is stored and
    # the record memoizes the stored form apart from it.
    it 'stores a frozen hash read from the record and written back' do
      post = create(:post)
      post.set_meta('probe', { color: 'red' })
      held = post.get_meta('probe')
      held[:color] = 'blue'
      held.freeze

      post.set_meta('probe', held)

      expect(post.get_meta('probe')).to eq('color' => 'blue')
      expect(post.get_meta('probe')).not_to equal(held)
      expect(CamaleonCms::Post.find(post.id).get_meta('probe')).to eq('color' => 'blue')
    end

    # A list read from the record, changed in place and written back by a write that fails, reads what is
    # stored again and stays the one the record reads, so the record does not read a change nothing stored.
    it 'reads what is stored again into a list written back by a write that fails' do
      post = create(:post)
      post.set_meta('probe_gallery', ['a.jpg'])
      gallery = post.get_meta('probe_gallery')
      gallery << 'b.jpg'
      allow(post).to receive(:write_meta_row).and_raise(ActiveRecord::StatementInvalid, 'write failed')

      expect { post.set_meta('probe_gallery', gallery) }.to raise_error(ActiveRecord::StatementInvalid)

      expect(gallery).to eq(['a.jpg'])
      expect(post.get_meta('probe_gallery')).to equal(gallery)
    end

    # A list written back by a write that fails, whose row another instance deleted meanwhile, holds nothing, as
    # the record reads no value for the key, rather than the change nothing stored.
    it 'empties a list written back by a write that fails once its row is gone' do
      post = create(:post)
      post.set_meta('probe_gallery', ['a.jpg'])
      gallery = post.get_meta('probe_gallery')
      gallery << 'b.jpg'
      CamaleonCms::Post.find(post.id).delete_meta('probe_gallery')
      allow(post).to receive(:write_meta_row).and_raise(ActiveRecord::StatementInvalid, 'write failed')

      expect { post.set_meta('probe_gallery', gallery) }.to raise_error(ActiveRecord::StatementInvalid)

      expect(gallery).to be_empty
      expect(post.get_meta('probe_gallery', 'none')).to eq('none')
    end

    # ActiveRecord leaves on a row the value its failed save assigned; the row takes back the value it stores,
    # so the eager-loaded metas a later read takes it from do not read a value nothing stored.
    it 'reads what is stored after a write the database refuses, with the metas loaded' do
      post = create(:post)
      post.set_meta('probe', 'stored')
      loaded = CamaleonCms::Post.includes(:metas).find(post.id)
      row = loaded.metas.target.find { |meta| meta.key == 'probe' }
      allow(row).to receive(:save!).and_raise(ActiveRecord::StatementInvalid, 'write failed')

      expect { loaded.set_meta('probe', 'refused') }.to raise_error(ActiveRecord::StatementInvalid)

      expect([loaded.get_meta('probe'), row.value]).to eq(%w[stored stored])
    end

    # A validation or a callback of the meta model refuses a row's save without raising, which the write took
    # for stored: the instance read the refused value, and a refused new row stayed among its loaded metas.
    it 'raises when the meta model refuses the row, and reads what is stored' do
      post = create(:post)
      post.set_meta('probe', 'stored')
      loaded = CamaleonCms::Post.includes(:metas).find(post.id)
      allow_any_instance_of(described_class).to receive(:valid?).and_return(false)

      expect { loaded.set_meta('probe', 'refused') }.to raise_error(ActiveRecord::RecordInvalid)
      expect { loaded.set_meta('probe_new', 'refused') }.to raise_error(ActiveRecord::RecordInvalid)

      expect([loaded.get_meta('probe'), loaded.get_meta('probe_new')]).to eq(['stored', nil])
      expect(loaded.metas.map(&:key)).not_to include('probe_new')
    end

    # A list written back by a write the database refuses reads the row again from the eager-loaded metas,
    # which hold what is stored, not the list the failed save assigned.
    it 'reads what is stored again into a list written back by a write the database refuses' do
      post = create(:post)
      post.set_meta('probe_gallery', ['a.jpg'])
      loaded = CamaleonCms::Post.includes(:metas).find(post.id)
      gallery = loaded.get_meta('probe_gallery')
      gallery << 'b.jpg'
      row = loaded.metas.target.find { |meta| meta.key == 'probe_gallery' }
      allow(row).to receive(:save!).and_raise(ActiveRecord::StatementInvalid, 'write failed')

      expect { loaded.set_meta('probe_gallery', gallery) }.to raise_error(ActiveRecord::StatementInvalid)

      expect(gallery).to eq(['a.jpg'])
      expect(loaded.get_meta('probe_gallery')).to equal(gallery)
    end

    # An indifferent hash converts a nested plain Hash into a copy but keeps a nested indifferent hash by
    # reference; the options copy shares neither with the caller's hash.
    it 'copies a caller hash without sharing its nested hashes' do
      post_type = create(:post_type)
      theme = { color: 'red' }.with_indifferent_access
      passed = { 'theme' => theme, 'sizes' => [{ 'top' => 'xl' }.with_indifferent_access] }
      post_type.set_meta('_default', passed)

      post_type.options[:theme][:color] = 'blue'
      post_type.options[:sizes].first[:top] = 'm'

      expect([theme[:color], passed['sizes'].first[:top]]).to eq(%w[red xl])
      expect(post_type.get_meta('_default')).not_to equal(passed)
    end

    # Hash#with_indifferent_access copies a Hash default and default proc along; the options copy carries
    # neither, so a missing option reads nil as after a reload and a storing default proc adds no keys.
    it 'copies a caller hash without its default' do
      post_type = create(:post_type)
      passed = Hash.new { |hash, key| hash[key] = [] }.merge!('has_category' => false)
      post_type.set_meta('_default', passed)

      expect(post_type.options[:has_single_category]).to be_nil
      expect(post_type).not_to be_manage_categories
      post_type.set_option('has_tags', true)
      post_type.options[:phantom]
      post_type.set_option('has_seo', true)
      expect(CamaleonCms::PostType.find(post_type.id).options.keys).to eq(%w[has_category has_tags has_seo])
    end

    # PostType's set_meta check names a JSON string as one form the whole options row arrives in; the writing
    # instance parses it as a freshly loaded record parses the row it stored.
    it 'reads and writes options a caller passed to set_meta as a JSON string' do
      post_type = create(:post_type)
      post_type.set_meta('_default', { 'has_tags' => true }.to_json)

      expect([post_type.options[:has_tags], post_type.get_option('has_tags')]).to eq([true, true])
      post_type.set_option('has_seo', false)
      expect(post_type.options).to eq('has_tags' => true, 'has_seo' => false)
      expect(CamaleonCms::PostType.find(post_type.id).options).to eq('has_tags' => true, 'has_seo' => false)
    end

    # A record with no options row reads them as none, whether or not get_meta was asked for them first,
    # and takes a write.
    it 'reads and writes options as none on a record with no options row' do
      post = create(:post)
      expect(post.get_meta('_default')).to be_nil

      expect(post.options).to eq({})
      expect(post.get_option(:color, 'none')).to eq('none')
      post.set_option('color', 'red')
      expect(post.get_option(:color)).to eq('red')
      expect(CamaleonCms::Post.find(post.id).get_option(:color)).to eq('red')
    end

    # The empty options of a record with no options row are a new hash on each read, not a memoized
    # default: a change made to them without an option writer is neither read back nor stored.
    it 'does not read back or store a change made to the empty options it returns' do
      post = create(:post)
      post.options[:color] = 'red'

      expect(post.options[:color]).to be_nil
      post.set_option('size', 'xl')
      expect(CamaleonCms::Post.find(post.id).options).to eq('size' => 'xl')
    end

    [nil, ''].each do |passed|
      it "reads and writes options set_meta wrote as #{passed.inspect} as none" do
        post = create(:post)
        post.set_meta('_default', passed)
        reloaded = CamaleonCms::Post.find(post.id)

        expect([post.options, reloaded.options]).to all(eq({}))
        expect([post.get_option(:color, 'none'), reloaded.get_option(:color, 'none')]).to eq(%w[none none])
        reloaded.set_option('color', 'red')
        expect(CamaleonCms::Post.find(post.id).get_option(:color)).to eq('red')
      end
    end
  end

  describe 'a stored meta that repeats a key' do
    # Older writes stored a key twice (json 2 allowed it). A read keeps the last value, as json 2 did,
    # instead of warning under json 2 and failing to parse under json 3.
    around do |example|
      deprecated = Warning[:deprecated]
      Warning[:deprecated] = true
      example.run
    ensure
      Warning[:deprecated] = deprecated
    end

    it 'reads the last value of the repeated key without a warning' do
      post_type = create(:post_type)
      post_type.metas.find_by!(key: '_default').update!(value: '{"has_category":false,"has_category":true}')
      stored = CamaleonCms::PostType.find(post_type.id)

      has_category = nil
      expect { has_category = stored.get_option(:has_category) }.not_to output(/duplicate key/).to_stderr
      expect(has_category).to be(true)
    end
  end

  # set_meta memoizes the value the caller passed while the row stores it as text, so the writing instance
  # answered with the caller's value and every other read, a reload's included, with the stored form: a
  # boolean as the column's 't' or 'f', which every reader takes as present, and the hashes in an array
  # with String keys only.
  describe 'a value that the text column or JSON would change' do
    let(:post_type) { installed_post_type }

    it 'stores a boolean so it reads back as the boolean' do
      post = create(:post, post_type: post_type)
      post.set_meta('probe_flag', false)

      expect(post.reload.get_meta('probe_flag', 'default')).to be(false)
      expect(CamaleonCms::Post.find(post.id).get_meta('probe_flag', 'default')).to be(false)
    end

    it 'reads the hashes in a stored array by either key type' do
      post = create(:post, post_type: post_type)
      post.set_meta('probe_slides', [{ title: 'a' }])

      slides = post.reload.get_meta('probe_slides')
      expect(slides.first[:title]).to eq('a')
      expect(slides.first['title']).to eq('a')
    end

    # earlier releases stored a boolean as the column's 't' or 'f'
    it 'reads a boolean stored as the column cast and stores it again as the boolean' do
      post = create(:post, post_type: post_type)
      post.metas.create!(key: 'probe_legacy', value: 'f')

      expect(CamaleonCms::Post.find(post.id).get_meta('probe_legacy', 'default')).to be(false)
      expect(post.metas.find_by!(key: 'probe_legacy').value).to eq('false')
    end

    it 'reads such a boolean without storing it where writes are prevented' do
      post = create(:post, post_type: post_type)
      post.metas.create!(key: 'probe_legacy', value: 't')

      ActiveRecord::Base.while_preventing_writes do
        expect(CamaleonCms::Post.find(post.id).get_meta('probe_legacy')).to be(true)
      end
      expect(post.metas.find_by!(key: 'probe_legacy').value).to eq('t')
    end

    # Storing the boolean again is a write made while reading, so whatever it raises leaves the row for a
    # later read and the read returns the boolean.
    it 'reads such a boolean when storing it again raises' do
      post = create(:post, post_type: post_type)
      post.metas.create!(key: 'probe_legacy', value: 't')
      loaded = CamaleonCms::Post.includes(:metas).find(post.id)
      legacy = loaded.metas.find { |meta| meta.key == 'probe_legacy' }
      allow(legacy).to receive(:update_column).and_raise(FrozenError, 'frozen meta')

      expect(loaded.get_meta('probe_legacy')).to be(true)
      expect(post.metas.find_by!(key: 'probe_legacy').value).to eq('t')
    end
  end
end
