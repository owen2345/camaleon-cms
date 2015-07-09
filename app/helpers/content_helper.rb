module ContentHelper
  # initialize content variables
  def content_init
    @_before_content = []
    @_after_content = []
  end

  # prepend content for admin or frontend (after <body>)
  def content_prepend(content)
    @_before_content << content
  end

  # append content for admin or frontend (before </body>)
  def content_append(content)
    @_after_content << content
  end

  # draw all before contents
  def content_before_draw
    @_before_content.join("")
  end

  # draw all after contents
  def content_after_draw
    @_after_content.join("")
  end
end