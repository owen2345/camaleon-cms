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
      # The writer had already put the value into the memoized options; the refusal drops that memo.
      expect(post_type.options.keys.map(&:to_s)).not_to include(option)
      expect(stored_post_type.get_option(option)).to be_nil
      expect(stored_post_type.get_option('has_tags')).to be(true)
    end

    it 'refuses an unknown class name' do
      expect { post_type.set_option(option, 'Plugins::Missing::Decorator') }
        .to raise_error(ActiveRecord::RecordInvalid, /Plugins::Missing::Decorator/)

      expect(stored_post_type.get_option(option)).to be_nil
    end

    it 'refuses it through set_options and set_multiple_options, with a symbol key too' do
      expect { post_type.set_options(option.to_sym => 'Object') }.to raise_error(ActiveRecord::RecordInvalid)
      expect { post_type.set_multiple_options(option => 'Object', 'has_tags' => true) }
        .to raise_error(ActiveRecord::RecordInvalid)

      expect(stored_post_type.get_option(option)).to be_nil
      expect(stored_post_type.get_option('has_tags')).to be(false)
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

  describe '#post_decorator_class' do
    it 'ignores a stored value that is not a post decorator, warns, and leaves it stored' do
      # A value stored before the option was checked at save.
      meta = post_type.metas.find_by!(key: '_default')
      meta.update!(value: JSON.parse(meta.value).merge(option => 'Object').to_json)
      allow(Rails.logger).to receive(:warn)
      expect(Rails.logger).to receive(:warn).with(/cama_post_decorator_class 'Object'/)

      expect(stored_post_type.post_decorator_class).to eq(CamaleonCms::PostDecorator)
      expect(stored_post_type.get_option(option)).to eq('Object')
    end

    it 'is the default for a post without a post type' do
      expect(CamaleonCms::Post.new.decorator_class).to eq(CamaleonCms::PostDecorator)
    end
  end
end
