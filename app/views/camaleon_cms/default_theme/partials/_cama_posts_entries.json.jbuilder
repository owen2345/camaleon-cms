json.current_page  posts.current_page
json.per_page posts.per_page
json.total_entries posts.total_entries
json.previous_page url_for(params.merge(page: posts.previous_page)) if posts.previous_page.present?
json.next_page url_for(params.merge(page: posts.next_page)) if posts.next_page.present?
json.entries posts.decorate do |post|
  json.partial! partial: 'partials/cama_post_entry', locals:{ post: post }
end