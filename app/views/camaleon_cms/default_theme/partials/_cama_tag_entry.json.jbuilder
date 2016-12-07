json.extract! post_tag, :id, :created_at
json.title post_tag.the_title
json.description post_tag.the_excerpt
json.url post_tag.the_url
json.slug post_tag.the_slug