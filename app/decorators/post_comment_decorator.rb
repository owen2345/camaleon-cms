class PostCommentDecorator < Draper::Decorator
  delegate_all

  # return created at date formatted
  def the_created_at(format = :long)
    h.l(object.created_at, format: format.to_sym)
  end

  # return owner of this comment
  def the_user
    object.user
  end

  def the_content
    object.content
  end

end
