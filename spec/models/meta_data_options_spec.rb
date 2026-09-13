# frozen_string_literal: true

# data_options and data_metas are written to a record's options and metas when it is saved, but they stayed
# assigned: every later save of the same instance wrote them again, over any value set since. A post type
# also skipped its data_metas when it was created and wrote them on its first update instead.
RSpec.describe CamaleonCms::Metas do
  let(:site) { CamaleonCms::Site.first }

  it 'keeps a later option write when a post type created with data_options is updated' do
    post_type = site.post_types.create!(name: 'Catalog', slug: 'catalog', data_options: { has_category: true })
    post_type.set_option(:has_category, false)

    post_type.update!(name: 'Products')

    expect(CamaleonCms::PostType.find(post_type.id).get_option(:has_category)).to be(false)
  end

  it 'stores the data_metas a post type is created with' do
    post_type = site.post_types.create!(name: 'Catalog', slug: 'catalog', data_metas: { icon_color: 'red' })

    expect(CamaleonCms::PostType.find(post_type.id).get_meta('icon_color')).to eq('red')
  end

  it 'keeps later writes when a post created with data_options and data_metas is updated' do
    post = create(:post, data_options: { has_comments: true }, data_metas: { subtitle: 'first' })
    post.set_option(:has_comments, false)
    post.set_meta('subtitle', 'second')

    post.update!(title: 'Renamed')

    stored = CamaleonCms::Post.find(post.id)
    expect(stored.get_option(:has_comments)).to be(false)
    expect(stored.get_meta('subtitle')).to eq('second')
  end

  it 'writes data_options given to an update once' do
    post = create(:post)
    post.update!(data_options: { has_comments: true })
    expect(CamaleonCms::Post.find(post.id).get_option(:has_comments)).to be(true)
    post.set_option(:has_comments, false)

    post.update!(title: 'Renamed')

    expect(CamaleonCms::Post.find(post.id).get_option(:has_comments)).to be(false)
  end
end
