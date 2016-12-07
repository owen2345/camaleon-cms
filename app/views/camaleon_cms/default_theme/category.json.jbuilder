json.extract! @category, :created_at, :updated_at, :term_order, :user_id
json.partial! partial: 'partials/cama_category_entry', locals:{ category: @category }

json.post_type do
  json.partial! partial: 'partials/cama_post_type_entry', locals:{ post_type: @category.post_type.decorate }
end

json.posts do
  json.partial! partial: 'partials/cama_posts_entries', locals:{ posts: @posts }
end

json.children @category.children.decorate do |category|
  json.partial! partial: 'partials/cama_category_entry', locals:{ category: category }
end

