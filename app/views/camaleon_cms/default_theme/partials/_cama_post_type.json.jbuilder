json.extract! post_type, :created_at, :updated_at, :term_order
json.title post_type.the_title
json.description post_type.the_excerpt
json.url post_type.the_url
json.slug post_type.the_slug
json.thumb post_type.the_thumb_url