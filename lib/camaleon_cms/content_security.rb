# frozen_string_literal: true

module CamaleonCms
  # SVG content security is now handled by CamaleonCms::SvgContentChecker
  # (Nokogiri XML parse-based detection). These patterns are retained for non-SVG file
  # scanning as a defense-in-depth layer.
  module ContentSecurity
    UNSAFE_EVENT_PATTERNS = %w[
      onabort onafter onbefore onbegin onblur oncanplay onchange onclick oncontextmenu oncopy oncuechange oncut
      ondblclick ondrag ondrop ondurationchange onend onended onerror onfocus onhashchange oninvalid oninput onkey
      onload onmessage onmouse ononline onoffline onpagehide onpageshow onpage onpaste onpause onplay onpopstate
      onprogress onpropertychange onratechange onreadystatechange onrepeat onreset onresize onscroll onsearch onseek
      onselect onshow onstalled onstorage onsuspend ontimeupdate ontoggle onunloadonsubmit onvolumechange onwaiting
      onwheel
    ].map { |pattern| /#{pattern}\w*\s*=/i }.freeze

    SUSPICIOUS_PATTERNS = (UNSAFE_EVENT_PATTERNS + [
      /<script[\s>]/i,
      /javascript:/i,
      /<iframe[\s>]/i,
      /<object[\s>]/i,
      /<embed[\s>]/i,
      /<base[\s>]/i,
      /data:/i
    ]).freeze
  end
end
