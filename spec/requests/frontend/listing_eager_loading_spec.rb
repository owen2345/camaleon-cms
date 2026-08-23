# frozen_string_literal: true

# Guards the three frontend listing actions (category / post_type / post_tag). They paginate
# `<taxonomy>.the_posts`, which runs through verify_front_visibility -> Post.with_eager. The guard
# lives at the request level -- exercising the real controller relation the view iterates -- so that
# removing the preload (or letting it promote to a join) fails a spec. The helper/model specs pin the
# scope shape; this pins that the listing pages actually load their posts' associations up front.
RSpec.describe 'Frontend listing eager loading', type: :request do
  init_site

  let(:post_type) { @site.the_post_type('post').decorate }
  let(:headers) { { 'HTTP_HOST' => @site.slug } }

  def create_post(slug)
    post_type.posts.create!(title: "Listing #{slug}", slug: slug, status: 'published')
  end

  def metas_query_count(&block)
    sql_queries(matching: /FROM\s+["'`]?metas["'`]?/i, &block).size
  end

  it 'renders the post_type, category and post_tag listings' do
    post = create_post('listing-render-probe')
    category = post_type.categories.first || post_type.categories.create!(name: 'Probe', slug: 'listing-probe-cat')
    post.assign_category([category.id])
    post.update_tags('listing-probe-tag')
    tag = post_type.post_tags.find_by(name: 'listing-probe-tag')

    get post_type.the_url(as_path: true), headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(post.title)

    get category.decorate.the_url(as_path: true), headers: headers
    expect(response).to have_http_status(:ok)

    get tag.decorate.the_url(as_path: true), headers: headers
    expect(response).to have_http_status(:ok)
  end

  it 'preloads the listed posts metas instead of an N+1 (constant metas queries as posts grow)' do
    create_post('listing-eager-1')
    path = post_type.the_url(as_path: true)

    one_post_metas = metas_query_count { get path, headers: headers }
    expect(response).to have_http_status(:ok)

    3.times { |i| create_post("listing-eager-more-#{i}") }
    four_post_metas = metas_query_count { get path, headers: headers }
    expect(response).to have_http_status(:ok)

    # with_eager batch-loads every listed post's metas in one query, so adding posts must not add
    # per-post metas selects. Without the preload each extra post issues its own get_meta lookups.
    expect(four_post_metas - one_post_metas).to be <= 1
  end

  it 'never promotes the listing into a multi-way joined query' do
    create_post('listing-join-probe')

    joins = sql_queries(matching: /LEFT OUTER JOIN/i) do
      get post_type.the_url(as_path: true), headers: headers
    end

    expect(joins).to all(satisfy { |sql| sql.scan(/LEFT OUTER JOIN/i).size <= 1 })
  end
end
