json.extract! @post_type, :created_at, :updated_at, :term_order, :user_id
json.partial! partial: 'partials/cama_post_type_entry', locals:{ post_type: @post_type }
json.posts do
  json.partial! partial: 'partials/cama_posts_entries', locals:{ posts: @posts }
end
json.categories @post_type.categories.decorate do |category|
  json.partial! partial: 'partials/cama_category_entry', locals:{ category: category }
end

json.tags @post_type.post_tags.decorate do |post_tag|
  json.partial! partial: 'partials/cama_tag_entry', locals:{ post_tag: post_tag }
end

