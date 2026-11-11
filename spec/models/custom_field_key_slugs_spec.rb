# frozen_string_literal: true

# KeySlugs tells, with no query, which slugs where(custom_field_slug: key) reads. Each example of the
# list compares the two reads for each stored slug.
RSpec.describe CamaleonCms::CustomFieldsRelationship::KeySlugs do
  let(:model) { CamaleonCms::CustomFieldsRelationship }
  let(:rows) do
    ['note', 'other', '5', '2020-01-01', '2020-01-01 00:00:00', nil].map do |slug|
      model.create!(custom_field_slug: slug, custom_field_id: 1, value: 'v')
    end
  end

  [
    'note', :note, 5, nil, %w[note other], [:note, 5], ['note', nil], [], [['note']], [%w[note other]],
    [['note'], nil], [false, 'note'], 'n'..'o', 'n'...'other', 'o'.., ..'n', 4..6, ['other', 'n'..'o'], [nil, 'n'..'o'],
    # The database reads a Set as a list.
    Set['note', 'other'], Set['note', nil], [Set['note']], Set['n'..'o'],
    # The database reads an infinite bound as no bound. A Range from Infinity or to -Infinity with no
    # other bound reads no slug.
    1..Float::INFINITY, -Float::INFINITY..5, Float::INFINITY..5, 1..-Float::INFINITY,
    -Float::INFINITY..Float::INFINITY, Float::INFINITY..Float::INFINITY, ..-Float::INFINITY,
    # The database reads a Date or a Time key as the String that the connection quotes.
    Date.new(2020, 1, 1), Time.utc(2020, 1, 1), Date.new(2020, 1, 1)..Date.new(2020, 1, 2),
    [Date.new(2020, 1, 1), 'note']
  ].each do |key|
    it "reads the slugs that the database reads for the key #{key.inspect}" do
      stored = model.where(id: rows.map(&:id), custom_field_slug: key).pluck(:custom_field_slug)
      key_slugs = described_class.new(key)

      expect(rows.map(&:custom_field_slug).select { |slug| key_slugs.include?(slug) }).to match_array(stored)
    end
  end

  # The database raises an error for a Hash key.
  it 'reads no slug for a Hash key' do
    expect(described_class.new({ a: 1 }).include?('note')).to be(false)
  end

  # On SQLite, the connection cannot quote a binary String with a byte that is not ASCII. The
  # database then raises an error for such a key.
  it 'reads no slug for a key that the connection cannot quote' do
    key_slugs = described_class.new((+"note\xFF").force_encoding(Encoding::BINARY))

    expect(rows.map(&:custom_field_slug).select { |slug| key_slugs.include?(slug) }).to eq([])
  end
end
