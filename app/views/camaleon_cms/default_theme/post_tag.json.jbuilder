json.extract! @post_tag, :created_at, :updated_at, :term_order, :user_id
json.partial! partial: 'partials/cama_tag_entry', locals:{ post_tag: @post_tag }

json.post_type do
  json.partial! partial: 'partials/cama_post_type_entry', locals:{ post_type: @post_tag.post_type.decorate }
end

json.posts do
  json.partial! partial: 'partials/cama_posts_entries', locals:{ posts: @posts }
end