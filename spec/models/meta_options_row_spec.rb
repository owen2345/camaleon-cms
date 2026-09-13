# frozen_string_literal: true

# A record's options live in one meta row (`_default`) holding a JSON object. A row that holds anything
# else -- legacy data, a corrupt import -- made every reader and writer raise (`get_option` called
# `key?` on a String, `set_option` called `with_indifferent_access`), so the record's pages 500 and
# nothing could repair it. The options of such a row read as empty and a write starts from empty,
# replacing the row; the row itself is left alone until then.
RSpec.describe CamaleonCms::Metas, type: :model do
  let(:site) { CamaleonCms::Site.first }
  let(:post_type) { site.post_types.find_by(slug: 'post') }
  let(:record) { create(:post, post_type: post_type) }

  def reload(post_record)
    CamaleonCms::Post.find(post_record.id)
  end

  describe 'an options row that is not a JSON object' do
    %w[corrupt [] 42].each do |stored|
      it "reads as empty when the row holds #{stored}" do
        record.set_meta('_default', stored)
        stored_record = reload(record)

        expect(stored_record.options).to eq({})
        expect(stored_record.get_option('status_default', 'fallback')).to eq('fallback')
        expect(stored_record.get_option('status_default')).to be_nil
      end
    end

    it 'takes a written option, starting from empty' do
      record.set_meta('_default', 'corrupt')
      stored_record = reload(record)

      stored_record.set_option('status_default', 'published')

      expect(reload(record).get_option('status_default')).to eq('published')
      expect(reload(record).options.keys).to eq(['status_default'])
    end

    it 'leaves the row as it is until an option is written' do
      record.set_meta('_default', 'corrupt')

      reload(record).options

      expect(reload(record).get_meta('_default')).to eq('corrupt')
    end
  end
end
