json.extract! post, :id, :created_at
json.title post.the_title
json.description post.the_excerpt
json.url post.the_url
json.slug post.the_slug
json.thumb post.the_thumb_url