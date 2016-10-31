json.title @category.the_title
json.description @category.the_excerpt
json.link @category.the_url
json.guid @category.the_id
json.thumb @category.the_thumb_url
json.post_type do
  json.partial! partial: 'partials/cama_post_type', locals:{ post_type: @post_type }
end
json.posts do
  json.partial! partial: 'partials/cama_posts_entries', locals:{ posts: @posts }
end
