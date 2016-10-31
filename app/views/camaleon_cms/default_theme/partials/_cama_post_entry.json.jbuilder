json.extract! post, :created_at, :updated_at, :status, :post_parent, :published_at, :user_id, :post_order, :is_feature
json.title post.the_title
json.description post.the_excerpt
json.content post.the_content
json.url post.the_url
json.slug post.the_slug
json.thumb post.the_thumb_url