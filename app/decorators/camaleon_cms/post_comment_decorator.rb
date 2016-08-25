class CamaleonCms::PostCommentDecorator < Draper::Decorator
  delegate_all

  # return created at date formatted
  def the_created_at(format = :long)
    h.l(object.created_at, format: format.to_sym)
  end

  # return owner of this comment
  def the_user
    object.user.decorate
  end
  alias_method :the_author, :the_user

  def the_post
    object.post.decorate
  end

  def the_content
    object.content
  end

  def the_answers
    object.children.approveds
  end

  def the_author_name
    object.author.presence || object.user.full_name
  end

  def the_author_email
    object.author_email.presence || object.user.email
  end

  def the_author_url
    object.author_url.presence || (object.user.username == 'anonymous' ? '' : object.user.decorate.the_url)
  end

end
