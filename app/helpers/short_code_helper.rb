module ShortCodeHelper

  # Internal method
  def shortcodes_init
    @_shortcodes = ["widget"]
    @_shortcodes_template = {}
    @_shortcodes_descr = {}
  end

  # add shortcode
  # key: chortcode key
  # template: template to render, if nil will render "shortcode_templates/<key>"
  # descr: description for shortcode
  def shortcode_add(key, template = nil, descr = '')
    @_shortcodes << key
    @_shortcodes_template = @_shortcodes_template.merge({"#{key}"=> template}) if template.present?
    @_shortcodes_descr[key] = descr if descr.present?
  end

  # add or update shortcode template
  # key: chortcode key to add or update
  # template: template to render, if nil will render "shortcode_templates/<key>"
  def shortcode_change_template(key, template = nil)
    @_shortcodes_template[key] = template
  end

  # delete shortcode
  # key: chortcode key to delete
  def shortcode_delete(key)
    @_shortcodes.delete(key)
  end

  # run all shortcodes in the content
  # content: (string) text to find a short codes
  # args: custom arguments to pass for short codes render, sample: {owner: my_model, a: true}
    # if args != Hash, this will re send as args = {owner: args}
  def do_shortcode(content, args = {})
    args = {owner: args} unless args.is_a?(Hash)
    content.scan(/(\[(#{@_shortcodes.join("|")})\s?(.*?)\])/) do |item|
      shortcode, code, attrs = item
      res = render :file => (@_shortcodes_template[code].present? ? @_shortcodes_template[code] : "shortcode_templates/#{code}"), :locals => {attributes: _shortcode_parse_attr(attrs), args: args}
      content = content.sub(shortcode, res)
    end
    content
  end

  # render direct a shortcode
  # template: custom template to be rendered for this short code
  # sample: render_shortcode("[slider_basic as]")
  # sample2: render_shortcode("[slider_basic as]", theme_view("custom_slider"))
  def render_shortcode(shortcode, template = nil)
    shortcode, code, attrs = shortcode.scan(/(\[(#{@_shortcodes.join("|")})\s?(.*?)\])/).first
    template ||= (@_shortcodes_template[code].present? ? @_shortcodes_template[code] : "shortcode_templates/#{code}")
    render :file => template, :locals => {attributes: _shortcode_parse_attr(attrs)}
  end

  private
  def _shortcode_parse_attr(text)
    res = {}
    return res unless text.present?
    text.scan(/(\w+)\s*=\s*"([^"]*)"(?:\s|$)|(\w+)\s*=\s*\'([^\']*)\'(?:\s|$)|(\w+)\s*=\s*([^\s\'"]+)(?:\s|$)|"([^"]*)"(?:\s|$)|(\S+)(?:\s|$)/).each do |item|
      item.each_with_index do |c, index|
        if c.present?
          res[c] = item[index+1]
          break
        end
      end
    end
    res
  end



end
