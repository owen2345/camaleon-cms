# frozen_string_literal: true

# set_field_value stores the items of a list with the orders that follow the order of the call.
# The reads sort by that order only, so items with one order can come back in any order.
RSpec.describe CamaleonCms::CustomFieldsRead, type: :model do
  let(:post_type) { create(:post_type) }
  let(:post) { create(:post, post_type: post_type) }

  before do
    group = CamaleonCms::CustomFieldGroup.create!(name: 'Fields', slug: 'fields',
                                                  object_class: 'PostType_Post', objectid: post_type.id,
                                                  site: post_type.site)
    group.add_manual_field({ name: 'Colors', slug: 'colors' }, { field_key: 'text_box', multiple: true })
  end

  def stored_orders
    post.custom_field_values.where(custom_field_slug: 'colors').pluck(:value, :term_order)
  end

  it 'stores the items of a list with the orders 0, 1, 2 and reads them in that order' do
    post.set_field_value('colors', %w[3 1 2])

    expect(stored_orders).to eq([['3', 0], ['1', 1], ['2', 2]])
    expect(post.reload.get_field_values('colors')).to eq(%w[3 1 2])
  end

  it 'starts the orders of a list at the order of the call' do
    post.save_field_value('colors', %w[b a], 5)

    expect(stored_orders).to eq([['b', 5], ['a', 6]])
  end

  it 'starts the orders of a list at the order that the column stores for a String' do
    post.set_field_value('colors', %w[b a], { order: '3' })

    expect(stored_orders).to eq([['b', 3], ['a', 4]])
  end

  it 'starts the orders of a list at 0 when the order is nil' do
    post.set_field_value('colors', %w[b a], { order: nil })

    expect(stored_orders).to eq([['b', 0], ['a', 1]])
  end

  it 'stores one value with the order of the call' do
    post.set_field_value('colors', 'red', { order: 4 })

    expect(stored_orders).to eq([['red', 4]])
  end

  it 'appends a list after the stored items when the order of the call follows them' do
    post.set_field_value('colors', %w[b a])
    post.set_field_value('colors', %w[d c], { order: 2, clear: false })

    expect(stored_orders).to eq([['b', 0], ['a', 1], ['d', 2], ['c', 3]])
    expect(post.reload.get_field_values('colors')).to eq(%w[b a d c])
  end

  it 'gives the orders of a list as the form save gives them' do
    post.set_field_value('colors', %w[b a])
    from_helper = stored_orders

    post.set_field_values({ '0' => { 'colors' => { values: { '0' => 'b', '1' => 'a' } } } })

    expect(stored_orders).to eq(from_helper)
  end
end
