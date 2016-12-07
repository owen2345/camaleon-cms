json.comments post.the_comments.decorate do |comment|
  json.extract! comment, :id, :user_id, :content, :is_anonymous
  json.children comment.the_answers.decorate do |children|
    json.extract! children, :id, :user_id, :content, :is_anonymous
  end
end