module CamaleonCms
  module ContentHelper
    # initialize content variables
    def cama_content_init
      state = cama_content_state
      state[:before_content] = []
      state[:after_content] = []
    end

    # prepend content for admin or frontend (after <body>)
    # sample: cama_content_prepend(<div>my prepend content</div>)
    def cama_content_prepend(content)
      cama_content_state[:before_content] << content
    end

    # append content for admin or frontend (before </body>)
    # sample: cama_content_prepend(<div>my after content</div>)
    def cama_content_append(content)
      cama_content_state[:after_content] << content
    end

    # draw all before contents registered by cama_content_prepend
    def cama_content_before_draw
      cama_content_state[:before_content].join('')
    rescue StandardError
      ''
    end

    # draw all after contents registered by cama_content_append
    def cama_content_after_draw
      cama_content_state[:after_content].join('')
    rescue StandardError
      ''
    end

    private

    def cama_content_state
      CurrentRequest.content_helper_state ||= { before_content: [], after_content: [] }
    end
  end
end
