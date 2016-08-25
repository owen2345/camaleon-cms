module CamaleonCms::ContentHelper
  # initialize content variables
  def cama_content_init
    @_before_content = []
    @_after_content = []
  end

  # prepend content for admin or frontend (after <body>)
  # sample: cama_content_prepend(<div>my prepend content</div>)
  def cama_content_prepend(content)
    @_before_content << content
  end

  # append content for admin or frontend (before </body>)
  # sample: cama_content_prepend(<div>my after content</div>)
  def cama_content_append(content)
    @_after_content << content
  end

  # draw all before contents registered by cama_content_prepend
  def cama_content_before_draw
    @_before_content.join("") rescue ""
  end

  # draw all after contents registered by cama_content_append
  def cama_content_after_draw
    @_after_content.join("") rescue ""
  end
end
