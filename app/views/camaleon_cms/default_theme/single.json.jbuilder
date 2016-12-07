json.partial! partial: 'partials/cama_post_entry', locals:{ post: @post }
json.extract! @post, :post_type_id, :created_at, :updated_at, :status, :post_parent, :published_at, :user_id, :post_order, :is_feature
json.content @post.the_content
json.visits @post.total_visits
json.urls @post.the_urls

json.partial! partial: 'partials/cama_comments_entry', locals:{ post: @post }

json.fields @post.the_fields_grouped(@post.field_values.pluck(:custom_field_slug))

json.categories @post.categories.decorate do |category|
  json.partial! partial: 'partials/cama_category_entry', locals:{ category: category }
end

json.tags @post.post_tags.decorate do |post_tag|
  json.partial! partial: 'partials/cama_tag_entry', locals:{ post_tag: post_tag }
end

json.owner do
  json.partial! partial: 'partials/cama_user_entry', locals:{ user: @post.the_author }
end
